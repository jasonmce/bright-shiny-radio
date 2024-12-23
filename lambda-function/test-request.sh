#!/bin/bash

curl -i -X POST \
  -H "Content-Type: application/json" \
  -H "apikey: thisismyKey" \
  -d '{"artist": "Vanilla Ice", "title": "Ice Ice Baby - test", "duration": 270}' \
  https://1qmkd21l42.execute-api.us-east-1.amazonaws.com/prod