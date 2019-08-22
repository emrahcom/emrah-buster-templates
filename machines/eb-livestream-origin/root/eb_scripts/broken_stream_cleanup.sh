#!/bin/bash

URL="http://127.0.0.1/livestream/status"
CRITERIA="/rtmp/server/application/live/stream[time>60000 and bw_video=0]/name/text()"

for stream in $(curl -s $URL | xmlstarlet sel -t -v "$CRITERIA")
do
    pkill -f "ffmpeg.*rtmp://.*/$stream$"
done
