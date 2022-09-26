#!/bin/bash
COLOR_OS="#f087bd"
SYMBOL_OS="" #""

if ! updates_arch=$(checkupdates 2> /dev/null | wc -l ); then
    updates_arch=0
fi

if ! updates_aur=$(yay -Qum 2> /dev/null | wc -l); then
    updates_aur=0
fi

if [[ "$updates_arch" -gt 0 || "$updates_aur" -gt 0  ]]; then
    echo "%{F$COLOR_OS}$SYMBOL_OS $updates_arch+$updates_aur%{F-}"
fi
