#!/bin/bash
 
lock=" Lock"
switchuser=" Switch User"
sleep=" Sleep"
hibernate=" Hibernate"
reboot=" Reboot"
shutdown="襤 Poweroff"
exit="ﰱ"
 
selected_option=$(echo "$lock
$switchuser
$sleep
$hibernate
$reboot
$shutdown
$exit" | rofi -dmenu -i -p "Powermenu" \
		  -theme "~/.config/rofi/powermenu.rasi")

if [ "$selected_option" == "$lock" ]
then
    xsecurelock
elif [ "$selected_option" == "$switchuser" ]
then
    dm-tool switch-to-greeter
    #loginctl terminate-user `whoami`
elif [ "$selected_option" == "$shutdown" ]
then
    loginctl poweroff
elif [ "$selected_option" == "$reboot" ]
then
    loginctl reboot
elif [ "$selected_option" == "$sleep" ]
then
    loginctl suspend
elif [ "$selected_option" == "$hibernate" ]
then
    loginctl hibernate
else
    echo "No match"
fi
