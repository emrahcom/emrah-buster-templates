#!/bin/bash

# -----------------------------------------------------------------------------
# JIBRI-EPHEMERAL-START.SH
# -----------------------------------------------------------------------------
#
# Create and run the ephimeral Jibri containers. The number of containers
# depends on the CORES count (one Jibri instance per 2 cores) but it can not be
# more than LIMIT.
#
# -----------------------------------------------------------------------------
LIMIT=16
CORES=$(nproc --all)

(( N = LIMIT * 2 ))
[[ $N -gt $CORES ]] && N=$CORES

for c in $(seq 2 2 $N); do
    (( ID = c / 2 ))

    lxc-copy -n eb-jibri-template -N eb-jibri-$ID -e
done
