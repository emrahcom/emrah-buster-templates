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
sed -i "/^\s*p2pTestMode:/ s~false$~false,~" $JITSI_MEET_CONFIG
sed -i '/^\s*capScreenshareBitrate:/d' $JITSI_MEET_CONFIG
sed -i '/\/\/ capScreenshareBitrate/a \        capScreenshareBitrate: 1' \
    $JITSI_MEET_CONFIG

sed -i "/disableAudioLevels:/ s~//\s*~~" $JITSI_MEET_CONFIG
sed -i "/disableAudioLevels:/ s~:.*~: true,~" $JITSI_MEET_CONFIG
sed -i "/startAudioMuted:/ s~//\s*~~" $JITSI_MEET_CONFIG
sed -i "/startAudioMuted:/ s~:.*~: 10,~" $JITSI_MEET_CONFIG
sed -i "/startWithAudioMuted:/ s~//\s*~~" $JITSI_MEET_CONFIG
sed -i "/startWithAudioMuted:/ s~:.*~: false,~" $JITSI_MEET_CONFIG

sed -i "/startVideoMuted:/ s~//\s*~~" $JITSI_MEET_CONFIG
sed -i "/startVideoMuted:/ s~:.*~: 10,~" $JITSI_MEET_CONFIG
sed -i "/startWithVideoMuted:/ s~//\s*~~" $JITSI_MEET_CONFIG
sed -i "/startWithVideoMuted:/ s~:.*~: true,~" $JITSI_MEET_CONFIG
sed -i "/channelLastN:/ s~//\s*~~" $JITSI_MEET_CONFIG
sed -i "/channelLastN:/ s~:.*~: 4,~" $JITSI_MEET_CONFIG
sed -i "/requireDisplayName:/ s~//\s*~~" $JITSI_MEET_CONFIG
sed -i "/requireDisplayName:/ s~:.*~: true,~" $JITSI_MEET_CONFIG
sed -i "/defaultLanguage:/ s~//\s*~~" $JITSI_MEET_CONFIG
sed -i "/defaultLanguage:/ s~:.*~: 'en',~" $JITSI_MEET_CONFIG
sed -i "/disableInviteFunctions:/ s~//\s*~~" $JITSI_MEET_CONFIG
sed -i "/disableInviteFunctions:/ s~:.*~: false,~" $JITSI_MEET_CONFIG
sed -i "/doNotStoreRoom:/ s~//\s*~~" $JITSI_MEET_CONFIG
sed -i "/doNotStoreRoom:/ s~:.*~: false,~" $JITSI_MEET_CONFIG

#sed -i "/resolution:/ s~//\s*~~" $JITSI_MEET_CONFIG
#sed -i "/resolution:/ s~:.*~: 720,~" $JITSI_MEET_CONFIG
#sed -i "/constraints:/ s~//\s*~~" $JITSI_MEET_CONFIG
#sed -i "/constraints:/ s~:.*~: \
#{\
#video: {\
#aspectRatio: 16 / 9, \
#height: {\
#ideal: 720, \
#max: 720, \
#min: 240}}},~" $JITSI_MEET_CONFIG

# -----------------------------------------------------------------------------
# jitsi-meet interface_config.js
# -----------------------------------------------------------------------------
cp $FAVICON $JITSI_MEET/images/favicon.ico
cp $WATERMARK $JITSI_MEET/images/watermark.svg

sed -i "/^\s*APP_NAME:/ s~:.*~: '$APP_NAME',~" $JITSI_MEET_INTERFACE
sed -i "/^\s*DISABLE_FOCUS_INDICATOR:/ s~:.*~: true,~" \
    $JITSI_MEET_INTERFACE
sed -i "/^\s*DISABLE_JOIN_LEAVE_NOTIFICATIONS:/ s~:.*~: true,~" \
    $JITSI_MEET_INTERFACE
sed -i "/^\s*DISABLE_VIDEO_BACKGROUND:/ s~:.*~: true,~" $JITSI_MEET_INTERFACE
sed -i "/^\s*GENERATE_ROOMNAMES_ON_WELCOME_PAGE:/ s~:.*~: false,~" \
    $JITSI_MEET_INTERFACE
sed -i "/^\s*HIDE_INVITE_MORE_HEADER:/ s~:.*~: false,~" $JITSI_MEET_INTERFACE
sed -i "/^\s*JITSI_WATERMARK_LINK:/ s~:.*~: '$WATERMARK_LINK',~" \
    $JITSI_MEET_INTERFACE
sed -i "/^\s*LANG_DETECTION:/ s~:.*~: true,~" $JITSI_MEET_INTERFACE
sed -i "/ENFORCE_NOTIFICATION_AUTO_DISMISS_TIMEOUT:/ s~//\s*~~" \
    $JITSI_MEET_INTERFACE
sed -i "/^\s*ENFORCE_NOTIFICATION_AUTO_DISMISS_TIMEOUT:/ s~:.*~: 5000,~" \
    $JITSI_MEET_INTERFACE

sed -i "s~'videobackgroundblur'~''~" $JITSI_MEET_INTERFACE
#sed -i "s~'embedmeeting'~''~" $JITSI_MEET_INTERFACE
#sed -i "s~'invite'~''~" $JITSI_MEET_INTERFACE
#sed -i "s~'feedback'~''~" $JITSI_MEET_INTERFACE

# -----------------------------------------------------------------------------
# jitsi-meet customization
# -----------------------------------------------------------------------------
cp $BASEDIR/chat.svg $JITSI_MEET/images/
cp $BASEDIR/custom.css $JITSI_MEET/css/
sed -i "/custom\.css?v=/d" $JITSI_MEET/index.html
sed -i "/link.*stylesheet.*all.css?v=/a \
\    <link rel=\"stylesheet\" href=\"css/custom.css?v=$JITSI_MEET_VERSION\">" \
    $JITSI_MEET/index.html
sed -i "/\"app\.bundle\.min\.js\",/a \
\            \"custom.css?v=$JITSI_MEET_VERSION\"," \
    $JITSI_MEET/index.html

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
#     systemctl restart jitsi-videobridge2.service"
#
#sed -i "/enableUserRolesBasedOnToken:/ s~//\s*~~" $JITSI_MEET_CONFIG
#sed -i "/enableUserRolesBasedOnToken:/ s~:.*~: true,~" $JITSI_MEET_CONFIG
#sed -i "/enableFeaturesBasedOnToken:/ s~//\s*~~" $JITSI_MEET_CONFIG
#sed -i "/enableFeaturesBasedOnToken:/ s~:.*~: true,~" $JITSI_MEET_CONFIG
