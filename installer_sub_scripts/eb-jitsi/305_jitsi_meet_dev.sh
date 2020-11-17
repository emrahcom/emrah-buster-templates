# -----------------------------------------------------------------------------
# JITSI_MEET_DEV.SH
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
[ "$INSTALL_JITSI_MEET_DEV" != true ] && exit

echo
echo "---------------------- JITSI MEET DEV ---------------------"

# -----------------------------------------------------------------------------
# CONTAINER
# -----------------------------------------------------------------------------
# start container
lxc-start -n $MACH -d
lxc-wait -n $MACH -s RUNNING
lxc-attach -n $MACH -- ping -c1 deb.debian.org || sleep 3

# -----------------------------------------------------------------------------
# PACKAGES
# -----------------------------------------------------------------------------
# fake install
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     export DEBIAN_FRONTEND=noninteractive
     apt-get $APT_PROXY_OPTION -dy reinstall hostname"

# nodejs repo
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | \
         apt-key add -"

cp etc/apt/sources.list.d/nodesource.list $ROOTFS/etc/apt/sources.list.d/
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     apt-get -y --allow-releaseinfo-change update"

# packages
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     export DEBIAN_FRONTEND=noninteractive
     apt-get $APT_PROXY_OPTION -y install gnupg git build-essential
     apt-get $APT_PROXY_OPTION -y install nodejs"

# -----------------------------------------------------------------------------
# JITSI-MEET DEV
# -----------------------------------------------------------------------------
# store folder
mkdir -p /root/eb_store

# dev folder
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     mkdir -p /home/dev
     cd /home/dev"

# lib-jitsi-meet
if [[ ! -d /root/eb_store/lib-jitsi-meet ]]; then
    git clone --depth=200 -b master \
        https://github.com/jitsi/lib-jitsi-meet.git \
        /root/eb_store/lib-jitsi-meet
fi

bash -c \
    "set -e
     cd /root/eb_store/lib-jitsi-meet
     git pull"

rm -rf $ROOTFS/home/dev/lib-jitsi-meet
cp -arp /root/eb_store/lib-jitsi-meet $ROOTFS/home/dev/

lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     cd /home/dev/lib-jitsi-meet
     TMP=/tmp npm update"

# jitsi-meet
if [[ ! -d /root/eb_store/jitsi-meet ]]; then
    git clone --depth=200 -b master https://github.com/jitsi/jitsi-meet.git \
        /root/eb_store/jitsi-meet
fi

bash -c \
    "set -e
     cd /root/eb_store/jitsi-meet
     git pull"

rm -rf $ROOTFS/home/dev/jitsi-meet
cp -arp /root/eb_store/jitsi-meet $ROOTFS/home/dev/

lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     cd /home/dev/jitsi-meet
     TMP=/tmp DISABLE_V8_COMPILE_CACHE=1 npm install ../lib-jitsi-meet
     TMP=/tmp npm update
     TMP=/tmp make"

# -----------------------------------------------------------------------------
# SYSTEM CONFIGURATION
# -----------------------------------------------------------------------------
# nginx
cp $ROOTFS/etc/nginx/sites-available/$JITSI_HOST.conf \
    $ROOTFS/etc/nginx/sites-available/$JITSI_HOST-dev.conf
sed -i "s~/usr/share/jitsi-meet~/home/dev/jitsi-meet~g" \
    $ROOTFS/etc/nginx/sites-available/$JITSI_HOST-dev.conf

# enable?
if [[ "$ENABLE_JITSI_MEET_DEV" = true ]]; then
    rm -f $ROOTFS/etc/nginx/sites-enabled/$JITSI_HOST.conf
    rm -f $ROOTFS/etc/nginx/sites-enabled/$JITSI_HOST-dev.conf
    ln -s ../sites-available/$JITSI_HOST-dev.conf \
        $ROOTFS/etc/nginx/sites-enabled/

    lxc-attach -n $MACH -- \
        zsh -c \
        "set -e
         systemctl restart nginx"
fi

# dev tools
cp usr/local/sbin/enable-jitsi-meet-dev $ROOTFS/usr/local/sbin/
cp usr/local/sbin/disable-jitsi-meet-dev $ROOTFS/usr/local/sbin/
sed -i "s/___JITSI_HOST___/$JITSI_HOST/" \
    $ROOTFS/usr/local/sbin/enable-jitsi-meet-dev
sed -i "s/___JITSI_HOST___/$JITSI_HOST/" \
    $ROOTFS/usr/local/sbin/disable-jitsi-meet-dev
chmod 744 $ROOTFS/usr/local/sbin/enable-jitsi-meet-dev
chmod 744 $ROOTFS/usr/local/sbin/disable-jitsi-meet-dev

# -----------------------------------------------------------------------------
# SYSTEM INFO
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     node --version
     npm --version"
