DEF:rf=$RRD:rootfree:AVERAGE
DEF:ru=$RRD:rootused:AVERAGE
DEF:pf=$RRD:placefree:AVERAGE
DEF:pu=$RRD:placeused:AVERAGE
DEF:ps=$RRD:placestorj:AVERAGE
CDEF:rfg=rf,1048576,/
CDEF:rug=ru,1048576,/
CDEF:pfg=pf,1048576,/
CDEF:pug=pu,1048576,/
CDEF:psg=ps,1048576,/
CDEF:nrf=rf,-100,*
CDEF:nru=ru,-100,*
CDEF:lnnru=ru,nru,UNKN,IF
CDEF:lnnrf=ru,nrf,nru,+,UNKN,IF
GPRINT:rug:LAST:/ used %4.0lf M
GPRINT:rfg:LAST:/ free %4.0lf M\n
CDEF:lnps=ps,ps,UNKN,IF
CDEF:lnpu=pu,pu,UNKN,IF
CDEF:lnpf=pu,pf,pu,+,UNKN,IF
CDEF:puns=pu,ps,-
AREA:ps#1598C3:/place?/storj? used
GPRINT:psg:LAST:%4.0lf M
GPRINT:pug:LAST:/place? used %4.0lf M
GPRINT:pfg:LAST:/place? free %4.0lf M
LINE1:ps#48C4EC
