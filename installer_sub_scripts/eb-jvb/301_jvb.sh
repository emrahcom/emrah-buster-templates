# -----------------------------------------------------------------------------
# JVB.SH
# -----------------------------------------------------------------------------
set -e
source $INSTALLER/000_source

# -----------------------------------------------------------------------------
# ENVIRONMENT
# -----------------------------------------------------------------------------
MACH="eb-jvb"
cd $MACHINES/$MACH

ROOTFS="/var/lib/lxc/$MACH/rootfs"
DNS_RECORD=$(grep "address=/$MACH/" /etc/dnsmasq.d/eb_jvb | head -n1)
IP=${DNS_RECORD##*/}
SSH_PORT="30$(printf %03d ${IP##*.})"
echo JVB="$IP" >> $INSTALLER/000_source

# -----------------------------------------------------------------------------
# NFTABLES RULES
# -----------------------------------------------------------------------------
# public ssh
nft delete element eb-nat tcp2ip { $SSH_PORT } 2>/dev/null || true
nft add element eb-nat tcp2ip { $SSH_PORT : $IP }
nft delete element eb-nat tcp2port { $SSH_PORT } 2>/dev/null || true
nft add element eb-nat tcp2port { $SSH_PORT : 22 }
# tcp/9090
nft delete element eb-nat tcp2ip { 9090 } 2>/dev/null || true
nft add element eb-nat tcp2ip { 9090 : $IP }
nft delete element eb-nat tcp2port { 9090 } 2>/dev/null || true
nft add element eb-nat tcp2port { 9090 : 9090 }
# udp/10000
nft delete element eb-nat udp2ip { 10000 } 2>/dev/null || true
nft add element eb-nat udp2ip { 10000 : $IP }
nft delete element eb-nat udp2port { 10000 } 2>/dev/null || true
nft add element eb-nat udp2port { 10000 : 10000 }

# -----------------------------------------------------------------------------
# INIT
# -----------------------------------------------------------------------------
[ "$DONT_RUN_JVB" = true ] && exit

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

# container config
rm -rf $ROOTFS/var/cache/apt/archives
mkdir -p $ROOTFS/var/cache/apt/archives
sed -i '/^lxc\.net\./d' /var/lib/lxc/$MACH/config
sed -i '/^# Network configuration/d' /var/lib/lxc/$MACH/config

cat >> /var/lib/lxc/$MACH/config <<EOF

# Network configuration
lxc.net.0.type = veth
lxc.net.0.link = $BRIDGE
lxc.net.0.name = eth0
lxc.net.0.flags = up
lxc.net.0.ipv4.address = $IP/24
lxc.net.0.ipv4.gateway = auto

# Start options
lxc.start.auto = 1
lxc.start.order = 500
lxc.start.delay = 2
lxc.group = eb-group
lxc.group = onboot
EOF

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

# apt-transport-https, gnupg
# ngrep, ncat, jq, ruby-hocon
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     export DEBIAN_FRONTEND=noninteractive
     apt-get $APT_PROXY_OPTION -y install apt-transport-https gnupg
     apt-get $APT_PROXY_OPTION -y install ngrep ncat jq
     apt-get $APT_PROXY_OPTION -y install ruby-hocon"

# jvb
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
     debconf-set-selections <<< \
         'jitsi-videobridge2 jitsi-videobridge/jvb-hostname string $JITSI_HOST'

     apt-get $APT_PROXY_OPTION -y --install-recommends install \
         jitsi-videobridge2=2.2-22-g42bc1b99-1"

# -----------------------------------------------------------------------------
# JVB
# -----------------------------------------------------------------------------
# disable the certificate check for prosody connection
cat >>$ROOTFS/etc/jitsi/videobridge/sip-communicator.properties <<EOF
org.jitsi.videobridge.xmpp.user.shard.DISABLE_CERTIFICATE_VERIFICATION=true
EOF

# default memory limit for JVB
cat >>$ROOTFS/etc/jitsi/videobridge/config <<EOF

# set the maximum memory for the JVB daemon
VIDEOBRIDGE_MAX_MEMORY=3072m
EOF
lxc-attach -n $MACH -- systemctl restart jitsi-videobridge2.service

# colibri
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     hocon -f /etc/jitsi/videobridge/jvb.conf \
         set videobridge.apis.rest.enabled true
     hocon -f /etc/jitsi/videobridge/jvb.conf \
         set videobridge.ice.udp.port 10000"

# NAT harvester. theese will be needed if this is an in-house server.
cat >>$ROOTFS/etc/jitsi/videobridge/sip-communicator.properties <<EOF
#org.ice4j.ice.harvest.NAT_HARVESTER_LOCAL_ADDRESS=$IP
#org.ice4j.ice.harvest.NAT_HARVESTER_PUBLIC_ADDRESS=$REMOTE_IP
EOF

# jvb-config
cp usr/local/sbin/jvb-config $ROOTFS/usr/local/sbin/
chmod 744 $ROOTFS/usr/local/sbin/jvb-config
cp etc/systemd/system/jvb-config.service $ROOTFS/etc/systemd/system/

lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     systemctl daemon-reload
     systemctl enable jvb-config.service"

# -----------------------------------------------------------------------------
# CONTAINER SERVICES
# -----------------------------------------------------------------------------
lxc-stop -n $MACH
lxc-wait -n $MACH -s STOPPED
lxc-start -n $MACH -d
lxc-wait -n $MACH -s RUNNING
