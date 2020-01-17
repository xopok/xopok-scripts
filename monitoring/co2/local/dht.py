#!/usr/bin/python3

import os
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

filename = os.path.join('/dev/shm', 'dht-' + pin)
try:
  with open(filename) as f:
    h, t = [float(x) for x in next(f).split()]
except:
  h = None
  t = None

def get():
  humidity, temperature = Adafruit_DHT.read_retry(sensor_args['22'], pin, retries=11)
  if humidity is not None and temperature is not None and 0 <= humidity <= 100.0:
    return (humidity, temperature)
  return (None, None)

if h is None:
  # Need to seed the stored values
  h, t = get()

for i in (1,2,3,4):
  h2, t2 = get()
  if h is not None and 0 <= h <= 100.0 and h2 is not None and 0 <= h2 <= 100.0 and abs(t - t2) < 1:
    # Good readings
    with open(filename, "w+") as f:
      print('{0:0.1f} {1:0.1f}'.format(h2, t2), file=f)
    print('{0:0.1f} {1:0.1f}'.format(h2, t2))
    sys.exit(0)
  else:
    print('Attempt {0:d} failed'.format(1), file=sys.stderr)
        

print('U U')
sys.exit(1)
