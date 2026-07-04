from rrd_dsl import GraphBuilder


def build_graph(rrd_file):
    g = GraphBuilder(rrd_file)

    rf = g.def_ds("rf", "rootfree")
    ru = g.def_ds("ru", "rootused")
    pf = g.def_ds("pf", "placefree")
    pu = g.def_ds("pu", "placeused")
    ps = g.def_ds("ps", "placestorj")

    rfg = g.cdef("rfg", rf / 1048576)
    rug = g.cdef("rug", ru / 1048576)
    pfg = g.cdef("pfg", pf / 1048576)
    pug = g.cdef("pug", pu / 1048576)
    psg = g.cdef("psg", ps / 1048576)
    nrf = g.cdef("nrf", rf * -100)
    nru = g.cdef("nru", ru * -100)
    g.cdef("lnnru", "ru,nru,UNKN,IF")
    g.cdef("lnnrf", "ru,nrf,nru,+,UNKN,IF")

    g.gprint("rug", "/ used %4.0lf", "LAST")
    g.gprint("rfg", "/ free %4.0lf\\n", "LAST")

    g.cdef("lnps", "ps,ps,UNKN,IF")
    g.cdef("lnpu", "pu,pu,UNKN,IF")
    g.cdef("lnpf", "pu,pf,pu,+,UNKN,IF")
    g.cdef("puns", pu - ps)

    g.area(ps, "1598C3", "/place?/storj? used")
    g.gprint("psg", "%4.0lf M", "LAST")
    g.gprint("pug", "/place? used %4.0lf M", "LAST")
    g.gprint("pfg", "/place? free %4.0lf M", "LAST")
    g.line(1, ps, "48C4EC")

    return g.compile()
