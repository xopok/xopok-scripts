#!/usr/bin/env python

import os
import sys
import re
import time
import subprocess
import tempfile
import xml.dom.minidom as xmldom

ac3fifo = False

def GetText(n):
    return n.childNodes.item(0).data

def CreateFifo(suffix='.ac3'):
    tfile, tname = tempfile.mkstemp(suffix=suffix)
    os.close(tfile)
    os.unlink(tname)
    os.mkfifo(tname)
    return tname

filesToDelete = []

def main():
    if len(sys.argv) < 3:
        print "Usage: %s infile outfile" % sys.argv[0]
        sys.exit(1)

    infile = sys.argv[1]
    outfile = sys.argv[2]

    if not os.path.exists(infile):
        print "%s not exists" % infile
        sys.exit(1)

    p = subprocess.Popen(['mkvinfo', '-s', infile], stdout=subprocess.PIPE)

    tracksToConvert = []
    tracksToCopy = []

    # TODO: preserve track's language
    for line in p.stdout.xreadlines():
      if line.startswith("Track"):
        r = re.search("Track [0-9]+: ([^,]+), codec ID: ([^,]+), mkvmerge[^0-9]+([0-9]+),.*", line)
        if r and r.groups()[0] == 'audio':
          id = r.groups()[2]
          if r.groups()[1] != 'A_DTS':
            tracksToCopy.append(id)
          else:
            tracksToConvert.append(id)
      else:
        p.kill()
        p.wait()
        break

    if not tracksToConvert:
        print "Nothing to convert"
        return 0

    tracks = []

    for i in tracksToConvert:
        dts = CreateFifo(suffix='.dts')
        if ac3fifo:
            ac3 = CreateFifo(suffix='.ac3')
        else:
            tfile, ac3 = tempfile.mkstemp(suffix='.ac3')
            os.close(tfile)
        filesToDelete.append(dts)
        filesToDelete.append(ac3)
        tracks.append((i, dts, ac3))

    # Extractor
    cmdline = ['mkvextract', 'tracks', infile]
    for id, dts, ac3 in tracks:
        cmdline += ['%s:%s' % (id, dts)]

    print cmdline
    p_extract = subprocess.Popen(cmdline, stdout=subprocess.PIPE)
    devnull = os.open('/dev/null', os.O_WRONLY)

    convs = []
    # Converters
    for id, dts, ac3 in tracks:
        cmdline = ['ffmpeg', '-v', '3', '-y', '-i', dts, '-alang', 'rus', '-ab', '448k', '-ar', '48000', '-ac', '6', '-acodec', 'ac3', ac3]
        print cmdline
        if not ac3fifo:
            p = subprocess.Popen(cmdline, stdout=devnull, stderr=devnull)
        else:
            p = subprocess.Popen(cmdline, stdout=subprocess.PIPE, stderr=devnull)
            p1 = subprocess.Popen(['bash', '-c', 'cat > %s' % ac3], stdin = p.stdout)
            convs.append((p1, None))
        convs.append((p, cmdline))

    # Wait for extract and convert
    if not ac3fifo:
        out_e = p_extract.communicate()
        if p_extract.returncode != 0:
            print "Extract failed, %s" % str(out_e)
            return 2
        
        for i, cmdline in convs:
            out = i.communicate()
            if i.returncode != 0:
                print "Convert (%s) failed, %s" % (str(cmdline), str(out))
                return 3

    # Merger
    cmdline = ['mkvmerge', '-q', '-o', outfile]

    for id, dts, ac3 in tracks:
        cmdline += [ac3]

    if tracksToCopy:
        cmdline += ['-a', ",".join(tracksToCopy)]
    else:
        cmdline += ['-A']
    cmdline += [infile]

    print cmdline
    p_merge = subprocess.Popen(cmdline, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    out = p_merge.communicate()
    if p_merge.returncode != 0:
        print "Merge failed: [%s], [%s]" % (out[0], out[1])
        return 1

    print "Ok"
    return 0

if __name__ == '__main__':
    res = 1
    #try:
    res = main()
    #except Exception, e:
    #    print e
    #    pass
    for i in filesToDelete:
        try:
            os.unlink(i)    
        except:
            pass
    sys.exit(res)
