from rrd_dsl import GraphBuilder


def build_graph(rrd_file):
    g = GraphBuilder(rrd_file)

    tcpu = g.def_ds("tcpu", "tcpu")
    thdd = g.def_ds("thdd", "thdd")
    tssd = g.def_ds("tssd", "tssd")

    g.line(1, tcpu, "FF0000", "t CPU")
    g.gprint("tcpu", " %.2lf\\n", "LAST")

    g.line(1, thdd, "00FF00", "t HDD1")
    g.gprint("thdd", " %.0lf\\n", "LAST")

    g.line(1, tssd, "00ACCF", "t HDD2")
    g.gprint("tssd", " %.0lf\\n", "LAST")

    return g.compile()
