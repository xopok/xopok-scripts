DEF:free0=$RRD:free0:AVERAGE
DEF:free1=$RRD:free1:AVERAGE
DEF:free2=$RRD:free2:AVERAGE
CDEF:nfree0=free0,-1,*,-1,MAX
CDEF:nfree1=free1,-1,*,-1,MAX
CDEF:nfree2=free2,-1,*,-1,MAX
CDEF:lnfree0=free0,nfree0,UNKN,IF
CDEF:lnfree1=free1,nfree1,nfree0,+,UNKN,IF
CDEF:lnfree2=free2,nfree2,nfree1,nfree0,+,+,UNKN,IF
AREA:nfree0#24BC14
AREA:nfree1#CC7016::STACK
AREA:nfree2#1598C3::STACK
VDEF:tot0=nfree0,TOTAL
LINE1:lnfree0#54EC48:node3
GPRINT:nfree0:AVERAGE:avg %1.2lf %s
GPRINT:tot0:total %1.2lf %s
GPRINT:nfree0:LAST:last %1.2lf %s/s\n
VDEF:tot1=nfree1,TOTAL
LINE1:lnfree1#EC9D48:node1
GPRINT:nfree1:AVERAGE:avg %1.2lf %s
GPRINT:tot1:total %1.2lf %s
GPRINT:nfree1:LAST:last %1.2lf %s/s\n
VDEF:tot2=nfree2,TOTAL
LINE1:lnfree2#48C4EC:node2
GPRINT:nfree2:AVERAGE:avg %1.2lf %s
GPRINT:tot2:total %1.2lf %s
GPRINT:nfree2:LAST:last %1.2lf %s/s\n
HRULE:0#FFFFFF
