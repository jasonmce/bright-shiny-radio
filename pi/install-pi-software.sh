#!/bin/bash

# Bash script to install fm_transmitter and my music list player

printf "###\n"
printf "### Perform updates\n\n"

sudo apt-get update \
|| exit_on_error "Failed to perform updates"

printf "\n\n###\n"
printf "### Install required libraries for the fm transmitter\n\n"

sudo apt-get install make build-essential && \
sudo apt-get install libraspberrypi-dev --yes \
|| exit_on_error "Failed to perform updates"

printf "\n\n###\n"
printf "### Install the fm_transmitter\n"

curl -sL https://github.com/markondej/fm_transmitter/archive/refs/heads/master.zip --output fm_transmitter.zip
unzip fm_transmitter.zip
cd fm_transmitter-master
make
mv fm_transmitter ~/
cd ~/

printf "\n\n###\n"
printf "### Clean up the fm_transmitter source\n"

rm fm_transmitter.zip
rm -rf fm_transmitter-master

printf "\n\n###\n"
printf "### Copy the player script and make it executable\n"

curl -sL https://raw.githubusercontent.com/jasonmce/pi-radio-aws-site/refs/heads/main/pi/player.sh --output player.sh
chmod 755 player.sh
# make it start at launch
(crontab -l 2>/dev/null; echo "@reboot  /home/pi/player.sh")  | sort -u | crontab -

## Turn off HDMI to save power, will take effect at next reboot.
echo "/usr/bin/tvservice –o" | sudo tee -a /etc/rc.local

## Create an ini file of settings the player will need to run.
CONFIG_FILE="player.ini"
cat > "$CONFIG_FILE" <<EOF
[settings]
FREQUENCY="87.1" # The FM frequency to broadcast.
ARTIST="Favorite Band" # The artist of song.wav
TITLE="Greatest song ever" # The title of song.wav
DURATION=270 # Length of song.wav in seconds
API_URL="https://api.YourSite.com" # Where play history is posted for storage
API_KEY="thisismySecretKey" # The secret key needed to post history to storage
EOF

printf "You must update the values in $CONFIG_FILE before starting the player\n"

printf "Once player.ini is updated, you can run ./player.sh to start the transmitter\n"
