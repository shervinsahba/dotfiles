#!/bin/bash
PATH=/usr/bin
ALERT_TITLE="Virus found!"
ALERT="clamav detects: $CLAM_VIRUSEVENT_VIRUSNAME in $CLAM_VIRUSEVENT_FILENAME"

logger -t clamav-alert "$ALERT"

# Push + email via ntfy (ntfy-send reads root-only files, hence sudo)
sudo -n /usr/local/bin/ntfy-send "$ALERT_TITLE" "$ALERT" urgent

# Desktop notification for every logged-in graphical user
for ADDRESS in /run/user/*; do
    USERID=${ADDRESS#/run/user/}
    sudo -n -u "#$USERID" DBUS_SESSION_BUS_ADDRESS="unix:path=$ADDRESS/bus" \
        notify-send -u critical -i dialog-warning "$ALERT_TITLE" "$ALERT"
done

