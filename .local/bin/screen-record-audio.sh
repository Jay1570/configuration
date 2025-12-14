#!/usr/bin/env bash

mkdir -p ~/Videos/recordings

# select speaker (sink)
speaker=$(pactl list sinks short | awk '{print $2}' | wofi --dmenu -p "Select Speaker")
[ -z "$speaker" ] && exit 1

# select mic (source)
mic=$(pactl list sources short | awk '{print $2}' | wofi --dmenu -p "Select Microphone")
[ -z "$mic" ] && exit 1

outfile=~/Videos/recordings/rec-$(date +'%Y%m%d-%H%M%S').mkv

wf-recorder -r 60 -c libsvtav1 \
    -a "$speaker" \
    -a "$mic" \
    -f "$outfile"

