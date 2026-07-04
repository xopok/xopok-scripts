from rrd_dsl import GraphBuilder


def build_graph(rrd_file):
    g = GraphBuilder(rrd_file)

    ds1 = g.def_ds("ds1", "l1")
    ds2 = g.def_ds("ds2", "l5")
    ds3 = g.def_ds("ds3", "l15")

    g.cdef("bo", "ds1,UN,0,ds1,IF,0,GT,UNKN,INF,IF")
    g.area("bo", "DDDDDD", "")

    g.cdef("bi", "ds1,UN,0,ds1,IF,0,GT,INF,UNKN,IF")
    g.area("bi", "FEFEED", "")

    g.args.append("HRULE:1.0#44B5FF")
    g.area(ds3, "FFEE00", "Last 15 min")

    g.vdef("max1", "ds1,MAXIMUM")
    g.vdef("min1", "ds1,MINIMUM")
    g.vdef("avg1", "ds1,AVERAGE")
    g.args.append("GPRINT:max1:Max %6.2lf")
    g.args.append("GPRINT:min1:Min %6.2lf")
    g.args.append("GPRINT:avg1:Avg %6.2lf\\n")

    g.line(3, ds2, "FFCC00", "Last  5 min")
    g.vdef("max2", "ds2,MAXIMUM")
    g.vdef("min2", "ds2,MINIMUM")
    g.vdef("avg2", "ds2,AVERAGE")
    g.args.append("GPRINT:max2:Max %6.2lf")
    g.args.append("GPRINT:min2:Min %6.2lf")
    g.args.append("GPRINT:avg2:Avg %6.2lf\\n")

    g.line(1, ds1, "FF0000", "Last  1 min")
    g.vdef("max3", "ds3,MAXIMUM")
    g.vdef("min3", "ds3,MINIMUM")
    g.vdef("avg3", "ds3,AVERAGE")
    g.args.append("GPRINT:max3:Max %6.2lf")
    g.args.append("GPRINT:min3:Min %6.2lf")
    g.args.append("GPRINT:avg3:Avg %6.2lf\\n")

    return g.compile()
