#!/bin/bash

####
# Raspberry Pi FM Transmitter Playback Script
#
# Description:
#   Continuously broadcasts a specified audio file (`song.wav`) on FM
#   using PiFmRds, and posts playback events to a remote API.
#
# Requirements:
#   - Running on a Raspberry Pi
#   - `pi_fm_rds` in the same directory as this script and executable
#   - `player.ini` with valid configuration and located in /home/pi
#   - `song.wav` must be located in the same directory as this script
#
# Optional:
#   - Internet connection for posting playback history
#   - URL and Credentials to post API  playback history
#   - 20-40 cm solid core wire antenna connected to Raspberry Pi GPIO pin 4
#     Without an antenna your broadcast will be very weak
#
# Behavior:
#   - Loops indefinitely, playing `song.wav` and posting playback logs
#   - Handles graceful exit on user interruption (CTRL-C)
#
# Optional Flags:
#   --configtest   Verifies configuration and presence of required files
#   --status       List logged errors from the last 24 hours.
#                  Exits with code 0 if no errors, or 1 if errors exist.
####

# Application identifier for journalctl
APP_NAME="player.sh"
CONFIG_FILE="player.ini"

# Flags for admin tasks
do_configtest=false
do_status=false

# Color codes for console output
COLOR_RESET='\033[0m'
COLOR_INFO='\033[1;32m'  # Bright green
COLOR_ERROR='\033[1;31m' # Bright red

# Global error counter
ERROR_COUNT=0

log_info() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${COLOR_INFO}[$timestamp] [INFO]  $message${COLOR_RESET}"
    logger --tag "$APP_NAME" --priority user.info "$message"
}

log_error() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${COLOR_ERROR}[$timestamp] [ERROR] $message${COLOR_RESET}" >&2
    logger --tag "$APP_NAME" --priority user.err "$message"
    ((ERROR_COUNT++))
}

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --configtest) do_configtest=true ;;
        --status)     do_status=true ;;
        *) log_error "Unknown argument: $arg"; exit 2 ;;
    esac
done

### Status check
# Display errors from the last 24 hours and use an exit code.
if [ "$do_status" == true ]; then
    error_list=$(journalctl --quiet -p err --since "24 hours ago" --identifier "$APP_NAME" --no-pager)
    if [[ -z "$error_list" ]]; then
        echo "No errors in the last 24 hours"
        exit 0
    else
        echo "Errors in the last 24 hours:"
        echo "$error_list"
        exit 1
    fi
fi

log_info "Starting $APP_NAME"

# Validate the presence of required files
[[ -x ./pi_fm_rds ]] || log_error "pi_fm_rds not found or not executable"
[[ -f ./song.wav ]] || log_error "song.wav file not found"

# Load configuration file and validate
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "$CONFIG_FILE file not found"
else
    log_info "Loading configuration from $CONFIG_FILE"
    source <(grep -E "^[a-zA-Z_]+=.+" "$CONFIG_FILE")

    log_info "Broadcasting on Frequency: $FREQUENCY"
    log_info "RDS Station Name: $STATION_NAME"
    log_info "Artist: $ARTIST"
    log_info "Title: $TITLE"
    log_info "Duration: $DURATION seconds"
    log_info "API url: $API_URL"
    log_info "API security token: $API_KEY"

    # Validate frequency is a single decimal floating point number between 87.0 and 108.0.
    if ! [[ -n "$FREQUENCY" && "$FREQUENCY" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        log_error "FREQUENCY must be a numeric value, $FREQUENCY given"
    fi
    if ! awk -v f="$FREQUENCY" 'BEGIN { exit (f >= 87.0 && f <= 108.0) ? 0 : 1 }'; then
        log_error "FREQUENCY must be between 87.0 and 108.0, $FREQUENCY given"
    fi

    [[ -n "$STATION_NAME" && ${#STATION_NAME} -gt 8 ]] && log_error "STATION_NAME must be 8 characters or less, got: '$STATION_NAME'"

    [[ ! -n "$ARTIST" || ${#ARTIST} -gt 60 ]] && log_error "ARTIST must be between 1 and 60 characters, got: '$ARTIST'"
    [[ ! -n "$TITLE" || ${#TITLE} -gt 60 ]] && log_error "TITLE must be between 1 and 60 characters, got: '$TITLE'"

    # Validate combined length of ARTIST and TITLE is no more than 64 characters
    combined_length=$(( ${#ARTIST} + ${#TITLE} + 3 ))  # +3 for " - " separator in RDS
    if (( combined_length > 64 )); then
        log_error "Combined ARTIST and TITLE length must be less than 62 characters (currently $combined_length) ARTIST='$ARTIST', TITLE='$TITLE'"
    fi

    # Validate duration (5 seconds to Alices Restaurant)
    if ! [[ "$DURATION" =~ ^[0-9]+$ ]]; then
        log_error "DURATION must be an integer, got: $DURATION"
    elif (( DURATION < 5 || DURATION > 1114 )); then
        log_error "DURATION must be between 5 and Alices Restaurant (1114 seconds), got: $DURATION"
    fi

    # Check URL format (basic check)
    if ! [[ "$API_URL" =~ ^https?:// ]]; then
        log_error "API_URL must start with http:// or https://, $API_URL given"
    fi
fi

if [ $ERROR_COUNT -ne 0 ]; then
    echo "Exiting due to errors."
    exit 1
fi

## Exit now cleanly if we are doing a configuration test.
if [ "$do_configtest" == true ]; then
    log_info "Configuration test passed."
    exit 0
fi

# Set the RDS -ps flag if the station name is set.
PS_FLAG=$([ -n "$STATION_NAME" ] && echo "-ps $STATION_NAME" || echo "$d")

# Handle CTRL-C to exit cleanly
trap 'echo -e "\n** Caught CTRL-C. Exiting."; exit 0' INT

# Post a message to the API to indicate that the script has started.
post_song_to_api() {
    POST_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
      -H "Content-Type: application/json" \
      -H "apikey: $API_KEY" \
      -d "{\"artist\": \"$ARTIST\", \"title\": \"$TITLE\", \"duration\": $DURATION}" \
      "$API_URL")

    if [ "$POST_RESPONSE" -ne 200 ]; then
        log_error "Error: Failed to post playback info to API. HTTP status code: $POST_RESPONSE"
    else
        log_info "Successfully posted playback info to API."
    fi
}

# Play the song using pi_fm_rds.
# Exit gracefully on failure, because there is no point continuing.
play_song() {
    if ! sudo ./pi_fm_rds -freq "$FREQUENCY" -audio song.wav -rt "$ARTIST - $TITLE" $PS_FLAG; then
        log_error "Error: Failed to transmit using pi_fm_rds. Exiting."
        exit 1
    fi
}

## Transmitter player loop.
while :
do
    post_song_to_api
    play_song
done
