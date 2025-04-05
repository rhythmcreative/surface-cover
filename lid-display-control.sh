#!/bin/bash

# lid-display-control.sh
# Script to monitor Surface Type Cover lid state and control internal display accordingly
# When lid closes: turn off internal display (eDP-1)
# When lid opens: turn on internal display (eDP-1)

# --- Variables ---
INTERNAL_DISPLAY="eDP-1"
LID_STATE_FILE=""
PREVIOUS_STATE=""
SLEEP_INTERVAL=2  # Check every 2 seconds

# --- Functions ---

# Error logging function
log_error() {
    echo "[ERROR] $(date): $1" >&2
}

# Info logging function
log_info() {
    echo "[INFO] $(date): $1"
}

# Find lid state file
find_lid_state_file() {
    # Try the common lid state file location first
    if [ -r "/proc/acpi/button/lid/LID0/state" ]; then
        LID_STATE_FILE="/proc/acpi/button/lid/LID0/state"
        return 0
    fi

    # If not found, try to find any lid state file
    local found_file=$(find /proc/acpi/button/lid -name state 2>/dev/null | head -n 1)
    if [ -n "$found_file" ] && [ -r "$found_file" ]; then
        LID_STATE_FILE="$found_file"
        return 0
    fi

    log_error "No readable lid state file found"
    return 1
}

# Check dependencies
check_dependencies() {
    if ! command -v xrandr >/dev/null 2>&1; then
        log_error "xrandr is not installed or not in PATH"
        return 1
    fi
    return 0
}

# Get current lid state
get_lid_state() {
    if [ ! -r "$LID_STATE_FILE" ]; then
        log_error "Lid state file is not readable: $LID_STATE_FILE"
        return 1
    fi

    local state=$(grep -o "open\|closed" "$LID_STATE_FILE" 2>/dev/null)
    if [ -z "$state" ]; then
        log_error "Could not determine lid state"
        return 1
    fi

    echo "$state"
    return 0
}

# Check if internal display exists
check_internal_display() {
    if ! xrandr --listmonitors | grep -q "$INTERNAL_DISPLAY"; then
        log_error "Internal display $INTERNAL_DISPLAY not found"
        return 1
    fi
    return 0
}

# Turn internal display on
turn_display_on() {
    log_info "Turning internal display ON"
    if ! xrandr --output "$INTERNAL_DISPLAY" --auto; then
        log_error "Failed to turn on internal display"
        return 1
    fi
    return 0
}

# Turn internal display off
turn_display_off() {
    log_info "Turning internal display OFF"
    if ! xrandr --output "$INTERNAL_DISPLAY" --off; then
        log_error "Failed to turn off internal display"
        return 1
    fi
    return 0
}

# Handle lid state changes
handle_lid_state() {
    local current_state="$1"
    
    # If state unchanged, do nothing
    if [ "$current_state" = "$PREVIOUS_STATE" ]; then
        return 0
    fi
    
    log_info "Lid state changed from '$PREVIOUS_STATE' to '$current_state'"
    PREVIOUS_STATE="$current_state"
    
    case "$current_state" in
        "open")
            turn_display_on
            ;;
        "closed")
            turn_display_off
            ;;
        *)
            log_error "Unknown lid state: $current_state"
            return 1
            ;;
    esac
    
    return 0
}

# Cleanup function
cleanup() {
    log_info "Terminating lid-display-control script"
    # Always turn the display back on when exiting
    turn_display_on >/dev/null 2>&1
    exit 0
}

# --- Main ---

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Check dependencies
if ! check_dependencies; then
    exit 1
fi

# Find lid state file
if ! find_lid_state_file; then
    exit 1
fi

log_info "Using lid state file: $LID_STATE_FILE"

# Check if internal display exists
if ! check_internal_display; then
    exit 1
fi

log_info "Monitoring lid state for display $INTERNAL_DISPLAY"

# Get initial lid state
PREVIOUS_STATE=$(get_lid_state)
if [ $? -ne 0 ]; then
    log_error "Failed to get initial lid state"
    exit 1
fi

log_info "Initial lid state: $PREVIOUS_STATE"

# Main loop
while true; do
    current_state=$(get_lid_state)
    if [ $? -eq 0 ]; then
        handle_lid_state "$current_state"
    fi
    sleep "$SLEEP_INTERVAL"
done

