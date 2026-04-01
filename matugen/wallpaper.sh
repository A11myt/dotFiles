#!/bin/bash
swww query || swww-daemon &
sleep 0.5
swww img "$1" --transition-type center --transition-fps 60
