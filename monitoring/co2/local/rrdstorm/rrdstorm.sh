#!/bin/bash
####################################################################
# rrdstorm v1.3 (c) 2007-2008 http://xlife.zuavra.net && cupacup at wl500g.info
# Adapted for RT-N66u by ryzhov_al @ wl500g.info
#
# Published under the terms of the GNU General Public License v2.
# This program simplifies the use of rrdtool and rrdupdate.
# Please, check WAN interface name at line #369 (default is "ppp0"), and
# your disk partitions names at lines #435, #436 (default is "sda1" and "sda2").
#
# Usage:
# first run "rrdstorm create 0 1 2 3 4 5 6" to create html an database files,
# then you must update databases ever 60s using "rrdstorm update 0 1 2 3 4 5 6".
# You may draw all graphs using "rrdstorm graph 0 1 2 3 4 5 6"
# or draw graphs for a some periode of time using "rrdstorm graph_cron s 0 1 2 3 4 5 6"
# where:
# s means 1 hour graphs,
# h means 4 hours graphs,
# d means 24 hours graphs,
# w means weekly graphs,
# m means monthly graphs,
# y means yearly graphs.
#
# and numbers mean:
# 0 - Average system load,
# 1 - RAM usage,
# 2 - Wireless PHY's temperatures,
# 3 - CPU usage,
# 4 - WAN traffic statistics,
# 5 - Disk space,
# 6 - Wireless outgoing traffic.
#
####################################################################
VERSION="raio"
DATE=$(date '+%x %R')
####################################################################

#-------------------------------------------------------------------
# configuration
#-------------------------------------------------------------------

RRDTOOL=/usr/bin/rrdtool
RRDUPDATE=/usr/bin/rrdupdate
RRDDATA=/var/lib/rrd/storj
RRDOUTPUT=/dev/shm/rrd.img
FORCEGRAPH=no

#-------------------------------------------------------------------
# data definition: Average system load
#-------------------------------------------------------------------

RRDcFILE[0]="load:60:System load graphs"
RRDcDEF[0]='
DS:l1:GAUGE:120:0:100
DS:l5:GAUGE:120:0:100
DS:l15:GAUGE:120:0:100
RRA:AVERAGE:0.5:1:576
RRA:AVERAGE:0.5:6:672
RRA:AVERAGE:0.5:24:732
RRA:AVERAGE:0.5:144:1460
'
RRDuSRC[0]="l1:l5:l15"
RRDuVAL[0]='
UT=$(head -n1 /proc/loadavg)
L1=$(echo "$UT"|awk "{print \$1}")
L5=$(echo "$UT"|awk "{print \$2}")
L15=$(echo "$UT"|awk "{print \$3}")
echo "${L1}:${L5}:${L15}"
'
RRDgUM[0]='proc/min'
RRDgLIST[0]="0 1 2 3 4 5"
RRDgDEF[0]=$(cat <<EOF
'DEF:ds1=\$RRD:l1:AVERAGE'
'DEF:ds2=\$RRD:l5:AVERAGE'
'DEF:ds3=\$RRD:l15:AVERAGE'
'CDEF:bo=ds1,UN,0,ds1,IF,0,GT,UNKN,INF,IF'
'AREA:bo#DDDDDD:'
'CDEF:bi=ds1,UN,0,ds1,IF,0,GT,INF,UNKN,IF'
'AREA:bi#FEFEED:'
'HRULE:1.0#44B5FF'
'AREA:ds3#FFEE00:Last 15 min'
  'VDEF:max1=ds1,MAXIMUM'
  'VDEF:min1=ds1,MINIMUM'
  'VDEF:avg1=ds1,AVERAGE'
  GPRINT:max1:"Max %6.2lf"
  GPRINT:min1:"Min %6.2lf"
  GPRINT:avg1:"Avg %6.2lf\n"
'LINE3:ds2#FFCC00:Last  5 min'
  'VDEF:max2=ds2,MAXIMUM'
  'VDEF:min2=ds2,MINIMUM'
  'VDEF:avg2=ds2,AVERAGE'
  GPRINT:max2:"Max %6.2lf"
  GPRINT:min2:"Min %6.2lf"
  GPRINT:avg2:"Avg %6.2lf\n"
'LINE1:ds1#FF0000:Last  1 min'
  'VDEF:max3=ds3,MAXIMUM'
  'VDEF:min3=ds3,MINIMUM'
  'VDEF:avg3=ds3,AVERAGE'
  GPRINT:max3:"Max %6.2lf"
  GPRINT:min3:"Min %6.2lf"
  GPRINT:avg3:"Avg %6.2lf\n"
EOF
)

RRDgGRAPH[0]='3600|load1|System load, last hour|[ "$M" = 30 ]'
RRDgGRAPH[1]='14400|load6|System load, last 4 hours|[ "$M" = 30 ]'
RRDgGRAPH[2]='86400|load24|System load, last day|[ "$H" = 04 ] && [ "$M" = 30 ]|--x-grid HOUR:1:DAY:1:HOUR:1:0:%H'
RRDgGRAPH[3]='604800|loadW|System load, last week|[ "$H" = 04 ] && [ "$M" = 30 ]|--x-grid HOUR:4:DAY:1:DAY:1:0:"%a %d/%m"'
RRDgGRAPH[4]='2678400|loadM|System load, last month|[ "$H" = 04 ] && [ "$M" = 30 ]'
RRDgGRAPH[5]='31536000|loadY|System load, last year|[ "$H" = 04 ] && [ "$M" = 30 ]'

#-------------------------------------------------------------------
# data definition: RAM usage
#-------------------------------------------------------------------

RRDcFILE[1]="mem:60:RAM usage graphs"
RRDcDEF[1]='
DS:cached:GAUGE:120:0:1000000
DS:buffer:GAUGE:120:0:1000000
DS:free:GAUGE:120:0:1000000
DS:total:GAUGE:120:0:1000000
DS:swapt:GAUGE:120:0:1000000
DS:swapf:GAUGE:120:0:1000000
RRA:AVERAGE:0.5:1:576
RRA:AVERAGE:0.5:6:672
RRA:AVERAGE:0.5:24:732
RRA:AVERAGE:0.5:144:1460
'
RRDuSRC[1]="cached:buffer:free:total:swapt:swapf"
RRDuVAL[1]='
C=$(grep ^Cached /proc/meminfo|awk "{print \$2}")
B=$(grep ^Buffers /proc/meminfo|awk "{print \$2}")
F=$(grep ^MemFree /proc/meminfo|awk "{print \$2}")
T=$(grep ^MemTotal /proc/meminfo|awk "{print \$2}")
ST=$(grep ^SwapTotal /proc/meminfo|awk "{print \$2}")
SF=$(grep ^SwapFree /proc/meminfo|awk "{print \$2}")
echo "${C}:${B}:${F}:${T}:${ST}:${SF}"
'
RRDgUM[1]='bytes'
RRDgLIST[1]="6 7 8 9 10 11"
RRDgDEF[1]=$(cat <<EOF
'DEF:dsC=\$RRD:cached:AVERAGE'
'DEF:dsB=\$RRD:buffer:AVERAGE'
'DEF:dsF=\$RRD:free:AVERAGE'
'DEF:dsT=\$RRD:total:AVERAGE'
'CDEF:bo=dsT,UN,0,dsT,IF,0,GT,UNKN,INF,IF'
'AREA:bo#DDDDDD:'
'CDEF:tot=dsT,1024,*'
'CDEF:fre=dsF,1024,*'
'CDEF:freP=fre,100,*,tot,/'
'CDEF:buf=dsB,1024,*'
'CDEF:bufP=buf,100,*,tot,/'
'CDEF:cac=dsC,1024,*'
'CDEF:cacP=cac,100,*,tot,/'
'CDEF:use=dsT,dsF,dsC,+,dsB,+,-,1024,*'
'CDEF:useP=use,100,*,tot,/'
'CDEF:l=use,1,1,IF'
'AREA:use#CC3300:User   '
'LINE2:l#AC1300::STACK'
  'VDEF:maxU=use,MAXIMUM'
  'VDEF:minU=use,MINIMUM'
  'VDEF:avgU=use,AVERAGE'
  'VDEF:curU=use,LAST'
  'VDEF:procU=useP,LAST'
  GPRINT:curU:"Last %6.2lf %s"
  GPRINT:procU:"%3.0lf%%"
  GPRINT:avgU:"Avg %6.2lf %s"
  GPRINT:maxU:"Max %6.2lf %s"
  GPRINT:minU:"Min %6.2lf %s\n"
'AREA:cac#FF9900:Cached :STACK'
'LINE2:l#DF7900::STACK'
  'VDEF:maxC=cac,MAXIMUM'
  'VDEF:minC=cac,MINIMUM'
  'VDEF:avgC=cac,AVERAGE'
  'VDEF:curC=cac,LAST'
  'VDEF:procC=cacP,LAST'
  GPRINT:curC:"Last %6.2lf %s"
  GPRINT:procC:"%3.0lf%%"
  GPRINT:avgC:"Avg %6.2lf %s"
  GPRINT:maxC:"Max %6.2lf %s"
  GPRINT:minC:"Min %6.2lf %s\n"
'AREA:buf#FFCC00:Buffers:STACK'
'LINE2:l#DFAC00::STACK'
  'VDEF:maxB=buf,MAXIMUM'
  'VDEF:minB=buf,MINIMUM'
  'VDEF:avgB=buf,AVERAGE'
  'VDEF:curB=buf,LAST'
  'VDEF:procB=bufP,LAST'
  GPRINT:curB:"Last %6.2lf %s"
  GPRINT:procB:"%3.0lf%%"
  GPRINT:avgB:"Avg %6.2lf %s"
  GPRINT:maxB:"Max %6.2lf %s"
  GPRINT:minB:"Min %6.2lf %s\n"
'AREA:fre#FFFFCC:Unused :STACK'
  'VDEF:maxF=fre,MAXIMUM'
  'VDEF:minF=fre,MINIMUM'
  'VDEF:avgF=fre,AVERAGE'
  'VDEF:curF=fre,LAST'
  'VDEF:procF=freP,LAST'
  GPRINT:curF:"Last %6.2lf %s"
  GPRINT:procF:"%3.0lf%%"
  GPRINT:avgF:"Avg %6.2lf %s"
  GPRINT:maxF:"Max %6.2lf %s"
  GPRINT:minF:"Min %6.2lf %s\n"
EOF
)

RRDgGRAPH[6]='3600|mem1|RAM usage, last hour|[ "$M" = 30 ]|-l 0 -r'
RRDgGRAPH[7]='14400|mem6|RAM usage, last 4 hours|[ "$M" = 30 ]|-l 0 -r'
RRDgGRAPH[8]='86400|mem24|RAM usage, last day|[ "$H" = 04 ] && [ "$M" = 30 ]|-l 0 -r --x-grid HOUR:1:DAY:1:HOUR:1:0:%H'
RRDgGRAPH[9]='604800|memW|RAM usage, last week|[ "$H" = 04 ] && [ "$M" = 30 ]|-l 0 -r --x-grid HOUR:4:DAY:1:DAY:1:0:"%a %d/%m"'
RRDgGRAPH[10]='2678400|memM|RAM usage, last month|[ "$H" = 04 ] && [ "$M" = 30 ]|-l 0 -r'
RRDgGRAPH[11]='31536000|memY|RAM usage, last year|[ "$H" = 04 ] && [ "$M" = 30 ]|-l 0 -r'

#-------------------------------------------------------------------
# data definition: CO2, temperature and humidity
#-------------------------------------------------------------------

RRDcFILE[2]="temp:60:CO2, temperature and humidity"
RRDcDEF[2]='
DS:co2:GAUGE:120:0:10000
DS:tempint:GAUGE:120:-273:100
DS:tempkid:GAUGE:120:-273:100
DS:tempout:GAUGE:120:-273:100
DS:tempout2:GAUGE:120:-273:100
DS:humint:GAUGE:120:0:100
DS:humkid:GAUGE:120:0:100
DS:humout:GAUGE:120:0:100
DS:humout2:GAUGE:120:0:100
DS:humconv:GAUGE:120:0:100
RRA:AVERAGE:0.5:1m:1d
RRA:AVERAGE:0.5:10m:1w
RRA:AVERAGE:0.5:1h:1M
RRA:AVERAGE:0.5:4h:1y
RRA:AVERAGE:0.5:1d:10y
RRA:MAX:0.5:1d:10y
RRA:MIN:0.5:1d:10y
'
RRDuSRC[2]="co2:humint:tempint:humout:tempout:humout2:tempout2:humkid:tempkid:humconv"
RRDuVAL[2]='
#CO2FILE=/dev/shm/co2level
#CO2LEVEL=`/home/pi/co2/k30.py -t 1`
CO2LEVEL=U
#echo "${CO2LEVEL}" > ${CO2FILE}
sudo -u ubuntu rsync -ax -e "ssh -o ConnectTimeout=2 -o ServerAliveInterval=2 -ServerAliveCountMax=2" "pi@192.168.0.13:/dev/shm/sdr*" /dev/shm/
Calc()
{
if [ -f "$1" ] && [ `stat --format=%Y $1` -ge $(( `date +%s` - 120 )) ]; then
  cat "$1"
else
  echo "U U"
fi
}
HUMTEMPINT=`cat /dev/shm/sdr-Nexus-TH-51-1`
HUMTEMPOUT=$(Calc /dev/shm/sdr-Nexus-TH-51-2)
HUMTEMPOUT2=$(Calc /dev/shm/sdr-Hideki-TS04-3-2)
HUMTEMPKID=`cat /dev/shm/sdr-Nexus-TH-51-3`
HUMTEMP=`echo ${HUMTEMPINT} ${HUMTEMPOUT} ${HUMTEMPOUT2} ${HUMTEMPKID}`
HUMCONV=$(echo "$HUMTEMP"| awk "{print \$3\" \"\$4\" \"\$2}")
echo $HUMCONV > /tmp/conv
HUMCONV=`/home/ubuntu/xopok-scripts/monitoring/co2/local/humconv.py $HUMCONV`
HUMTEMP=`echo ${HUMTEMP} | sed "s/ /:/g"`
TEMPOUT=`echo ${HUMTEMPOUT} | sed "s/.* //"`

echo "${CO2LEVEL}:${HUMTEMP}:${HUMCONV}"
'

RRDgUM[2]='ppm'
RRDgLIST[2]="12 13 14 15 16 17"
RRDgDEF[2]=$(cat <<EOF
'DEF:ds1=\$RRD:co2:AVERAGE'
'DEF:ds4=\$RRD:humconv:AVERAGE'
'DEF:ds5=\$RRD:tempint:AVERAGE'
'DEF:ds5k=\$RRD:tempkid:AVERAGE'
'DEF:ds6=\$RRD:humint:AVERAGE'
'DEF:ds7=\$RRD:tempout:AVERAGE'
'DEF:ds72=\$RRD:tempout2:AVERAGE'
'DEF:ds7min=\$RRD:tempout:MIN'
'DEF:ds7max=\$RRD:tempout:MAX'
'DEF:ds8=\$RRD:humout:AVERAGE'
'CDEF:scaled_ds4=ds4,20,*'
'CDEF:scaled_ds5=ds5,20,*'
'CDEF:scaled_ds5k=ds5k,20,*'
'CDEF:scaled_ds6=ds6,20,*'
'CDEF:scaled_ds7=ds7,20,*'
'CDEF:scaled_ds72=ds72,20,*'
'CDEF:scaled_ds7min=ds7min,20,*'
'CDEF:scaled_ds7max=ds7max,20,*'
'CDEF:scaled_ds8=ds8,20,*'
'AREA:1200#634d21'
'AREA:800#495217'
'AREA:400#3e4d3e'
'LINE1:scaled_ds5k#FEE12B:TKid '
GPRINT:ds5k:LAST:"%3.1lf"
'LINE1:scaled_ds5#a0a0a0:TInt '
GPRINT:ds5:LAST:"%3.1lf"
'LINE1:scaled_ds6#00ACCF:HumInt '
GPRINT:ds6:LAST:"%3.1lf"
'LINE2:ds1#5167b5:CO2'
GPRINT:ds1:LAST:"%4.0lf\n"
'LINE1:scaled_ds7#309030:TWest'
GPRINT:ds7:LAST:"%3.1lf"
'LINE1:scaled_ds72#FF7F00:TEast'
GPRINT:ds72:LAST:"%3.1lf"
'LINE1:scaled_ds8#00CF6F:HumWest'
GPRINT:ds8:LAST:"%3.1lf"
'LINE1:scaled_ds7min#0000FF'
'LINE1:scaled_ds7max#ff0000'
'LINE1:scaled_ds4#ffffff:HumConv:dashes=4,2'
GPRINT:ds4:LAST:"%3.1lf\n"
EOF
)

RRDgGRAPH[12]='14400|temp4|Air, last 4 hours|[ "$M" = 30 ]|--right-axis 0.05:0 --right-axis-label "Temp/Humidity" --right-axis-format "%1.0lf" --units-exponent 0 --slope-mode'
RRDgGRAPH[13]='86400|temp24|Air, last day|[ "$H" = 04 ] && [ "$M" = 30 ]|--x-grid HOUR:1:DAY:1:HOUR:1:0:%H --right-axis 0.05:0 --right-axis-label "Temp/Humidity" --right-axis-format "%1.0lf" --units-exponent 0 --slope-mode'
RRDgGRAPH[14]='604800|tempW|Air, last week|[ "$H" = 04 ] && [ "$M" = 30 ]|--x-grid HOUR:4:DAY:1:DAY:1:0:"%a %d/%m" --right-axis 0.05:0 --right-axis-label "Temp/Humidity" --right-axis-format "%1.0lf" --units-exponent 0 --slope-mode'
RRDgGRAPH[15]='2678400|tempM|Air, last month|[ "$H" = 04 ] && [ "$M" = 30 ]|--right-axis 0.05:0 --right-axis-label "Temp/Humidity" --right-axis-format "%1.0lf" --units-exponent 0 --slope-mode'
RRDgGRAPH[16]='31536000|tempY|Air, last year|[ "$H" = 04 ] && [ "$M" = 30 ]|--right-axis 0.05:0 --right-axis-label "Temp/Humidity" --right-axis-format "%1.0lf" --units-exponent 0 --slope-mode'
RRDgGRAPH[17]='126144000|temp4Y|Air, last 4 years|[ "$H" = 04 ] && [ "$M" = 30 ]|--right-axis 0.05:0 --right-axis-label "Temp/Humidity" --right-axis-format "%1.0lf" --units-exponent 0 --slope-mode'


#-------------------------------------------------------------------
# data definition: disk IO usage
#-------------------------------------------------------------------

RRDcFILE[3]="disks:60:Disks IO usage graphs"
RRDcDEF[3]='
DS:ar:DERIVE:120:0:U
DS:aw:DERIVE:120:0:U
DS:arm:DERIVE:120:0:U
DS:awm:DERIVE:120:0:U
DS:ars:DERIVE:120:0:U
DS:aws:DERIVE:120:0:U
DS:br:DERIVE:120:0:U
DS:bw:DERIVE:120:0:U
DS:brm:DERIVE:120:0:U
DS:bwm:DERIVE:120:0:U
DS:brs:DERIVE:120:0:U
DS:bws:DERIVE:120:0:U
RRA:AVERAGE:0.5:1m:1d
RRA:AVERAGE:0.5:10m:1w
RRA:AVERAGE:0.5:1h:1M
RRA:AVERAGE:0.5:1d:10y
'
RRDuSRC[3]="ar:arm:ars:aw:awm:aws:br:brm:brs:bw:bwm:bws"
#echo $(cat /sys/block/`readlink /dev/disk/by-id/ata-OCZ-VERTEX2_OCZ-4LNRT8Q4D5JSE37Q | sed "s,.*/,,"`/stat | awk "{print \$1\":\"\$2\":\"\$3\":\"\$5\":\"\$6\":\"\$7}")
RRDuVAL[3]='
echo -n $(cat /sys/block/`readlink /dev/disk/by-id/usb-WD_Elements_25A3_5A324A5257504554-0\:0 | sed "s,.*/,,"`/stat | awk "{print \$1\":\"\$2\":\"\$3\":\"\$5\":\"\$6\":\"\$7}"):
echo U:U:U:U:U:U
'
RRDgUM[3]='SSD <-- requests/s --> HDD'
RRDgLIST[3]="19 20 21 22 23"
RRDgDEF[3]=$(cat <<EOF
'DEF:ar=\$RRD:ar:AVERAGE'
'DEF:aw=\$RRD:aw:AVERAGE'
'DEF:ars=\$RRD:ars:AVERAGE'
'DEF:aws=\$RRD:aws:AVERAGE'
'DEF:br=\$RRD:br:AVERAGE'
'DEF:bw=\$RRD:bw:AVERAGE'
'DEF:brs=\$RRD:brs:AVERAGE'
'DEF:bws=\$RRD:bws:AVERAGE'
'CDEF:nbr=br,-1,*'
'CDEF:nbw=bw,-1,*'
'CDEF:snbrs=brs,-1,*,2048,/,16,*'
'CDEF:snbws=bws,-1,*,2048,/,16,*'
'CDEF:sars=ars,2048,/,16,*'
'CDEF:saws=aws,2048,/,16,*'
'CDEF:arkb=ars,2,/'
'CDEF:awkb=aws,2,/'
'CDEF:brkb=brs,2,/'
'CDEF:bwkb=bws,2,/'
'LINE1:ar#54EC48:HDD avg r/s'
GPRINT:ar:AVERAGE:"%.2lf"
'LINE1:aw#EA644A:w/s'
GPRINT:aw:AVERAGE:"%.2lf"
'LINE2:sars#24BC14:rkB/s'
GPRINT:arkb:AVERAGE:"%.2lf"
'CDEF:argb=arkb,1024,/,1024,/'
'VDEF:totargb=argb,TOTAL'
GPRINT:totargb:"%.2lf GiB"
'LINE2:saws#CC3118:wkB/s'
GPRINT:awkb:AVERAGE:"%.2lf"
'CDEF:awgb=awkb,1024,/,1024,/'
'VDEF:totawgb=awgb,TOTAL'
GPRINT:totawgb:"%.2lf GiB\n"
'LINE1:nbr#54EC48:SSD avg r/s'
GPRINT:br:AVERAGE:"%.2lf"
'LINE1:nbw#EA644A:w/s'
GPRINT:bw:AVERAGE:"%.2lf"
'LINE2:snbrs#24BC14:rkB/s'
GPRINT:brkb:AVERAGE:"%.2lf"
'CDEF:brgb=brkb,1024,/,1024,/'
'VDEF:totbrgb=brgb,TOTAL'
GPRINT:totbrgb:"%.2lf GiB"
'LINE2:snbws#CC3118:wkB/s'
GPRINT:bwkb:AVERAGE:"%.2lf"
'CDEF:bwgb=bwkb,1024,/,1024,/'
'VDEF:totbwbb=bwgb,TOTAL'
GPRINT:totbwbb:"%.2lf GiB\n"
'HRULE:0#FFFFFF'
EOF
)

#RRDgGRAPH[18]='3600|cpu1|CPU usage, last hour|[ "$M" = 30 ]|-l 0 -r -u 99.99'
RRDgGRAPH[19]='14400|disks4|Disks IO usage, last 4 hours|[ "$M" = 30 ]|-r --right-axis 65536:0 --right-axis-label "B/s" --alt-y-grid'
RRDgGRAPH[20]='86400|disks24|Disks IO usage, last day|[ "$H" = 04 ] && [ "$M" = 30 ]|-r --x-grid HOUR:1:DAY:1:HOUR:1:0:%H --right-axis 65536:0 --right-axis-label "B/s"'
RRDgGRAPH[21]='604800|disksW|Disks IO usage, last week|[ "$H" = 04 ] && [ "$M" = 30 ]|-r --x-grid HOUR:4:DAY:1:DAY:1:0:"%a %d/%m" --right-axis 65536:0 --right-axis-label "B/s"'
RRDgGRAPH[22]='2678400|disksM|Disks IO usage, last month|[ "$H" = 04 ] && [ "$M" = 30 ]|-r --right-axis 65536:0 --right-axis-label "B/s"'
RRDgGRAPH[23]='31536000|disksY|Disks IO usage, last year|[ "$H" = 04 ] && [ "$M" = 30 ]|-r --right-axis 65536:0 --right-axis-label "B/s"'

#-------------------------------------------------------------------
# data definition: Storj upload and download statistics
#-------------------------------------------------------------------

RRDcFILE[4]="pieces:60:Storj Traffic graphs"
FN4=COUNTER
RRDcDEF[4]='
DS:upload:ABSOLUTE:600:0:U
DS:uploaded:ABSOLUTE:600:0:U
DS:uploadfailed:ABSOLUTE:600:0:U
DS:download:ABSOLUTE:600:0:U
DS:downloaded:ABSOLUTE:600:0:U
DS:downloadfailed:ABSOLUTE:600:0:U
DS:audit:ABSOLUTE:600:0:U
DS:audited:ABSOLUTE:600:0:U
DS:auditfailed:ABSOLUTE:600:0:U
DS:deleted:ABSOLUTE:600:0:U
RRA:AVERAGE:0.5:1:576
RRA:AVERAGE:0.5:6:672
RRA:AVERAGE:0.5:24:732
RRA:AVERAGE:0.5:144:1460
'
RRDuSRC[4]="upload:uploaded:uploadfailed:download:downloaded:downloadfailed:audit:audited:auditfailed:deleted"
RRDuVAL[4]='
LOG=`sudo docker logs --since 1m storagenode0 2>&1; sudo docker logs --since 1m storagenode1 2>&1; sudo docker logs --since 1m storagenode2 2>&1`
UPLOAD=$(echo "$LOG" | grep -c "upload started" | xargs -n 1 expr 60 \*)
UPLOADED=$(echo "$LOG" | grep -c "uploaded" | xargs -n 1 expr 60 \*)
UPLOADFAILED=$(echo "$LOG" | grep -c "upload [a-z]*led" | xargs -n 1 expr 60 \*)
DOWNLOAD=$(echo "$LOG" | grep -c "download started" | xargs -n 1 expr 60 \*)
DOWNLOADED=$(echo "$LOG" | grep -c "downloaded" | xargs -n 1 expr 60 \*)
DOWNLOADFAILED=$(echo "$LOG" | grep -c "download failed" | xargs -n 1 expr 60 \*)
AUDIT=$(echo "$LOG" | grep -c "download started.*GET_AUDIT" | xargs -n 1 expr 60 \*)
AUDITED=$(echo "$LOG" | grep -c "downloaded.*GET_AUDIT" | xargs -n 1 expr 60 \*)
AUDITFAILED=$(echo "$LOG" | grep -c "download failed.*GET_AUDIT" | xargs -n 1 expr 60 \*)
DELETED=$(echo "$LOG" | grep -c "deleted" | xargs -n 1 expr 60 \*)
echo "${UPLOAD}:${UPLOADED}:${UPLOADFAILED}:${DOWNLOAD}:${DOWNLOADED}:${DOWNLOADFAILED}:${AUDIT}:${AUDITED}:${AUDITFAILED}:${DELETED}"
'
RRDgUM[4]='Downloads <-- pieces/min --> Uploads'
RRDgLIST[4]="24 26 27 28 29"
RRDgDEF[4]=$(cat <<EOF
'DEF:ds1=\$RRD:upload:AVERAGE'
'DEF:ds2=\$RRD:uploaded:AVERAGE'
'DEF:ds3=\$RRD:uploadfailed:AVERAGE'
'DEF:ds4=\$RRD:download:AVERAGE'
'DEF:ds5=\$RRD:downloaded:AVERAGE'
'DEF:ds6=\$RRD:downloadfailed:AVERAGE'
'DEF:ds7=\$RRD:audit:AVERAGE'
'DEF:ds8=\$RRD:audited:AVERAGE'
'DEF:ds9=\$RRD:auditfailed:AVERAGE'
'DEF:dsd=\$RRD:deleted:AVERAGE'
'CDEF:ln1=ds2,ds2,UNKN,IF'
'CDEF:ln2=ds3,ds2,ds3,+,UNKN,IF'
'AREA:ds2#1598C3'
'AREA:ds3#CC7016::STACK'
'LINE1:ln2#EC9D48'
'LINE1:ln1#48C4EC'
'CDEF:d=ds5'
'CDEF:df=ds6'
'CDEF:af=ds9'
'CDEF:nd=d,-1,*'
'CDEF:ndf=df,-1,*'
'CDEF:naf=af,-1,*'
'CDEF:lnd=d,nd,UNKN,IF'
'CDEF:lndf=df,ndf,nd,+,UNKN,IF'
'CDEF:lnaf=af,naf,ndf,nd,+,+,UNKN,IF'
'AREA:nd#24BC14'
'AREA:ndf#CC7016::STACK'
'AREA:naf#CC3118::STACK'
'LINE1:lndf#EC9D48'
'LINE1:lnd#54EC48'
'LINE1:lnaf#EA644A'
'CDEF:nds8=ds8,ds9,+,-1,*'
'LINE1:nds8#FFFFFF'
'LINE1:dsd#FFFFFF'
'HRULE:0#FFFFFF'
'VDEF:totuploaded=ds2,TOTAL'
  GPRINT:totuploaded:"Uploaded %1.1lf %s"
'VDEF:totupload=ds1,TOTAL'
  GPRINT:totupload:"/  %1.1lf %s;"
'VDEF:totdownloaded=ds5,TOTAL'
  GPRINT:totdownloaded:"Downloaded %1.1lf %s"
'VDEF:totdownload=ds4,TOTAL'
  GPRINT:totdownload:"/  %1.1lf %s attempts\n"
EOF
)  
#'CDEF:utotal=ds2,'
#'CDEF:uftotal=ds3,TOTAL'
#'CDEF:ufratio=uftotal,utotal,/,100,*'
#'CDEF:dtotal=ds5,TOTAL'
#'CDEF:dftotal=ds6,TOTAL'
#'CDEF:dfratio=dftotal,dtotal,/,100,*'
#'VDEF:dfrat=dfratio,TOTAL'
#'VDEF:ufrat=ufratio,TOTAL'
#'GPRINT:ufrat:"%1.1lf pct Upload failed\n"'
#'GPRINT:dfrat:"%1.1lf pct Download failed "'
   
RRDgGRAPH[24]='14400|piece4|Storj Traffic, last 4 hours|[ "$M" = 30 ]|-r --right-axis 1:0 --alt-y-grid'
RRDgGRAPH[26]='86400|piece24|Storj Traffic, last day|[ "$M" -ge 30 ] && [ "$M" -le 45 ]|-r --right-axis 1:0 --x-grid HOUR:1:DAY:1:HOUR:1:0:%H'
RRDgGRAPH[27]='604800|pieceW|Storj Traffic, last week|[ "$M" -ge 30 ] && [ "$M" -le 45 ]|-r --right-axis 1:0 --x-grid HOUR:4:DAY:1:DAY:1:0:"%a %d/%m"'
RRDgGRAPH[28]='2678400|pieceM|Storj Traffic, last month|[ "$H" = 04 ] && [ "$M" -ge 30 ] && [ "$M" -le 45 ]|-r --right-axis 1:0 '
RRDgGRAPH[29]='31536000|pieceY|Storj Traffic, last year|[ "$H" = 04 ] && [ "$M" -ge 30 ] && [ "$M" -le 45 ]|-r --right-axis 1:0 '

#-------------------------------------------------------------------
# data definition: Disk space
#-------------------------------------------------------------------

RRDcFILE[5]="hdd:60:Disk space graphs"
RRDcDEF[5]='
DS:rootfree:GAUGE:600:0:U
DS:rootused:GAUGE:600:0:U
DS:placefree:GAUGE:600:0:U
DS:placeused:GAUGE:600:0:U
DS:placestorj:GAUGE:600:0:U
RRA:AVERAGE:0.5:1m:1d
RRA:AVERAGE:0.5:10m:1w
RRA:AVERAGE:0.5:1h:1M
RRA:AVERAGE:0.5:1d:10y
'
RRDuSRC[5]="rootfree:rootused:placefree:placeused:placestorj"
RRDuVAL[5]='
echo -n $(df -B1 / | tail -n 1 | awk "{print \$4\":\"\$3}"):
echo -n $(df -B1 /place | tail -n 1 | awk "{print \$4\":\"\$3}"):
STORAGE=/place/storj
TOTAL=$(df -B1 /place | tail -n 1 | awk "{ print \$3; }")
OTHER=$(du -sx -B1 --exclude "${STORAGE}*" /place | awk "{ print \$1; }")
echo $(expr $TOTAL - $OTHER)
'
#RRDgUM[5]='/root (x100) <- 0 -> /place'
RRDgUM[5]='/place/storj?'
RRDgLIST[5]="30 32 33 34 35"
RRDgDEF[5]=$(cat <<EOF
'DEF:rf=\$RRD:rootfree:AVERAGE'
'DEF:ru=\$RRD:rootused:AVERAGE'
'DEF:pf=\$RRD:placefree:AVERAGE'
'DEF:pu=\$RRD:placeused:AVERAGE'
'DEF:ps=\$RRD:placestorj:AVERAGE'
'CDEF:rfg=rf,1048576,/'
'CDEF:rug=ru,1048576,/'
'CDEF:pfg=pf,1048576,/'
'CDEF:pug=pu,1048576,/'
'CDEF:psg=ps,1048576,/'
'CDEF:nrf=rf,-100,*'
'CDEF:nru=ru,-100,*'
'CDEF:lnnru=ru,nru,UNKN,IF'
'CDEF:lnnrf=ru,nrf,nru,+,UNKN,IF'
GPRINT:rug:LAST:"/ used %4.0lf M"
GPRINT:rfg:LAST:"/ free %4.0lf M\n"
'CDEF:lnps=ps,ps,UNKN,IF'
'CDEF:lnpu=pu,pu,UNKN,IF'
'CDEF:lnpf=pu,pf,pu,+,UNKN,IF'
'CDEF:puns=pu,ps,-'
'AREA:ps#1598C3:/place/storj.v3 used'
GPRINT:psg:LAST:"%4.0lf M"
GPRINT:pug:LAST:"/place used %4.0lf M"
GPRINT:pfg:LAST:"/place free %4.0lf M"
'LINE1:ps#48C4EC'
EOF
)

#'AREA:nru#EC9D48:root-used'
#'AREA:nrf#a6f0a1:root-free:STACK'
#'LINE1:lnnru#CC7016'
#'LINE1:lnnrf#24BC14'
#'AREA:puns#EC9D48:/place used:STACK'
#'AREA:pf#a6f0a1:/place free:STACK'
#'LINE1:lnpu#CC7016'
#'LINE1:lnpf#C9B215'
#'HRULE:0#000000'

RRDgGRAPH[30]='14400|hdd4|Disk space, 4 last hours|[ "$M" = 30 ]|-r --right-axis 1:0 --alt-y-grid'
#RRDgGRAPH[31]='21600|hdd6|Disk space, last 6 hours|[ "$M" = 30 ]|-r'
RRDgGRAPH[32]='86400|hdd24|Disk space, last day|[ "$M" -ge 30 ] && [ "$M" -le 45 ]|-r --right-axis 1:0 --alt-y-grid --x-grid HOUR:1:DAY:1:HOUR:1:0:%H '
RRDgGRAPH[33]='604800|hddW|Disk space, last week|[ "$M" -ge 30 ] && [ "$M" -le 45 ]|-r --right-axis 1:0 --alt-y-grid --x-grid HOUR:4:DAY:1:DAY:1:0:"%a %d/%m" '
RRDgGRAPH[34]='2678400|hddM|Disk space, last month|[ "$H" = 04 ] && [ "$M" -ge 30 ] && [ "$M" -le 45 ]|-r --right-axis 1:0  --alt-y-grid '
RRDgGRAPH[35]='31536000|hddY|Disk space, last year|[ "$H" = 04 ] && [ "$M" -ge 30 ] && [ "$M" -le 45 ]|-r --right-axis 1:0  --alt-y-grid '
#--right-axis 0.01:0 --right-axis-label "root <- 0"

#--y-grid 1000000000:10

#-------------------------------------------------------------------
# data definition: WAN traffic
#-------------------------------------------------------------------

RRDcFILE[6]="wan:60:WAN traffic graphs"
RRDcDEF[6]='
DS:in:COUNTER:600:0:1000000000
DS:out:COUNTER:600:0:1000000000
DS:dockin:COUNTER:600:0:1000000000
DS:dockout:COUNTER:600:0:1000000000
RRA:AVERAGE:0.5:1m:1d
RRA:AVERAGE:0.5:10m:1w
RRA:AVERAGE:0.5:1h:1M
RRA:AVERAGE:0.5:1d:10y
'
RRDuSRC[6]="in:out:dockin:dockout"
RRDuVAL[6]='
IF="eth0:"
IN=$(grep "${IF}" /proc/net/dev|awk -F ":" "{print \$2}"|awk "{print \$1}")
OUT=$(grep "${IF}" /proc/net/dev|awk -F ":" "{print \$2}"|awk "{print \$9}")
IF="docker0:"
DOCKIN=$(grep "${IF}" /proc/net/dev|awk -F ":" "{print \$2}"|awk "{print \$1}")
DOCKOUT=$(grep "${IF}" /proc/net/dev|awk -F ":" "{print \$2}"|awk "{print \$9}")
echo "${IN}:${OUT}:${DOCKIN}:${DOCKOUT}"
'
RRDgUM[6]='Down <-- bytes/s --> Up'
RRDgLIST[6]="36 38 39 40 41"
RRDgDEF[6]=$(cat <<EOF
'DEF:in=\$RRD:in:AVERAGE'
'DEF:out=\$RRD:out:AVERAGE'
'DEF:dockin=\$RRD:dockout:AVERAGE'
'DEF:dockout=\$RRD:dockin:AVERAGE'
'CDEF:nin=in,-1,*'
'CDEF:ndockin=dockin,-1,*'
'CDEF:lnnin=in,nin,UNKN,IF'
'CDEF:lnndockin=dockin,ndockin,UNKN,IF'
'CDEF:lnout=out,out,UNKN,IF'
'CDEF:lndockout=dockout,dockout,UNKN,IF'
'AREA:nin#CC7016'
'AREA:ndockin#1598C3'
'LINE1:lnnin#EC9D48'
'LINE1:lnndockin#48C4EC'
'AREA:out#CC7016'
'AREA:dockout#24BC14'
'LINE1:lnout#EC9D48'
'LINE1:lndockout#54EC48'
'HRULE:0#FFFFFF'
'VDEF:totout=out,TOTAL'
  GPRINT:totout:"Uplink   %1.2lf %s"
'VDEF:totdockout=dockout,TOTAL'
  GPRINT:totdockout:"Storj %1.2lf %s "
'VDEF:avgdockout=dockout,AVERAGE'
  GPRINT:avgdockout:"(avg %1.2lf %s/s)\n"
'VDEF:totin=in,TOTAL'
  GPRINT:totin:"Downlink %1.2lf %s"
'VDEF:totdockin=dockin,TOTAL'
  GPRINT:totdockin:"Storj %1.2lf %s "
'VDEF:avgdockin=dockin,AVERAGE'
  GPRINT:avgdockin:"(avg %1.2lf %s/s)\n"
EOF
)

RRDgGRAPH[36]='14400|wan4|WAN traffic, last 4 hours|[ "$M" = 30 ]|-r --right-axis 1:0 --alt-y-grid'
#RRDgGRAPH[37]='14400|wan6|WLAN outgoing traffic, last 4 hours|[ "$M" = 30 ]|-r'
RRDgGRAPH[38]='86400|wan24|WAN traffic, last day|[ "$M" -ge 30 ] && [ "$M" -le 45 ]|-r --right-axis 1:0 --alt-y-grid --x-grid HOUR:1:DAY:1:HOUR:1:0:%H'
RRDgGRAPH[39]='604800|wanW|WAN traffic, last week|[ "$M" -ge 30 ] && [ "$M" -le 45 ]|-r --right-axis 1:0 --alt-y-grid --x-grid HOUR:4:DAY:1:DAY:1:0:"%a %d/%m"'
RRDgGRAPH[40]='2678400|wanM|WAN traffic, last month|[ "$H" = 04 ] && [ "$M" -ge 30 ] && [ "$M" -le 45 ]|-r --alt-y-grid --right-axis 1:0 '
RRDgGRAPH[41]='31536000|wanY|WAN traffic, last year|[ "$H" = 04 ] && [ "$M" -ge 30 ] && [ "$M" -le 45 ]|-r --alt-y-grid --right-axis 1:0 '

#------------------------------------------------------------------------
# data definition: System components health (e.g. HDD or CPU temperature)
#------------------------------------------------------------------------

RRDcFILE[7]="syshealth:60:System health graphs"
RRDcDEF[7]='
DS:tcpu:GAUGE:120:-273:100
DS:thdd:GAUGE:120:-273:100
DS:tssd:GAUGE:120:-273:100
RRA:AVERAGE:0.5:1m:1d
RRA:AVERAGE:0.5:10m:1w
RRA:AVERAGE:0.5:1h:1M
RRA:AVERAGE:0.5:4h:1y
RRA:AVERAGE:0.5:1d:10y
RRA:MAX:0.5:1d:10y
RRA:MIN:0.5:1d:10y
'
RRDuSRC[7]="tcpu:thdd:tssd"
RRDuVAL[7]='
TCPU=$(cat /sys/class/thermal/thermal_zone0/temp | awk "{printf \"%.1f\", \$1/1000}")
THDD=$(smartctl -d sat -a /dev/disk/by-id/usb-WD_Elements_25A3_5A324A5257504554-0:0 | grep "Celsius" | awk "{print \$10;}")
TSSD=$(smartctl -d sat -a /dev/disk/by-id/wwn-0x5e83a97f356e1138                    | grep "Celsius" | awk "{print \$10;}")
echo "${TCPU}:${THDD}:U"
'
RRDgUM[7]='Temperature'
RRDgLIST[7]="42 44 45 46 47"
RRDgDEF[7]=$(cat <<EOF
'DEF:tcpu=\$RRD:tcpu:AVERAGE'
'DEF:thdd=\$RRD:thdd:AVERAGE'
'DEF:tssd=\$RRD:tssd:AVERAGE'
'LINE1:tcpu#FF0000:t CPU'
  GPRINT:tcpu:LAST:" %.2lf\n"
'LINE1:thdd#00FF00:t HDD'
  GPRINT:thdd:LAST:" %.0lf\n"
'LINE1:tssd#00ACCF:t SSD'
  GPRINT:tssd:LAST:" %.0lf\n"
EOF
)

RRDgGRAPH[42]='14400|syshealth4|System temp, last 4 hours|[ "$M" = 30 ]| --right-axis 1:0'
#RRDgGRAPH[43]='14400|syshealth6|System load, last 4 hours|[ "$M" = 30 ]'
RRDgGRAPH[44]='86400|syshealth24|System temp, last day|[ "$H" = 04 ] && [ "$M" = 30 ]|--right-axis 1:0 --x-grid HOUR:1:DAY:1:HOUR:1:0:%H'
RRDgGRAPH[45]='604800|syshealthW|System temp, last week|[ "$H" = 04 ] && [ "$M" = 30 ]|--right-axis 1:0 --x-grid HOUR:4:DAY:1:DAY:1:0:"%a %d/%m"'
RRDgGRAPH[46]='2678400|syshealthM|System temp, last month|[ "$H" = 04 ] && [ "$M" = 30 ]|--right-axis 1:0'
RRDgGRAPH[47]='31536000|syshealthY|System temp, last year|[ "$H" = 04 ] && [ "$M" = 30 ]|--right-axis 1:0'

#------------------------------------------------------------------------
# data definition: Free disk space per storj node
#------------------------------------------------------------------------

FILENAME="nodespace"
GRAPHNAME="Free disk space per storj node"
RRDcFILE[8]="${FILENAME}:60:${GRAPHNAME}"
RRDcDEF[8]='
DS:free0:DERIVE:300:-100000000000000:100000000000000
DS:free1:DERIVE:300:-100000000000000:100000000000000
DS:free2:DERIVE:300:-100000000000000:100000000000000
RRA:AVERAGE:0.5:1m:1d
RRA:AVERAGE:0.5:10m:1w
RRA:AVERAGE:0.5:1h:1M
RRA:AVERAGE:0.5:1d:10y
'
RRDuSRC[8]="free0:free1:free2"
RRDuVAL[8]='
echo -n $(docker logs --since 2m storagenode0 2>&1 | grep "Available Space" | tail -n 1 | sed "s/.*{/{/" | jq ".[\"Available Space\"]"):
echo -n $(docker logs --since 2m storagenode1 2>&1 | grep "Available Space" | tail -n 1 | sed "s/.*{/{/" | jq ".[\"Available Space\"]"):
echo -n $(docker logs --since 2m storagenode2 2>&1 | grep "Available Space" | tail -n 1 | sed "s/.*{/{/" | jq ".[\"Available Space\"]")
'
RRDgUM[8]='Disk space'
RRDgLIST[8]="48 50 51 52 53"
RRDgDEF[8]=$(cat <<EOF
'DEF:free0=\$RRD:free0:AVERAGE'
'DEF:free1=\$RRD:free1:AVERAGE'
'DEF:free2=\$RRD:free2:AVERAGE'
'CDEF:nfree0=free0,-1,*'
'CDEF:nfree1=free1,-1,*'
'CDEF:nfree2=free2,-1,*'
'CDEF:lnfree0=free0,nfree0,UNKN,IF'
'CDEF:lnfree1=free1,nfree1,nfree0,+,UNKN,IF'
'CDEF:lnfree2=free2,nfree2,nfree1,nfree0,+,+,UNKN,IF'
'AREA:nfree0#24BC14'
'AREA:nfree1#CC7016::STACK'
'AREA:nfree2#1598C3::STACK'
'VDEF:tot0=nfree0,TOTAL'
'LINE1:lnfree0#54EC48:node0'
  GPRINT:nfree0:AVERAGE:"avg %1.2lf %s"
  GPRINT:tot0:"total %1.2lf %s"
  GPRINT:nfree0:LAST:"last %1.2lf %s/s\n"
'VDEF:tot1=nfree1,TOTAL'
'LINE1:lnfree1#EC9D48:node1'
  GPRINT:nfree1:AVERAGE:"avg %1.2lf %s"
  GPRINT:tot1:"total %1.2lf %s"
  GPRINT:nfree1:LAST:"last %1.2lf %s/s\n"
'VDEF:tot2=nfree2,TOTAL'
'LINE1:lnfree2#48C4EC:node2'
  GPRINT:nfree2:AVERAGE:"avg %1.2lf %s"
  GPRINT:tot2:"total %1.2lf %s"
  GPRINT:nfree2:LAST:"last %1.2lf %s/s\n"
'HRULE:0#FFFFFF'
EOF
)

RRDgGRAPH[48]="14400|${FILENAME}4|${GRAPHNAME}, last 4 hours|[ \"$M\" = 30 ]| --right-axis 1:0 --alt-y-grid"
#RRDgGRAPH[43]='14400|syshealth6|System load, last 4 hours|[ "$M" = 30 ]'
RRDgGRAPH[50]="86400|${FILENAME}24|${GRAPHNAME}, last day|[ \"\$H\" = 04 ] && [ \"\$M\" = 30 ]|--right-axis 1:0 --alt-y-grid --x-grid HOUR:1:DAY:1:HOUR:1:0:%H"
RRDgGRAPH[51]="604800|${FILENAME}W|${GRAPHNAME}, last week|[ \"\$H\" = 04 ] && [ \"\$M\" = 30 ]|--right-axis 1:0 --alt-y-grid --x-grid HOUR:4:DAY:1:DAY:1:0:\"%a %d/%m\""
RRDgGRAPH[52]="2678400|${FILENAME}M|${GRAPHNAME}, last month|[ \"\$H\" = 04 ] && [ \"\$M\" = 30 ]|--right-axis 1:0 --alt-y-grid"
RRDgGRAPH[53]="31536000|${FILENAME}Y|${GRAPHNAME}, last year|[ \"\$H\" = 04 ] && [ \"\$M\" = 30 ]|--right-axis 1:0 --alt-y-grid"


####################################################################
# STOP MODIFICATIONS HERE, UNLESS YOU REALLY KNOW WHAT YOU'RE DOING
####################################################################

#-------------------------------------------------------------------
# functions
#-------------------------------------------------------------------

#1=rrdfile 2=step 3=definition
CreateRRD()
{
    echo "$RRDTOOL" create "$1" --step "$2" $3
	"$RRDTOOL" create "$1" --step "$2" $3
}

#1=file, 2=data sources, 3=values
UpdateRRD()
{
    T=$(date +%s)
    T=$(expr $T / 60 \* 60)
    "$RRDUPDATE" "$1" -t "$2" "$T:${3}"
}

#1=imgfile, 2=secs to go back, 3=um text, 4=title text,
#5=rrdfile, 6=definition, 7=extra params
CreateGraph()
{
  RRD="$5"
	DEF=$(echo "${6} "|sed 's/"/\\"/g'|sed '/[^ ]$/s/$/ \\/')
  eval "DEF=\"$DEF\""
	eval "\"$RRDTOOL\" graph \"$1\" $7 -M -a SVG -s \"-${2}\" -e -20 -w 550 -h 240 -v \"$3\" -t \"$4\" $DEF"
}

#-------------------------------------------------------------------
# main code
#-------------------------------------------------------------------

# TODO: examine parameters and output help if any mistake

# grab command
COMMAND="$1"
CRON_GRAPH_TIME="$2"
shift

# prepare main HTML index file
[ "$COMMAND" = create ] && {
	[ -d "$RRDOUTPUT" ] || mkdir -p "$RRDOUTPUT"
	HTMLINDEX="${RRDOUTPUT}/storj.html"
	[ -f "$HTMLINDEX" ] || {
		echo "<head><title>RRDStorm</title>
			<style>body{background:white;color:black}</style></head>
			<body><h1>RRDStorm</h1><ul>" > "$HTMLINDEX"
		MAKEINDEX=yes
	}
}
# cycle numbers
for N in "$@"; do
	# does this N exist?
	[ -z "${RRDcFILE[$N]}" ] && continue
	# extract common data
	FILEBASE=$(echo "${RRDcFILE[$N]}"|awk -F: '{print $1}')
	RRDFILE="${RRDDATA}/${FILEBASE}.rrd"
	# honor command
	case "$COMMAND" in
		create)
			# extract base data
			HTMLFILE="${RRDOUTPUT}/${FILEBASE}.html"
			STEP=$(echo "${RRDcFILE[$N]}"|awk -F: '{print $2}')
			HTITLE=$(echo "${RRDcFILE[$N]}"|awk -F: '{print $3}')
			# check RRD archive
			[ -d "$RRDDATA" ] || mkdir -p "$RRDDATA"
			[ -f "$RRDFILE" ] || CreateRRD  "$RRDFILE" "$STEP" "${RRDcDEF[$N]}"
			# check individual HTML file
			[ -f "$HTMLFILE" ] || {
				echo "<head><title>${HTITLE}</title>
					<style>body{background:white;color:black}</style></head>
					<body style=\"background-color:black;color:lightgray\"><h1>${HTITLE}</h1><center>" > "$HTMLFILE"
				for P in ${RRDgLIST[$N]}; do
					[ -z "${RRDgGRAPH[$P]}" ] && continue
					IMGBASE=$(echo "${RRDgGRAPH[$P]}"|cut -d'|' -f2)
					echo "<img src=\"${IMGBASE}.svg\"><br>" >> "$HTMLFILE"
				done
				echo "</center><p>RRDStorm for ${VERSION} / ${DATE}</p></body>" >> "$HTMLFILE"
				# Creating timed dash files
				for F in "4h:4 Hours dashboard:12 19 24 30 48 36 42" "1d:1 Day dashboard:13 20 26 32 50 38 44"; do
				    TIMEDFILENAME=$(echo "$F"|cut -d':' -f1)
				    TIMEDFILETITLE=$(echo "$F"|cut -d':' -f2)
				    TIMEDFILESOURCES=$(echo "$F"|cut -d':' -f3)
				    DASHFILE="${RRDOUTPUT}/${TIMEDFILENAME}.html"
				    echo "<head><title>${TIMEDFILETITLE}</title>
					<style>body{background:white;color:black}</style></head>
					<body style=\"background-color:black;color:lightgray\"><h1>${TIMEDFILETITLE}</h1><center>" > "$DASHFILE"
				    for P in ${TIMEDFILESOURCES}; do
					[ -z "${RRDgGRAPH[$P]}" ] && continue
					IMGBASE=$(echo "${RRDgGRAPH[$P]}"|cut -d'|' -f2)
					HTMLFILEBASEINDEX=$(expr $P / 6)
					HTMLFILEBASE=$(echo "${RRDcFILE[$HTMLFILEBASEINDEX]}"|cut -d':' -f1)
					echo "<a href=\"${HTMLFILEBASE}.html\"><img src=\"${IMGBASE}.svg\"></a><br>" >> "$DASHFILE"
				    done
				    echo "</center><p>RRDStorm for ${VERSION} / ${DATE}</p></body>" >> "$DASHFILE"
				done
			}
			# update the main HTML index
			[ ! -z "$MAKEINDEX" ] && {
				echo "<li><a href=\"${FILEBASE}.html\">${HTITLE}</a>" >> "$HTMLINDEX"
			}
		;;
		update)
			VAL=$(eval "${RRDuVAL[$N]}")
			echo "Updating ($N) $RRDFILE with $VAL .."
			UpdateRRD "$RRDFILE" "${RRDuSRC[$N]}" "$VAL"
		;;
		help)
			echo "Usage: rrdstorm {create|update|graph|graph_cron[s h d w m y]} 0 1 2 .."
			echo "graph_cron is for cron to quicky update just one graph [1h=s 4h=h 24h=d 1week=w 1 month=m 1year=y]} 0 1 2 .."
		;;
		graph)
			# grab hour and minute
			M=$(date "+%M")
			H=$(date "+%H")
			# do graphs
			for P in ${RRDgLIST[$N]}; do
				[ -z "${RRDgGRAPH[$P]}" ] && continue
				BACK=$(echo "${RRDgGRAPH[$P]}"|cut -d'|' -f1)
				IMGBASE=$(echo "${RRDgGRAPH[$P]}"|cut -d'|' -f2)
				TITLE=$(echo "${RRDgGRAPH[$P]}"|cut -d'|' -f3)" @ \"$H\":\"$M\""
				EXTRA=$(echo "${RRDgGRAPH[$P]}"|cut -d'|' -f5)
				[ ! -z "$FORCEGRAPH" ] && {
					RET=1
				} || {
					COND=$(echo "${RRDgGRAPH[$P]}"|cut -d'|' -f4)
					[ -z "$COND" ] && RET=1 || {
						COND="if ${COND}; then RET=1; else RET=0; fi"
						eval "$COND"
					}
				}
				[ "$RET" = 1 ] && {
					echo "Making graph (${N}:${P}) ${RRDOUTPUT}/${IMGBASE}.png .."
					CreateGraph "${RRDOUTPUT}/${IMGBASE}.svg" "$BACK" "${RRDgUM[$N]}" "$TITLE" "$RRDFILE" "${RRDgDEF[$N]}" "$EXTRA --graph-render-mode normal --color CANVAS#000000 --color FONT#FFFFFF --color BACK#000000"
				}
			done
		;;
		graph_cron)
			if [[ $N =~ ^[0-9]{1,3}$ ]]; then
				# grab hour and minute
				M=$(date "+%M")
				H=$(date "+%H")
				# do graphs
				if [ $CRON_GRAPH_TIME == "s" ]; then
    					CRON_SUB_GRAPH=0
				elif [ $CRON_GRAPH_TIME == "h" ]; then
    					CRON_SUB_GRAPH=1
				elif [ $CRON_GRAPH_TIME == "d" ]; then
    					CRON_SUB_GRAPH=2
				elif [ $CRON_GRAPH_TIME == "w" ]; then
    					CRON_SUB_GRAPH=3
				elif [ $CRON_GRAPH_TIME == "m" ]; then
    					CRON_SUB_GRAPH=4
				elif [ $CRON_GRAPH_TIME == "y" ]; then
    					CRON_SUB_GRAPH=5
				else
					exit 1
				fi
				P=$((((($N+1)*6)-6)+$CRON_SUB_GRAPH))
				[ -z "${RRDgGRAPH[$P]}" ] && continue
				BACK=$(echo "${RRDgGRAPH[$P]}"|cut -d'|' -f1)
				IMGBASE=$(echo "${RRDgGRAPH[$P]}"|cut -d'|' -f2)
				TITLE=$(echo "${RRDgGRAPH[$P]}"|cut -d'|' -f3)
				EXTRA=$(echo "${RRDgGRAPH[$P]}"|cut -d'|' -f5)
				[ ! -z "$FORCEGRAPH" ] && {
					RET=1
				} || {
					COND=$(echo "${RRDgGRAPH[$P]}"|cut -d'|' -f4)
					[ -z "$COND" ] && RET=1 || {
						COND="if ${COND}; then RET=1; else RET=0; fi"
						eval "$COND"
					}
				}
				[ "$RET" = 1 ] && {
					echo "Making graph (${N}:${P}) ${RRDOUTPUT}/${IMGBASE}.svg .."
					CreateGraph "${RRDOUTPUT}/${IMGBASE}.svg" "$BACK" "${RRDgUM[$N]}" "$TITLE" "$RRDFILE" "${RRDgDEF[$N]}" "$EXTRA --color CANVAS#000000 --color FONT#FFFFFF --color BACK#000000"
				}
			fi
		;;
		*)
			echo "Usage: rrdstorm {create|update|graph|graph_cron[s h d w m y]} 0 1 2 .."
			exit 1
		;;
	esac
done

# close the main HTML index
[ ! -z "$MAKEINDEX" ] && {
	echo "</ul><p>RRDStorm for ${VERSION} / ${DATE}</p></body>" >> "$HTMLINDEX"
}

exit 0
