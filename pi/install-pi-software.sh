#!/bin/bash

# Bash script to install fm_transmitter and my music list player

printf "###\n"
printf "### Perform updates\n\n"

sudo apt-get update && sudo apt-get upgrade --yes\
|| exit_on_error "Failed to perform updates"

printf "\n\n###\n"
printf "### Install required libraries for the fm transmitter\n\n"

sudo apt install libsndfile1-dev --yes \
|| exit_on_error "Failed to install required libraries"

printf "\n\n###\n"
printf "### Install PiFmRds transmitter\n"

curl -sL https://github.com/jasonmce/PiFmRds-single-play/archive/refs/heads/master.zip --output PiFmRds-single-play.zip
unzip PiFmRds-single-play.zip
cd PiFmRds-single-play-master/src
make clean && make \
|| exit_on_error "Failed to make PiFmRds"

mv pi_fm_rds ~/pi_fm_rds
cd ~/

printf "\n\n###\n"
printf "### Clean up the PiFmRds source\n"

rm PiFmRds.zip
rm -rf PiFmRds-master

printf "\n\n###\n"
printf "### Copy the player script and make it executable\n"

curl -sL https://raw.githubusercontent.com/jasonmce/bright-shiny-radio/refs/heads/main/pi/player.sh --output player.sh
chmod 755 player.sh
# make it start at launch
(crontab -l 2>/dev/null; echo "@reboot  /home/pi/player.sh")  | sort -u | crontab -

printf "\n\n###\n"
printf "### Turn off HDMI to save power, will take effect at next reboot\n"

echo "/usr/bin/tvservice -o" | sudo tee -a /etc/rc.local

## Create an ini file of settings the player will need to run.
CONFIG_FILE="player.ini"
cat > "$CONFIG_FILE" <<EOF
[settings]
FREQUENCY="87.1" # The FM frequency to broadcast.
STATION_NAME="MYRADIO" # Optional station name to broadcast, limit 8 characters.
ARTIST="Favorite Band" # The artist of song.wav
TITLE="Greatest song ever" # The title of song.wav
DURATION=270 # Length of song.wav in seconds
API_URL="https://api.YourSite.com" # Where play history is posted for storage
API_KEY="thisismySecretKey" # The secret key needed to post history to storage
EOF

printf "You must update the values in $CONFIG_FILE before starting the player\n"

printf "Once player.ini is updated, you can run ./player.sh to start the transmitter\n"
