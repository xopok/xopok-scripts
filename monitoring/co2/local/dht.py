#!/usr/bin/python

import sys
import Adafruit_DHT

# Parse command line parameters.
sensor_args = { '11': Adafruit_DHT.DHT11,
		'22': Adafruit_DHT.DHT22,
		'2302': Adafruit_DHT.AM2302 }
samples = 1
if len(sys.argv) >= 2:
	pin = sys.argv[1]
	if len(sys.argv) == 3:
		samples = int(sys.argv[2])
else:
	sys.exit(1)

humiditySum = 0
tempSum = 0
samplesDone = 0

while samplesDone < samples:
  humidity, temperature = Adafruit_DHT.read_retry(Adafruit_DHT.DHT22, pin)
  if humidity is not None and temperature is not None:
    humiditySum += humidity
    tempSum += temperature
    samplesDone += 1
  else:
    print >> sys.stderr, 'Failed to get reading. Try again'

humidity = humiditySum / samplesDone
temperature = tempSum / samplesDone  
print '{1:0.1f},{0:0.1f}'.format(temperature, humidity)

sys.exit(0)
