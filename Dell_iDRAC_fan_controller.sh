#!/bin/bash

# Enable strict bash mode to stop the script if an uninitialized variable is used, if a command fails, or if a command with a pipe fails
# Not working in some setups: https://github.com/tigerblue77/Dell_iDRAC_fan_controller/issues/48
# set -euo pipefail

source functions.sh

# Trap the signals for container exit and run graceful_exit function
trap 'graceful_exit' SIGINT SIGQUIT SIGTERM

# Prepare, format and define initial variables

# Read new parameters from environment variables with defaults
FAN_SPEED_INCREASE_PERCENTAGE=${FAN_SPEED_INCREASE_PERCENTAGE:-10}  # Default to 10% if not set
CPU_TEMPERATURE_THRESHOLD_MAX=${CPU_TEMPERATURE_THRESHOLD_MAX:-80}  # Default to 80°C if not set

# Check if FAN_SPEED variable is in hexadecimal format. If not, convert it to hexadecimal
if [[ $FAN_SPEED == 0x* ]]; then
  readonly DECIMAL_FAN_SPEED=$(convert_hexadecimal_value_to_decimal "$FAN_SPEED")
  readonly HEXADECIMAL_FAN_SPEED=$FAN_SPEED
else
  readonly DECIMAL_FAN_SPEED=$FAN_SPEED
  readonly HEXADECIMAL_FAN_SPEED=$(convert_decimal_value_to_hexadecimal "$FAN_SPEED")
fi

# Initialize CURRENT_FAN_SPEED to the preset fan speed
CURRENT_FAN_SPEED=$DECIMAL_FAN_SPEED

# Check if the iDRAC host is set to 'local' or not then set the IDRAC_LOGIN_STRING accordingly
if [[ $IDRAC_HOST == "local" ]]; then
  if [ ! -e "/dev/ipmi0" ] && [ ! -e "/dev/ipmi/0" ] && [ ! -e "/dev/ipmidev/0" ]; then
    print_error_and_exit "Could not open device at /dev/ipmi0 or /dev/ipmi/0 or /dev/ipmidev/0, check that you added the device to your Docker container or stop using local mode"
  fi
  IDRAC_LOGIN_STRING='open'
else
  echo "iDRAC/IPMI username: $IDRAC_USERNAME"
  #echo "iDRAC/IPMI password: $IDRAC_PASSWORD"
  IDRAC_LOGIN_STRING="lanplus -H $IDRAC_HOST -U $IDRAC_USERNAME -P $IDRAC_PASSWORD"
fi

get_Dell_server_model

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

# Define the interval for printing
readonly TABLE_HEADER_PRINT_INTERVAL=10
i=$TABLE_HEADER_PRINT_INTERVAL
# Set the flag used to check if the active fan control profile has changed
IS_DELL_FAN_CONTROL_PROFILE_APPLIED=true

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

# Start monitoring
while true; do
  # Sleep for the specified interval before taking another reading
  sleep $CHECK_INTERVAL &
  SLEEP_PROCESS_PID=$!

  retrieve_temperatures $IS_EXHAUST_TEMPERATURE_SENSOR_PRESENT $IS_CPU2_TEMPERATURE_SENSOR_PRESENT

  # Initialize a variable to store the comments displayed when the fan control profile changed
  COMMENT=" -"
  if [ $CPU1_TEMPERATURE -ge $CPU_TEMPERATURE_THRESHOLD_MAX ] || ($IS_CPU2_TEMPERATURE_SENSOR_PRESENT && [ $CPU2_TEMPERATURE -ge $CPU_TEMPERATURE_THRESHOLD_MAX ]); then
    apply_Dell_fan_control_profile
    if ! $IS_DELL_FAN_CONTROL_PROFILE_APPLIED; then
      IS_DELL_FAN_CONTROL_PROFILE_APPLIED=true
      COMMENT="CPU temperature reached max threshold, Dell default dynamic fan control profile applied for safety"
    fi
  elif [ $CPU1_TEMPERATURE -ge $CPU_TEMPERATURE_THRESHOLD ] || ($IS_CPU2_TEMPERATURE_SENSOR_PRESENT && [ $CPU2_TEMPERATURE -ge $CPU_TEMPERATURE_THRESHOLD ]); then
    # Increase fan speed
    CURRENT_FAN_SPEED=$(increase_fan_speed $FAN_SPEED_INCREASE_PERCENTAGE $CURRENT_FAN_SPEED)
    apply_user_fan_control_profile $CURRENT_FAN_SPEED
    COMMENT="CPU temperature above threshold, increasing fan speed to $CURRENT_FAN_SPEED%"
  else
    # Reset to default fan speed
    CURRENT_FAN_SPEED=$DECIMAL_FAN_SPEED
    apply_user_fan_control_profile $CURRENT_FAN_SPEED
    if $IS_DELL_FAN_CONTROL_PROFILE_APPLIED; then
      IS_DELL_FAN_CONTROL_PROFILE_APPLIED=false
      COMMENT="CPU temperature decreased and is now OK (<= $CPU_TEMPERATURE_THRESHOLD°C), user's fan control profile applied."
    fi
  fi

  # If server model is Gen 14 (*40) or newer
  if ! $DELL_POWEREDGE_GEN_14_OR_NEWER; then
    if $DISABLE_THIRD_PARTY_PCIE_CARD_DELL_DEFAULT_COOLING_RESPONSE; then
      disable_third_party_PCIe_card_Dell_default_cooling_response
      THIRD_PARTY_PCIE_CARD_DELL_DEFAULT_COOLING_RESPONSE_STATUS="Disabled"
    else
      enable_third_party_PCIe_card_Dell_default_cooling_response
      THIRD_PARTY_PCIE_CARD_DELL_DEFAULT_COOLING_RESPONSE_STATUS="Enabled"
    fi
  fi

  # Print temperatures, active fan control profile and comment if any change happened during last time interval
  if [ $i -eq $TABLE_HEADER_PRINT_INTERVAL ]; then
    echo "                     ------- Temperatures -------"
    echo "    Date & time      Inlet  CPU 1  CPU 2  Exhaust          Active fan speed profile          Third-party PCIe card Dell default cooling response  Comment"
    i=0
  fi
  printf "%19s  %3d°C  %3d°C  %3s°C  %5s°C  %40s  %51s  %s\n" "$(date +"%d-%m-%Y %T")" $INLET_TEMPERATURE $CPU1_TEMPERATURE "$CPU2_TEMPERATURE" "$EXHAUST_TEMPERATURE" "$CURRENT_FAN_CONTROL_PROFILE" "$THIRD_PARTY_PCIE_CARD_DELL_DEFAULT_COOLING_RESPONSE_STATUS" "$COMMENT"
  ((i++))
  wait $SLEEP_PROCESS_PID
done
