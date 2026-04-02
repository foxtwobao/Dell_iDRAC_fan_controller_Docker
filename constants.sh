#!/bin/bash

# Define the interval for printing temperature table header
readonly TABLE_HEADER_PRINT_INTERVAL=10

# Default fan step (temperature degrees per step)
readonly DEFAULT_FAN_STEP=20

# Default number of retries when iDRAC command fails
readonly DEFAULT_IDRAC_RETRY_COUNT=3

# Default delay between retries (seconds)
readonly DEFAULT_IDRAC_RETRY_DELAY=5
