DEF:in=$RRD:in:AVERAGE
DEF:out=$RRD:out:AVERAGE
DEF:dockin=$RRD:dockout:AVERAGE
DEF:dockout=$RRD:dockin:AVERAGE
CDEF:nin=in,-1,*
CDEF:ndockin=dockin,-1,*
CDEF:lnnin=in,nin,UNKN,IF
CDEF:lnndockin=dockin,ndockin,UNKN,IF
CDEF:lnout=out,out,UNKN,IF
CDEF:lndockout=dockout,dockout,UNKN,IF
AREA:nin#CC7016
AREA:ndockin#1598C3
LINE1:lnnin#EC9D48
LINE1:lnndockin#48C4EC
AREA:out#CC7016
AREA:dockout#24BC14
LINE1:lnout#EC9D48
LINE1:lndockout#54EC48
HRULE:0#FFFFFF
VDEF:totout=out,TOTAL
GPRINT:totout:Uplink   %1.2lf %s
VDEF:totdockout=dockout,TOTAL
GPRINT:totdockout:Storj %1.2lf %s 
VDEF:avgdockout=dockout,AVERAGE
GPRINT:avgdockout:(avg %1.2lf %s/s)\n
VDEF:totin=in,TOTAL
GPRINT:totin:Downlink %1.2lf %s
VDEF:totdockin=dockin,TOTAL
GPRINT:totdockin:Storj %1.2lf %s 
VDEF:avgdockin=dockin,AVERAGE
GPRINT:avgdockin:(avg %1.2lf %s/s)\n
