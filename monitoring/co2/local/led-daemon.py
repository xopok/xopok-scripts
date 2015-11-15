#!/usr/bin/python

import RPi.GPIO as GPIO
import time

GPIO.setmode(GPIO.BCM)

ledRed = 16
ledGreen = 20
levelFile = "/dev/shm/co2level"

patterns = [
  [(0, 400),     ledGreen, (3000, 2, 250, 2, 250, 2, 250, 2)],
  [(400, 500),   ledGreen, (3000, 2, 250, 2, 250, 2)],
  [(500, 600),   ledGreen, (3000, 2, 250, 2)],
  [(600, 700),   ledGreen, (3000, 2)],
  [(700, 800),   ledRed,   (1000, 50)],
  [(800, 900),   ledRed,   (1000, 50, 200, 50)],
  [(900, 1000),  ledRed,   (1000, 50, 200, 50, 200, 50)],
  [(1000, 1200), ledRed,   (1500, 50, 200, 50, 200, 50, 200, 50)],
  [(1200, 1500), ledRed,   (1500, 50, 200, 50, 200, 50, 200, 50, 200, 50)],
  [(1500, 2000), ledRed,   (4000, 300, 200, 300, 200, 300, 200, 300, 200, 300, 200, 300)],
  [(2000, 5000), ledRed,   (4000, 300, 200, 300, 200, 300, 200, 300, 200, 300, 200, 300, 200, 300)],
  [(5000, 9999), ledRed,   (500, 50, 100, 250)],
]

GPIO.setup(ledRed, GPIO.OUT)
GPIO.setup(ledGreen, GPIO.OUT)

def blink(led, pattern):
  elapsed = 0
  total, pulses = pattern[0], pattern[1:]
  state = True
  for i in pulses:
    GPIO.output(led, GPIO.HIGH if state else GPIO.LOW)
    time.sleep(i / 1000.0)
    state = not state
    elapsed += i
  GPIO.output(led, GPIO.LOW)
  if elapsed < total:
    time.sleep((total - elapsed) / 1000.0)

for (level_range, led, pattern) in patterns:
  blink(led, pattern)

while True:
  try:
    with open(levelFile, 'r') as f:
      level = f.readline()
    intLevel = int(level)
  except:
    intLevel = -1
    blink(ledGreen, (500, 500))
    blink(ledRed, (1500, 500))
    continue

  blinked = False
  for (level_range, led, pattern) in patterns:
    if (level_range[0] < intLevel <= level_range[1]):
      blink(led, pattern)
      blinked = True
  if not blinked:
    level_range, led, pattern = patterns[-1]
    blink(led, pattern)


GPIO.cleanup() 
