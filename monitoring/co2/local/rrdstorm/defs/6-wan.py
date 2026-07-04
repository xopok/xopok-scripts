from rrd_dsl import GraphBuilder


def build_graph(rrd_file):
    g = GraphBuilder(rrd_file)

    din = g.def_ds("in", "in")
    dout = g.def_ds("out", "out")
    ddockin = g.def_ds("dockin", "dockout")
    ddockout = g.def_ds("dockout", "dockin")

    nin = g.cdef("nin", din * -1)
    ndockin = g.cdef("ndockin", ddockin * -1)
    g.cdef("lnnin", "in,nin,UNKN,IF")
    g.cdef("lnndockin", "dockin,ndockin,UNKN,IF")
    g.cdef("lnout", "out,out,UNKN,IF")
    g.cdef("lndockout", "dockout,dockout,UNKN,IF")

    g.area(nin, "CC7016")
    g.area(ndockin, "1598C3")
    g.line(1, "lnnin", "EC9D48")
    g.line(1, "lnndockin", "48C4EC")
    g.area(dout, "CC7016")
    g.area(ddockout, "24BC14")
    g.line(1, "lnout", "EC9D48")
    g.line(1, "lndockout", "54EC48")
    g.hrule(0, "FFFFFF")

    g.vdef("totout", "out,TOTAL")
    g.gprint("totout", "Uplink   %1.2lf %s")
    g.vdef("totdockout", "dockout,TOTAL")
    g.gprint("totdockout", "Storj %1.2lf %s ")
    g.vdef("avgdockout", "dockout,AVERAGE")
    g.gprint("avgdockout", "(avg %1.2lf %s/s)\\n")
    g.vdef("totin", "in,TOTAL")
    g.gprint("totin", "Downlink %1.2lf %s")
    g.vdef("totdockin", "dockin,TOTAL")
    g.gprint("totdockin", "Storj %1.2lf %s ")
    g.vdef("avgdockin", "dockin,AVERAGE")
    g.gprint("avgdockin", "(avg %1.2lf %s/s)\\n")

    return g.compile()
