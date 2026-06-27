#!/bin/bash
# Data extraction: CO2, temperature and humidity
# Usage: ./data/2-temp.sh
# Output: colon-separated values: co2:co2kid:humint:tempint:humout:tempout:humout2:tempout2:humkid:tempkid:humconv

Calc() {
    if [ -f "$1" ] && [ `stat --format=%Y $1` -ge $(( `date +%s` - 120 )) ]; then
        cat "$1"
    else
        echo "U U"
    fi
}

CO2LEVEL=`sudo -u vlysenkov ssh -o ConnectTimeout=2 -o ServerAliveInterval=2 -ServerAliveCountMax=2 -l pi 192.168.50.13 "[ -f /tmp/k30.upd ] || ( cd /home/pi/xopok-scripts; git stash>/dev/null; git pull>/dev/null; touch /tmp/k30.upd; ) ; /home/pi/xopok-scripts/monitoring/co2/local/k30.py -t 1" || echo "U"`
CO2KID=`sudo -u vlysenkov ssh -o ConnectTimeout=2 -o ServerAliveInterval=2 -ServerAliveCountMax=2 -l pi 192.168.50.14 "/home/pi/xopok-scripts/monitoring/co2/local/k30.py -t 3 -d ttyS0" || echo "U"`
CO2KID=`[ $CO2KID -eq 0 ] && echo "U" || echo $CO2KID`

HUMTEMPINT=$(Calc /dev/shm/sdr-Nexus-TH-95-1)
HUMTEMPOUT=$(Calc /dev/shm/sdr-Nexus-TH-83-2)
HUMTEMPOUT2=$(Calc /dev/shm/sdr-Nexus-TH-48-2)
HUMTEMPKID=$(Calc /dev/shm/sdr-Nexus-TH-101-3)
HUMTEMP=${HUMTEMPINT} ${HUMTEMPOUT} ${HUMTEMPOUT2} ${HUMTEMPKID}
HUMCONV=$(echo "$HUMTEMP"| awk "{print \$3\" \"\$4\" \"\$8}")
HUMCONV=`/home/vlysenkov/xopok-scripts/monitoring/co2/local/humconv.py $HUMCONV`
HUMTEMP=$(echo ${HUMTEMP} | sed "s/ /:/g")
TEMPOUT=$(echo ${HUMTEMPOUT} | sed "s/.* //")

echo "${CO2LEVEL}:${CO2KID}:${HUMTEMP}:${HUMCONV}"
