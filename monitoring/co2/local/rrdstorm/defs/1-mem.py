from rrd_dsl import GraphBuilder


def build_graph(rrd_file):
    g = GraphBuilder(rrd_file)

    dsC = g.def_ds("dsC", "cached")
    dsB = g.def_ds("dsB", "buffer")
    dsF = g.def_ds("dsF", "free")
    dsT = g.def_ds("dsT", "total")

    g.cdef("bo", "dsT,UN,0,dsT,IF,0,GT,UNKN,INF,IF")
    g.area("bo", "DDDDDD", "")

    tot = g.cdef("tot", dsT * 1024)
    fre = g.cdef("fre", dsF * 1024)
    freP = g.cdef("freP", fre * 100 / tot)
    buf = g.cdef("buf", dsB * 1024)
    bufP = g.cdef("bufP", buf * 100 / tot)
    cac = g.cdef("cac", dsC * 1024)
    cacP = g.cdef("cacP", cac * 100 / tot)
    use = g.cdef("use", (dsT - (dsF + dsC + dsB)) * 1024)
    useP = g.cdef("useP", use * 100 / tot)
    g.cdef("l", "use,1,1,IF")

    g.area(use, "CC3300", "User")
    g.args.append("LINE2:l#AC1300::STACK")

    g.vdef("maxU", "use,MAXIMUM")
    g.vdef("minU", "use,MINIMUM")
    g.vdef("avgU", "use,AVERAGE")
    g.vdef("curU", "use,LAST")
    g.vdef("procU", "useP,LAST")
    g.args.append("GPRINT:curU:Last %6.2lf %s")
    g.args.append("GPRINT:procU:%3.0lf%%")
    g.args.append("GPRINT:avgU:Avg %6.2lf %s")
    g.args.append("GPRINT:maxU:Max %6.2lf %s")
    g.args.append("GPRINT:minU:Min %6.2lf %s\\n")

    g.area(cac, "FF9900", "Cached ", stack=True)
    g.args.append("LINE2:l#DF7900::STACK")

    g.vdef("maxC", "cac,MAXIMUM")
    g.vdef("minC", "cac,MINIMUM")
    g.vdef("avgC", "cac,AVERAGE")
    g.vdef("curC", "cac,LAST")
    g.vdef("procC", "cacP,LAST")
    g.args.append("GPRINT:curC:Last %6.2lf %s")
    g.args.append("GPRINT:procC:%3.0lf%%")
    g.args.append("GPRINT:avgC:Avg %6.2lf %s")
    g.args.append("GPRINT:maxC:Max %6.2lf %s")
    g.args.append("GPRINT:minC:Min %6.2lf %s\\n")

    g.area(buf, "FFCC00", "Buffers", stack=True)
    g.args.append("LINE2:l#DFAC00::STACK")

    g.vdef("maxB", "buf,MAXIMUM")
    g.vdef("minB", "buf,MINIMUM")
    g.vdef("avgB", "buf,AVERAGE")
    g.vdef("curB", "buf,LAST")
    g.vdef("procB", "bufP,LAST")
    g.args.append("GPRINT:curB:Last %6.2lf %s")
    g.args.append("GPRINT:procB:%3.0lf%%")
    g.args.append("GPRINT:avgB:Avg %6.2lf %s")
    g.args.append("GPRINT:maxB:Max %6.2lf %s")
    g.args.append("GPRINT:minB:Min %6.2lf %s\\n")

    g.area(fre, "FFFFCC", "Unused ", stack=True)

    g.vdef("maxF", "fre,MAXIMUM")
    g.vdef("minF", "fre,MINIMUM")
    g.vdef("avgF", "fre,AVERAGE")
    g.vdef("curF", "fre,LAST")
    g.vdef("procF", "freP,LAST")
    g.args.append("GPRINT:curF:Last %6.2lf %s")
    g.args.append("GPRINT:procF:%3.0lf%%")
    g.args.append("GPRINT:avgF:Avg %6.2lf %s")
    g.args.append("GPRINT:maxF:Max %6.2lf %s")
    g.args.append("GPRINT:minF:Min %6.2lf %s\\n")

    return g.compile()
