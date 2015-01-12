#!/usr/bin/python

import RPi.GPIO as GPIO
import time
import math

GPIO.setmode(GPIO.BCM)

ledRed = 16
ledGreen = 20
levelFile = "/dev/shm/co2level"

streetLevel = 400
lowLevel = 425
highLevel = 700
higherLevel = 1000
veryhighLevel = 1500
blinkStep = 100

GPIO.setup(ledRed, GPIO.OUT)
GPIO.setup(ledGreen, GPIO.OUT)

def blink(led, count, onDuration, offDuration, totalDuration):
  elapsed = 0
  for i in xrange(count):
    GPIO.output(led, GPIO.HIGH)
    time.sleep(onDuration)
    GPIO.output(led, GPIO.LOW)
    time.sleep(offDuration)
    elapsed += onDuration + offDuration
  if elapsed < totalDuration:
    time.sleep(totalDuration - elapsed)

blink(ledGreen, 1, 0.002, 0.25, 1)
blink(ledGreen, 2, 0.002, 0.25, 1)
blink(ledGreen, 3, 0.002, 0.25, 1)
blink(ledRed, 1, 0.05, 0.2, 1)
blink(ledRed, 2, 0.05, 0.2, 1)
blink(ledRed, 3, 0.05, 0.2, 1)
blink(ledRed, 1, 0.3, 0.2, 2)
blink(ledRed, 2, 0.3, 0.2, 2)
blink(ledRed, 3, 0.3, 0.2, 2)
blink(ledRed, 4, 0.3, 0.2, 2)

while True:
  try:
    with open(levelFile, 'r') as f:
      level = f.readline()
    intLevel = int(level)
  except:
    intLevel = -1


  if intLevel >= higherLevel:
    total = 2
    led = ledRed
    diff = intLevel - higherLevel
    onDuration = 0.3
    offDuration = 0.2
  elif intLevel >= highLevel:
    total = 1
    led = ledRed
    diff = intLevel - highLevel
    onDuration = 0.05
    offDuration = 0.2
  else:
    total = 3
    led = ledGreen
    diff = highLevel - intLevel
    onDuration = 0.002
    offDuration = 0.25
    
  count = int(math.ceil(float(diff) / blinkStep))
  if count == 0:
    count = 1

  blink(led, count, onDuration, offDuration, total)

  """
    ratio = float(intLevel - highLevel) / (veryhighLevel - highLevel)
    if ratio > 1:
      ratio = 1
    if ratio < 0.05:
      ratio = 0.05
    blink(ledRed, 1, ratio, 0, 1)
  elif intLevel < lowLevel: 
    ratio = float(lowLevel - intLevel) / (lowLevel - streetLevel)
    if ratio > 0.1:
      ratio = 0.1
    if ratio < 0.02:
      ratio = 0.02
    blink(ledGreen, 1, ratio, 0, 3)
  else:
    time.sleep(10)
  """

GPIO.cleanup() 
