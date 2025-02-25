# Define global functions

# This function applies Dell's default dynamic fan control profile
function apply_Dell_fan_control_profile() {
  ipmitool -I $IDRAC_LOGIN_STRING raw 0x30 0x30 0x01 0x01 > /dev/null
  CURRENT_FAN_CONTROL_PROFILE="Dell default dynamic fan control profile"
}

# This function applies a user-specified static fan control profile with a given speed
function apply_user_fan_control_profile() {
  local speed=$1
  local hex_speed=$(convert_decimal_value_to_hexadecimal $speed)
  ipmitool -I $IDRAC_LOGIN_STRING raw 0x30 0x30 0x01 0x00 > /dev/null
  ipmitool -I $IDRAC_LOGIN_STRING raw 0x30 0x30 0x02 0xff $hex_speed > /dev/null
  CURRENT_FAN_CONTROL_PROFILE="User static fan control profile ($speed%)"
}

# This function increases fan speed by a percentage and ensures it doesn't exceed 100%
function increase_fan_speed() {
  local increase=$1
  local current_speed=$2
  local new_speed=$((current_speed + increase))
  if [ $new_speed -gt 100 ]; then
    new_speed=100
  fi
  echo $new_speed
}

# Convert decimal to hexadecimal
function convert_decimal_value_to_hexadecimal() {
  local -r DECIMAL_NUMBER=$1
  local -r HEXADECIMAL_NUMBER=$(printf '0x%02x' $DECIMAL_NUMBER)
  echo $HEXADECIMAL_NUMBER
}

# Convert hexadecimal to decimal
function convert_hexadecimal_value_to_decimal() {
  local -r HEXADECIMAL_NUMBER=$1
  local -r DECIMAL_NUMBER=$(printf '%d' $HEXADECIMAL_NUMBER)
  echo $DECIMAL_NUMBER
}

# Retrieve temperature sensors data using ipmitool
function retrieve_temperatures() {
  if (( $# != 2 )); then
    print_error "Illegal number of parameters.\nUsage: retrieve_temperatures \$IS_EXHAUST_TEMPERATURE_SENSOR_PRESENT \$IS_CPU2_TEMPERATURE_SENSOR_PRESENT"
    return 1
  fi
  local -r IS_EXHAUST_TEMPERATURE_SENSOR_PRESENT=$1
  local -r IS_CPU2_TEMPERATURE_SENSOR_PRESENT=$2

  local -r DATA=$(ipmitool -I $IDRAC_LOGIN_STRING sdr type temperature | grep degrees)

  # Parse CPU data
  local -r CPU_DATA=$(echo "$DATA" | grep "3\." | grep -Po '\d{2}')
  CPU1_TEMPERATURE=$(echo $CPU_DATA | awk "{print \$$CPU1_TEMPERATURE_INDEX;}")
  if $IS_CPU2_TEMPERATURE_SENSOR_PRESENT; then
    CPU2_TEMPERATURE=$(echo $CPU_DATA | awk "{print \$$CPU2_TEMPERATURE_INDEX;}")
  else
    CPU2_TEMPERATURE="-"
  fi

  # Parse inlet temperature data
  INLET_TEMPERATURE=$(echo "$DATA" | grep Inlet | grep -Po '\d{2}' | tail -1)

  # If exhaust temperature sensor is present, parse its temperature data
  if $IS_EXHAUST_TEMPERATURE_SENSOR_PRESENT; then
    EXHAUST_TEMPERATURE=$(echo "$DATA" | grep Exhaust | grep -Po '\d{2}' | tail -1)
  else
    EXHAUST_TEMPERATURE="-"
  fi
}

# For Gen 13 and older generation servers
function enable_third_party_PCIe_card_Dell_default_cooling_response() {
  ipmitool -I $IDRAC_LOGIN_STRING raw 0x30 0xce 0x00 0x16 0x05 0x00 0x00 0x00 0x05 0x00 0x00 0x00 0x00 > /dev/null
}

# For Gen 13 and older generation servers
function disable_third_party_PCIe_card_Dell_default_cooling_response() {
  ipmitool -I $IDRAC_LOGIN_STRING raw 0x30 0xce 0x00 0x16 0x05 0x00 0x00 0x00 0x05 0x00 0x01 0x00 0x00 > /dev/null
}

# Prepare traps in case of container exit
function graceful_exit() {
  apply_Dell_fan_control_profile
  if ! $KEEP_THIRD_PARTY_PCIE_CARD_COOLING_RESPONSE_STATE_ON_EXIT; then
    enable_third_party_PCIe_card_Dell_default_cooling_response
  fi
  print_warning_and_exit "Container stopped, Dell default dynamic fan control profile applied for safety"
}

# Get Dell server model
function get_Dell_server_model() {
  local -r IPMI_FRU_content=$(ipmitool -I $IDRAC_LOGIN_STRING fru 2>/dev/null)
  SERVER_MANUFACTURER=$(echo "$IPMI_FRU_content" | grep "Product Manufacturer" | awk -F ': ' '{print $2}')
  SERVER_MODEL=$(echo "$IPMI_FRU_content" | grep "Product Name" | awk -F ': ' '{print $2}')
  if [ -z "$SERVER_MANUFACTURER" ]; then
    SERVER_MANUFACTURER=$(echo "$IPMI_FRU_content" | tr -s ' ' | grep "Board Mfg :" | awk -F ': ' '{print $2}')
  fi
  if [ -z "$SERVER_MODEL" ]; then
    SERVER_MODEL=$(echo "$IPMI_FRU_content" | tr -s ' ' | grep "Board Product :" | awk -F ': ' '{print $2}')
  fi
}

# Define functions to check if CPU temperatures are above the threshold
function CPU1_OVERHEATING() { [ $CPU1_TEMPERATURE -gt $CPU_TEMPERATURE_THRESHOLD ]; }
function CPU2_OVERHEATING() { [ $CPU2_TEMPERATURE -gt $CPU_TEMPERATURE_THRESHOLD ]; }

# Error and warning functions
function print_error() {
  local -r ERROR_MESSAGE="$1"
  printf "/!\ Error /!\ %s." "$ERROR_MESSAGE" >&2
}

function print_error_and_exit() {
  local -r ERROR_MESSAGE="$1"
  print_error "$ERROR_MESSAGE"
  printf " Exiting.\n" >&2
  exit 1
}

function print_warning() {
  local -r WARNING_MESSAGE="$1"
  printf "/!\ Warning /!\ %s." "$WARNING_MESSAGE"
}

function print_warning_and_exit() {
  local -r WARNING_MESSAGE="$1"
  print_warning "$WARNING_MESSAGE"
  printf " Exiting.\n"
  exit 0
}
