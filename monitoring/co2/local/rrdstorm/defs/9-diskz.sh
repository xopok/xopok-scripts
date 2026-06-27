DEF:ar=$RRD:ar:AVERAGE
DEF:aw=$RRD:aw:AVERAGE
DEF:ars=$RRD:ars:AVERAGE
DEF:aws=$RRD:aws:AVERAGE
DEF:br=$RRD:cr:AVERAGE
DEF:bw=$RRD:cw:AVERAGE
DEF:brs=$RRD:crs:AVERAGE
DEF:bws=$RRD:cws:AVERAGE
DEF:sr=$RRD:br:AVERAGE
DEF:sw=$RRD:bw:AVERAGE
DEF:srs=$RRD:brs:AVERAGE
DEF:sws=$RRD:bws:AVERAGE
CDEF:nbr=br,-1,*
CDEF:nbw=bw,-1,*
CDEF:snbrs=brs,-1,*,2048,/,16,*
CDEF:snbws=bws,-1,*,2048,/,16,*
CDEF:sars=ars,2048,/,16,*
CDEF:saws=aws,2048,/,16,*
CDEF:arkb=ars,2,/
CDEF:awkb=aws,2,/
CDEF:brkb=brs,2,/
CDEF:bwkb=bws,2,/
CDEF:srkb=srs,2,/
CDEF:swkb=sws,2,/
LINE1:ar#54EC48:HDD1 avg r/s
GPRINT:ar:AVERAGE:%.2lf
LINE1:aw#EA644A:w/s
GPRINT:aw:AVERAGE:%.2lf
LINE2:sars#24BC14:rK/s
GPRINT:arkb:AVERAGE:%.2lf
CDEF:argb=arkb,1024,/,1024,/
VDEF:totargb=argb,TOTAL
GPRINT:totargb:Sum%.2lf GiB
LINE2:saws#CC3118:wK/s
GPRINT:awkb:AVERAGE:%.2lf
CDEF:awgb=awkb,1024,/,1024,/
VDEF:totawgb=awgb,TOTAL
GPRINT:totawgb:Sum%.2lf GiB\n
LINE1:nbr#54EC48:HDD2 avg r/s
GPRINT:br:AVERAGE:%.2lf
LINE1:nbw#EA644A:w/s
GPRINT:bw:AVERAGE:%.2lf
LINE2:snbrs#24BC14:rK/s
GPRINT:brkb:AVERAGE:%.2lf
CDEF:brgb=brkb,1024,/,1024,/
VDEF:totbrgb=brgb,TOTAL
GPRINT:totbrgb:Sum%.2lf GiB
LINE2:snbws#CC3118:wK/s
GPRINT:bwkb:AVERAGE:%.2lf
CDEF:bwgb=bwkb,1024,/,1024,/
VDEF:totbwbb=bwgb,TOTAL
GPRINT:totbwbb:Sum%.2lf GiB\n
GPRINT:sr:AVERAGE:SSD avg r/s %.2lf
GPRINT:sw:AVERAGE:w/s %.2lf
GPRINT:srkb:AVERAGE:| rK/s %.2lf
CDEF:srgb=srkb,1024,/,1024,/
VDEF:totsrgb=srgb,TOTAL
GPRINT:totsrgb:Sum%.2lf GiB
GPRINT:swkb:AVERAGE:| wK/s %.2lf
CDEF:swgb=swkb,1024,/,1024,/
VDEF:totswbb=swgb,TOTAL
GPRINT:totswbb:Sum%.2lf GiB\n
HRULE:0#FFFFFF
