#!/usr/bin/env python3

#Python app to run a K-30 Sensor
import serial
import time
from optparse import OptionParser
import sys

parser = OptionParser()
parser.add_option("-t", "--retry-attempts", dest="retries",
                  help="Perform multiple attempts to read data", metavar="ATTEMPTS")
parser.add_option("-d", "--device", dest="serial", default="serial0",
                  help="Device name in /dev")

(options, args) = parser.parse_args()

device = "/dev/" + options.serial
ser = serial.Serial(device, timeout=2)
print("Serial " + device + " Connected!", file=sys.stderr)
ser.flushInput()
time.sleep(0.1)

num = int(options.retries)
success = False

while num > 0:
    ser.flushInput()
    ser.write(serial.to_bytes([0xFE, 0x44, 0x00, 0x08, 0x02, 0x9F, 0x25]))
    time.sleep(.01)
    num -= 1
    resp = ser.read(7)
    if len(resp) < 7:
        time.sleep(1)
        continue
    high = resp[3]
    low = resp[4]
    co2 = (high*256) + low
    print(co2)
    success = True
    break
    #print(time.strftime("%c") + ": CO2 = " + str(co2) + " ppm", file=sys.stderr)

if not success:
  print("U")

sys.exit(0 if success else 1)
