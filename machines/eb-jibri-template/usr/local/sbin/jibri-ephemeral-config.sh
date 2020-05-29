#!/bin/bash

# -----------------------------------------------------------------------------
# JIBRI-EPHEMERAL-CONFIG.SH
# -----------------------------------------------------------------------------
#
# Customize the Jibri config for the current instance
#
# -----------------------------------------------------------------------------

(( INSTANCE_ID = $(hostname | egrep -o '[0-9]+$') + 0 ))
INSTANCE=$(hostname)
LOOPBACK=$(aplay -l | grep "card $INSTANCE_ID:" | cut -d ' ' -f3 | uniq)

[ -n "$INSTANCE" ] && \
    sed "s/\(.*\"nickname\":\).*/\1 \"$INSTANCE-$RANDOM\"/" \
        /etc/jitsi/jibri/config.json
[ -n "$LOOPBACK" ] && \
    sed -i "s/Loopback,/$LOOPBACK,/" /home/jibri/.asoundrc
