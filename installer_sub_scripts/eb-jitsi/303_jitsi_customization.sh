# -----------------------------------------------------------------------------
# JITSI_CUSTOMIZATION.SH
# -----------------------------------------------------------------------------
set -e
source $INSTALLER/000_source

# -----------------------------------------------------------------------------
# ENVIRONMENT
# -----------------------------------------------------------------------------
MACH="eb-jitsi-host"
cd $MACHINES/$MACH

# -----------------------------------------------------------------------------
# INIT
# -----------------------------------------------------------------------------
[ "$DONT_RUN_JITSI_CUSTOMIZATION" = true ] && exit

echo
echo "------------------- JITSI CUSTOMIZATION -------------------"

# -----------------------------------------------------------------------------
# CUSTOMIZATION
# -----------------------------------------------------------------------------
JITSI_MEET="/var/lib/lxc/eb-jitsi/rootfs/usr/share/jitsi-meet"

if [[ ! -d "/root/jitsi_customization" ]]
then
    cp -arp jitsi_customization /root/
    cp $JITSI_MEET/images/favicon.ico /root/jitsi_customization/
    cp $JITSI_MEET/images/watermark.png /root/jitsi_customization/

    sed -i "s/___TURN_HOST___/$TURN_HOST/g" /root/README.md
    sed -i "s/___JITSI_HOST___/$JITSI_HOST/g" /root/README.md
    sed -i "s/___JITSI_HOST___/$JITSI_HOST/g" /root/customize.sh
fi

bash /root/jitsi_customization/customize.sh
