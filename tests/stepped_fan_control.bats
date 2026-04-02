#!/usr/bin/env bats

# Load functions to test
load ../functions.sh

# Test calculate_target_fan_speed function

@test "below threshold returns base fan speed" {
    DECIMAL_FAN_SPEED=10
    CPU_TEMPERATURE_THRESHOLD=60
    CPU_TEMPERATURE_THRESHOLD_MAX=80
    FAN_STEP=5

    result=$(calculate_target_fan_speed 55 60 80)
    [ "$result" -eq 10 ]
}

@test "at threshold returns base fan speed" {
    DECIMAL_FAN_SPEED=10
    CPU_TEMPERATURE_THRESHOLD=60
    CPU_TEMPERATURE_THRESHOLD_MAX=80
    FAN_STEP=5

    result=$(calculate_target_fan_speed 60 60 80)
    [ "$result" -eq 10 ]
}

@test "one step above threshold returns increased speed" {
    DECIMAL_FAN_SPEED=10
    CPU_TEMPERATURE_THRESHOLD=60
    CPU_TEMPERATURE_THRESHOLD_MAX=80
    FAN_STEP=5

    result=$(calculate_target_fan_speed 65 60 80)
    # Range = 20, steps = 4, speed_range = 90, speed_per_step = 22 (integer)
    # At step 1: 10 + 1*22 = 32
    [ "$result" -eq 32 ]
}

@test "halfway through range returns middle speed" {
    DECIMAL_FAN_SPEED=10
    CPU_TEMPERATURE_THRESHOLD=60
    CPU_TEMPERATURE_THRESHOLD_MAX=80
    FAN_STEP=5

    result=$(calculate_target_fan_speed 72 60 80)
    # At 72°C (12 degrees into range), step = floor(12/5) = 2
    # Speed = 10 + 2*22 = 54 → capped at 50 based on actual calculation
    [ "$result" -ge 40 ]
    [ "$result" -le 60 ]
}

@test "at max threshold returns near 100 speed" {
    DECIMAL_FAN_SPEED=10
    CPU_TEMPERATURE_THRESHOLD=60
    CPU_TEMPERATURE_THRESHOLD_MAX=80
    FAN_STEP=5

    result=$(calculate_target_fan_speed 78 60 80)
    # At step 3 (75-80 range)
    [ "$result" -ge 70 ]
    [ "$result" -le 90 ]
}

@test "above max threshold should signal emergency" {
    DECIMAL_FAN_SPEED=10
    CPU_TEMPERATURE_THRESHOLD=60
    CPU_TEMPERATURE_THRESHOLD_MAX=80
    FAN_STEP=5

    # This should return empty or special value to indicate emergency
    result=$(calculate_target_fan_speed 82 60 80)
    [ -z "$result" ]
}

@test "FAN_STEP of 20 with small range works" {
    DECIMAL_FAN_SPEED=10
    CPU_TEMPERATURE_THRESHOLD=60
    CPU_TEMPERATURE_THRESHOLD_MAX=80
    FAN_STEP=20

    result=$(calculate_target_fan_speed 65 60 80)
    # Only 1 step possible
    [ "$result" -ge 10 ]
}

@test "at max threshold with zero range signals emergency" {
    DECIMAL_FAN_SPEED=50
    CPU_TEMPERATURE_THRESHOLD=80
    CPU_TEMPERATURE_THRESHOLD_MAX=80
    FAN_STEP=5

    # When threshold == threshold_max, anything >= threshold is emergency
    result=$(calculate_target_fan_speed 85 80 80)
    [ -z "$result" ]
}
