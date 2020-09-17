#!/bin/bash
set -e

[[ "$(whoami)" != "jibri" ]] && exit 1

FOLDER=$1
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
