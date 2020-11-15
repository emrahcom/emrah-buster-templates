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

# -----------------------------------------------------------------------------
# NFTABLES RULES
# -----------------------------------------------------------------------------
# tcp/8080
nft delete element eb-nat tcp2ip { 8080 } 2>/dev/null || true
nft add element eb-nat tcp2ip { 8080 : $JITSI }
nft delete element eb-nat tcp2port { 8080 } 2>/dev/null || true
nft add element eb-nat tcp2port { 8080 : 8080 }

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
    rm -f $ROOTFS/etc/nginx/sites-enabled/$JITSI_HOST-dev.conf
    ln -s ../sites-available/$JITSI_HOST-dev.conf \
        $ROOTFS/etc/nginx/sites-enabled/

    lxc-attach -n $MACH -- \
        zsh -c \
        "set -e
         systemctl restart nginx"
fi

# -----------------------------------------------------------------------------
# SYSTEM INFO
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     node --version
     npm --version"
