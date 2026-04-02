#!/bin/bash

# Enable strict bash mode to stop the script if an uninitialized variable is used, if a command fails, or if a command with a pipe fails
# Not working in some setups: https://github.com/tigerblue77/Dell_iDRAC_fan_controller/issues/48
# set -euo pipefail

source functions.sh
source constants.sh

# Trap the signals for container exit and run graceful_exit function
trap 'graceful_exit' SIGINT SIGQUIT SIGTERM

# Prepare, format and define initial variables

# Read new parameters from environment variables with defaults
FAN_STEP=${FAN_STEP:-$DEFAULT_FAN_STEP}
CPU_TEMPERATURE_THRESHOLD_MAX=${CPU_TEMPERATURE_THRESHOLD_MAX:-80}
IDRAC_RETRY_COUNT=${IDRAC_RETRY_COUNT:-$DEFAULT_IDRAC_RETRY_COUNT}
IDRAC_RETRY_DELAY=${IDRAC_RETRY_DELAY:-$DEFAULT_IDRAC_RETRY_DELAY}

# Make these readonly after reading
readonly FAN_STEP
readonly IDRAC_RETRY_COUNT
readonly IDRAC_RETRY_DELAY

# Check if FAN_SPEED variable is in hexadecimal format. If not, convert it to hexadecimal
if [[ "$FAN_SPEED" == 0x* ]]; then
  readonly DECIMAL_FAN_SPEED=$(convert_hexadecimal_value_to_decimal "$FAN_SPEED")
  readonly HEXADECIMAL_FAN_SPEED="$FAN_SPEED"
else
  readonly DECIMAL_FAN_SPEED="$FAN_SPEED"
  readonly HEXADECIMAL_FAN_SPEED=$(convert_decimal_value_to_hexadecimal "$FAN_SPEED")
fi

# Initialize CURRENT_FAN_SPEED to the preset fan speed
CURRENT_FAN_SPEED=$DECIMAL_FAN_SPEED

# Set the IDRAC_LOGIN_STRING using the function
set_iDRAC_login_string "$IDRAC_HOST" "$IDRAC_USERNAME" "$IDRAC_PASSWORD"

if ! execute_with_retry $IDRAC_RETRY_COUNT $IDRAC_RETRY_DELAY "get_Dell_server_model"; then
  print_error_and_exit "Failed to get Dell server model from iDRAC after $IDRAC_RETRY_COUNT retries"
fi

if [[ ! $SERVER_MANUFACTURER == "DELL" ]]; then
  print_error_and_exit "Your server isn't a Dell product"
fi

# If server model is Gen 14 (*40) or newer
if [[ $SERVER_MODEL =~ .*[RT][[:space:]]?[0-9][4-9]0.* ]]; then
  readonly DELL_POWEREDGE_GEN_14_OR_NEWER=true
  readonly CPU1_TEMPERATURE_INDEX=2
  readonly CPU2_TEMPERATURE_INDEX=4
else
  readonly DELL_POWEREDGE_GEN_14_OR_NEWER=false
  readonly CPU1_TEMPERATURE_INDEX=1
  readonly CPU2_TEMPERATURE_INDEX=2
fi

# Log main information
echo "Server model: $SERVER_MANUFACTURER $SERVER_MODEL"
echo "iDRAC/IPMI host: $IDRAC_HOST"
echo "Fan speed objective: $DECIMAL_FAN_SPEED%"
echo "Fan speed increase percentage: $FAN_SPEED_INCREASE_PERCENTAGE%"
echo "CPU temperature threshold: $CPU_TEMPERATURE_THRESHOLD°C"
echo "CPU temperature max threshold: $CPU_TEMPERATURE_THRESHOLD_MAX°C"
echo "Check interval: ${CHECK_INTERVAL}s"
echo ""

TABLE_HEADER_PRINT_COUNTER=$TABLE_HEADER_PRINT_INTERVAL
# Set the flag used to check if the active fan control profile has changed
IS_DELL_DEFAULT_FAN_CONTROL_PROFILE_APPLIED=true

# Check present sensors
IS_EXHAUST_TEMPERATURE_SENSOR_PRESENT=true
IS_CPU2_TEMPERATURE_SENSOR_PRESENT=true
retrieve_temperatures $IS_EXHAUST_TEMPERATURE_SENSOR_PRESENT $IS_CPU2_TEMPERATURE_SENSOR_PRESENT
if [ -z "$EXHAUST_TEMPERATURE" ]; then
  echo "No exhaust temperature sensor detected."
  IS_EXHAUST_TEMPERATURE_SENSOR_PRESENT=false
fi
if [ -z "$CPU2_TEMPERATURE" ]; then
  echo "No CPU2 temperature sensor detected."
  IS_CPU2_TEMPERATURE_SENSOR_PRESENT=false
fi
if ! $IS_EXHAUST_TEMPERATURE_SENSOR_PRESENT || ! $IS_CPU2_TEMPERATURE_SENSOR_PRESENT; then
  echo ""
fi

#readonly NUMBER_OF_DETECTED_CPUS=(${CPUS_TEMPERATURES//;/ })
# TODO : write "X CPU sensors detected." and remove previous ifs
readonly HEADER=$(build_header $NUMBER_OF_DETECTED_CPUS)

# Start monitoring
while true; do
  # Sleep for the specified interval before taking another reading
  sleep "$CHECK_INTERVAL" &
  SLEEP_PROCESS_PID=$!

  if ! execute_with_retry $IDRAC_RETRY_COUNT $IDRAC_RETRY_DELAY "retrieve_temperatures $IS_EXHAUST_TEMPERATURE_SENSOR_PRESENT $IS_CPU2_TEMPERATURE_SENSOR_PRESENT"; then
    print_warning "Failed to retrieve temperatures after $IDRAC_RETRY_COUNT retries, skipping this cycle"
    wait $SLEEP_PROCESS_PID
    continue
  fi

  # Initialize a variable to store the comments displayed when the fan control profile changed
  COMMENT=" -"

  # Calculate target fan speed based on highest CPU temperature
  local max_cpu_temp=$CPU1_TEMPERATURE
  if $IS_CPU2_TEMPERATURE_SENSOR_PRESENT && [ "$CPU2_TEMPERATURE" -gt "$max_cpu_temp" ]; then
    max_cpu_temp=$CPU2_TEMPERATURE
  fi

  # Determine target speed based on temperature
  if [ "$max_cpu_temp" -ge "$CPU_TEMPERATURE_THRESHOLD_MAX" ]; then
    # Emergency: apply Dell default dynamic fan control
    apply_Dell_default_fan_control_profile
    if ! $IS_DELL_DEFAULT_FAN_CONTROL_PROFILE_APPLIED; then
      IS_DELL_DEFAULT_FAN_CONTROL_PROFILE_APPLIED=true
      COMMENT="CPU temperature reached max threshold ($CPU_TEMPERATURE_THRESHOLD_MAX°C), Dell default dynamic fan control applied for safety"
    fi
  elif [ "$max_cpu_temp" -ge "$CPU_TEMPERATURE_THRESHOLD" ]; then
    # Within stepped range: calculate and apply target speed
    local target_speed=$(calculate_target_fan_speed "$max_cpu_temp" "$CPU_TEMPERATURE_THRESHOLD" "$CPU_TEMPERATURE_THRESHOLD_MAX")
    CURRENT_FAN_SPEED=$target_speed
    apply_user_fan_control_profile $CURRENT_FAN_SPEED
    if $IS_DELL_DEFAULT_FAN_CONTROL_PROFILE_APPLIED; then
      IS_DELL_DEFAULT_FAN_CONTROL_PROFILE_APPLIED=false
      COMMENT="CPU temperature decreased, stepped fan control resumed at $CURRENT_FAN_SPEED%"
    else
      COMMENT="CPU temperature above threshold, fan speed set to $CURRENT_FAN_SPEED%"
    fi
  else
    # Below threshold: use base fan speed
    if [ "$CURRENT_FAN_SPEED" != "$DECIMAL_FAN_SPEED" ]; then
      CURRENT_FAN_SPEED=$DECIMAL_FAN_SPEED
      apply_user_fan_control_profile $CURRENT_FAN_SPEED
      COMMENT="CPU temperature OK (< $CPU_TEMPERATURE_THRESHOLD°C), fan speed returned to $CURRENT_FAN_SPEED%"
    fi
    IS_DELL_DEFAULT_FAN_CONTROL_PROFILE_APPLIED=false
  fi

  # If server model is not Gen 14 (*40) or newer
  if ! $DELL_POWEREDGE_GEN_14_OR_NEWER; then
    # Enable or disable, depending on the user's choice, third-party PCIe card Dell default cooling response
    # No comment will be displayed on the change of this parameter since it is not related to the temperature of any device (CPU, GPU, etc...) but only to the settings made by the user when launching this Docker container
    if "$DISABLE_THIRD_PARTY_PCIE_CARD_DELL_DEFAULT_COOLING_RESPONSE"; then
      disable_third_party_PCIe_card_Dell_default_cooling_response || print_warning "Failed to disable third-party PCIe card cooling response"
      THIRD_PARTY_PCIE_CARD_DELL_DEFAULT_COOLING_RESPONSE_STATUS="Disabled"
    else
      enable_third_party_PCIe_card_Dell_default_cooling_response || print_warning "Failed to enable third-party PCIe card cooling response"
      THIRD_PARTY_PCIE_CARD_DELL_DEFAULT_COOLING_RESPONSE_STATUS="Enabled"
    fi
  fi

  # Print temperatures, active fan control profile and comment if any change happened during last time interval
  if [ $TABLE_HEADER_PRINT_COUNTER -eq $TABLE_HEADER_PRINT_INTERVAL ]; then
    printf "%s\n" "$HEADER"
    TABLE_HEADER_PRINT_COUNTER=0
  fi
  print_temperature_array_line "$INLET_TEMPERATURE" "$CPUS_TEMPERATURES" "$EXHAUST_TEMPERATURE" "$CURRENT_FAN_CONTROL_PROFILE" "$THIRD_PARTY_PCIE_CARD_DELL_DEFAULT_COOLING_RESPONSE_STATUS" "$COMMENT"
  ((TABLE_HEADER_PRINT_COUNTER++))
  wait $SLEEP_PROCESS_PID
done
