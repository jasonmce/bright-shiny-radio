#!/bin/bash

####
# Raspberry Pi FM Transmitter Playback Script
#
# Description:
#   This script continuously plays a specified audio file (`song.wav`) via
#   an FM transmitter using PiFmRds, and logs each playback event to a
#   remote server. It is designed for use on a Raspberry Pi with the
#   PiFmRds software installed and configured.
#
# Requirements:
#   - Raspberry Pi with PiFmRds installed
#   - `song.wav` must be located in the same directory as this script
#   - Internet connection for posting playback history
#   - URL and Credentials to post API  playback history
#
# Behavior:
#   - Loops indefinitely, playing `song.wav` and posting playback logs
#   - Handles graceful exit on user interruption (CTRL-C)
####

# Application identifier for journalctl
APP_NAME="player.sh"

# Color codes for console output
COLOR_RESET='\033[0m'
COLOR_INFO='\033[1;32m'  # Bright green
COLOR_ERROR='\033[1;31m' # Bright red

# Global error counter
ERROR_COUNT=0

# Displays a terminal message and log it.
log_info() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${COLOR_INFO}[$timestamp] [INFO]  $message${COLOR_RESET}"
    logger --tag "$APP_NAME" --priority user.info "$message"
}

# Displays a terminal message, log it, and increments an error counter.
log_error() {
    local message="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${COLOR_ERROR}[$timestamp] [ERROR] $message${COLOR_RESET}" >&2
    logger --tag "$APP_NAME" --priority user.err "$message"
    ((ERROR_COUNT++))
}

log_info "Starting " $APP_NAME

# Validate the presence of required files and directories
if [ ! -x ./pi_fm_rds ]; then
    log_error "Error: pi_fm_rds not found or not executable in current directory."
fi

if [ ! -f "/home/pi/song.wav" ]; then
    log_error "There is no song.wav file to transmit"
fi

CONFIG_FILE="/home/pi/player.ini"

# Load configuration file
if [[ -f "$CONFIG_FILE" ]]; then
    source <(grep -E "^[a-zA-Z_]+=.+" "$CONFIG_FILE")
else
    log_error "No player.ini configuration file found"
fi

log_info "Using configuration:"
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

if ! [[ -n "$DURATION" && "$DURATION" =~ ^[0-9]+$ ]]; then
    log_error "DURATION must be an integer value (seconds), $DURATION given"
fi
if (( $DURATION < 5 )) || (( $DURATION > 1114 )); then
    log_error "DURATION must be between 5 seconds and 1114 seconds (Alices Restaurant), $DURATION given"
fi

# Check URL format (basic check)
if ! [[ "$API_URL" =~ ^https?:// ]]; then
    log_error "API_URL must start with http:// or https://, $API_URL given"
fi

if [ $ERROR_COUNT -ne 0 ]; then
    echo "Exiting due to errors."
    exit 1
fi

# Set the RDS -ps flag if the station name is set.
PS_FLAG=$([ -n "$STATION_NAME" ] && echo "-ps $STATION_NAME" || echo "$d")

#Function of what trap command calls
function ctrl_c() {
    printf "\n** Trapped CTRL-C after $i seconds.\n"
    exit 0
}
trap ctrl_c INT

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
    # Post playback info to API.
    post_song_to_api

    # Transmit the song to our listening audience.
    play_song

done
