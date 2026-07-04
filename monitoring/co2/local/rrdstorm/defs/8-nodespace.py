from rrd_dsl import GraphBuilder


def build_graph(rrd_file):
    g = GraphBuilder(rrd_file)

    free0 = g.def_ds("free0", "free0")
    free1 = g.def_ds("free1", "free1")
    free2 = g.def_ds("free2", "free2")

    g.cdef("nfree0", "free0,-1,*,-1,MAX")
    g.cdef("nfree1", "free1,-1,*,-1,MAX")
    g.cdef("nfree2", "free2,-1,*,-1,MAX")

    g.cdef("lnfree0", "free0,nfree0,UNKN,IF")
    g.cdef("lnfree1", "free1,nfree1,nfree0,+,UNKN,IF")
    g.cdef("lnfree2", "free2,nfree2,nfree1,nfree0,+,+,UNKN,IF")

    g.args.append("AREA:nfree0#24BC14")
    g.area("nfree1", "CC7016", "", stack=True)
    g.area("nfree2", "1598C3", "", stack=True)

    g.vdef("tot0", "nfree0,TOTAL")
    g.line(1, "lnfree0", "54EC48", "node3")
    g.gprint("nfree0", "avg %1.2lf %s", "AVERAGE")
    g.gprint("tot0", "total %1.2lf %s")
    g.gprint("nfree0", "last %1.2lf %s/s\\n", "LAST")

    g.vdef("tot1", "nfree1,TOTAL")
    g.line(1, "lnfree1", "EC9D48", "node1")
    g.gprint("nfree1", "avg %1.2lf %s", "AVERAGE")
    g.gprint("tot1", "total %1.2lf %s")
    g.gprint("nfree1", "last %1.2lf %s/s\\n", "LAST")

    g.vdef("tot2", "nfree2,TOTAL")
    g.line(1, "lnfree2", "48C4EC", "node2")
    g.gprint("nfree2", "avg %1.2lf %s", "AVERAGE")
    g.gprint("tot2", "total %1.2lf %s")
    g.gprint("nfree2", "last %1.2lf %s/s\\n", "LAST")

    g.args.append("HRULE:0#FFFFFF")

    return g.compile()
