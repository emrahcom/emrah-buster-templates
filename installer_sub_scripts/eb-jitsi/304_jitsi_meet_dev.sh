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
# NFTABLES RULES
# -----------------------------------------------------------------------------
# tcp/8000
nft delete element eb-nat tcp2ip { 8000 } 2>/dev/null || true
nft add element eb-nat tcp2ip { 8000 : $JITSI }
nft delete element eb-nat tcp2port { 8000 } 2>/dev/null || true
nft add element eb-nat tcp2port { 8000 : 8000 }

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
# clones
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     cd
     rm -rf jitsi-meet lib-jitsi-meet
     git clone https://github.com/jitsi/jitsi-meet.git
     git clone https://github.com/jitsi/lib-jitsi-meet.git"

# -----------------------------------------------------------------------------
# SYSTEM CONFIGURATION
# -----------------------------------------------------------------------------
# nginx
cp $ROOTFS/etc/nginx/sites-available/$JITSI_HOST.conf \
    $ROOTFS/etc/nginx/sites-available/$JITSI_HOST-dev.conf
sed -i "s~/usr/share/jitsi-meet~/root/jitsi-meet~g" \
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
