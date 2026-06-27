DEF:dsC=$RRD:cached:AVERAGE
DEF:dsB=$RRD:buffer:AVERAGE
DEF:dsF=$RRD:free:AVERAGE
DEF:dsT=$RRD:total:AVERAGE
CDEF:bo=dsT,UN,0,dsT,IF,0,GT,UNKN,INF,IF
AREA:bo#DDDDDD:
CDEF:tot=dsT,1024,*
CDEF:fre=dsF,1024,*
CDEF:freP=fre,100,*,tot,/
CDEF:buf=dsB,1024,*
CDEF:bufP=buf,100,*,tot,/
CDEF:cac=dsC,1024,*
CDEF:cacP=cac,100,*,tot,/
CDEF:use=dsT,dsF,dsC,+,dsB,+,-,1024,*
CDEF:useP=use,100,*,tot,/
CDEF:l=use,1,1,IF
AREA:use#CC3300:User   
LINE2:l#AC1300::STACK
VDEF:maxU=use,MAXIMUM
VDEF:minU=use,MINIMUM
VDEF:avgU=use,AVERAGE
VDEF:curU=use,LAST
VDEF:procU=useP,LAST
GPRINT:curU:Last %6.2lf %s
GPRINT:procU:%3.0lf%%
GPRINT:avgU:Avg %6.2lf %s
GPRINT:maxU:Max %6.2lf %s
GPRINT:minU:Min %6.2lf %s\n
AREA:cac#FF9900:Cached :STACK
LINE2:l#DF7900::STACK
VDEF:maxC=cac,MAXIMUM
VDEF:minC=cac,MINIMUM
VDEF:avgC=cac,AVERAGE
VDEF:curC=cac,LAST
VDEF:procC=cacP,LAST
GPRINT:curC:Last %6.2lf %s
GPRINT:procC:%3.0lf%%
GPRINT:avgC:Avg %6.2lf %s
GPRINT:maxC:Max %6.2lf %s
GPRINT:minC:Min %6.2lf %s\n
AREA:buf#FFCC00:Buffers:STACK
LINE2:l#DFAC00::STACK
VDEF:maxB=buf,MAXIMUM
VDEF:minB=buf,MINIMUM
VDEF:avgB=buf,AVERAGE
VDEF:curB=buf,LAST
VDEF:procB=bufP,LAST
GPRINT:curB:Last %6.2lf %s
GPRINT:procB:%3.0lf%%
GPRINT:avgB:Avg %6.2lf %s
GPRINT:maxB:Max %6.2lf %s
GPRINT:minB:Min %6.2lf %s\n
AREA:fre#FFFFCC:Unused :STACK
VDEF:maxF=fre,MAXIMUM
VDEF:minF=fre,MINIMUM
VDEF:avgF=fre,AVERAGE
VDEF:curF=fre,LAST
VDEF:procF=freP,LAST
GPRINT:curF:Last %6.2lf %s
GPRINT:procF:%3.0lf%%
GPRINT:avgF:Avg %6.2lf %s
GPRINT:maxF:Max %6.2lf %s
GPRINT:minF:Min %6.2lf %s\n
