#!/bin/bash

theme="$HOME/.config/rofi/launcher.rasi"

if [ "$1" == "-show" ]; then
    rofi -show "$2" -theme "${theme}"
else
    rofi -show drun -theme "${theme}"
fi
