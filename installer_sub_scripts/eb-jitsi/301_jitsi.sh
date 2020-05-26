# -----------------------------------------------------------------------------
# JITSI.SH
# -----------------------------------------------------------------------------
set -e
source $INSTALLER/000_source

# -----------------------------------------------------------------------------
# ENVIRONMENT
# -----------------------------------------------------------------------------
MACH="eb-jitsi"
cd $MACHINES/$MACH

ROOTFS="/var/lib/lxc/$MACH/rootfs"
DNS_RECORD=$(grep "address=/$MACH/" /etc/dnsmasq.d/eb_jitsi | head -n1)
IP=${DNS_RECORD##*/}
SSH_PORT="30$(printf %03d ${IP##*.})"
echo JITSI="$IP" >> $INSTALLER/000_source

# -----------------------------------------------------------------------------
# NFTABLES RULES
# -----------------------------------------------------------------------------
# public ssh
nft delete element eb-nat tcp2ip { $SSH_PORT } 2>/dev/null || true
nft add element eb-nat tcp2ip { $SSH_PORT : $IP }
nft delete element eb-nat tcp2port { $SSH_PORT } 2>/dev/null || true
nft add element eb-nat tcp2port { $SSH_PORT : 22 }
# http
nft delete element eb-nat tcp2ip { 80 } 2>/dev/null || true
nft add element eb-nat tcp2ip { 80 : $IP }
nft delete element eb-nat tcp2port { 80 } 2>/dev/null || true
nft add element eb-nat tcp2port { 80 : 80 }
# https
nft delete element eb-nat tcp2ip { 443 } 2>/dev/null || true
nft add element eb-nat tcp2ip { 443 : $IP }
nft delete element eb-nat tcp2port { 443 } 2>/dev/null || true
nft add element eb-nat tcp2port { 443 : 443 }
# udp/10000
nft delete element eb-nat udp2ip { 10000 } 2>/dev/null || true
nft add element eb-nat udp2ip { 10000 : $IP }
nft delete element eb-nat udp2port { 10000 } 2>/dev/null || true
nft add element eb-nat udp2port { 10000 : 10000 }

# -----------------------------------------------------------------------------
# INIT
# -----------------------------------------------------------------------------
[ "$DONT_RUN_JITSI" = true ] && exit

echo
echo "-------------------------- $MACH --------------------------"

# -----------------------------------------------------------------------------
# REINSTALL_IF_EXISTS
# -----------------------------------------------------------------------------
EXISTS=$(lxc-info -n $MACH | egrep '^State' || true)
if [ -n "$EXISTS" -a "$REINSTALL_JITSI_IF_EXISTS" != true ]
then
    echo "Already installed. Skipped..."
    echo
    echo "Please set REINSTALL_JITSI_IF_EXISTS in $APP_CONFIG"
    echo "if you want to reinstall this container"
    exit
fi

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

# Devices
lxc.cgroup.devices.allow = c 116:* rwm
lxc.mount.entry = /dev/snd dev/snd none bind,optional,create=dir

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

# -----------------------------------------------------------------------------
# HOSTNAME
# -----------------------------------------------------------------------------
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     echo $MACH > /etc/hostname
     sed -i 's/\(127.0.1.1\s*\).*$/\1$JITSI_HOST $MACH/' /etc/hosts
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
     apt-get $APT_PROXY_OPTION update
     apt-get $APT_PROXY_OPTION -y dist-upgrade"

# apt-transport-https, gnupg
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     export DEBIAN_FRONTEND=noninteractive
     apt-get $APT_PROXY_OPTION -y install apt-transport-https gnupg"

# ssl packages
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     export DEBIAN_FRONTEND=noninteractive
     apt-get $APT_PROXY_OPTION -y install ssl-cert ca-certificates certbot"

# jitsi
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
     debconf-set-selections <<< \
         'jicofo jitsi-videobridge/jvb-hostname string $JITSI_HOST'
     debconf-set-selections <<< \
         'jitsi-meet-web-config jitsi-meet/cert-choice select Generate a new self-signed certificate (You will later get a chance to obtain a Let'\''s encrypt certificate)'

     apt-get $APT_PROXY_OPTION -y --install-recommends install jitsi-meet"

# -----------------------------------------------------------------------------
# SELF-SIGNED CERTIFICATE
# -----------------------------------------------------------------------------
cd /root/eb_ssl
rm -f /root/eb_ssl/ssl_eb_jitsi.*

# the extension file for multiple hosts:
# the container IP, the host IP and the host name
cat >ssl_eb_jitsi.ext <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
EOF

echo "DNS.1 = $JITSI_HOST" >>ssl_eb_jitsi.ext
echo "IP.1 = $REMOTE_IP" >>ssl_eb_jitsi.ext
echo "IP.2 = $IP" >>ssl_eb_jitsi.ext

# the domain key and the domain certificate
openssl req -nodes -newkey rsa:2048 \
    -keyout ssl_eb_jitsi.key -out ssl_eb_jitsi.csr \
    -subj "/O=emrah-buster/OU=jitsi/CN=$JITSI_HOST"
openssl x509 -req -CA eb_CA.pem -CAkey eb_CA.key -CAcreateserial \
    -days 10950 -in ssl_eb_jitsi.csr -out ssl_eb_jitsi.pem \
    -extfile ssl_eb_jitsi.ext

cd $MACHINES/$MACH

# -----------------------------------------------------------------------------
# SYSTEM CONFIGURATION
# -----------------------------------------------------------------------------
# certificates
cp /root/eb_ssl/eb_CA.pem $ROOTFS/usr/local/share/ca-certificates/jitsi-CA.crt
cp /root/eb_ssl/eb_CA.pem $ROOTFS/usr/share/jitsi-meet/static/jitsi-CA.crt
cp /root/eb_ssl/ssl_eb_jitsi.key $ROOTFS/etc/ssl/private/ssl-eb.key
cp /root/eb_ssl/ssl_eb_jitsi.pem $ROOTFS/etc/ssl/certs/ssl-eb.pem

lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     update-ca-certificates

     chmod 640 /etc/ssl/private/ssl-eb.key
     chown root:ssl-cert /etc/ssl/private/ssl-eb.key

     rm /etc/jitsi/meet/$JITSI_HOST.key
     rm /etc/jitsi/meet/$JITSI_HOST.crt
     ln -s /etc/ssl/private/ssl-eb.key /etc/jitsi/meet/$JITSI_HOST.key
     ln -s /etc/ssl/certs/ssl-eb.pem /etc/jitsi/meet/$JITSI_HOST.crt"

# nginx
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     rm /etc/nginx/sites-enabled/default
     rm -rf /var/www/html
     ln -s /usr/share/jitsi-meet /var/www/html"

lxc-attach -n $MACH -- systemctl stop nginx.service
lxc-attach -n $MACH -- systemctl start nginx.service

# certbot service
cp ../common/lib/systemd/system/certbot.service $ROOTFS/lib/systemd/system/
lxc-attach -n $MACH -- systemctl daemon-reload

# -----------------------------------------------------------------------------
# JITSI
# -----------------------------------------------------------------------------
# jitsi-meet config
sed -i 's~//\s*disableAudioLevels:.*~disableAudioLevels: true,~' \
    $ROOTFS/etc/jitsi/meet/$JITSI_HOST-config.js
sed -i 's~//\s*startAudioMuted:.*~startAudioMuted: 10,~' \
    $ROOTFS/etc/jitsi/meet/$JITSI_HOST-config.js
sed -i 's~//\s*resolution:.*~resolution: 480,~' \
    $ROOTFS/etc/jitsi/meet/$JITSI_HOST-config.js
sed -i 's~//\s*startVideoMuted:.*~startVideoMuted: 10,~' \
    $ROOTFS/etc/jitsi/meet/$JITSI_HOST-config.js
sed -i 's~//\s*requireDisplayName:.*~requireDisplayName: true,~' \
    $ROOTFS/etc/jitsi/meet/$JITSI_HOST-config.js

# jitsi-meet interface config
sed -i '/DISABLE_JOIN_LEAVE_NOTIFICATIONS/s/false/true/' \
    $ROOTFS/usr/share/jitsi-meet/interface_config.js

# NAT config for videobridge
PUBLIC=$(dig +short $JITSI_HOST)
[ -z "$PUBLIC" ] && PUBLIC=$REMOTE_IP

cat >>$ROOTFS/etc/jitsi/videobridge/sip-communicator.properties <<EOF
org.ice4j.ice.harvest.NAT_HARVESTER_LOCAL_ADDRESS=$IP
org.ice4j.ice.harvest.NAT_HARVESTER_PUBLIC_ADDRESS=$PUBLIC
EOF

# -----------------------------------------------------------------------------
# CONTAINER SERVICES
# -----------------------------------------------------------------------------
lxc-stop -n $MACH
lxc-wait -n $MACH -s STOPPED
lxc-start -n $MACH -d
lxc-wait -n $MACH -s RUNNING
