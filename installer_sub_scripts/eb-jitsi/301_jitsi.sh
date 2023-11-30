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
# tcp/5222
nft delete element eb-nat tcp2ip { 5222 } 2>/dev/null || true
nft add element eb-nat tcp2ip { 5222 : $IP }
nft delete element eb-nat tcp2port { 5222 } 2>/dev/null || true
nft add element eb-nat tcp2port { 5222 : 5222 }
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
     wget -qO /tmp/jitsi.gpg.key https://download.jitsi.org/jitsi-key.gpg.key
     cat /tmp/jitsi.gpg.key | gpg --dearmor > \
         /usr/share/keyrings/jitsi-keyring.gpg
     apt-get update"

lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     export DEBIAN_FRONTEND=noninteractive
     debconf-set-selections <<< \
         'jicofo jitsi-videobridge/jvb-hostname string $JITSI_HOST'
     debconf-set-selections <<< \
         'jitsi-meet-web-config jitsi-meet/cert-choice select Generate a new self-signed certificate'

     apt-get $APT_PROXY_OPTION -y --install-recommends install \
         jitsi-meet=2.0.7648-1 \
         jitsi-meet-web=1.0.6447-1 \
         jitsi-meet-web-config=1.0.6447-1 \
         jitsi-meet-prosody=1.0.6447-1 \
         jitsi-meet-turnserver=1.0.6918-1 \
         jitsi-videobridge2=2.2-22-g42bc1b99-1 \
         jicofo=1.0-911-1"

# jitsi-meet-tokens related packages
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     export DEBIAN_FRONTEND=noninteractive
     apt-get $APT_PROXY_OPTION -y install luarocks liblua5.2-dev
     apt-get $APT_PROXY_OPTION -y install gcc git"

# -----------------------------------------------------------------------------
# EXTERNAL IP
# -----------------------------------------------------------------------------
EXTERNAL_IP=$(dig -4 +short myip.opendns.com a @resolver1.opendns.com) || true
echo EXTERNAL_IP="$EXTERNAL_IP" >> $INSTALLER/000_source

# -----------------------------------------------------------------------------
# JMS SSH KEY
# -----------------------------------------------------------------------------
mkdir -p /root/.ssh
chmod 700 /root/.ssh
cp $MACHINES/eb-jitsi-host/root/.ssh/jms-config /root/.ssh/

# create ssh key if not exists
if [[ ! -f /root/.ssh/jms ]] || [[ ! -f /root/.ssh/jms.pub ]]
then
    rm -f /root/.ssh/jms{,.pub}
    ssh-keygen -qP '' -t rsa -b 2048 -f /root/.ssh/jms
fi

# copy the public key to a downloadable place
cp /root/.ssh/jms.pub $ROOTFS/usr/share/jitsi-meet/static/

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
echo "DNS.2 = $TURN_HOST" >>ssl_eb_jitsi.ext
echo "IP.1 = $IP" >>ssl_eb_jitsi.ext
echo "IP.2 = $REMOTE_IP" >>ssl_eb_jitsi.ext
[[ -n "$EXTERNAL_IP" ]] && [[ "$EXTERNAL_IP" != "$REMOTE_IP" ]] && \
    echo "IP.3 = $EXTERNAL_IP" >>ssl_eb_jitsi.ext || \
    true

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
cp /root/eb_ssl/eb_CA.pem $ROOTFS/usr/local/share/ca-certificates/jms-CA.crt
cp /root/eb_ssl/eb_CA.pem $ROOTFS/usr/share/jitsi-meet/static/jms-CA.crt
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

# set-letsencrypt-cert
cp $MACHINES/common/usr/local/sbin/set-letsencrypt-cert $ROOTFS/usr/local/sbin/
chmod 744 $ROOTFS/usr/local/sbin/set-letsencrypt-cert

# certbot service
mkdir -p $ROOTFS/etc/systemd/system/certbot.service.d
cp $MACHINES/common/etc/systemd/system/certbot.service.d/override.conf \
    $ROOTFS/etc/systemd/system/certbot.service.d/
echo 'ExecStartPost=systemctl restart coturn.service' >> \
    $ROOTFS/etc/systemd/system/certbot.service.d/override.conf
lxc-attach -n $MACH -- systemctl daemon-reload

# coturn
cat >>$ROOTFS/etc/turnserver.conf <<EOF

# the following lines added by eb-jitsi
listening-ip=$IP
allowed-peer-ip=$IP
no-udp
EOF

lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     adduser turnserver ssl-cert
     systemctl restart coturn.service"

# prosody
sed -i "/rate *=.*kb.s/  s/[0-9]*kb/512kb/" $ROOTFS/etc/prosody/prosody.cfg.lua
sed -i "s/^-- \(https_ports = { };\)/\1/" \
    $ROOTFS/etc/prosody/conf.avail/$JITSI_HOST.cfg.lua
sed -i "/turns.*tcp/ s/host\s*=[^,]*/host = \"$TURN_HOST\"/" \
    $ROOTFS/etc/prosody/conf.avail/$JITSI_HOST.cfg.lua
sed -i "/turns.*tcp/ s/5349/443/" \
    $ROOTFS/etc/prosody/conf.avail/$JITSI_HOST.cfg.lua
cp usr/share/jitsi-meet/prosody-plugins/*.lua \
    $ROOTFS/usr/share/jitsi-meet/prosody-plugins/
lxc-attach -n $MACH -- systemctl reload prosody.service

# jicofo
cat >>$ROOTFS/etc/jitsi/jicofo/config <<EOF

# set the maximum memory for the jicofo daemon
JICOFO_MAX_MEMORY=3072m
EOF
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     hocon -f /etc/jitsi/jicofo/jicofo.conf \
         set jicofo.conference.enable-auto-owner true"
lxc-attach -n $MACH -- systemctl restart jicofo.service

# nginx
mkdir -p $ROOTFS/etc/systemd/system/nginx.service.d
cp etc/systemd/system/nginx.service.d/override.conf \
    $ROOTFS/etc/systemd/system/nginx.service.d/
cp $ROOTFS/etc/nginx/nginx.conf $ROOTFS/etc/nginx/nginx.conf.old
sed -i "/worker_connections/ s/\\S*;/8192;/" \
    $ROOTFS/etc/nginx/nginx.conf
mkdir -p $ROOTFS/usr/local/share/nginx/modules-available
cp usr/local/share/nginx/modules-available/jitsi-meet.conf \
    $ROOTFS/usr/local/share/nginx/modules-available/
sed -i "s/___LOCAL_IP___/$IP/" \
    $ROOTFS/usr/local/share/nginx/modules-available/jitsi-meet.conf
sed -i "s/___TURN_HOST___/$TURN_HOST/" \
    $ROOTFS/usr/local/share/nginx/modules-available/jitsi-meet.conf
mv $ROOTFS/etc/nginx/sites-available/$JITSI_HOST.conf \
    $ROOTFS/etc/nginx/sites-available/$JITSI_HOST.conf.old
cp etc/nginx/sites-available/jms.conf \
    $ROOTFS/etc/nginx/sites-available/$JITSI_HOST.conf
sed -i "s/___JITSI_HOST___/$JITSI_HOST/" \
    $ROOTFS/etc/nginx/sites-available/$JITSI_HOST.conf
sed -i "s/___TURN_HOST___/$TURN_HOST/" \
    $ROOTFS/etc/nginx/sites-available/$JITSI_HOST.conf
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     ln -s /usr/local/share/nginx/modules-available/jitsi-meet.conf \
         /etc/nginx/modules-enabled/60-jitsi-meet-custom.conf
     rm /etc/nginx/sites-enabled/default
     rm -rf /var/www/html
     ln -s /usr/share/jitsi-meet /var/www/html"

lxc-attach -n $MACH -- systemctl daemon-reload
lxc-attach -n $MACH -- systemctl stop nginx.service
lxc-attach -n $MACH -- systemctl start nginx.service

# -----------------------------------------------------------------------------
# JVB
# -----------------------------------------------------------------------------
# default memory limit
cat >>$ROOTFS/etc/jitsi/videobridge/config <<EOF

# set the maximum memory for the JVB daemon
VIDEOBRIDGE_MAX_MEMORY=3072m
EOF

# colibri
lxc-attach -n $MACH -- \
    zsh -c \
    "set -e
     hocon -f /etc/jitsi/videobridge/jvb.conf \
         set videobridge.apis.rest.enabled true
     hocon -f /etc/jitsi/videobridge/jvb.conf \
         set videobridge.ice.udp.port 10000"

# NAT harvester. these will be needed if this is an in-house server.
[[ -n "$EXTERNAL_IP" ]] && \
    PUBLIC_IP=$EXTERNAL_IP || \
    PUBLIC_IP=$REMOTE_IP

cat >>$ROOTFS/etc/jitsi/videobridge/sip-communicator.properties <<EOF
org.ice4j.ice.harvest.NAT_HARVESTER_LOCAL_ADDRESS=$IP
org.ice4j.ice.harvest.NAT_HARVESTER_PUBLIC_ADDRESS=$PUBLIC_IP
EOF

# restart
lxc-attach -n $MACH -- systemctl restart jitsi-videobridge2.service

# -----------------------------------------------------------------------------
# TOOLS & SCRIPTS
# -----------------------------------------------------------------------------
# jicofo-log-analyzer
cp usr/local/bin/jicofo-log-analyzer $ROOTFS/usr/local/bin/
chmod 755 $ROOTFS/usr/local/bin/jicofo-log-analyzer

# -----------------------------------------------------------------------------
# CONTAINER SERVICES
# -----------------------------------------------------------------------------
lxc-stop -n $MACH
lxc-wait -n $MACH -s STOPPED
lxc-start -n $MACH -d
lxc-wait -n $MACH -s RUNNING

# -----------------------------------------------------------------------------
# HOST CUSTOMIZATION FOR JITSI
# -----------------------------------------------------------------------------
# jitsi tools
cp $MACHINES/eb-jitsi-host/usr/local/sbin/add-jvb-node /usr/local/sbin/
cp $MACHINES/eb-jitsi-host/usr/local/sbin/set-letsencrypt-cert /usr/local/sbin/
chmod 744 /usr/local/sbin/add-jvb-node
chmod 744 /usr/local/sbin/set-letsencrypt-cert

# Scale down JVBs (disabled by default)
cp $MACHINES/eb-jitsi-host/usr/local/sbin/scale-down-jvb-nodes /usr/local/sbin/
chmod 744 /usr/local/sbin/scale-down-jvb-nodes
cp $MACHINES/eb-jitsi-host/etc/systemd/system/scale-down-jvb-nodes.service \
    /etc/systemd/system/

systemctl daemon-reload
systemctl disable scale-down-jvb-nodes.service
