# -----------------------------------------------------------------------------
# CHECK_SND_ALOOP.SH
# -----------------------------------------------------------------------------
set -e
source $INSTALLER/000_source

# -----------------------------------------------------------------------------
# INIT
# -----------------------------------------------------------------------------
[ "$DONT_RUN_JIBRI" = true ] && exit

echo
echo "----------------- SND_ALOOP SUPPORT CHECK -----------------"

modprobe snd_aloop 2>/dev/null || true

if [ -z "$(grep snd_aloop /proc/modules)" ]; then
    cat <<EOF

This kernel ($(uname -r)) does not support snd_aloop module.

Please install the standard Linux kernel (probably it's linux-image-$(dpkg --print-architecture))
and reboot it.
EOF

[ "$AM_I_IN_LXC" = true ] && cat <<EOF

If this is a container, please load the snd_aloop module to the host
permanently
EOF

    false
fi
