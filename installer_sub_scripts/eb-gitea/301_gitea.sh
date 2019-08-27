# -----------------------------------------------------------------------------
# GITEA.SH
# -----------------------------------------------------------------------------
set -e
source $INSTALLER/000_source

# -----------------------------------------------------------------------------
# ENVIRONMENT
# -----------------------------------------------------------------------------
MACH="eb-gitea"
cd $MACHINES/$MACH

ROOTFS="/var/lib/lxc/$MACH/rootfs"
DNS_RECORD=$(grep "address=/$MACH/" /etc/dnsmasq.d/eb_gitea | head -n1)
IP=${DNS_RECORD##*/}
SSH_PORT="30$(printf %03d ${IP##*.})"
echo GITEA="$IP" >> $INSTALLER/000_source

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

# -----------------------------------------------------------------------------
# INIT
# -----------------------------------------------------------------------------
[ "$DONT_RUN_GITEA" = true ] && exit

echo
echo "-------------------------- $MACH --------------------------"

# -----------------------------------------------------------------------------
# REINSTALL_IF_EXISTS
# -----------------------------------------------------------------------------
EXISTS=$(lxc-info -n $MACH | egrep '^State' || true)
if [ -n "$EXISTS" -a "$REINSTALL_GITEA_IF_EXISTS" != true ]
then
    echo "Already installed. Skipped..."
    echo
    echo "Please set REINSTALL_GITEA_IF_EXISTS in $APP_CONFIG"
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
    "echo $MACH > /etc/hostname
     sed -i 's/\(127.0.1.1\s*\).*$/\1$MACH/' /etc/hosts
     hostname $MACH"

# -----------------------------------------------------------------------------
# PACKAGES
# -----------------------------------------------------------------------------
# update
lxc-attach -n $MACH -- \
    zsh -c \
    "apt-get $APT_PROXY_OPTION update
     sleep 3
     apt-get $APT_PROXY_OPTION -y dist-upgrade"

# packages
lxc-attach -n $MACH -- \
    zsh -c \
    "export DEBIAN_FRONTEND=noninteractive
     debconf-set-selections <<< \
         'mysql-server mysql-server/root_password password'
     debconf-set-selections <<< \
         'mysql-server mysql-server/root_password_again password'
     apt-get $APT_PROXY_OPTION -y install mariadb-server"

lxc-attach -n $MACH -- \
    zsh -c \
    "export DEBIAN_FRONTEND=noninteractive
     apt-get install -y ssl-cert ca-certificates certbot
     apt-get install -y nginx-extras"

lxc-attach -n $MACH -- \
    zsh -c \
    "export DEBIAN_FRONTEND=noninteractive
     apt-get install -y git"

# -----------------------------------------------------------------------------
# SYSTEM CONFIGURATION
# -----------------------------------------------------------------------------
# ssl
lxc-attach -n $MACH -- \
    zsh -c \
    "ln -s ssl-cert-snakeoil.pem /etc/ssl/certs/ssl-eb.pem
     ln -s ssl-cert-snakeoil.key /etc/ssl/private/ssl-eb.key"

# nginx
cp etc/nginx/conf.d/custom.conf $ROOTFS/etc/nginx/conf.d/
cp etc/nginx/snippets/eb_ssl.conf $ROOTFS/etc/nginx/snippets/
cp etc/nginx/sites-available/gitea $ROOTFS/etc/nginx/sites-available/
ln -s ../sites-available/gitea $ROOTFS/etc/nginx/sites-enabled/
rm $ROOTFS/etc/nginx/sites-enabled/default

lxc-attach -n $MACH -- systemctl stop nginx.service
lxc-attach -n $MACH -- systemctl start nginx.service

# certbot service
cp ../common/lib/systemd/system/certbot.service $ROOTFS/lib/systemd/system/
lxc-attach -n $MACH -- systemctl daemon-reload

# -----------------------------------------------------------------------------
# GITEA
# -----------------------------------------------------------------------------
# gitea user
lxc-attach -n $MACH -- adduser gitea --system --group --disabled-password \
    --shell /bin/bash --gecos ''

# gitea database
lxc-attach -n $MACH -- mysql <<EOF
CREATE DATABASE gitea DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER gitea@localhost IDENTIFIED VIA unix_socket;
GRANT ALL PRIVILEGES on gitea.* to gitea@localhost;
EOF

# gitea download
latest_dir=$(curl -s https://dl.gitea.io/gitea/ | \
	     ack -o "/gitea/\d+\.\d+\.\d+/" | tail -n1 | \
	     sed 's~\(^/\|/$\)~~g')
latest_ver=$(echo $latest_dir | sed 's~/~-~g')
latest_lnk="https://dl.gitea.io/$latest_dir/$latest_ver-linux-amd64"

[[ -z "$latest_ver" ]] && \
[[ -n "$(find /root/eb_store -maxdepth 1 -name 'gitea-*-linux-amd64')" ]] && \
latest_ver=$(ls -1 /root/eb_store/gitea-*-linux-amd64 | \
             ack -o 'gitea-\d+\.\d+\.\d+' | tail -n1)

mkdir -p /root/eb_store
if [[ ! -f "/root/eb_store/$latest_ver-linux-amd64" ]]
then
    wget -NP /tmp $latest_lnk
    mv /tmp/$latest_ver-linux-amd64 /root/eb_store/
else
    echo "Gitea already exists. Skipped the download"
fi

# deploy the gitea application
cp /root/eb_store/$latest_ver-linux-amd64 $ROOTFS/home/gitea/
lxc-attach -n $MACH -- \
    zsh -c \
    "chown gitea:gitea /home/gitea/$latest_ver-linux-amd64
     chmod u+x /home/gitea/$latest_ver-linux-amd64
     su -l gitea -c 'ln -s $latest_ver-linux-amd64 /home/gitea/gitea'"

# Gitea initial config
lxc-attach -n $MACH -- \
    zsh -c \
    "su -l gitea -c '/home/gitea/gitea web >/dev/null 2>&1'" &

lxc-attach -n $MACH -- \
    zsh -c \
    "while true; do sleep 1; curl --head http://127.0.0.1:3000 && break; done"
lxc-attach -n $MACH -- \
    zsh -c \
    "curl -s -X POST \
	 -d 'app_name=Gitea: Git with a cup of tea' \
         -d 'db_type=MySQL&db_host=/var/run/mysqld/mysqld.sock' \
         -d 'db_user=gitea&db_passwd=&db_name=gitea&charset=utf8mb4' \
	 -d 'repo_root_path=/home/gitea/gitea-repositories' \
	 -d 'lfs_root_path=/home/gitea/data/lfs' \
	 -d 'log_root_path=/home/gitea/log' \
	 -d 'domain=$REMOTE_IP&ssh_port=$SSH_PORT&run_user=gitea' \
	 -d 'app_url=https://$REMOTE_IP/&http_port=3000' \
	 -d 'ssl_mode=disable' \
	 http://127.0.0.1:3000/install
     sleep 3"
lxc-attach -n $MACH -- \
    zsh -c \
    "pkill gitea"
lxc-attach -n $MACH -- \
    zsh -c \
    "sed -i '/^INSTALL_LOCK/ s/true/false/' /home/gitea/custom/conf/app.ini"

# Gitea upgrade script
cp root/eb_scripts/upgrade_gitea.sh $ROOTFS/root/eb_scripts/
chmod u+x $ROOTFS/root/eb_scripts/upgrade_gitea.sh

# systemd the gitea services
cp etc/systemd/system/gitea.service $ROOTFS/etc/systemd/system/
cp etc/systemd/system/upgrade_gitea.service $ROOTFS/etc/systemd/system/
lxc-attach -n $MACH -- \
    zsh -c \
    "systemctl daemon-reload
     systemctl enable gitea.service
     systemctl enable upgrade_gitea.service
     systemctl restart gitea.service
     systemctl restart upgrade_gitea.service"

# -----------------------------------------------------------------------------
# CONTAINER SERVICES
# -----------------------------------------------------------------------------
lxc-stop -n $MACH
lxc-wait -n $MACH -s STOPPED
lxc-start -n $MACH -d
lxc-wait -n $MACH -s RUNNING
