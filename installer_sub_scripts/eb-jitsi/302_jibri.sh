# -----------------------------------------------------------------------------
# JIBRI.SH
# -----------------------------------------------------------------------------
set -e
source $INSTALLER/000_source

# -----------------------------------------------------------------------------
# ENVIRONMENT
# -----------------------------------------------------------------------------
MACH="eb-jitsi"
cd $MACHINES/$MACH

ROOTFS="/var/lib/lxc/$MACH/rootfs"

# -----------------------------------------------------------------------------
# INIT
# -----------------------------------------------------------------------------
[ "$DONT_RUN_JIBRI" = true ] && exit

echo
echo "-------------------------- $MACH --------------------------"

# -----------------------------------------------------------------------------
# CONTAINER SETUP
# -----------------------------------------------------------------------------
# start container
lxc-start -n $MACH -d
lxc-wait -n $MACH -s RUNNING

# -----------------------------------------------------------------------------
# HOST PACKAGES
# -----------------------------------------------------------------------------
zsh -c \
    "set -e
     export DEBIAN_FRONTEND=noninteractive
     apt-get $APT_PROXY_OPTION -y install kmod"

# -----------------------------------------------------------------------------
# PACKAGES
# -----------------------------------------------------------------------------
# fake install
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     export DEBIAN_FRONTEND=noninteractive
     apt-get $APT_PROXY_OPTION -dy reinstall hostname"

# update
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     export DEBIAN_FRONTEND=noninteractive
     apt-get $APT_PROXY_OPTION update
     apt-get $APT_PROXY_OPTION -y dist-upgrade"

# packages
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     export DEBIAN_FRONTEND=noninteractive
     apt-get $APT_PROXY_OPTION -y install libnss3-tools
     apt-get $APT_PROXY_OPTION -y install va-driver-all vdpau-driver-all
     apt-get $APT_PROXY_OPTION -y install chromium chromium-driver
     apt-get $APT_PROXY_OPTION -y install jibri"

# -----------------------------------------------------------------------------
# SYSTEM CONFIGURATION
# -----------------------------------------------------------------------------
# snd_aloop module
[ -z "$(lsmod | ack snd_aloop)" ] && modprobe snd_aloop
[ -z "$(egrep '^snd_aloop' /etc/modules)" ] && echo snd_aloop >>/etc/modules

# chromium managed policies
mkdir -p $ROOTFS/etc/chromium/policies/managed
cp etc/chromium/policies/managed/eb_policies.json \
    $ROOTFS/etc/chromium/policies/managed/

# -----------------------------------------------------------------------------
# JIBRI
# -----------------------------------------------------------------------------
# jibri groups
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     usermod -aG adm,audio,video,plugdev jibri"

# pki
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     mkdir -p /home/jibri/.pki/nssdb
     chmod 700 /home/jibri/.pki
     chmod 700 /home/jibri/.pki/nssdb

     certutil -A -n "jitsi" -i /usr/local/share/ca-certificates/jitsi-CA.crt \
         -t "TCu,Cu,Tu" -d sql:/home/jibri/.pki/nssdb/
     chown jibri:jibri /home/jibri/.pki -R"

# prosody config
cat >> $ROOTFS/etc/prosody/conf.avail/$JITSI_HOST.cfg.lua <<EOF

VirtualHost "recorder.$JITSI_HOST"
    modules_enabled = {
      "ping";
    }
    authentication = "internal_plain"
EOF

# prosody register
PASSWD1=$(echo -n $RANDOM$RANDOM | sha256sum | cut -c 1-20)
PASSWD2=$(echo -n $RANDOM$RANDOM$RANDOM | sha256sum | cut -c 1-20)

lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     prosodyctl register jibri auth.$JITSI_HOST $PASSWD1
     prosodyctl register recorder recorder.$JITSI_HOST $PASSWD2"

# jicofo config
cat >> $ROOTFS/etc/jitsi/jicofo/sip-communicator.properties <<EOF
org.jitsi.jicofo.jibri.BREWERY=JibriBrewery@internal.auth.$JITSI_HOST
org.jitsi.jicofo.jibri.PENDING_TIMEOUT=90
EOF

# jitsi-meet config
sed -i 's~//\s*fileRecordingsEnabled.*~fileRecordingsEnabled: true,~' \
    $ROOTFS/etc/jitsi/meet/$JITSI_HOST-config.js
sed -i 's~//\s*fileRecordingsServiceSharingEnabled.*~fileRecordingsServiceSharingEnabled: true,~' \
    $ROOTFS/etc/jitsi/meet/$JITSI_HOST-config.js
sed -i 's~//\s*liveStreamingEnabled.*~liveStreamingEnabled: true,~' \
    $ROOTFS/etc/jitsi/meet/$JITSI_HOST-config.js
sed -i "/liveStreamingEnabled/a \\\n    hiddenDomain: 'recorder.$JITSI_HOST'," \
    $ROOTFS/etc/jitsi/meet/$JITSI_HOST-config.js

# jibri config
cp etc/jitsi/jibri/config.json $ROOTFS/etc/jitsi/jibri/config.json
sed -i "s/___JITSI_HOST___/$JITSI_HOST/" $ROOTFS/etc/jitsi/jibri/config.json
sed -i "s/___PASSWD1___/$PASSWD1/" $ROOTFS/etc/jitsi/jibri/config.json
sed -i "s/___PASSWD2___/$PASSWD2/" $ROOTFS/etc/jitsi/jibri/config.json

# the finalize_recording script
cp usr/local/bin/finalize_recording.sh $ROOTFS/usr/local/bin/
chmod 755 $ROOTFS/usr/local/bin/finalize_recording.sh

# jibri service
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     systemctl enable jibri.service
     systemctl start jibri.service"

# -----------------------------------------------------------------------------
# CONTAINER SERVICES
# -----------------------------------------------------------------------------
lxc-stop -n $MACH
lxc-wait -n $MACH -s STOPPED
lxc-start -n $MACH -d
lxc-wait -n $MACH -s RUNNING
