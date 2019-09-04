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
HUMLEVELFILE=/dev/shm/humlevel
HUMOUTLEVELFILE=/dev/shm/outhumlevel
HUMCONVLEVELFILE=/dev/shm/convhumlevel
TEMPLEVELFILE=/dev/shm/templevel
TEMPINTLEVELFILE=/dev/shm/tempintlevel
TEMPOUTLEVELFILE=/dev/shm/tempoutlevel

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
HUMRRD="${RRDDATA}/humidity.rrd"
HUMOUTRRD="${RRDDATA}/humidity_out.rrd"
TEMPINTRRD="${RRDDATA}/temperature_int.rrd"
TEMPOUTRRD="${RRDDATA}/temperature_out.rrd"
HUMCONVRRD="${RRDDATA}/humidity_conv.rrd"

CreateRRD ()
{	
	rrdtool create "${1}" --step=60 \
	DS:${2}:GAUGE:120:-273:10000 \
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
if [ ! -f "${HUMRRD}" ]
	then
		echo "RRD file : ${HUMRRD} does not exist. Creating Now..."
		CreateRRD "${HUMRRD}" "humidity"
fi
if [ ! -f "${HUMOUTRRD}" ]
	then
		echo "RRD file : ${HUMOUTRRD} does not exist. Creating Now..."
		CreateRRD "${HUMOUTRRD}" "humidityout"
fi
if [ ! -f "${TEMPINTRRD}" ]
	then
		echo "RRD file : ${TEMPINTRRD} does not exist. Creating Now..."
		CreateRRD "${TEMPINTRRD}" "tempint"
fi
if [ ! -f "${TEMPOUTRRD}" ]
	then
		echo "RRD file : ${TEMPOUTRRD} does not exist. Creating Now..."
		CreateRRD "${TEMPOUTRRD}" "tempout"
fi
if [ ! -f "${HUMCONVRRD}" ]
	then
		echo "RRD file : ${HUMCONVRRD} does not exist. Creating Now..."
		CreateRRD "${HUMCONVRRD}" "humidityconv"
fi

killall -q -r ".*dht.py.*"
killall -q -r ".*k30.py.*"
MAINLEVEL=`/home/pi/co2/k30.py -t 1`
HUMTEMPLEVEL=`/home/pi/co2/dht.py 24`
HUMTEMPOUTLEVEL=`/home/pi/co2/dht.py 25`
HUMLEVEL=`echo $HUMTEMPLEVEL | sed "s/,.*//"`
TEMPINTLEVEL=`echo $HUMTEMPLEVEL | sed "s/.*,//"`
HUMOUTLEVEL=`echo $HUMTEMPOUTLEVEL | sed "s/,.*//"`
TEMPOUTLEVEL=`echo $HUMTEMPOUTLEVEL | sed "s/.*,//"`
HUMCONVLEVEL=`/home/pi/co2/humconv.py $HUMOUTLEVEL $TEMPOUTLEVEL $TEMPINTLEVEL`
echo /home/pi/co2/humconv.py $HUMOUTLEVEL $TEMPOUTLEVEL $TEMPINTLEVEL
MAINTEMP="0" #`cat /sys/bus/w1/devices/28-0000065cf907/w1_slave | grep "t=" | sed "s/.*t=//"`
# MAINTEMP=`python -c "print $MAINTEMP / 1000.0"`
UUID=`cat /home/pi/co2/uuid`

# Save level for led daemon
echo "$MAINLEVEL" > $MAINLEVELFILE
echo "$MAINTEMP" > $TEMPLEVELFILE
echo "$HUMLEVEL" > $HUMLEVELFILE
echo "$TEMPINTLEVEL" > $TEMPINTLEVELFILE
echo "$HUMOUTLEVEL" > $HUMOUTLEVELFILE
echo "$TEMPOUTLEVEL" > $TEMPOUTLEVELFILE

# Create dash page
CreateHTML "${RRDIMG}/index.html" dash "${MAINLEVEL}" "${MAINTEMP}"

JSONFILE="${RRDIMG}/data.json"
echo "{\n" \
     " \"Date\": \"$DAYTIME\", \n" \
     " \"co2\": \"$MAINLEVEL\", \n" \
     " \"T_in\": \"$TEMPINTLEVEL\", \n" \
     " \"H_in\": \"$HUMLEVEL\", \n" \
     " \"T_out\": \"$TEMPOUTLEVEL\", \n" \
     " \"H_out\": \"$HUMOUTLEVEL\", \n" \
     " \"H_conv\": \"$HUMCONVLEVEL\" \n}" > ${JSONFILE}_tmp
echo "{\n" \
     " \"$MAINLEVEL ppm\": \"$HUMCONVLEVEL% conv\", \n" \
     " \"$TEMPINTLEVEL °C \" : \"$HUMLEVEL% in\", \n" \
     " \"$TEMPOUTLEVEL °C \" : \"$HUMOUTLEVEL% out\", \n" \
     " \"At\": \"$DAYTIME\" \n}" > ${JSONFILE}_tmp
mv -f ${JSONFILE}_tmp ${JSONFILE}

# Debug
#echo "MAIN sensor CO2 level : ${MAINLEVEL}"

# Update the Databases
`rrdupdate "${MAINRRD}" -t co2 N:"${MAINLEVEL}"`
`rrdupdate "${TEMPRRD}" -t temp N:"${MAINTEMP}"`
`rrdupdate "${TEMPINTRRD}" -t tempint N:"${TEMPINTLEVEL}"`
`rrdupdate "${HUMRRD}" -t humidity N:"${HUMLEVEL}"`
`rrdupdate "${TEMPOUTRRD}" -t tempout N:"${TEMPOUTLEVEL}"`
`rrdupdate "${HUMOUTRRD}" -t humidityout N:"${HUMOUTLEVEL}"`
`rrdupdate "${HUMCONVRRD}" -t humidityconv N:"${HUMCONVLEVEL}"`

# $1 = ImageFile , $2 = Time in secs to go back , $3 = RRDfile, $4, $5, $6, $7, $8 - rrdfiles, $9 = GraphText , $10 width, $11 height, $12 add options
CreateGraph ()
{
  rrdtool graph "${1}.new" --slope-mode -a SVG -s -"${2}" -w $10 -h $11 -D --units-exponent 0 -v "ppm" $12 \
  --right-axis 0.05:0 --right-axis-label "Temp/Humidity" --right-axis-format "%1.0lf" \
  'DEF:ds1='${3}':co2:AVERAGE' \
  'DEF:ds2='${3}':co2:MAX' \
  'DEF:ds3='${3}':co2:MIN' \
  'DEF:ds4='${4}':humidityconv:AVERAGE' \
  'DEF:ds5='${5}':tempint:AVERAGE' \
  'DEF:ds6='${6}':humidity:AVERAGE' \
  'DEF:ds7='${7}':tempout:AVERAGE' \
  'DEF:ds8='${8}':humidityout:AVERAGE' \
  'CDEF:scaled_ds4=ds4,20,*' \
  'CDEF:scaled_ds5=ds5,20,*' \
  'CDEF:scaled_ds6=ds6,20,*' \
  'CDEF:scaled_ds7=ds7,20,*' \
  'CDEF:scaled_ds8=ds8,20,*' \
  'HRULE:2500#FF3300:Drowsiness' \
  'HRULE:5000#FF0000:Maximum' \
  'AREA:1000#FFDB94:Stiffness' \
  'AREA:700#E6FFB2:Safe' \
  'AREA:400#C2F0C2:Fresh' \
  'LINE1:ds2#FF8080:Max CO2' \
  'LINE1:scaled_ds4#000000:HumConv:dashes=4,2' \
  'LINE1:scaled_ds5#303030:TInt' \
  'LINE1:scaled_ds6#00ACCF:HumInt' \
  'LINE1:scaled_ds7#309030:TOut' \
  'LINE1:scaled_ds8#00CF6F:HumOut' \
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
  -t "${9}"
  mv -f "${1}.new" "${1}"
}

# $1 = ImageFile , $2 = Time in secs to go back , $3..$8 = RRDfiles , $9 = GraphText 
CreateDashGraph ()
{
  rrdtool graph "${1}.new" --slope-mode -a SVG -s -"${2}" -w 710 -h 550 -D --units-exponent 0 -v "ppm" \
  --right-axis 0.05:0 --right-axis-label "Temp/Humidity" --right-axis-format "%1.0lf" \
  'DEF:ds1='${3}':co2:AVERAGE' \
  'DEF:ds2='${3}':co2:MAX' \
  'DEF:ds3='${3}':co2:MIN' \
  'DEF:ds4='${4}':humidityconv:AVERAGE' \
  'DEF:ds5='${5}':tempint:AVERAGE' \
  'DEF:ds6='${6}':humidity:AVERAGE' \
  'DEF:ds7='${7}':tempout:AVERAGE' \
  'DEF:ds8='${8}':humidityout:AVERAGE' \
  'CDEF:scaled_ds4=ds4,20,*' \
  'CDEF:scaled_ds5=ds5,20,*' \
  'CDEF:scaled_ds6=ds6,20,*' \
  'CDEF:scaled_ds7=ds7,20,*' \
  'CDEF:scaled_ds8=ds8,20,*' \
  'AREA:1000#FFDB94:Stiffness' \
  'AREA:700#E6FFB2:Safe' \
  'AREA:400#C2F0C2:Fresh' \
  'LINE2:ds1#0000FF:CO2' \
  'LINE1:scaled_ds4#000000:HumConv:dashes=4,2' \
  'LINE2:scaled_ds5#303030:TInt' \
  'LINE2:scaled_ds6#00ACCF:HumInt' \
  'LINE1:scaled_ds7#309030:TOut' \
  'LINE1:scaled_ds8#00CF6F:HumOut' \
  GPRINT:ds1:MAX:"Max %4.0lf" \
  GPRINT:ds1:MIN:"Min %4.0lf" \
  GPRINT:ds1:LAST:"Curr %4.0lf" \
  GPRINT:ds5:LAST:"TInt %2.1lf" \
  GPRINT:ds6:LAST:"HumInt %2.1lf" \
  GPRINT:ds7:LAST:"TOut %2.1lf" \
  GPRINT:ds8:LAST:"HumOut %2.1lf" \
  GPRINT:ds4:LAST:"HumConv %2.1lf" \
  -t "${9}"
  mv -f "${1}.new" "${1}"

  CreateGraph "${RRDIMG}/dashday.svg" 86400 "${MAINRRD}" "${HUMCONVRRD}" "${TEMPINTRRD}" "${HUMRRD}" "${TEMPOUTRRD}" "${HUMOUTRRD}" "Day@${DAYTIME}" 710 160 --no-legend
}

# Update Daily graphs every 10 mins 
#if [ "${MTIME}" = 00 ] || [ "${MTIME}" = 10 ] || [ "${MTIME}" = 20 ] || [ "${MTIME}" = 30 ] || [ "${MTIME}" = 40 ] || [ "${MTIME}" = 50 ];

# Update Daily graphs every minute
#if [ "${MTIME}" = 00 ] || [ "${MTIME}" = 30 ];
#then
# 1 Day Graph
CreateDashGraph "${RRDIMG}/maindash.svg" 14400 "${MAINRRD}" "${HUMCONVRRD}" "${TEMPINTRRD}" "${HUMRRD}" "${TEMPOUTRRD}" "${HUMOUTRRD}" "4Hours@${DAYTIME}"
#echo "Dash Graphs created....."

CreateGraph "${RRDIMG}/mainday.svg" 86400 "${MAINRRD}" "${HUMCONVRRD}" "${TEMPINTRRD}" "${HUMRRD}" "${TEMPOUTRRD}" "${HUMOUTRRD}" "Day@${DAYTIME}" 1280 480
#echo "Daily Graphs created....."
#fi

# Update Weekly graph twice an hour or if the image is missing
if [ "${MTIME}" = 00 ] || [ "${MTIME}" = 30 ] || [ ! -f "${RRDIMG}/mainweek.svg" ];
then
# 1 Week Graph
CreateGraph "${RRDIMG}/mainweek.svg" 604800 "${MAINRRD}" "${HUMCONVRRD}" "${TEMPINTRRD}" "${HUMRRD}" "${TEMPOUTRRD}" "${HUMOUTRRD}" "Week@${DAYTIME}" 1280 480
#echo "Weekly Graphs created....."
fi

# Update  Monthly and Yearly graphs once a day (maybe twice a day on 12h settings) or if missing
if [ "${HTIME}" = 04 ] && [ "${MTIME}" = 00 ] || [ ! -f "${RRDIMG}/mainmonth.svg" ] || [ ! -f "${RRDIMG}/mainyear.svg" ];
then
# 1 Month Graph
CreateGraph "${RRDIMG}/mainmonth.svg" 2678400 "${MAINRRD}" "${HUMCONVRRD}" "${TEMPINTRRD}" "${HUMRRD}" "${TEMPOUTRRD}" "${HUMOUTRRD}" "Month@${DAYTIME}" 1280 480
#echo "Monthly Graphs Created...."
# 1 Year Graph
CreateGraph "${RRDIMG}/mainyear.svg" 31536000 "${MAINRRD}" "${HUMCONVRRD}" "${TEMPINTRRD}" "${HUMRRD}" "${TEMPOUTRRD}" "${HUMOUTRRD}" "Year@${DAYTIME}" 1280 480
#CreateGraph "${RRDIMG}/mainyear.svg" 63072000 "${MAINRRD}" "${HUMCONVRRD}" "${TEMPINTRRD}" "${HUMRRD}" "${TEMPOUTRRD}" "${HUMOUTRRD}" "Year@${DAYTIME}" 1280 480
#echo "Yearly Graphs Created...."
fi

# Now upload the value to the server
wget --timeout=15 --no-check-certificate "https://co2.accosto.com:8443" --post-data "uuid=$UUID&co2=$MAINLEVEL" -O /dev/null

#echo " <------------------------------------------------------------->"
#echo " "

exit 0
