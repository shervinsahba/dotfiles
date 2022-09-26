#!/bin/bash

## @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
## check_app_status: reports application status to polybar
## 	by Shervin S. (shervin@tuta.io)

## 	This script is used to create polybar modules that mimic
##  taskbar icons. A glyph represents the application. The color of
##  glyph changes depending on whether the program is running.

## polybar setup:
## Call this script as the "exec" option in a polybar user module.
## For example, for Discord, try this module. Note that #1 token
## below ought to be replaced by your glyph of choice.
##
##  [module/discord]
##  type = custom/script
##  exec = $HOME/.config/polybar/scripts/check_app_status.sh -i #1 Discord
##  click-left = discord &
##  click-right = killall Discord && killall Discord
##  interval = 5
##  format-background = ${color.mb}
##
## Similarly, the -c and -d flags can set connected/disconnected colors.


GLYPH='#1'					# set via -i <glyph>; default #1
COLOR_CONNECTED=#FFFFFF		# set bia -c <color>; default white
COLOR_DISCONNECTED=#888888  # set via -d <color>; default gray

# process option flags
OPTIND=1
while getopts ':i:c:d' flag; do
	case "${flag}" in
		i) GLYPH="${OPTARG}" ;;
   		c) COLOR_CONNECTED="${OPTARG}" ;;
   		d) COLOR_DISCONNECTED="${OPTARG}" ;;
    	*) echo "Unexpected option ${flag}" 1>&2; exit 1 ;;
	esac
done
shift "$((OPTIND-1))"    #purge option flags


#require application process name
if [ -z "$1" ] ; then
	echo "App name missing" 1>&2; exit 1
fi
APP_PROCESS_NAME="$1"


check_app() {
	if pgrep -x "$APP_PROCESS_NAME" >/dev/null; then
		echo %{F$COLOR_CONNECTED}"$GLYPH"%{F-}
	else
		echo %{F$COLOR_DISCONNECTED}"$GLYPH"%{F-}
	fi
}

# hotfix for tutanota-desktop, which seems to report its job name without the final letter
if [ "$APP_PROCESS_NAME" = tutanota-desktop ]; then
   APP_PROCESS_NAME=tutanota-deskto
fi

# check to see if app is running
if hash $(echo "$1" | tr '[:upper:]' '[:lower:]') &>/dev/null; then
	check_app
fi
