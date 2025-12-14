#!/usr/bin/env bash

mkdir -p ~/Videos/recordings

outfile=~/Videos/recordings/rec-screenonly-$(date +'%Y%m%d-%H%M%S').mkv

wf-recorder -r 60 -c libsvtav1 -f "$outfile"
