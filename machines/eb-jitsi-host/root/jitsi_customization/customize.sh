#!/bin/bash
set -e

# -----------------------------------------------------------------------------
# This script customizes the Jitsi installation. Run it on the host machine.
#
# usage:
#     bash customize.sh
# -----------------------------------------------------------------------------
APP_NAME="Jitsi Meet"
WATERMARK_LINK="https://jitsi.org"

BASEDIR=$(dirname $0)
JITSI_MEET="/var/lib/lxc/eb-jitsi/rootfs/usr/share/jitsi-meet"
JITSI_MEET_INTERFACE="$JITSI_MEET/interface_config.js"
JITSI_MEET_CONFIG="/var/lib/lxc/eb-jitsi/rootfs/etc/jitsi/meet/___JITSI_HOST___-config.js"
JITSI_MEET_VERSION=$(lxc-attach -n eb-jitsi -- apt-cache policy jitsi-meet | \
                     grep Installed | cut -d: -f2 | xargs)
PROSODY="/var/lib/lxc/eb-jitsi/rootfs/etc/prosody/conf.avail/___JITSI_HOST___.cfg.lua"
JICOFO="/var/lib/lxc/eb-jitsi/rootfs/etc/jitsi/jicofo"

FAVICON="$BASEDIR/favicon.ico"
WATERMARK="$BASEDIR/watermark.svg"

# -----------------------------------------------------------------------------
# backup
# -----------------------------------------------------------------------------
DATE=$(date +'%Y%m%d%H%M%S')
BACKUP=$BASEDIR/backup/$DATE

mkdir -p $BACKUP
cp $JITSI_MEET_INTERFACE $BACKUP/
cp $JITSI_MEET_CONFIG $BACKUP/
cp $JITSI_MEET/images/favicon.ico $BACKUP/
cp $JITSI_MEET/images/watermark.svg $BACKUP/

# -----------------------------------------------------------------------------
# jitsi-meet config.js
# -----------------------------------------------------------------------------
sed -i "/startWithVideoMuted:/ s~//\s*~~" $JITSI_MEET_CONFIG
sed -i "/startWithVideoMuted:/ s~:.*~: true,~" $JITSI_MEET_CONFIG
sed -i "/channelLastN:/ s~//\s*~~" $JITSI_MEET_CONFIG
sed -i "/channelLastN:/ s~:.*~: 6,~" $JITSI_MEET_CONFIG

# -----------------------------------------------------------------------------
# jitsi-meet interface_config.js
# -----------------------------------------------------------------------------
cp $FAVICON $JITSI_MEET/
cp $FAVICON $JITSI_MEET/images/
cp $WATERMARK $JITSI_MEET/images/

#sed -i "s/watermark.svg/watermark.png/" $JITSI_MEET_INTERFACE
sed -i "/^\s*APP_NAME:/ s~:.*~: '$APP_NAME',~" $JITSI_MEET_INTERFACE
sed -i "/^\s*DISABLE_JOIN_LEAVE_NOTIFICATIONS:/ s~:.*~: true,~" \
    $JITSI_MEET_INTERFACE
sed -i "/^\s*GENERATE_ROOMNAMES_ON_WELCOME_PAGE:/ s~:.*~: false,~" \
    $JITSI_MEET_INTERFACE
sed -i "/^\s*JITSI_WATERMARK_LINK:/ s~:.*~: '$WATERMARK_LINK',~" \
    $JITSI_MEET_INTERFACE
sed -i "/ENFORCE_NOTIFICATION_AUTO_DISMISS_TIMEOUT:/ s~//\s*~~" \
    $JITSI_MEET_INTERFACE
sed -i "/^\s*ENFORCE_NOTIFICATION_AUTO_DISMISS_TIMEOUT:/ s~:.*~: 5000,~" \
    $JITSI_MEET_INTERFACE

# -----------------------------------------------------------------------------
# jwt
# -----------------------------------------------------------------------------
#lxc-attach -n eb-jitsi -- \
#    zsh -c \
#    "set -e
#     export DEBIAN_FRONTEND=noninteractive
#     debconf-set-selections <<< \
#         'jitsi-meet-tokens jitsi-meet-tokens/appid string myappid'
#     debconf-set-selections <<< \
#         'jitsi-meet-tokens jitsi-meet-tokens/appsecret password myappsecret'
#     apt-get -y install jitsi-meet-tokens"
#
#sed -i '/allow_empty_token/d' $PROSODY
#sed -i '/token_affiliation/d' $PROSODY
#sed -i '/token_owner_party/d' $PROSODY
#sed -i '/\s*app_secret=/a \
#\    allow_empty_token = false' $PROSODY
#sed -i '/^Component .conference\./,/admins/!b; /\s*"token_verification"/a \
#\        "token_affiliation";' $PROSODY
#sed -i '/^Component .conference\./,/admins/!b; /\s*"token_affiliation"/a \
#\        "token_owner_party";' $PROSODY
#lxc-attach -n eb-jitsi -- systemctl restart prosody.service
#
#lxc-attach -n eb-jitsi -- \
#    zsh -c \
#    "set -e
#     hocon -f /etc/jitsi/jicofo/jicofo.conf \
#         set jicofo.conference.enable-auto-owner false
#     systemctl restart jicofo.service
#     systemctl restart jitsi-videobridge2.service"
#
#sed -i "/disableProfile:/ s~//\s*~~" $JITSI_MEET_CONFIG
#sed -i "/disableProfile:/ s~:.*~: true,~" $JITSI_MEET_CONFIG
#sed -i "/enableFeaturesBasedOnToken:/ s~//\s*~~" $JITSI_MEET_CONFIG
#sed -i "/enableFeaturesBasedOnToken:/ s~:.*~: true,~" $JITSI_MEET_CONFIG
