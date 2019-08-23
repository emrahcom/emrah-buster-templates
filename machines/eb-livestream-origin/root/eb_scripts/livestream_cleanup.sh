#!/bin/bash

find /usr/local/eb/livestream/hls -mindepth 2 -type f -name "*.m3u8" -cmin +10 -delete
find /usr/local/eb/livestream/hls -mindepth 2 -type f -name "*.ts" -cmin +10 -delete
find /usr/local/eb/livestream/hls -mindepth 1 -empty -delete
find /usr/local/eb/livestream/dash -mindepth 2 -type f -name "*.mpd" -cmin +10 -delete
find /usr/local/eb/livestream/dash -mindepth 2 -type f -name "*.m4?" -cmin +10 -delete
find /usr/local/eb/livestream/dash -mindepth 1 -empty -delete
