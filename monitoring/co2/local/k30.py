#!/usr/bin/env python3

#Python app to run a K-30 Sensor
import serial
import time
from optparse import OptionParser
import sys

parser = OptionParser()
parser.add_option("-t", "--average-time", dest="avgtime",
                  help="Report value averaged across this period of time", metavar="SECONDS")
parser.add_option("-d", "--device", dest="serial", default="serial0",
                  help="Device name in /dev")

(options, args) = parser.parse_args()

device = "/dev/" + options.serial
ser = serial.Serial(device)
print("Serial " + device + " Connected!", file=sys.stderr)
ser.flushInput()
time.sleep(1)

sum = 0
num = int(options.avgtime)
num_init = num

while True:
    ser.write(serial.to_bytes([0xFE, 0x44, 0x00, 0x08, 0x02, 0x9F, 0x25]))

    #ser.write("\xFE\x44\x00\x08\x02\x9F\x25")
    time.sleep(.01)
    resp = ser.read(7)
    # print("Resp: %d" % len(resp), file=sys.stderr)
    high = resp[3]
    low = resp[4]
    co2 = (high*256) + low
    sum += co2
    num -= 1
    #print(time.strftime("%c") + ": CO2 = " + str(co2) + " ppm", file=sys.stderr)
    if (num > 0):
        time.sleep(1)
    if (num == 0):
        break

print(int(sum/num_init))
#print int(sum/num_init)
