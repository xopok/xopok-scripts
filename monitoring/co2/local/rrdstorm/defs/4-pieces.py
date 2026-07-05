from rrd_dsl import GraphBuilder


def build_graph(rrd_file):
    g = GraphBuilder(rrd_file)

    ds1 = g.def_ds("ds1", "upload")
    ds2 = g.def_ds("ds2", "uploaded")
    ds3 = g.def_ds("ds3", "uploadfailed")
    ds4 = g.def_ds("ds4", "download")
    ds5 = g.def_ds("ds5", "downloaded")
    ds6 = g.def_ds("ds6", "downloadfailed")
    ds7 = g.def_ds("ds7", "audit")
    ds8 = g.def_ds("ds8", "audited")
    ds9 = g.def_ds("ds9", "auditfailed")
    dsd = g.def_ds("dsd", "deleted")

    g.cdef("ln1", "ds2,ds2,UNKN,IF")
    g.cdef("ln2", "ds3,ds2,ds3,+,UNKN,IF")

    g.area("ds2", "1598C3")
    g.area(ds3, "CC7016", "", stack=True)
    g.args.append("LINE1:ln2#EC9D48")
    g.args.append("LINE1:ln1#48C4EC")

    g.cdef("d", ds5)
    g.cdef("df", ds6)
    g.cdef("af", ds9)
    g.cdef("nd", "d,-1,*")
    g.cdef("ndf", "df,-1,*")
    g.cdef("naf", "af,-1,*")

    g.cdef("lnd", "d,nd,UNKN,IF")
    g.cdef("lndf", "df,ndf,nd,+,UNKN,IF")
    g.cdef("lnaf", "af,naf,ndf,nd,+,+,UNKN,IF")

    g.area("nd", "24BC14")
    g.area("ndf", "CC7016", "", stack=True)
    g.area("naf", "CC3118", "", stack=True)
    g.args.append("LINE1:lndf#EC9D48")
    g.args.append("LINE1:lnd#54EC48")
    g.args.append("LINE1:lnaf#EA644A")

    g.cdef("nds8", (ds8 + ds9) * -1)
    g.args.append("LINE1:nds8#FFFFFF")
    g.args.append("LINE1:dsd#FFFFFF")
    g.hrule(0, "FFFFFF")

    g.vdef("totuploaded", "ds2,TOTAL")
    g.gprint("totuploaded", "Uploaded %1.1lf %s")
    g.vdef("totupload", "ds1,TOTAL")
    g.gprint("totupload", "/  %1.1lf %s;")
    g.vdef("totdownloaded", "ds5,TOTAL")
    g.gprint("totdownloaded", "Downloaded %1.1lf %s")
    g.vdef("totdownload", "ds4,TOTAL")
    g.gprint("totdownload", "/  %1.1lf %s attempts\\n")

    return g.compile()
