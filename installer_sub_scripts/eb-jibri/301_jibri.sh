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
systemctl stop jibri-ephemeral-container.service

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
lxc-attach -n $MACH -- ping -c1 deb.debian.org || sleep 3

# -----------------------------------------------------------------------------
# HOSTNAME
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     echo $MACH > /etc/hostname
     sed -i 's/\(127.0.1.1\s*\).*$/\1$MACH/' /etc/hosts
     hostname $MACH"

# -----------------------------------------------------------------------------
# HOST PACKAGES
# -----------------------------------------------------------------------------
zsh -c \
    "set -e
     export DEBIAN_FRONTEND=noninteractive
     apt-get $APT_PROXY_OPTION -y install kmod alsa-utils"

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
     apt-get -y --allow-releaseinfo-change update
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
     apt-get $APT_PROXY_OPTION -y install stunnel x11vnc"

# jibri
cp etc/apt/sources.list.d/jitsi-stable.list $ROOTFS/etc/apt/sources.list.d/
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     wget -qO /tmp/jitsi.gpg.key https://download.jitsi.org/jitsi-key.gpg.key
     cat /tmp/jitsi.gpg.key | gpg --dearmor > \
         /usr/share/keyrings/jitsi-keyring.gpg
     apt-get update"

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
# disable ssh service
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     systemctl stop ssh.service
     systemctl disable ssh.service"

# snd_aloop module
[ -z "$(egrep '^snd_aloop' /etc/modules)" ] && echo snd_aloop >>/etc/modules
cp $MACHINES/eb-jibri-host/etc/modprobe.d/alsa-loopback.conf /etc/modprobe.d/
rmmod -f snd_aloop || true
modprobe snd_aloop || true
[[ "$DONT_CHECK_SND_ALOOP" = true ]] || [[ -n "$(lsmod | ack snd_aloop)" ]]

# chromium managed policies
mkdir -p $ROOTFS/etc/chromium/policies/managed
cp etc/chromium/policies/managed/eb_policies.json \
    $ROOTFS/etc/chromium/policies/managed/

# stunnel
cp etc/stunnel/facebook.conf $ROOTFS/etc/stunnel/
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     systemctl start stunnel4.service"

# -----------------------------------------------------------------------------
# JIBRI
# -----------------------------------------------------------------------------
# jibri groups
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     usermod -aG adm,audio,video,plugdev jibri"

# jibri ssh
mkdir -p $ROOTFS/home/jibri/.ssh
chmod 700 $ROOTFS/home/jibri/.ssh
cp home/jibri/.ssh/jibri-config $ROOTFS/home/jibri/.ssh/
[[ -f /root/.ssh/jibri ]] && \
    cp /root/.ssh/jibri $ROOTFS/home/jibri/.ssh/ || \
    true

lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     chown jibri:jibri /home/jibri/.ssh -R"

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
     chown jibri:jibri /home/jibri/.pki -R"

# jibri config
cp etc/jitsi/jibri/jibri.conf $ROOTFS/etc/jitsi/jibri/

# the customized scripts
cp usr/local/bin/finalize_recording.sh $ROOTFS/usr/local/bin/
chmod 755 $ROOTFS/usr/local/bin/finalize_recording.sh
cp usr/local/bin/ffmpeg $ROOTFS/usr/local/bin/
chmod 755 $ROOTFS/usr/local/bin/ffmpeg

# jibri ephemeral config service
cp usr/local/sbin/jibri-ephemeral-config $ROOTFS/usr/local/sbin/
chmod 744 $ROOTFS/usr/local/sbin/jibri-ephemeral-config
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

# jibri vnc
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     mkdir -p /home/jibri/.vnc
     x11vnc -storepasswd jibri /home/jibri/.vnc/passwd
     chown jibri:jibri /home/jibri/.vnc -R"

# -----------------------------------------------------------------------------
# CONTAINER SERVICES
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- systemctl stop jibri.service
lxc-stop -n $MACH
lxc-wait -n $MACH -s STOPPED

# -----------------------------------------------------------------------------
# EPHEMERAL JIBRI CONTAINERS
# -----------------------------------------------------------------------------
cp $MACHINES/eb-jibri-host/usr/local/sbin/jibri-ephemeral-start /usr/local/sbin/
cp $MACHINES/eb-jibri-host/usr/local/sbin/jibri-ephemeral-stop /usr/local/sbin/
chmod 744 /usr/local/sbin/jibri-ephemeral-start
chmod 744 /usr/local/sbin/jibri-ephemeral-stop

cp $MACHINES/eb-jibri-host/etc/systemd/system/jibri-ephemeral-container.service \
    /etc/systemd/system/

systemctl daemon-reload
systemctl enable jibri-ephemeral-container.service
