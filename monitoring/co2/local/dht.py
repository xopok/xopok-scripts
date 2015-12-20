#!/usr/bin/python

import sys
import Adafruit_DHT

# Parse command line parameters.
sensor_args = { '11': Adafruit_DHT.DHT11,
		'22': Adafruit_DHT.DHT22,
		'2302': Adafruit_DHT.AM2302 }

if len(sys.argv) >= 2:
	pin = sys.argv[1]
else:
	sys.exit(1)

while True:
  humidity, temperature = Adafruit_DHT.read_retry(sensor_args['22'], pin)
  if humidity is not None and temperature is not None and 0 <= humidity <= 100.0:
    print '{1:0.1f},{0:0.1f}'.format(temperature, humidity)
    sys.exit(0)
  else:
    print >> sys.stderr, 'Failed to get reading. Try again'

sys.exit(1)
