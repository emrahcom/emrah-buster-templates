#!/bin/bash
set -e

FOLDER=$1
KEY=$(basename $FOLDER)
VIDEO_PATH=$(find $FOLDER -name '*.mp4' | head -1)
VIDEO_NAME=$(basename $VIDEO_PATH)
VIDEO_NAME_KEY=$(echo $VIDEO_NAME | sed "s/.mp4/_$KEY.mp4/")

[[ ! -f "$VIDEO_PATH" ]] && exit 1

# write your codes here. for example:

exit 0
