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

APP_NAME="Jitsi Meet"
FAVICON="$BASEDIR/favicon.ico"
WATERMARK="$BASEDIR/watermark.png"
WATERMARK_LINK="https://jitsi.org"

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
sed -i '/\/\/ capScreenshareBitrate/a \        capScreenshareBitrate: 1,' \
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
