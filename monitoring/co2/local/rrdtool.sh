#!/bin/sh
#
# macsat RRDTool script for ASUS WL-500g (Deluxe) v1.1 (18-07-2005)
#
# (c) 2005 by macsat@macsat.com
# Feel free to distribute and improve :-)
#
#

# Configuration Start 

# Directory for storing RRD Databases
RRDDATA=/dev/shm/rrd.db
RRDBACKUP=/var/lib/rrd/co2

# Directory for storing webpages / images
RRDIMG=/dev/shm/rrd.img

# For led daemon
MAINLEVELFILE=/dev/shm/co2level

# Restore rrd db from backup if necessary
[ -d $RRDDATA ] || cp -a $RRDBACKUP $RRDDATA

# Configuration End

# Set time-variables
MTIME=`date "+%M"`
HTIME=`date "+%H"`
DAYTIME=`date "+%H:%M"`

#Output date for log...
date

if [ ! -d "${RRDDATA}" ]
	then
		echo "RRD Database dir: $RRDDATA does not exist...Creating Now...."
		mkdir -p "${RRDDATA}"
fi

if [ ! -d "${RRDIMG}" ]
	then
		echo "RRD Image / web dir: $RRDIMG does not exist....Creating Now...."
		mkdir -p "${RRDIMG}"
fi

[ "X$1" = "X" ] || exit 0

# $1 = html file $2 = Period
CreateHTML () 
{
if [ $2 = "dash" ]
then
  T=`echo ${4} | sed "s/..$//"`
  sed "s/%LEVEL%/${3}/" < /var/lib/rrd/dash.html.tmpl | sed "s/%TEMP%/${T}/" > "${1}"
else
  echo "<HTML><HEAD><TITLE>RRDTool CO2 Graph Page</TITLE><meta http-equiv=\"refresh\" content=\"60\" ></HEAD>" > "${1}"
  echo "<!-- Latest compiled and minified CSS --><link rel=\"stylesheet\" href=\"//netdna.bootstrapcdn.com/bootstrap/3.1.1/css/bootstrap.min.css\">" >> "${1}"
  #echo ".vertical{ writing-mode:tb-rl; -webkit-transform:rotate(90deg); -moz-transform:rotate(90deg); -o-transform: rotate(90deg); -ms-transform:rotate(90deg); white-space:nowrap; display:block; bottom:0; width:20px; height:20px; }" >> "${1}"
  echo "<script src=\"https://ajax.googleapis.com/ajax/libs/jquery/1.11.0/jquery.min.js\"></script>" >> "${1}"
  echo "<!-- Latest compiled and minified JavaScript --><script src=\"//netdna.bootstrapcdn.com/bootstrap/3.1.1/js/bootstrap.min.js\"></script>" >> "${1}"
  echo "<BODY><center>" >> "${1}"
  echo "<br><img src='mainday.svg'><br><img src='mainweek.svg'><br><img src='mainmonth.svg'><br><img src='mainyear.svg'><br></CENTER></BODY></HTML>" >> "${1}"
fi
#echo "Created."
}

if [ ! -f "${RRDIMG}/charts.html" ]
        then
#                echo " charts.html does not exist.....Creating Now...."
		CreateHTML "${RRDIMG}/charts.html" all
fi

#if [ ! -f "${RRDIMG}/week.html" ]
#        then
#               echo " week.html does not exist.....Creating Now...."
#		CreateHTML "${RRDIMG}/week.html" week
#fi

#if [ ! -f "${RRDIMG}/month.html" ]
#        then
#                echo " month.html does not exist.....Creating Now...."
#		CreateHTML "${RRDIMG}/month.html" month
#fi

#if [ ! -f "${RRDIMG}/year.html" ]
#        then
#                echo " year.html does not exist.....Creating Now...."
#		CreateHTML "${RRDIMG}/year.html" year
#fi



CO2MAIN=main

#debug lines
#echo "Main CO2 sensor name: ${CO2MAIN}"

MAINRRD="${RRDDATA}/${CO2MAIN}.rrd"
TEMPRRD="${RRDDATA}/temperature.rrd"

CreateRRD ()
{	
	rrdtool create "${1}" --step=60 \
	DS:${2}:GAUGE:120:0:10000 \
	RRA:AVERAGE:0.5:1:1440 \
\
	RRA:AVERAGE:0.5:10:1008 \
	RRA:AVERAGE:0.5:60:744 \
	RRA:AVERAGE:0.5:360:1460 \
\
	RRA:MIN:0.5:10:1008 \
	RRA:MIN:0.5:60:744 \
	RRA:MIN:0.5:360:1460 \
\
	RRA:MAX:0.5:10:1008 \
	RRA:MAX:0.5:60:744 \
	RRA:MAX:0.5:360:1460 \
	RRA:AVERAGE:0.5:144:1460
}

if [ ! -f "${MAINRRD}" ]
	then
		echo "RRD file : ${MAINRRD} does not exist. Creating Now..."
		CreateRRD "${MAINRRD}" "co2"
fi
if [ ! -f "${TEMPRRD}" ]
	then
		echo "RRD file : ${TEMPRRD} does not exist. Creating Now..."
		CreateRRD "${TEMPRRD}" "temp"
fi

MAINLEVEL=`/home/pi/co2/k30.py -t 5`
MAINTEMP=`cat /sys/bus/w1/devices/28-0000065cf907/w1_slave | grep "t=" | sed "s/.*t=//"`
MAINTEMP=`python -c "print $MAINTEMP / 1000.0"`
UUID=`cat /home/pi/co2/uuid`

# Save level for led daemon
echo "$MAINLEVEL" > $MAINLEVELFILE
echo "$MAINTEMP" #> $MAINTEMPFILE

# Now upload the value to the server
wget --timeout=15 --no-check-certificate "https://co2.accosto.com:8443" --post-data "uuid=$UUID&co2=$MAINLEVEL" -O /dev/null

# Create dash page
CreateHTML "${RRDIMG}/index.html" dash "${MAINLEVEL}" "${MAINTEMP}"

# Debug
#echo "MAIN sensor CO2 level : ${MAINLEVEL}"

# Update the Databases
`rrdupdate "${MAINRRD}" -t co2 N:"${MAINLEVEL}"`
`rrdupdate "${TEMPRRD}" -t temp N:"${MAINTEMP}"`

# $1 = ImageFile , $2 = Time in secs to go back , $3 = RRDfil , $5 = GraphText , $6 width, $7 height, $8 add options
CreateGraph ()
{
  rrdtool graph "${1}.new" --slope-mode -a SVG -s -"${2}" -w $6 -h $7 -D --units-exponent 0 -v "ppm" $8 \
  --right-axis 0.05:0 --right-axis-label "Temp" --right-axis-format "%1.0lf" \
  'DEF:ds1='${3}':co2:AVERAGE' \
  'DEF:ds2='${3}':co2:MAX' \
  'DEF:ds3='${3}':co2:MIN' \
  'DEF:ds4='${4}':temp:AVERAGE' \
  'CDEF:scaled_ds4=ds4,20,*' \
  'HRULE:2500#FF3300:Drowsiness' \
  'HRULE:5000#FF0000:Maximum' \
  'AREA:1000#FFDB94:Stiffness' \
  'AREA:700#E6FFB2:Safe' \
  'AREA:400#C2F0C2:Fresh' \
  'LINE1:ds2#FF8080:Max CO2' \
  'LINE1:scaled_ds4#000000:Temp' \
  GPRINT:ds2:MAX:"Max %4.0lf" \
  GPRINT:ds2:MIN:"Min %4.0lf" \
  'LINE1:ds3#80AF80:Min CO2' \
  GPRINT:ds3:MAX:"Max %4.0lf" \
  GPRINT:ds3:MIN:"Min %4.0lf" \
  'LINE2:ds1#0000FF:CO2' \
  GPRINT:ds1:MAX:"Max %4.0lf" \
  GPRINT:ds1:MIN:"Min %4.0lf" \
  GPRINT:ds1:AVERAGE:"Avg %4.0lf" \
  GPRINT:ds1:LAST:"Curr %4.0lf" \
  -t "${5}"
  mv -f "${1}.new" "${1}"
}

# $1 = ImageFile , $2 = Time in secs to go back , $3 = RRDfil , $4 = GraphText 
CreateDashGraph ()
{
  rrdtool graph "${1}.new" --slope-mode -a SVG -s -"${2}" -w 710 -h 550 -D --units-exponent 0 -v "ppm" \
  --right-axis 0.05:0 --right-axis-label "Temp" --right-axis-format "%1.0lf" \
  'DEF:ds1='${3}':co2:AVERAGE' \
  'DEF:ds2='${3}':co2:MAX' \
  'DEF:ds3='${3}':co2:MIN' \
  'DEF:ds4='${4}':temp:AVERAGE' \
  'CDEF:scaled_ds4=ds4,20,*' \
  'AREA:1000#FFDB94:Stiffness' \
  'AREA:700#E6FFB2:Safe' \
  'AREA:400#C2F0C2:Fresh' \
  'LINE2:ds1#0000FF:CO2' \
  'LINE2:scaled_ds4#000000:Temp' \
  GPRINT:ds1:MAX:"Max %4.0lf" \
  GPRINT:ds1:MIN:"Min %4.0lf" \
  GPRINT:ds1:LAST:"Curr %4.0lf" \
  GPRINT:ds4:LAST:"Temp %2.1lf" \
  -t "${5}"
  mv -f "${1}.new" "${1}"

  CreateGraph "${RRDIMG}/dashday.svg" 86400 "${MAINRRD}" "${TEMPRRD}" "Day@${DAYTIME}" 710 160 --no-legend
}

# Update Daily graphs every 10 mins 
#if [ "${MTIME}" = 00 ] || [ "${MTIME}" = 10 ] || [ "${MTIME}" = 20 ] || [ "${MTIME}" = 30 ] || [ "${MTIME}" = 40 ] || [ "${MTIME}" = 50 ];

# Update Daily graphs every minute
#if [ "${MTIME}" = 00 ] || [ "${MTIME}" = 30 ];
#then
# 1 Day Graph
CreateDashGraph "${RRDIMG}/maindash.svg" 14400 "${MAINRRD}" "${TEMPRRD}" "4Hours@${DAYTIME}"
#echo "Dash Graphs created....."

CreateGraph "${RRDIMG}/mainday.svg" 86400 "${MAINRRD}" "${TEMPRRD}" "Day@${DAYTIME}" 1280 480
#echo "Daily Graphs created....."
#fi

# Update Weekly graph twice an hour or if the image is missing
if [ "${MTIME}" = 00 ] || [ "${MTIME}" = 30 ] || [ ! -f "${RRDIMG}/mainweek.svg" ];
then
# 1 Week Graph
CreateGraph "${RRDIMG}/mainweek.svg" 604800 "${MAINRRD}" "${TEMPRRD}" "Week@${DAYTIME}" 1280 480
#echo "Weekly Graphs created....."
fi

# Update  Monthly and Yearly graphs once a day (maybe twice a day on 12h settings) or if missing
if [ "${HTIME}" = 04 ] && [ "${MTIME}" = 00 ] || [ ! -f "${RRDIMG}/mainmonth.svg" ];
then
# 1 Month Graph
CreateGraph "${RRDIMG}/mainmonth.svg" 2678400 "${MAINRRD}" "${TEMPRRD}" "Month@${DAYTIME}" 1280 480
#echo "Monthly Graphs Created...."
# 1 Year Graph
CreateGraph "${RRDIMG}/mainyear.svg" 31536000 "${MAINRRD}" "${TEMPRRD}" "Year@${DAYTIME}" 1280 480
#echo "Yearly Graphs Created...."
fi


#echo " <------------------------------------------------------------->"
#echo " "
