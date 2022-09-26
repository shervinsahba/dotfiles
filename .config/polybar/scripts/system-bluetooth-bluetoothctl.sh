#!/bin/sh

COLOR_POWERED=#62d6e8  #blue
COLOR_UNPOWERED=#4d4f68  #gray
COLOR_INACTIVE=#BD6A95  #red

bluetooth_print() {
    if [ "$(systemctl is-active "bluetooth.service")" = "active" ]; then
        if bluetoothctl show | grep -q "Powered: yes"; then
            echo "%{F$COLOR_POWERED}%{F-}"
        else
            echo "%{F$COLOR_UNPOWERED}%{F-}"
        fi

        devices_paired=$(bluetoothctl paired-devices | grep Device | cut -d ' ' -f 2)
        counter=0

        echo "$devices_paired" | while read -r line; do
            device_info=$(bluetoothctl info "$line")

            if echo "$device_info" | grep -q "Connected: yes"; then
                device_alias=$(echo "$device_info" | grep "Alias" | cut -d ' ' -f 2-)

                if [ $counter -gt 0 ]; then
                    printf ", %s" "$device_alias"
                else
                    printf " %s" "$device_alias"
                fi

                counter=$((counter + 1))
            fi
        done

        # printf '\n'
    else
        echo "%{F$COLOR_INACTIVE}%{F-}"
    fi
}

bluetooth_toggle() {
    if bluetoothctl show | grep -q "Powered: no"; then
        bluetoothctl power on >> /dev/null
        sleep 1

        devices_paired=$(bluetoothctl paired-devices | grep Device | cut -d ' ' -f 2)
        echo "$devices_paired" | while read -r line; do
            bluetoothctl connect "$line" >> /dev/null
        done
    else
        devices_paired=$(bluetoothctl paired-devices | grep Device | cut -d ' ' -f 2)
        echo "$devices_paired" | while read -r line; do
            bluetoothctl disconnect "$line" >> /dev/null
        done

        bluetoothctl power off >> /dev/null
    fi
}

case "$1" in
    --toggle) bluetooth_toggle ;;
    *) bluetooth_print ;;
esac