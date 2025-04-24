#!/bin/bash

#### Test Suite: player.sh Configuration Validation ####

###
# Description:
#   Validates the response of player.sh to missing files and invalid
#   configuration values.
#
#   It does not test the actual functionality of player.sh.
#
#   This is meant to be run in your development environment before committing
#   changes to the player.sh script.
#
# Optional Flags:
#   --debug   Show verbose debug output.
###

SHOW_DEBUG_OUTPUT=false
if [[ $1 == "--debug" ]]; then
    SHOW_DEBUG_OUTPUT=true
fi

debug_message() {
    if $SHOW_DEBUG_OUTPUT; then
        echo "$1"
    fi
}

backup_file_if_exists() {
    local file=$1
    local backup_file="${file}.bak"

    if [[ -f $file ]]; then
        mv "$file" "$backup_file"
        debug_message "Moved $file to $backup_file"
    else
        debug_message "$file does not exist, no action taken."
    fi
}

restore_file_if_existed() {
    local file=$1
    local backup_file="${file}.bak"

    if [[ -f $backup_file ]]; then
        mv "$backup_file" "$file"
        debug_message "Restored $file from $backup_file"
    else
        debug_message "$backup_file does not exist, no action taken."
    fi
}

# Create a file (backing up existing one)
create_file_if_not_exists() {
    local file=$1

    if [[ -f $file ]]; then
      backup_file_if_exists "$file"
    fi

    touch "$file"
    debug_message "Created $file"
}

# Restore or clean up test-created files
delete_file_if_created() {
    local file=$1
    local backup_file="${file}.bak"

    rm "$file"
    debug_message "removed $file"
    if [[ -f $backup_file ]]; then
        mv "$backup_file" "$file"
        debug_message "Restored $file from $backup_file"
    fi
}

# Helper: Append a config value to player.ini
update_config_file() {
    local key=$1
    local value=$2

    debug_message "Updating config file: $key=$value"
    echo "$key=\"$value\"" >> player.ini
}

# Create a known working environment for the test
create_working_environment() {
    create_file_if_not_exists "song.wav"
    create_file_if_not_exists "pi_fm_rds"
    create_file_if_not_exists "player.ini"

    chmod 755 "pi_fm_rds"
    update_config_file "FREQUENCY" "87.5"
    update_config_file "STATION_NAME" "Station"
    update_config_file "ARTIST" "Artist name"
    update_config_file "TITLE" "Song title"
    update_config_file "DURATION" 60
    update_config_file "API_URL" "http://example.com"
    update_config_file "API_KEY" "SECRET_KEY_HERE"
  }

restore_original_environment() {
    # Restore the original environment
    delete_file_if_created "song.wav"
    delete_file_if_created "pi_fm_rds"
    delete_file_if_created "player.ini"
}

verify_file_missing_error() {
    local file=$1
    local expected_error=$2

    response=$(bash player.sh --configtest 2>&1)
    [[ $? -ne 1 ]] && echo "❌ player.sh did not exit with error code 1\n$response"
    [[ "$response" =~ "$expected_error" ]] || echo "❌ Expected error message $expected_error not found in response\n$response"
}

verify_valid_config() {
    local key=$1
    local value=$2
    local expected_error=$3

    create_working_environment
    update_config_file "$key" "$value"

    response=$(bash player.sh --configtest 2>&1)
    [[ $? -ne 0 ]] && echo "❌ player.sh did not exit with error code 0 when $key=$value\n$response"
    [[ "$response" =~ "$expected_error" ]] && echo "❌ Error message $expected_error found in response when $key=$value\n$response"

    restore_original_environment
}

verify_invalid_config() {
    local key=$1
    local value=$2
    local expected_error=$3

    create_working_environment
    update_config_file "$key" "$value"

    response=$(bash player.sh --configtest 2>&1)
    [[ $? -ne 1 ]] && echo "❌ player.sh did not exit with error code 1 when $key=$value\n$response"
    [[ "$response" =~ "$expected_error" ]] || echo "❌ Error message $expected_error not found in response when $key=$value\n$response"

    restore_original_environment
}

positive_test() {
  create_working_environment

  response=$(bash player.sh --configtest 2>&1)
  [[ $? -ne 0 ]] && echo "❌ player.sh did not exit with error code 0\n$response"
  [[ "$response" =~ "$expected_error" ]] || echo "❌ Expected error message $expected_error not found in response\n$response"

  restore_original_environment
}

echo "▶ Running positive test validation"
positive_test

# Missing file errors
echo "▶ Running missing file tests"
verify_file_missing_error "song.wav" "song.wav file not found"
verify_file_missing_error "pi_fm_rds" "pi_fm_rds not found or not executable"
verify_file_missing_error "player.ini" "player.ini file not found"

# FREQUENCY required float between 87.0 and 108.0.
echo "▶ Running FREQUENCY value tests"
verify_valid_config "FREQUENCY" "87.0" "FREQUENCY must be between 87.0 and 108.0"
verify_valid_config "FREQUENCY" "99.1" "FREQUENCY must be between 87.0 and 108.0"
verify_valid_config "FREQUENCY" "108.0" "FREQUENCY must be between 87.0 and 108.0"

verify_invalid_config "FREQUENCY" "" "FREQUENCY must be between 87.0 and 108.0"
verify_invalid_config "FREQUENCY" "86.0" "FREQUENCY must be between 87.0 and 108.0"
verify_invalid_config "FREQUENCY" "108.1" "FREQUENCY must be between 87.0 and 108.0"
verify_invalid_config "FREQUENCY" "ninety nine one" "FREQUENCY must be between 87.0 and 108.0"

# # STATION_NAME optional string between 1 and 8 characters.
echo "▶ Running STATION_NAME value tests"
verify_valid_config "STATION_NAME" "" "STATION_NAME must be 8 characters or less"
verify_valid_config "STATION_NAME" "99.1" "STATION_NAME must be 8 characters or less"
verify_valid_config "STATION_NAME" "STATION" "STATION_NAME must be 8 characters or less"

verify_invalid_config "STATION_NAME" "EXCESSIVE" "STATION_NAME must be 8 characters or less"

# ARTIST required string between 1 and 60 characters.
# Since the test setup TITLE is 10 characters, we also have to be less than 52
# chars so the combined "artist - title" length is less than 65.
echo "▶ Running ARTIST value tests"
verify_valid_config "ARTIST" "A" "ARTIST must be between 1 and 60 characters"
verify_valid_config "ARTIST" "Valid Artist name" "ARTIST must be between 1 and 60 characters"
verify_valid_config "ARTIST" "this artist name is 51 characters long and is okay!" "ARTIST must be between 1 and 60 characters"

verify_invalid_config "ARTIST" "" "ARTIST must be between 1 and 60 characters"
verify_invalid_config "ARTIST" "this artist name is beyong 60 characters long and should be rejected" "ARTIST must be between 1 and 60 characters"

# TITLE required string between 1 and 60 characters.
# Since the test setup ARTIST is 11 characters, we also have to be less than 51
# chars so the combined "artist - title" length is less than 65.
echo "▶ Running TITLE value tests"
verify_valid_config "TITLE" "A" "TITLE must be between 1 and 60 characters"
verify_valid_config "TITLE" "Valid TITLE name" "TITLE must be between 1 and 60 characters"
verify_valid_config "TITLE" "this TITLE name is 50 characters long and is okay!" "TITLE must be between 1 and 60 characters"

verify_invalid_config "TITLE" "" "TITLE must be between 1 and 60 characters"
verify_invalid_config "TITLE" "this TITLE name is beyong 60 characters long and should be rejected" "TITLE must be between 1 and 60 characters"

# ARTIST + TITLE must be less than 62 characters.  Default artist name is 11 character, song title is 10 characters.
echo "▶ Running ARTIST + TITLE value tests"
verify_valid_config "ARTIST" "this ARTIST name is 50 characters long and is okay" "Combined ARTIST and TITLE length must be less than 62 characters"
verify_valid_config "TITLE" "this TITLE name is 49 characters long and is okay" "Combined ARTIST and TITLE length must be less than 62 characters"

verify_invalid_config "ARTIST" "this ARTIST name is beyong 51 characters long and should be rejected" "Combined ARTIST and TITLE length must be less than 62 characters"
verify_invalid_config "TITLE" "this TITLE name is beyong 60 characters long and should be rejected" "Combined ARTIST and TITLE length must be less than 62 characters"

# DURATION required integer from 5 to 1114.
echo "▶ Running DURATION value tests"
verify_valid_config "DURATION" "5" "DURATION must be between"
verify_valid_config "DURATION" "123" "DURATION must be between"
verify_valid_config "DURATION" "1114" "DURATION must be between"

verify_invalid_config "DURATION" "" "DURATION must be an integer"
verify_invalid_config "DURATION" "short" "DURATION must be an integer"
verify_invalid_config "DURATION" "dunno" "DURATION must be an integer"

verify_invalid_config "DURATION" "0" "DURATION must be between"
verify_invalid_config "DURATION" "4" "DURATION must be between"
verify_invalid_config "DURATION" "1115" "DURATION must be between"
verify_invalid_config "DURATION" "123456" "DURATION must be between"

# API_URL required string starting with http:// or https://
# This is a basic check, not a full URL validation.
echo "▶ Running API_URL value tests"
verify_valid_config "API_URL" "http://example.com" "API_URL must start with http:// or https://"
verify_valid_config "API_URL" "https://example.com" "API_URL must start with http:// or https://"
verify_valid_config "API_URL" "https://ev1sbdo123.execute-api.us-east-2.amazonaws.com/prod" "API_URL must start with http:// or https://"

verify_invalid_config "API_URL" "" "API_URL must start with http:// or https://"
verify_invalid_config "API_URL" "zoommtg://zoom.us/join?action=join&confno=<number>&pwd=<password>" "API_URL must start with http:// or https://"

echo "✅ Tests complete."
