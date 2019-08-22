#!/bin/bash

find /usr/local/eb/livestream/hls/ -type f -name "*.ts" -cmin +10 -delete
find /usr/local/eb/livestream/hls/ -type f -name "*.m3u8" -cmin +10 -delete
find /usr/local/eb/livestream/dash/ -type f -name "*.m4?" -cmin +10 -delete
find /usr/local/eb/livestream/dash/ -type f -name "*.mpd" -cmin +10 -delete
