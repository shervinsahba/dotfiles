#!/bin/bash
COLOR="#f087bd"

if ! updates_arch=$(checkupdates 2> /dev/null | wc -l ); then
    updates_arch=0
fi

if ! updates_aur=$(yay -Qum 2> /dev/null | wc -l); then
    updates_aur=0
fi

if [[ "$updates_arch" -gt 0 || "$updates_aur" -gt 0  ]]; then
    if [[ "$updates_arch" -gt 200 ]]; then
        echo "%{F$COLOR}$updates_arch%{F-}+$updates_aur"
    else
        echo "$updates_arch+$updates_aur"
    fi
fi
