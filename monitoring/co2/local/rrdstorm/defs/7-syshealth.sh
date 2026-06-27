DEF:tcpu=$RRD:tcpu:AVERAGE
DEF:thdd=$RRD:thdd:AVERAGE
DEF:tssd=$RRD:tssd:AVERAGE
LINE1:tcpu#FF0000:t CPU
GPRINT:tcpu:LAST: %.2lf\n
LINE1:thdd#00FF00:t HDD1
GPRINT:thdd:LAST: %.0lf\n
LINE1:tssd#00ACCF:t HDD2
GPRINT:tssd:LAST: %.0lf\n
