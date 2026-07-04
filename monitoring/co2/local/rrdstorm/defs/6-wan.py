from rrd_dsl import GraphBuilder


def build_graph(rrd_file):
    g = GraphBuilder(rrd_file)

    ds_in = g.def_ds("in", "in")
    ds_out = g.def_ds("out", "out")
    dockin = g.def_ds("dockin", "dockout")
    dockout = g.def_ds("dockout", "dockin")

    g.cdef("nin", ds_in * -1)
    g.cdef("ndockin", dockin * -1)

    g.cdef("lnnin", "in,nin,UNKN,IF")
    g.cdef("lnndockin", "dockin,ndockin,UNKN,IF")
    g.cdef("lnout", "out,out,UNKN,IF")
    g.cdef("lndockout", "dockout,dockout,UNKN,IF")

    g.args.append("AREA:nin#CC7016")
    g.args.append("AREA:ndockin#1598C3")
    g.args.append("LINE1:lnnin#EC9D48")
    g.args.append("LINE1:lnndockin#48C4EC")
    g.args.append("AREA:out#CC7016")
    g.args.append("AREA:dockout#24BC14")
    g.args.append("LINE1:lnout#EC9D48")
    g.args.append("LINE1:lndockout#54EC48")
    g.args.append("HRULE:0#FFFFFF")

    g.vdef("totout", "out,TOTAL")
    g.gprint("totout", "Uplink   %1.2lf %s")
    g.vdef("totdockout", "dockout,TOTAL")
    g.gprint("totdockout", "Storj %1.2lf %s")
    g.vdef("avgdockout", "dockout,AVERAGE")
    g.gprint("avgdockout", "(avg %1.2lf %s/s)\\n")

    g.vdef("totin", "in,TOTAL")
    g.gprint("totin", "Downlink %1.2lf %s")
    g.vdef("totdockin", "dockin,TOTAL")
    g.gprint("totdockin", "Storj %1.2lf %s")
    g.vdef("avgdockin", "dockin,AVERAGE")
    g.gprint("avgdockin", "(avg %1.2lf %s/s)\\n")

    return g.compile()
