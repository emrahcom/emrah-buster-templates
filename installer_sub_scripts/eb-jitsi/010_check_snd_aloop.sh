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
modprobe -n snd_aloop || \
    cat <<EOF
This kernel ($(uname -r)) does not support snd_aloop module.
Please install the standard Linux kernel and reboot it.
EOF
