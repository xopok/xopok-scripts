DEF:ds1=$RRD:upload:AVERAGE
DEF:ds2=$RRD:uploaded:AVERAGE
DEF:ds3=$RRD:uploadfailed:AVERAGE
DEF:ds4=$RRD:download:AVERAGE
DEF:ds5=$RRD:downloaded:AVERAGE
DEF:ds6=$RRD:downloadfailed:AVERAGE
DEF:ds7=$RRD:audit:AVERAGE
DEF:ds8=$RRD:audited:AVERAGE
DEF:ds9=$RRD:auditfailed:AVERAGE
DEF:dsd=$RRD:deleted:AVERAGE
CDEF:ln1=ds2,ds2,UNKN,IF
CDEF:ln2=ds3,ds2,ds3,+,UNKN,IF
AREA:ds2#1598C3
AREA:ds3#CC7016::STACK
LINE1:ln2#EC9D48
LINE1:ln1#48C4EC
CDEF:d=ds5
CDEF:df=ds6
CDEF:af=ds9
CDEF:nd=d,-1,*
CDEF:ndf=df,-1,*
CDEF:naf=af,-1,*
CDEF:lnd=d,nd,UNKN,IF
CDEF:lndf=df,ndf,nd,+,UNKN,IF
CDEF:lnaf=af,naf,ndf,nd,+,+,UNKN,IF
AREA:nd#24BC14
AREA:ndf#CC7016::STACK
AREA:naf#CC3118::STACK
LINE1:lndf#EC9D48
LINE1:lnd#54EC48
LINE1:lnaf#EA644A
CDEF:nds8=ds8,ds9,+,-1,*
LINE1:nds8#FFFFFF
LINE1:dsd#FFFFFF
HRULE:0#FFFFFF
VDEF:totuploaded=ds2,TOTAL
GPRINT:totuploaded:Uploaded %1.1lf %s
VDEF:totupload=ds1,TOTAL
GPRINT:totupload:/  %1.1lf %s;
VDEF:totdownloaded=ds5,TOTAL
GPRINT:totdownloaded:Downloaded %1.1lf %s
VDEF:totdownload=ds4,TOTAL
GPRINT:totdownload:/  %1.1lf %s attempts\n
