import unittest

from rrd_dsl import RPNVar, GraphBuilder


class TestRPNVarInit(unittest.TestCase):
    def test_string_name(self):
        var = RPNVar("ds1")
        self.assertEqual(var.name, "ds1")

    def test_numeric_name(self):
        var = RPNVar(42)
        self.assertEqual(var.name, "42")

    def test_str_returns_name(self):
        var = RPNVar("foo")
        self.assertEqual(str(var), "foo")


class TestRPNVarAdd(unittest.TestCase):
    def test_add_rpnvar(self):
        a = RPNVar("ds1")
        b = RPNVar("ds2")
        result = a + b
        self.assertEqual(str(result), "ds1,ds2,+")

    def test_add_integer(self):
        a = RPNVar("ds1")
        result = a + 10
        self.assertEqual(str(result), "ds1,10,+")

    def test_add_float(self):
        a = RPNVar("ds1")
        result = a + 3.14
        self.assertEqual(str(result), "ds1,3.14,+")

    def test_add_string(self):
        a = RPNVar("ds1")
        result = a + "INF"
        self.assertEqual(str(result), "ds1,INF,+")


class TestRPNVarSub(unittest.TestCase):
    def test_sub_rpnvar(self):
        a = RPNVar("ds1")
        b = RPNVar("ds2")
        result = a - b
        self.assertEqual(str(result), "ds1,ds2,-")

    def test_sub_integer(self):
        a = RPNVar("ds1")
        result = a - 5
        self.assertEqual(str(result), "ds1,5,-")

    def test_sub_zero(self):
        a = RPNVar("ds1")
        result = a - 0
        self.assertEqual(str(result), "ds1,0,-")


class TestRPNVarMul(unittest.TestCase):
    def test_mul_rpnvar(self):
        a = RPNVar("ds1")
        b = RPNVar("ds2")
        result = a * b
        self.assertEqual(str(result), "ds1,ds2,*")

    def test_mul_integer(self):
        a = RPNVar("ds1")
        result = a * 20
        self.assertEqual(str(result), "ds1,20,*")

    def test_mul_float(self):
        a = RPNVar("ds1")
        result = a * 1.5
        self.assertEqual(str(result), "ds1,1.5,*")

    def test_mul_by_one(self):
        a = RPNVar("ds1")
        result = a * 1
        self.assertEqual(str(result), "ds1,1,*")


class TestRPNVarDiv(unittest.TestCase):
    def test_div_rpnvar(self):
        a = RPNVar("ds1")
        b = RPNVar("ds2")
        result = a / b
        self.assertEqual(str(result), "ds1,ds2,/")

    def test_div_integer(self):
        a = RPNVar("ds1")
        result = a / 1000
        self.assertEqual(str(result), "ds1,1000,/")

    def test_div_float(self):
        a = RPNVar("ds1")
        result = a / 2.5
        self.assertEqual(str(result), "ds1,2.5,/")


class TestRPNVarChained(unittest.TestCase):
    def test_add_then_mul(self):
        ds1 = RPNVar("ds1")
        ds2 = RPNVar("ds2")
        result = (ds1 + ds2) * 20
        self.assertEqual(str(result), "ds1,ds2,+,20,*")

    def test_mul_then_add(self):
        ds1 = RPNVar("ds1")
        result = ds1 * 2 + 3
        self.assertEqual(str(result), "ds1,2,*,3,+")

    def test_div_then_sub(self):
        ds1 = RPNVar("ds1")
        result = ds1 / 1000 - 0.5
        self.assertEqual(str(result), "ds1,1000,/,0.5,-")

    def test_complex_expression(self):
        ds1 = RPNVar("ds1")
        ds2 = RPNVar("ds2")
        ds3 = RPNVar("ds3")
        result = (ds1 + ds2 + ds3) / 3
        self.assertEqual(str(result), "ds1,ds2,+,ds3,+,3,/")

    def test_nested_parentheses(self):
        ds1 = RPNVar("ds1")
        ds2 = RPNVar("ds2")
        result = (ds1 * 2 + ds2) / (ds1 + 1)
        self.assertEqual(str(result), "ds1,2,*,ds2,+,ds1,1,+,/")

    def test_fahrenheit_conversion(self):
        t = RPNVar("temp")
        f = t * 1.8 + 32
        self.assertEqual(str(f), "temp,1.8,*,32,+")

    def test_percentage_calculation(self):
        used = RPNVar("used")
        total = RPNVar("total")
        pct = used / total * 100
        self.assertEqual(str(pct), "used,total,/,100,*")


class TestRPNVarImmutability(unittest.TestCase):
    def test_original_unchanged_after_add(self):
        a = RPNVar("ds1")
        _ = a + 10
        self.assertEqual(str(a), "ds1")

    def test_original_unchained_after_chain(self):
        a = RPNVar("ds1")
        b = RPNVar("ds2")
        _ = a + b
        _ = a * 2
        self.assertEqual(str(a), "ds1")
        self.assertEqual(str(b), "ds2")


class TestGraphBuilderInit(unittest.TestCase):
    def test_init_with_rrd_file(self):
        g = GraphBuilder("/var/data.rrd")
        self.assertEqual(g.rrd_file, "/var/data.rrd")

    def test_init_empty_args(self):
        g = GraphBuilder("/var/data.rrd")
        self.assertEqual(g.args, [])


class TestGraphBuilderDefDs(unittest.TestCase):
    def test_basic_def(self):
        g = GraphBuilder("/var/data.rrd")
        var = g.def_ds("v", "value")
        self.assertIn("DEF:v=/var/data.rrd:value:AVERAGE", g.args)
        self.assertEqual(str(var), "v")

    def test_def_with_cf_maximum(self):
        g = GraphBuilder("/var/data.rrd")
        g.def_ds("v", "value", cf="MAXIMUM")
        self.assertIn("DEF:v=/var/data.rrd:value:MAXIMUM", g.args)

    def test_multiple_defs(self):
        g = GraphBuilder("/var/data.rrd")
        a = g.def_ds("a", "field1")
        b = g.def_ds("b", "field2")
        self.assertEqual(len(g.args), 2)
        self.assertEqual(str(a), "a")
        self.assertEqual(str(b), "b")


class TestGraphBuilderCdef(unittest.TestCase):
    def test_cdef_with_rpnvar(self):
        g = GraphBuilder("/var/data.rrd")
        ds = g.def_ds("ds1", "l1")
        c = g.cdef("scaled", ds * 1000)
        self.assertIn("CDEF:scaled=ds1,1000,*", g.args)
        self.assertEqual(str(c), "scaled")

    def test_cdef_with_raw_string(self):
        g = GraphBuilder("/var/data.rrd")
        g.cdef("bo", "ds1,UN,0,ds1,IF")
        self.assertIn("CDEF:bo=ds1,UN,0,ds1,IF", g.args)

    def test_cdef_chained_expression(self):
        g = GraphBuilder("/var/data.rrd")
        a = g.def_ds("a", "f1")
        b = g.def_ds("b", "f2")
        c = g.cdef("avg", (a + b) / 2)
        self.assertIn("CDEF:avg=a,b,+,2,/", g.args)


class TestGraphBuilderVdef(unittest.TestCase):
    def test_vdef_appends(self):
        g = GraphBuilder("/var/data.rrd")
        g.vdef("max1", "ds1,MAXIMUM")
        self.assertIn("VDEF:max1=ds1,MAXIMUM", g.args)


class TestGraphBuilderArea(unittest.TestCase):
    def test_area_basic(self):
        g = GraphBuilder("/var/data.rrd")
        g.area("ds1", "FF0000", "Legend")
        self.assertIn("AREA:ds1#FF0000:Legend", g.args)

    def test_area_no_legend(self):
        g = GraphBuilder("/var/data.rrd")
        g.area("ds1", "FF0000")
        self.assertIn("AREA:ds1#FF0000:", g.args)

    def test_area_stacked(self):
        g = GraphBuilder("/var/data.rrd")
        g.area("ds1", "FF0000", "Stacked", stack=True)
        self.assertIn("AREA:ds1#FF0000:Stacked:STACK", g.args)

    def test_area_with_rpnvar(self):
        g = GraphBuilder("/var/data.rrd")
        ds = g.def_ds("ds1", "f1")
        expr = ds * 100
        g.area(expr, "00FF00", "Scaled")
        self.assertIn("AREA:ds1,100,*#00FF00:Scaled", g.args)


class TestGraphBuilderLine(unittest.TestCase):
    def test_line3(self):
        g = GraphBuilder("/var/data.rrd")
        g.line(3, "ds1", "FF0000", "Legend")
        self.assertIn("LINE3:ds1#FF0000:Legend", g.args)

    def test_line1(self):
        g = GraphBuilder("/var/data.rrd")
        g.line(1, "ds1", "00FF00")
        self.assertIn("LINE1:ds1#00FF00:", g.args)

    def test_line_with_extra(self):
        g = GraphBuilder("/var/data.rrd")
        g.line(2, "ds1", "0000FF", "Val", ":STACK")
        self.assertIn("LINE2:ds1#0000FF:Val:STACK", g.args)


class TestGraphBuilderGprint(unittest.TestCase):
    def test_gprint_with_cf(self):
        g = GraphBuilder("/var/data.rrd")
        g.gprint("max1", "Max %6.2lf", "MAX")
        self.assertIn("GPRINT:max1:MAX:Max %6.2lf", g.args)

    def test_gprint_without_cf(self):
        g = GraphBuilder("/var/data.rrd")
        g.gprint("max1", "Max %6.2lf")
        self.assertIn("GPRINT:max1:Max %6.2lf", g.args)


class TestGraphBuilderHrule(unittest.TestCase):
    def test_hrule_basic(self):
        g = GraphBuilder("/var/data.rrd")
        g.hrule(100, "FF0000", "Limit")
        self.assertIn("HRULE:100#FF0000:Limit", g.args)

    def test_hrule_no_legend(self):
        g = GraphBuilder("/var/data.rrd")
        g.hrule(50, "0000FF")
        self.assertIn("HRULE:50#0000FF:", g.args)


class TestGraphBuilderCompile(unittest.TestCase):
    def test_compile_returns_args(self):
        g = GraphBuilder("/var/data.rrd")
        g.def_ds("v", "value")
        g.def_ds("v2", "value2")
        result = g.compile()
        self.assertEqual(result, g.args)
        self.assertEqual(len(result), 2)

    def test_compile_full_graph(self):
        g = GraphBuilder("/var/data.rrd")
        ds1 = g.def_ds("ds1", "l1")
        ds2 = g.def_ds("ds2", "l5")
        g.cdef("scaled", ds1 * 1000)
        g.vdef("max1", "ds1,MAXIMUM")
        g.area(ds1, "FF0000", "Load1")
        g.line(2, ds2, "00FF00", "Load5")
        g.gprint("max1", "Max %6.2lf", "MAX")
        g.hrule(100, "0000FF", "Threshold")

        result = g.compile()
        expected = [
            "DEF:ds1=/var/data.rrd:l1:AVERAGE",
            "DEF:ds2=/var/data.rrd:l5:AVERAGE",
            "CDEF:scaled=ds1,1000,*",
            "VDEF:max1=ds1,MAXIMUM",
            "AREA:ds1#FF0000:Load1",
            "LINE2:ds2#00FF00:Load5",
            "GPRINT:max1:MAX:Max %6.2lf",
            "HRULE:100#0000FF:Threshold",
        ]
        self.assertEqual(result, expected)


class TestGraphBuilderRpnvarIntegration(unittest.TestCase):
    def test_def_returns_usable_rpnvar(self):
        g = GraphBuilder("/var/data.rrd")
        ds = g.def_ds("ds1", "f1")
        expr = ds * 1.8 + 32
        g.cdef("fahr", expr)
        self.assertIn("CDEF:fahr=ds1,1.8,*,32,+", g.args)

    def test_cdef_returns_usable_rpnvar(self):
        g = GraphBuilder("/var/data.rrd")
        ds = g.def_ds("ds1", "f1")
        scaled = g.cdef("scaled", ds * 1000)
        g.area(scaled, "FF0000", "Area")
        self.assertIn("AREA:scaled#FF0000:Area", g.args)

    def test_complex_pipeline(self):
        g = GraphBuilder("/var/data.rrd")
        used = g.def_ds("used", "used")
        total = g.def_ds("total", "total")
        pct = g.cdef("pct", used / total * 100)
        avg = g.cdef("avg", pct / 100)
        g.area(pct, "00FF00", "Pct")
        g.line(1, avg, "FF0000", "Avg")

        result = g.compile()
        self.assertIn("CDEF:pct=used,total,/,100,*", result)
        self.assertIn("CDEF:avg=pct,100,/", result)


if __name__ == "__main__":
    unittest.main()
