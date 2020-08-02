#!/usr/bin/python2

import RPi.GPIO as GPIO
import time
import datetime

GPIO.setmode(GPIO.BCM)

ledRed = 16
ledGreen = 20
levelFile = "/dev/shm/co2level"

redNightFactor = 16
patterns = [
  [(0, 400),     ledGreen, (3000, 2, 248, 2, 248, 2, 248, 2),                                       1],
  [(400, 500),   ledGreen, (3000, 2, 248, 2, 248, 2),                                               1],
  [(500, 600),   ledGreen, (3000, 2, 248, 2),                                                       1],
  [(600, 700),   ledGreen, (3000, 2),                                                               1],
  [(700, 800),   ledRed,   (1000, 50),                                                              redNightFactor],
  [(800, 900),   ledRed,   (1000, 50, 200, 50),                                                     redNightFactor],
  [(900, 1000),  ledRed,   (1000, 50, 200, 50, 200, 50),                                            redNightFactor],
  [(1000, 1200), ledRed,   (1500, 50, 150, 50, 300, 50, 150, 50),                                   redNightFactor],
  [(1200, 1500), ledRed,   (1500, 50, 150, 50, 350, 50, 350, 50, 150, 50),                          redNightFactor],
  [(1500, 2000), ledRed,   (4000, 300, 200, 300, 200, 300, 200, 300, 200, 300, 200, 300),           1],
  [(2000, 5000), ledRed,   (4000, 300, 200, 300, 200, 300, 200, 300, 200, 300, 200, 300, 200, 300), 1],
  [(5000, 9999), ledRed,   (500, 50, 100, 250),                                                     1],
]

nightBegin = datetime.time(hour=22, minute=00)
nightEnd = datetime.time(hour=7, minute=00)

GPIO.setup(ledRed, GPIO.OUT)
GPIO.setup(ledGreen, GPIO.OUT)

def isNight():
  now = datetime.datetime.now().time()
  if (nightBegin > nightEnd):
    return now > nightBegin or now < nightEnd
  else:
    return nightBegin < now < nightEnd

def blink(led, pattern, nightFactor):
  elapsed = 0
  total, pulses = pattern[0], pattern[1:]
  state = True
  night = isNight()
  overflow = 0
  for i in pulses:
    GPIO.output(led, GPIO.HIGH if state else GPIO.LOW)
    if (night):
      if state:
        reducedDuration = max(2, int(i / nightFactor))
        overflow = i - reducedDuration
        i = reducedDuration
      else:
        i = i + overflow
        overflow = 0
    time.sleep(i / 1000.0)
    state = not state
    elapsed += i
  GPIO.output(led, GPIO.LOW)
  if elapsed < total:
    time.sleep((total - elapsed) / 1000.0)

for (level_range, led, pattern, nightFactor) in patterns:
  blink(led, pattern, nightFactor)

while True:
  try:
    with open(levelFile, 'r') as f:
      level = f.readline()
    intLevel = int(level)
  except:
    intLevel = -1
    blink(ledGreen, (500, 500), 1)
    blink(ledRed, (1500, 500), 1)
    continue

  blinked = False
  for (level_range, led, pattern, nightFactor) in patterns:
    if (level_range[0] < intLevel <= level_range[1]):
      blink(led, pattern, nightFactor)
      blinked = True
  if not blinked:
    level_range, led, pattern, nightFactor = patterns[-1]
    blink(led, pattern, 1)


GPIO.cleanup() 
