This project combines a RaspberryPi FM broadcasting a song and a website to show the playlist history.

# GOALS

## Create a simple and inexpensive radio station site in AWS using Terraform
Create a terraform manifest with a:
- playlist database
- api endpoint that writes to the playlist database
- http endpoint that returns a page showing the latest playlist records

## Create a pi installer bash script
Takes required arguments:
  frequency, apiKey, and apiUrl
Installs fm_transmitter
  @see https://github.com/markondej/fm_transmitter
Creates a /playlist directory to hold the song.wav
Installs a music player that is launched on start:
    Post the song to the API endpoint
    run fm_transmitter
    Repeat for the next play

bash -c  "$(curl -sL https://raw.githubusercontent.com/jasonmce/aws-playlist/master/install-pi-software.sh)"


## Polish
Create a cool custom case including "on the air" text
Add screen shots and pictures of my transmitter to the README

## Improvements
Switch fm_transmitter to use https://github.com/ChristopheJacquet/PiFmRds which includes RDS

## Thanks to
https://convertio.co/
