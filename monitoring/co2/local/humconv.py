#!/usr/bin/python3

import sys
import math

if len(sys.argv) >= 4:
  humout = float(sys.argv[1])
  tempout = float(sys.argv[2])
  tempin = float(sys.argv[3])
else:
  sys.exit(1)

abshum = (6.112 * math.exp((17.67 * tempout) / (tempout + 243.5)) * humout * 18.02) / ((273.15 + tempout) * 100 * 0.08314)

humint = abshum * ((273.15 + tempin) * 100 * 0.08314) / ((6.112 * math.exp((17.67 * tempin) / (tempin + 243.5)) * 18.02))

if humint > 100.0:
  humint = 100.0

print('{0:0.1f}'.format(humint))
