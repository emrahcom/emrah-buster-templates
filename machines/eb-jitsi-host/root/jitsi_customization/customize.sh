#!/bin/bash
set -e

# -----------------------------------------------------------------------------
# This script customizes the Jitsi installation. Run it on the host machine.
#
# usage:
#     bash customize.sh
# -----------------------------------------------------------------------------
BASEDIR=$(dirname $0)
JITSI_MEET="/var/lib/lxc/eb-jitsi/rootfs/usr/share/jitsi-meet"
INTERFACE="$JITSI_MEET/interface_config.js"
CONFIG="/var/lib/lxc/eb-jitsi/rootfs/etc/jitsi/meet/___JITSI_HOST___-config.js"
PROSODY="/var/lib/lxc/eb-jitsi/rootfs/etc/prosody/conf.avail/___JITSI_HOST___.cfg.lua"
JICOFO="/var/lib/lxc/eb-jitsi/rootfs/etc/jitsi/jicofo"

APP_NAME="Jitsi Meet"
FAVICON="$BASEDIR/favicon.ico"
WATERMARK="$BASEDIR/watermark.png"
WATERMARK_LINK="https://jitsi.org"

# -----------------------------------------------------------------------------
# backup
# -----------------------------------------------------------------------------
DATE=$(date +'%Y%m%d%H%M%S')
BACKUP=$BASEDIR/backup/$DATE

mkdir -p $BACKUP
cp $INTERFACE $BACKUP/
cp $CONFIG $BACKUP/
cp $JITSI_MEET/images/favicon.ico $BACKUP/
cp $JITSI_MEET/images/watermark.png $BACKUP/

# -----------------------------------------------------------------------------
# interface_config.js
# -----------------------------------------------------------------------------
cp $FAVICON $JITSI_MEET/images/favicon.ico
cp $WATERMARK $JITSI_MEET/images/watermark.png
cp $WATERMARK $JITSI_MEET/images/watermark-custom.png
sed -i "/^\s*DEFAULT_LOGO_URL:/ s~:.*~: 'images/watermark-custom.png',~" \
        $INTERFACE
sed -i "/^\s*APP_NAME:/ s~:.*~: '$APP_NAME',~" $INTERFACE

sed -i "/^\s*DISABLE_JOIN_LEAVE_NOTIFICATIONS:/ s~:.*~: true,~" $INTERFACE
sed -i "/^\s*DISABLE_VIDEO_BACKGROUND:/ s~:.*~: true,~" $INTERFACE
sed -i "/^\s*GENERATE_ROOMNAMES_ON_WELCOME_PAGE:/ s~:.*~: false,~" $INTERFACE
sed -i "/^\s*HIDE_INVITE_MORE_HEADER:/ s~:.*~: false,~" $INTERFACE
sed -i "/^\s*JITSI_WATERMARK_LINK:/ s~:.*~: '$WATERMARK_LINK',~" $INTERFACE
sed -i "/^\s*LANG_DETECTION:/ s~:.*~: true,~" $INTERFACE
sed -i "/ENFORCE_NOTIFICATION_AUTO_DISMISS_TIMEOUT:/ s~//\s*~~" $INTERFACE
sed -i "/^\s*ENFORCE_NOTIFICATION_AUTO_DISMISS_TIMEOUT:/ s~:.*~: 5000,~" \
    $INTERFACE

sed -i "s~'videobackgroundblur', *~~" $INTERFACE
#sed -i "s~'embedmeeting', *~~" $INTERFACE
#sed -i "s~'invite', *~~" $INTERFACE
#sed -i "s~'feedback', *~~" $INTERFACE

# -----------------------------------------------------------------------------
# config.js
# -----------------------------------------------------------------------------
sed -i "/^\s*p2pTestMode:/ s~false$~false,~" $CONFIG
sed -i '/^\s*capScreenshareBitrate:/d' $CONFIG
sed -i '/\/\/ capScreenshareBitrate/a \        capScreenshareBitrate: 1' \
    $CONFIG

sed -i "/disableAudioLevels:/ s~//\s*~~" $CONFIG
sed -i "/disableAudioLevels:/ s~:.*~: true,~" $CONFIG
sed -i "/startAudioMuted:/ s~//\s*~~" $CONFIG
sed -i "/startAudioMuted:/ s~:.*~: 10,~" $CONFIG
sed -i "/startWithAudioMuted:/ s~//\s*~~" $CONFIG
sed -i "/startWithAudioMuted:/ s~:.*~: false,~" $CONFIG

sed -i "/startVideoMuted:/ s~//\s*~~" $CONFIG
sed -i "/startVideoMuted:/ s~:.*~: 10,~" $CONFIG
sed -i "/startWithVideoMuted:/ s~//\s*~~" $CONFIG
sed -i "/startWithVideoMuted:/ s~:.*~: true,~" $CONFIG
sed -i "/channelLastN:/ s~//\s*~~" $CONFIG
sed -i "/channelLastN:/ s~:.*~: 2,~" $CONFIG
sed -i "/requireDisplayName:/ s~//\s*~~" $CONFIG
sed -i "/requireDisplayName:/ s~:.*~: true,~" $CONFIG
sed -i "/defaultLanguage:/ s~//\s*~~" $CONFIG
sed -i "/defaultLanguage:/ s~:.*~: 'en',~" $CONFIG
sed -i "/disableInviteFunctions:/ s~//\s*~~" $CONFIG
sed -i "/disableInviteFunctions:/ s~:.*~: false,~" $CONFIG
sed -i "/doNotStoreRoom:/ s~//\s*~~" $CONFIG
sed -i "/doNotStoreRoom:/ s~:.*~: false,~" $CONFIG

#sed -i "/resolution:/ s~//\s*~~" $CONFIG
#sed -i "/resolution:/ s~:.*~: 720,~" $CONFIG
#sed -i "/constraints:/ s~//\s*~~" $CONFIG
#sed -i "/constraints:/ s~:.*~: \
#{\
#video: {\
#aspectRatio: 16 / 9, \
#height: {\
#ideal: 720, \
#max: 720, \
#min: 240}}},~" $CONFIG

# -----------------------------------------------------------------------------
# token
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
#sed -i '/\s*app_secret=/a \        allow_empty_token = false' $PROSODY
#sed -i '/\s*"token_verification"/a \        "token_affiliation";' $PROSODY
#sed -i '/\s*"token_affiliation"/a \        "token_owner_party";' $PROSODY
#
#lxc-attach -n eb-jitsi -- systemctl restart prosody.service
#
#sed -i "/org.jitsi.jicofo.DISABLE_AUTO_OWNER/ s/^#//" \
#    $JICOFO/sip-communicator.properties
#
#lxc-attach -n eb-jitsi -- \
#    zsh -c \
#    "set -e
#     systemctl restart jicofo.service
#     systemctl stop jitsi-videobridge2.service
#     systemctl disable jitsi-videobridge2.service"
#
#sed -i "/enableUserRolesBasedOnToken:/ s~//\s*~~" $CONFIG
#sed -i "/enableUserRolesBasedOnToken:/ s~:.*~: true,~" $CONFIG
#sed -i "/enableFeaturesBasedOnToken:/ s~//\s*~~" $CONFIG
#sed -i "/enableFeaturesBasedOnToken:/ s~:.*~: true,~" $CONFIG
