#!/bin/bash

# -----------------------------------------------------------------------------
# JIBRI-EPHEMERAL-CONTAINER.SH
# -----------------------------------------------------------------------------
#
# Create and run the ephimeral Jibri containers. The number of containers
# depends on the CPU count.
#
# -----------------------------------------------------------------------------
CORES=$(nproc --all)

for c in $(seq 2 2 $CORES); do
    (( ID = c / 2 ))

    lxc-copy -n eb-jibri-template -N eb-jibri-$ID -e
done
