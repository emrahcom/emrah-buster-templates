#!/bin/bash

CHANNEL="test"
if [ -n "$1" ]
then
        CHANNEL="$1"
fi

VOLUME=0.1
KEY_FRAME_INTERVAL=2
VIDEO_SIZE=1024x576

ffmpeg -re \
    -f lavfi -i testsrc=size=$VIDEO_SIZE:rate=24 \
    -f lavfi -i sine=f=220:b=1 -af "volume=$VOLUME" \
    -c:v libx264 -preset ultrafast -profile:v main -tune zerolatency \
    -force_key_frames "expr:gte(t,n_forced*$KEY_FRAME_INTERVAL)" \
    -pix_fmt yuv420p \
    -c:a libfdk_aac \
    -f flv rtmp://127.0.0.1/livestream/$CHANNEL
