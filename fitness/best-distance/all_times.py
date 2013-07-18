#!/usr/bin/python

import sys
from time import time
from heapq import heappush, heappop, heapify
from bisect import bisect
from collections import Counter
import array

def silly(arr):
  answer = dict()
  for s in xrange(len(arr)):
    for e in xrange(s + 1, len(arr)):
      dt = arr[e][0] - arr[s][0]
      dd = arr[e][1] - arr[s][1]
      answer[dt] = max(answer.get(dt, (0, 0, 0)), (dd, arr[s][0], arr[e][0]))
  return answer.items()

def flt(answer):
  result = []
  md = 0
  for t, d in answer:
    if d > md:
      while result and (result[-1][1][0] / result[-1][0]) < (d[0] / t) * 1.00001:
        del result[-1]
      result.append((t, d))
      md = d
  return result

def time_call(function, *args, **kwargs):
  start = time()
  result = function(*args, **kwargs)
  return time() - start, result

def diff(a1, a2):
  a1 = a1[:]
  a2 = a2[:]
  while a1 and a2:
    if a1[0][0] == a2[0][0]:
      if abs(a1[0][1][0] - a2[0][1][0]) < 0.00001:
        pass
      else:
        print "-", a1[0]
        print "+", a2[0]
      del a1[0]
      del a2[0]
    else:
      if a1[0][0] < a2[0][0]:
        print "-", a1[0]
        del a1[0]
      else:
        print "+", a2[0]
        del a2[0]
  for v in a1:
    print "-", v
  for v in a2:
    print "+", v

def complete(a):
  result = [a[0]]
  pt, pd = a[0]
  for t, d in a[1:]:
    for tt in range(t - pt):
      result.append((pt + 1 + tt, pd + (d - pd) / (t - pt) * (tt + 1)))
    pt, pd = t, d
  return result

def calcMinMaxs(speeds, arr):
  cur = 2
  result = []
  spdlen = len(speeds)
  curmins = speeds
  curmaxs = speeds
  result.append((speeds, speeds))
  while (cur < spdlen):
    # mins/maxs holds min/max speed across the segment of length cur
    #   starting from position indicated
    #   multiplied by segment length
    # TODO: think about storing something else instead of plain min/max 
    half = cur/2
    mins = array.array('d', [min(curmins[i], curmins[i+half]) * 2 for i in xrange(spdlen - cur + 1)] )
    maxs = array.array('d', [max(curmaxs[i], curmaxs[i+half]) * 2 for i in xrange(spdlen - cur + 1)] )
    result.append((mins, maxs))
    curmins = mins
    curmaxs = maxs
    cur *= 2
  return result

def getSegments(minmaxs, arr, l, bestDistance):
  pos = 0
  endpos = len(arr) - l

  defaultSegmentLen = 24
  prevStep = 64
  prevLog = 6
  segments = []
  usePrevSegment = False
  while pos < endpos:
    posl = pos + l
    cur = arr[posl][1] - arr[pos][1]
    if cur > bestDistance:
      #segments.append((pos, min(defaultSegmentLen, endpos-pos)))
      if (usePrevSegment):
        i, j = segments[-1]
        segments[-1] = (i, j+defaultSegmentLen)
      else:
        segments.append((pos, defaultSegmentLen))
      pos += defaultSegmentLen
      usePrevSegment = True
      continue

    usePrevSegment = False

    diff = bestDistance - cur

    curStep = prevStep
    goodStep = 1
    goodLog = 0
    curLog = prevLog
    mins, maxs = minmaxs[curLog]
    forward = True
    remain = endpos - pos

    if not (curStep < remain) or not ((maxs[posl] - mins[pos]) < diff):
      forward = False
      curStep /= 2
      curLog -= 1
    else:
      goodStep = curStep
      goodLog = curLog
      curStep *= 2
      curLog += 1

    while 1 <= curStep < remain:
      mins, maxs = minmaxs[curLog]
      if ((maxs[posl] - mins[pos]) < diff):
        goodStep = curStep
        goodLog = curLog
        if not forward:
          break
        else:
          curStep *= 2
          curLog += 1
      else:
        if not forward:
          curStep /= 2
          curLog -= 1
        else:
          break

    prevStep = goodStep
    prevLog = goodLog
    pos += goodStep
  #print l, len(segments), ":", [(arr[i][0],arr[i+j][0]) for i, j in segments]
  return segments

def clever(arr):
  best = dict()
  count = len(arr)
  spdlen = count - 1
  speeds = array.array('d', [arr[i+1][1] - arr[i][1] for i in xrange(spdlen)] )
  minmaxs = calcMinMaxs(speeds, arr)

  bestPos = 0
  bestDistance = 0
  curForward = -1
  segmentedStep = 8
  for j in xrange(0, spdlen, segmentedStep):
    innerLen = min(j+segmentedStep, spdlen)
    if j > 0:
      segments = getSegments(minmaxs, arr, innerLen, bestDistance - 0.01)
    else:
      segments = [(0, spdlen)]
    for i in xrange(j, innerLen):
      pos = 0
      l = i+1

      hardEndPos = spdlen - i
      for (startpos, segmentLen) in segments:
        segmentLen += segmentedStep
        prevStep = 64
        prevLog = 6
        pos = startpos
        endpos = min(startpos + segmentLen, hardEndPos)
        while pos < endpos:
          posl = pos + l
          cur = arr[posl][1] - arr[pos][1]
          if cur > bestDistance:
            bestPos = pos
            bestDistance = cur
          diff = bestDistance - cur

          curStep = prevStep
          goodStep = 1
          goodLog = 0
          curLog = prevLog
          mins, maxs = minmaxs[curLog]
          forward = True
          remain = hardEndPos - pos

          if not (curStep < remain) or not ((maxs[posl] - mins[pos]) < diff):
            forward = False
            curStep /= 2
            curLog -= 1
          else:
            goodStep = curStep
            goodLog = curLog
            curStep *= 2
            curLog += 1
          while 1 <= curStep < remain:
            mins, maxs = minmaxs[curLog]
            if ((maxs[posl] - mins[pos]) < diff):
              goodStep = curStep
              goodLog = curLog
              if not forward:
                break
              else:
                if pos + goodStep > endpos:
                  break
                curStep *= 2
                curLog += 1
            else:
              if not forward:
                curStep /= 2
                curLog -= 1
              else:
                break

          prevStep = goodStep
          prevLog = goodLog
          pos += goodStep

      best[l] = (bestDistance, arr[bestPos][0], arr[bestPos+l][0])
      #print l, bestDistance, arr[bestPos][0], arr[bestPos+l][0]

      # Pre-compute next max based on the same segment
      if bestPos > 0 and bestPos+l+1 <= spdlen:
        left  = arr[bestPos+l][1] - arr[bestPos-1][1]
        right = arr[bestPos+l+1][1] - arr[bestPos][1]
        if left > right:
          bestPos -= 1
          bestDistance = left
        else:
          bestDistance = right
      else:
        bestPos = 0
        bestDistance = bestDistance - 0.01

  return best.items()

for f in sys.argv[1:]:
  arr = eval(open(f).read())#[:500]
  arr = complete(arr)

  clever_time, clever_answer = time_call(clever, arr)
  #silly_time, silly_answer = time_call(silly, arr)
  silly_time, silly_answer = 0, dict()

  clever_answer = flt(sorted(clever_answer))
  silly_answer = flt(sorted(silly_answer))

  print
  #print silly_answer
  #print clever_answer
  if silly_answer:
    diff(silly_answer, clever_answer)
  print len(arr)
  print silly_time, clever_time
