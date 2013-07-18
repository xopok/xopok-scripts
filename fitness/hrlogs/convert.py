#!/usr/bin/env python

import os
import sys
import getopt
from optparse import OptionParser
import datetime

def parseSegment(s, coef):
  s = s.split('@')
  if (len(s) > 2):
    raise RuntimeError("Invalid format")
  s[1] = float(s[1])*coef/3.6 # meters per second
  s[0] = int(s[0])
  #print s
  return s

def printHeader():
  pass

def main():
  parser = OptionParser()
  parser.add_option("-i", "--imperial",
                  action="store_true", dest="imperial", default=False,
                  help="Use Imperial measurements")
  parser.add_option("-t", "--starttime",
                  dest="starttime",
                  help="Override start time")

  (options, args) = parser.parse_args()

  coef = 1.0
  if options.imperial:
    coef = 1.609

  startoffset = None
  starttime = None
  if options.starttime:
    starttime = datetime.datetime.strptime(options.starttime, "%Y-%m-%d %H:%M:%S")

  segments = []

  for s in args:
    segments.append(parseSegment(s, coef))
  print >> sys.stderr, segments

  processed = {}

  print '''<?xml version="1.0" encoding="UTF-8"?>
<TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2 http://www.garmin.com/xmlschemas/TrainingCenterDatabasev2.xsd">
  <Activities>
    <Activity Sport="Running">'''
  lapStarted = False
  distance = 0
  elapsed = 0
  lastTs = None
  firstTs = None
  sumHr = 0
  numHr = 0
  maxHr = 0

  for line in sys.stdin.readlines():
    if line.startswith("#"):
      continue
    timestamp, hr = line.strip().split("=")
    timestamp = round(float(timestamp)/1000)
    if not starttime is None and startoffset is None:
      startoffset = int(starttime.strftime("%s")) - timestamp

    if not startoffset is None:
      timestamp = timestamp + startoffset

    # print timestamp, hr
    tsAsString = datetime.datetime.utcfromtimestamp(timestamp)
    #print tsAsString
    tsAsString = tsAsString.strftime("%Y-%m-%dT%H:%M:%SZ") #2007-08-07T02:42:41Z
    if tsAsString in processed:
      continue
    else:
      processed[tsAsString] = True
    if not lapStarted:
      firstTs = timestamp
      print "<Id>" + tsAsString + "</Id>"
      print '<Lap StartTime="' + tsAsString + '">'
      print """<!--TotalTimeSeconds>2160.000000</TotalTimeSeconds>
        <DistanceMeters>6200.070900</DistanceMeters-->
        <!--MaximumSpeed>18.6828499</MaximumSpeed-->
        <!--Calories>285</Calories-->
        <Intensity>Active</Intensity>
        <TriggerMethod>Manual</TriggerMethod>
        <Track>"""
    print "<Trackpoint>"
    print "  <Time>" + tsAsString + "</Time>"
    print "  <!--AltitudeMeters>0</AltitudeMeters-->"

    if lapStarted:
      span = timestamp - lastTs
      while segments:
        curSegment = segments[0]
        minspan = min(span, curSegment[0])
        curSegment[0] -= minspan
        distance += minspan*curSegment[1]
        span -= minspan
        if curSegment[0] > 0:
          break
        else:
          del segments[0]
      print "  <DistanceMeters>%f</DistanceMeters>" % distance
    else:
      print "  <DistanceMeters>0.0000000</DistanceMeters>"

    lastTs = timestamp
    print "  <HeartRateBpm><Value>" + hr + "</Value></HeartRateBpm>"
    print "</Trackpoint>"
    if not lapStarted:
      lapStarted = True
    hr = int(hr)
    sumHr += hr
    numHr += 1
    maxHr = max(maxHr, hr)
  
  print "</Track>"
  print """<TotalTimeSeconds>%f</TotalTimeSeconds>
        <DistanceMeters>%f</DistanceMeters>""" % (timestamp - firstTs, distance)
  print """<AverageHeartRateBpm xsi:type="HeartRateInBeatsPerMinute_t">
          <Value>%d</Value>
        </AverageHeartRateBpm>
        <MaximumHeartRateBpm xsi:type="HeartRateInBeatsPerMinute_t">
          <Value>%d</Value>
        </MaximumHeartRateBpm>""" % (int(round(sumHr / numHr)), maxHr)

  print "</Lap></Activity></Activities></TrainingCenterDatabase>"

if __name__ == "__main__":
    main()
