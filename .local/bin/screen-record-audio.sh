#!/usr/bin/env bash

mkdir -p ~/Videos/recordings

# Select speaker monitor (what's playing through speakers)
speaker_monitor=$(pactl list sources short | grep monitor | awk '{print $2}' | wofi --dmenu -p "Select Speaker Monitor")
[ -z "$speaker_monitor" ] && exit 1

# Select mic (source)
mic=$(pactl list sources short | grep -v monitor | awk '{print $2}' | wofi --dmenu -p "Select Microphone")
[ -z "$mic" ] && exit 1

outfile=~/Videos/recordings/rec-$(date +'%Y%m%d-%H%M%S').mkv

wf-recorder -r 60 -c libsvtav1 \
    -a "$speaker" \
    -a "$mic" \
    -f "$outfile"

