#!/bin/bash

# Confirm song.wav exists
if [ ! -f song.wav ]; then
    echo "There is no song.wav file to transmit, exiting"
    exit 1
fi

CONFIG_FILE="player.ini"

# Load configuration file
if [[ -f "$CONFIG_FILE" ]]; then
    source <(grep -E "^[a-zA-Z_]+=.+" "$CONFIG_FILE")
else
    printf "No player.ini configuration file found, exiting"
    exit 1
fi

echo "Using configuration:"
echo "Broadcasting on Frequency: $FREQUENCY"
echo "RDS Station Name: $STATION_NAME"
echo "Artist: $ARTIST"
echo "Title: $TITLE"
echo "Duration: $DURATION seconds"
echo "API url: $API_URL"
echo "API security token: $API_KEY"

## Gracefully exit with a message if any variable is unset.
: ${FREQUENCY:?Must set FREQUENCY.}
: ${STATION_NAME:?Must set STATION_NAME.}
: ${ARTIST:?Must set ARTIST.}
: ${TITLE:?Must set TITLE.}
: ${DURATION:?Must set DURATION.}
: ${API_URL:?Must set API_URL.}
: ${API_KEY:?Must set API_KEY.}

#Function of what trap command calls
function ctrl_c() {
    printf "\n** Trapped CTRL-C after $i seconds.\n"
    exit 0
}

## Add the song to the playlist, and then play it.
while :
do
  curl -X POST \
      -H "Content-Type: application/json" \
      -H "apikey: $API_KEY" \
      -d "{\"artist\": \"$ARTIST\", \"title\": \"$TITLE\", \"duration\": $DURATION}" \
      "$API_URL"

  sudo ./pi_fm_rds -freq $FREQUENCY -audio song.wav -ps "$STATION_NAME" -rt "$ARTIST - $TITLE"

done