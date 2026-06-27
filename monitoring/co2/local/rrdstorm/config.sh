#!/bin/bash
# rrdstorm decomposed - global configuration
# Source this file from wrapper.sh

VERSION="raio"
RRDTOOL="${RRDTOOL:-/usr/bin/rrdtool}"
RRDUPDATE="${RRDUPDATE:-/usr/bin/rrdupdate}"
RRDDATA="${RRDDATA:-/var/lib/rrd/storj}"
RRDOUTPUT="${RRDOUTPUT:-/dev/shm/rrd.img}"
FORCEGRAPH="${FORCEGRAPH:-no}"

TIMED_DASHBOARDS=(
    "4h:4 Hours dashboard:12 19 54 24 30 48 36 42"
    "1d:1 Day dashboard:13 20 56 26 32 50 38 44"
)
