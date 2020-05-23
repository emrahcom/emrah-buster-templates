#!/bin/bash

# In download-only mode (DOWNLOAD_ONLY=1), the newest version is downloaded
# but it's not upgraded. If it's disabled (DOWNLOAD_ONLY=0), the gitea service
# will be upgraded too and the gitea service will restart with the new
# executable.

DOWNLOAD_ONLY=0

latest_dir=$(curl -s https://dl.gitea.io/gitea/ | \
             ack -o '/gitea/\d+\.\d+\.\d+"' | ack -o "[0-9.]+" | \
             awk -F '.' '{printf "%03d%03d%03d-%s\n", $1, $2, $3, $0}' | \
             sort -n | tail -n1 | \
             awk -F '-' '{printf "gitea/%s", $2}')
latest_ver=$(echo $latest_dir | sed 's~/~-~g')
latest_lnk="https://dl.gitea.io/$latest_dir/$latest_ver-linux-amd64"

[[ -z "$latest_dir" ]] && exit 1
[[ -f "/home/gitea/$latest_ver-linux-amd64" ]] && exit

wget -qNP /tmp $latest_lnk || exit 2
mv /tmp/$latest_ver-linux-amd64 /home/gitea/
chown gitea:gitea /home/gitea/$latest_ver-linux-amd64
chmod u+x /home/gitea/$latest_ver-linux-amd64

[[ "$DOWNLOAD_ONLY" = 1 ]] && exit
systemctl stop gitea.service
rm -f /home/gitea/gitea
su -l gitea -c "ln -s $latest_ver-linux-amd64 /home/gitea/gitea"
systemctl start gitea.service
