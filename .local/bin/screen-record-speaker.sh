#!/usr/bin/env bash

mkdir -p ~/Videos/recordings

speaker=$(pactl list sinks short | awk '{print $2}' | wofi --dmenu -p "Select Speaker")
[ -z "$speaker" ] && exit 1

outfile=~/Videos/recordings/rec-speaker-$(date +'%Y%m%d-%H%M%S').mkv

wf-recorder -r 60 -c libsvtav1 \
    -a "$speaker" \
    -f "$outfile"
