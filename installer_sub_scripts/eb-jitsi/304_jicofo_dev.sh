# -----------------------------------------------------------------------------
# JICOFO_DEV.SH
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
[ "$INSTALL_JICOFO_DEV" != true ] && exit

echo
echo "------------------------ JICOFO DEV -----------------------"

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

# update
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     export DEBIAN_FRONTEND=noninteractive
     apt-get -y --allow-releaseinfo-change update"

# packages
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     export DEBIAN_FRONTEND=noninteractive
     apt-get $APT_PROXY_OPTION -y install gnupg git build-essential
     apt-get $APT_PROXY_OPTION -y install maven"

# -----------------------------------------------------------------------------
# JICOFO DEV
# -----------------------------------------------------------------------------
# store folder
mkdir -p /root/eb_store

# dev folder
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     mkdir -p /home/dev
     cd /home/dev"

# jicofo
if [[ ! -d /root/eb_store/jicofo ]]; then
    git clone --depth=1 -b master https://github.com/jitsi/jicofo.git \
        /root/eb_store/jicofo
fi

bash -c \
    "set -e
     cd /root/eb_store/jicofo
     git pull"

rm -rf $ROOTFS/home/dev/jicofo
cp -arp /root/eb_store/jicofo $ROOTFS/home/dev/

# -----------------------------------------------------------------------------
# SYSTEM INFO
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     mvn --version"
