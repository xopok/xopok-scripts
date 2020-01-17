#!/usr/bin/env python

#Python app to run a K-30 Sensor
import serial
import time
from optparse import OptionParser
import sys

ser = serial.Serial("/dev/serial0")
#print("Serial Connected!", file=sys.stderr)
ser.flushInput()
time.sleep(1)

parser = OptionParser()
parser.add_option("-t", "--average-time", dest="avgtime",
                  help="Report value averaged across this period of time", metavar="SECONDS")

(options, args) = parser.parse_args()

sum = 0
num = int(options.avgtime)
num_init = num

while True:
    #ser.write("\xFE\x44\x00\x08\x02\x9F\x25".encode())
    ser.write("\xFE\x44\x00\x08\x02\x9F\x25")
    time.sleep(.01)
    resp = ser.read(7)
    high = ord(resp[3])
    low = ord(resp[4])
    co2 = (high*256) + low
    sum += co2
    num -= 1
    #print(time.strftime("%c") + ": CO2 = " + str(co2) + " ppm", file=sys.stderr)
    if (num > 0):
        time.sleep(1)
    if (num == 0):
        break

#print(int(sum/num_init))
print int(sum/num_init)
