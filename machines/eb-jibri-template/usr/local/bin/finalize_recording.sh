#!/bin/bash
set -e

FOLDER=$1

[[ "$(whoami)" != "jibri" ]] && exit 1
[[ -z "$FOLDER" ]] && exit 2

KEY=$(basename $FOLDER)

for VIDEO_PATH in $(find $FOLDER -name '*.mp4')
do
    VIDEO_NAME=$(basename $VIDEO_PATH)
    VIDEO_NAME_KEY=$(echo $VIDEO_NAME | sed "s/.mp4/_$KEY.mp4/")

    # write your codes here.
    # for example:
    # cp $VIDEO_PATH /tmp/$VIDEO_NAME_KEY
done

exit 0
