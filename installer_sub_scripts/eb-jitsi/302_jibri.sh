# -----------------------------------------------------------------------------
# JIBRI.SH
# -----------------------------------------------------------------------------
set -e
source $INSTALLER/000_source

# -----------------------------------------------------------------------------
# ENVIRONMENT
# -----------------------------------------------------------------------------
MACH="eb-jibri-template"
cd $MACHINES/$MACH

ROOTFS="/var/lib/lxc/$MACH/rootfs"
JITSI_ROOTFS="/var/lib/lxc/eb-jitsi/rootfs"

# -----------------------------------------------------------------------------
# INIT
# -----------------------------------------------------------------------------
[ "$DONT_RUN_JIBRI" = true ] && exit

echo
echo "-------------------------- $MACH --------------------------"

# -----------------------------------------------------------------------------
# CONTAINER SETUP
# -----------------------------------------------------------------------------
# stop the template container if it's running
set +e
lxc-stop -n eb-buster
lxc-wait -n eb-buster -s STOPPED
set -e

# remove the old container if exists
set +e
lxc-autostart -s -g eb-jibri -t 60
lxc-autostart -k -g eb-jibri

lxc-stop -n $MACH
lxc-wait -n $MACH -s STOPPED
lxc-destroy -n $MACH
rm -rf /var/lib/lxc/$MACH
sleep 1
set -e

# create the new one
lxc-copy -n eb-buster -N $MACH -p /var/lib/lxc/

# shared directories
mkdir -p $SHARED/cache
mkdir -p $SHARED/recordings

# container config
rm -rf $ROOTFS/var/cache/apt/archives
mkdir -p $ROOTFS/var/cache/apt/archives
rm -rf $ROOTFS/usr/local/eb/recordings
mkdir -p $ROOTFS/usr/local/eb/recordings
sed -i '/^lxc\.net\./d' /var/lib/lxc/$MACH/config
sed -i '/^# Network configuration/d' /var/lib/lxc/$MACH/config

cat >> /var/lib/lxc/$MACH/config <<EOF
lxc.mount.entry = $SHARED/recordings usr/local/eb/recordings none bind 0 0

# Devices
lxc.cgroup.devices.allow = c 116:* rwm
lxc.mount.entry = /dev/snd dev/snd none bind,optional,create=dir

# Network configuration
lxc.net.0.type = veth
lxc.net.0.link = $BRIDGE
lxc.net.0.name = eth0
lxc.net.0.flags = up

# Start options
lxc.start.auto = 1
lxc.start.order = 600
lxc.start.delay = 2
lxc.group = eb-group
lxc.group = eb-jibri
EOF

# dhcp config
cp etc/network/interfaces $ROOTFS/etc/network/

# start container
lxc-start -n $MACH -d
lxc-wait -n $MACH -s RUNNING

# -----------------------------------------------------------------------------
# HOSTNAME
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     echo $MACH > /etc/hostname
     sed -i 's/\(127.0.1.1\s*\).*$/\1 $MACH/' /etc/hosts
     hostname $MACH"

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
     apt-get $APT_PROXY_OPTION -y install apt-transport-https gnupg
     apt-get $APT_PROXY_OPTION -y install ca-certificates
     apt-get $APT_PROXY_OPTION -y install libnss3-tools
     apt-get $APT_PROXY_OPTION -y install va-driver-all vdpau-driver-all
     apt-get $APT_PROXY_OPTION -y --install-recommends install ffmpeg
     apt-get $APT_PROXY_OPTION -y --install-recommends install chromium \
         chromium-driver
     apt-get $APT_PROXY_OPTION -y --install-recommends install \
         nvidia-openjdk-8-jre"

# jibri
cp etc/apt/sources.list.d/jitsi-stable.list $ROOTFS/etc/apt/sources.list.d/
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     apt-get $APT_PROXY_OPTION --allow-insecure-repositories update
     apt-get $APT_PROXY_OPTION --allow-unauthenticated -y install \
         jitsi-archive-keyring
     apt-get $APT_PROXY_OPTION update"

lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     export DEBIAN_FRONTEND=noninteractive
     apt-get $APT_PROXY_OPTION -y install jibri"

# packages removed
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     export DEBIAN_FRONTEND=noninteractive
     apt-get -y purge upower
     apt-get -y --purge autoremove"

# -----------------------------------------------------------------------------
# SYSTEM CONFIGURATION
# -----------------------------------------------------------------------------
# jitsi host
echo -e "$JITSI\t$JITSI_HOST" >> $ROOTFS/etc/hosts

# certificates
cp /root/eb_ssl/eb_CA.pem $ROOTFS/usr/local/share/ca-certificates/jitsi-CA.crt
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     update-ca-certificates"

# snd_aloop module
[ -z "$(egrep '^snd_aloop' /etc/modules)" ] && echo snd_aloop >>/etc/modules
cp $MACHINES/eb-jitsi-host/etc/modprobe.d/alsa-loopback.conf /etc/modprobe.d/
rmmod -f snd_aloop || true
[ -z "$(lsmod | ack snd_aloop)" ] && modprobe snd_aloop

# chromium managed policies
mkdir -p $ROOTFS/etc/chromium/policies/managed
cp etc/chromium/policies/managed/eb_policies.json \
    $ROOTFS/etc/chromium/policies/managed/

# default java
mv $ROOTFS/usr/lib/jvm/nvidia-java-8-openjdk-amd64/lib/security/cacerts \
    $ROOTFS/usr/lib/jvm/nvidia-java-8-openjdk-amd64/lib/security/cacerts.org
ln -sf /etc/ssl/certs/java/cacerts \
    $ROOTFS/usr/lib/jvm/nvidia-java-8-openjdk-amd64/lib/security/

lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     update-alternatives --install /usr/bin/java java \
         /usr/lib/jvm/nvidia-java-8-openjdk-amd64/bin/java 50
     update-alternatives --set java \
         /usr/lib/jvm/nvidia-java-8-openjdk-amd64/bin/java"

# -----------------------------------------------------------------------------
# JITSI CUSTOMIZATION FOR JIBRI
# -----------------------------------------------------------------------------
# prosody config
cat >> $JITSI_ROOTFS/etc/prosody/conf.avail/$JITSI_HOST.cfg.lua <<EOF

VirtualHost "recorder.$JITSI_HOST"
    modules_enabled = {
      "ping";
    }
    authentication = "internal_plain"
EOF

# prosody register
PASSWD1=$(echo -n $RANDOM$RANDOM | sha256sum | cut -c 1-20)
PASSWD2=$(echo -n $RANDOM$RANDOM$RANDOM | sha256sum | cut -c 1-20)

lxc-attach -n eb-jitsi -- \
    zsh -c \
    "set -e
     systemctl restart prosody.service"

lxc-attach -n eb-jitsi -- \
    zsh -c \
    "set -e
     prosodyctl unregister jibri auth.$JITSI_HOST || true
     prosodyctl register jibri auth.$JITSI_HOST $PASSWD1
     prosodyctl unregister recorder recorder.$JITSI_HOST || true
     prosodyctl register recorder recorder.$JITSI_HOST $PASSWD2"

# jicofo config
cat >> $JITSI_ROOTFS/etc/jitsi/jicofo/sip-communicator.properties <<EOF
org.jitsi.jicofo.jibri.BREWERY=JibriBrewery@internal.auth.$JITSI_HOST
org.jitsi.jicofo.jibri.PENDING_TIMEOUT=90
EOF

lxc-attach -n eb-jitsi -- \
    zsh -c \
    "set -e
     systemctl restart jicofo.service"

# jitsi-meet config
sed -i 's~//\s*fileRecordingsEnabled.*~fileRecordingsEnabled: true,~' \
    $JITSI_ROOTFS/etc/jitsi/meet/$JITSI_HOST-config.js
sed -i 's~//\s*fileRecordingsServiceSharingEnabled.*~fileRecordingsServiceSharingEnabled: true,~' \
    $JITSI_ROOTFS/etc/jitsi/meet/$JITSI_HOST-config.js
sed -i 's~//\s*liveStreamingEnabled:.*~liveStreamingEnabled: true,~' \
    $JITSI_ROOTFS/etc/jitsi/meet/$JITSI_HOST-config.js
sed -i "/liveStreamingEnabled:/a \\\n    hiddenDomain: 'recorder.$JITSI_HOST'," \
    $JITSI_ROOTFS/etc/jitsi/meet/$JITSI_HOST-config.js

# -----------------------------------------------------------------------------
# JIBRI
# -----------------------------------------------------------------------------
# jibri groups
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     usermod -aG adm,audio,video,plugdev jibri"

# recordings directory
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     chown jibri:jibri /usr/local/eb/recordings -R"

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

# jibri config
cp etc/jitsi/jibri/config.json $ROOTFS/etc/jitsi/jibri/config.json
sed -i "s/___JITSI_HOST___/$JITSI_HOST/" $ROOTFS/etc/jitsi/jibri/config.json
sed -i "s/___PASSWD1___/$PASSWD1/" $ROOTFS/etc/jitsi/jibri/config.json
sed -i "s/___PASSWD2___/$PASSWD2/" $ROOTFS/etc/jitsi/jibri/config.json

# the finalize_recording script
cp usr/local/bin/finalize_recording.sh $ROOTFS/usr/local/bin/
chmod 755 $ROOTFS/usr/local/bin/finalize_recording.sh

# jibri ephemeral config service
cp usr/local/sbin/jibri-ephemeral-config.sh $ROOTFS/usr/local/sbin/
chmod 744 $ROOTFS/usr/local/sbin/jibri-ephemeral-config.sh
cp etc/systemd/system/jibri-ephemeral-config.service \
    $ROOTFS/etc/systemd/system/

lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     systemctl daemon-reload
     systemctl enable jibri-ephemeral-config.service"

# jibri service
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     systemctl enable jibri.service
     systemctl start jibri.service"

# -----------------------------------------------------------------------------
# CONTAINER SERVICES
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- systemctl stop jibri.service
lxc-stop -n $MACH
lxc-wait -n $MACH -s STOPPED

# -----------------------------------------------------------------------------
# EPHEMERAL JIBRI CONTAINERS
# -----------------------------------------------------------------------------
cp $MACHINES/eb-jitsi-host/usr/local/sbin/jibri-ephemeral-start.sh \
    /usr/local/sbin/
cp $MACHINES/eb-jitsi-host/usr/local/sbin/jibri-ephemeral-stop.sh \
    /usr/local/sbin/
chmod 744 /usr/local/sbin/jibri-ephemeral-start.sh
chmod 744 /usr/local/sbin/jibri-ephemeral-stop.sh

cp $MACHINES/eb-jitsi-host/etc/systemd/system/jibri-ephemeral-container.service \
    /etc/systemd/system/

systemctl daemon-reload
systemctl enable jibri-ephemeral-container.service
systemctl start jibri-ephemeral-container.service
