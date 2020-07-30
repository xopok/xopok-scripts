#!/usr/bin/python3

import os
import sys
import json

for line in sys.stdin:
  try:
    r = json.loads(line)

    filename = os.path.join('/dev/shm/', "sdr-%s-%s-%s" % (r['model'], str(r['id']), str(r["channel"])))
    if 'temperature_F' in r:
      temp = "%.1f" % ((r["temperature_F"] - 32) * 5 / 9)
    elif 'temperature_C' in r:
      temp = "%.1f" % r["temperature_C"]
    else:
      temp = "U"
    if 'humidity' in r:
      hum = "%d" % r["humidity"]
    else:
      hum = "U"

    print("%s -> %s:%s" % (filename, temp, hum))
    with open(filename, 'w') as f:
      f.write("%s %s\n" % (hum, temp))

  except:
    print("Error handling %s" % line)
    with open('/place/sdr-errors', 'a+') as f:
      f.write("%s" % line)
    continue
