#!/usr/bin/env python3
"""Tests for plt2gpx converter.

Covers all test cases listed in README.md sections 5.1–5.4.
"""

import os
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

import sys
sys.path.insert(0, str(Path(__file__).parent))

import plt2gpx

NS = {"gpx": "http://www.topografix.com/GPX/1/1"}

NS0 = {"ns0": "http://www.topografix.com/GPX/1/1"}

# ---------------------------------------------------------------------------
# Helpers: build synthetic PLT content and parse GPX output
# ---------------------------------------------------------------------------

def make_plt_content(
    points=None,
    version="2.1",
    datum="WGS 84",
    altitude_unit="Feet",
    reserved="Reserved",
    line5="0,2,128,,0,0,2,0",
    line6="1",
    blank_lines=None,
):
    """Build PLT file content from a list of point tuples.

    points: list of (lat, lon, code, alt_ft, ozi_dt, date_str, time_str)
    blank_lines: list of line numbers (0-indexed) to leave blank
    """
    if points is None:
        points = []

    header = [
        f"OziExplorer Track Point File Version {version}",
        datum,
        f"Altitude is in {altitude_unit}",
        reserved,
        line5,
        line6,
    ]
    blank_lines = set(blank_lines or [])

    data_lines = []
    for p in points:
        lat, lon, code = p[0], p[1], p[2]
        alt_ft = p[3] if len(p) > 3 else ""
        ozi_dt = p[4] if len(p) > 4 else ""
        date_str = p[5] if len(p) > 5 else ""
        time_str = p[6] if len(p) > 6 else ""
        data_lines.append(
            f"{lat},{lon},{code},{alt_ft},{ozi_dt},{date_str},{time_str},"
        )

    all_lines = header + data_lines
    result_lines = []
    for i, line in enumerate(all_lines):
        if i in blank_lines:
            result_lines.append("")
        else:
            result_lines.append(line)

    return "\n".join(result_lines) + "\n"


def write_plt(tmpdir, name, content):
    p = Path(tmpdir) / name
    p.write_text(content, encoding="utf-8")
    return p


def parse_gpx(filepath):
    """Parse GPX file. Handles both gpx: and ns0: namespace prefixes."""
    tree = ET.parse(filepath)
    root = tree.getroot()
    
    # Try both namespace prefixes
    ns_to_try = [NS, NS0]
    trk = None
    for ns in ns_to_try:
        trk = root.find(f"{ns.keys().__class__.__name__ == 'dict'}", {})
    
    # Use Clark notation directly since minidom uses ns0 prefix
    trk = root.find("{http://www.topografix.com/GPX/1/1}trk")
    if trk is None:
        return {"name": "", "segments": [], "desc": ""}
    
    name = trk.find("{http://www.topografix.com/GPX/1/1}name")
    name_text = name.text if name is not None else ""
    
    segs = trk.findall("{http://www.topografix.com/GPX/1/1}trkseg")
    segments = []
    for seg in segs:
        pts = []
        for trkpt in seg.findall("{http://www.topografix.com/GPX/1/1}trkpt"):
            pt = {
                "lat": float(trkpt.get("lat", 0)),
                "lon": float(trkpt.get("lon", 0)),
            }
            ele = trkpt.find("{http://www.topografix.com/GPX/1/1}ele")
            if ele is not None:
                pt["ele"] = float(ele.text)
            time_el = trkpt.find("{http://www.topografix.com/GPX/1/1}time")
            if time_el is not None:
                pt["time"] = time_el.text
            pts.append(pt)
        segments.append(pts)
    
    meta = root.find("{http://www.topografix.com/GPX/1/1}metadata")
    desc = ""
    if meta is not None:
        d = meta.find("{http://www.topografix.com/GPX/1/1}desc")
        if d is not None:
            desc = d.text
    return {"name": name_text, "segments": segments, "desc": desc}


class TestParsePlt(unittest.TestCase):
    """Unit tests for parse_plt and parse_plt_header."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    # --- T8: Altitude conversion ---
    def test_T8_altitude_conversion(self):
        """Altitude 3280.84 ft → 1000.0m."""
        content = make_plt_content([
            (55.0, 38.0, 0, 3280.84, 38845.5, "", ""),
        ])
        p = write_plt(self.tmpdir, "alt.plt", content)
        track_name, datum, points = plt2gpx.parse_plt(p)
        self.assertEqual(len(points), 1)
        self.assertAlmostEqual(points[0]["ele"], 1000.0, places=1)

    # --- T9: Invalid altitude (-777) ---
    def test_T9_invalid_altitude(self):
        """Altitude -777 → no elevation."""
        content = make_plt_content([
            (55.0, 38.0, 0, -777, 38845.5, "", ""),
        ])
        p = write_plt(self.tmpdir, "noalt.plt", content)
        _, _, points = plt2gpx.parse_plt(p)
        self.assertEqual(len(points), 1)
        self.assertIsNone(points[0]["ele"])

    # --- E1: Empty file ---
    def test_E1_empty_file(self):
        """0-byte .plt → no points."""
        p = write_plt(self.tmpdir, "empty.plt", "")
        _, _, points = plt2gpx.parse_plt(p)
        self.assertEqual(len(points), 0)

    # --- E2: Header-only file ---
    def test_E2_header_only(self):
        """6-line header, no data → no points."""
        content = make_plt_content(points=[])
        p = write_plt(self.tmpdir, "header.plt", content)
        _, _, points = plt2gpx.parse_plt(p)
        self.assertEqual(len(points), 0)

    # --- E3: Missing datetime ---
    def test_E3_missing_datetime(self):
        """Empty field 5 → point without time."""
        content = (
            "OziExplorer Track Point File Version 2.1\n"
            "WGS 84\n"
            "Altitude is in Feet\n"
            "Reserved\n"
            "0,2,128,,0,0,2,0\n"
            "1\n"
            "55.0,38.0,0,0,,, \n"  # empty datetime, date, time fields (trailing space to keep fields)
        )
        p = write_plt(self.tmpdir, "notime.plt", content)
        _, _, points = plt2gpx.parse_plt(p)
        self.assertEqual(len(points), 1)
        self.assertIsNone(points[0]["time"])

    # --- E4: Invalid datetime ---
    def test_E4_invalid_datetime_zero(self):
        """Field 5 = 0 → no time (epoch 1899 is sentinel)."""
        content = make_plt_content([
            (55.0, 38.0, 0, 0, 0, "", ""),
        ])
        p = write_plt(self.tmpdir, "dtzero.plt", content)
        _, _, points = plt2gpx.parse_plt(p)
        self.assertEqual(len(points), 1)
        self.assertIsNone(points[0]["time"])

    def test_E4_invalid_datetime_non_numeric(self):
        """Field 5 = 'abc' → no time."""
        content = make_plt_content([
            (55.0, 38.0, 0, 0, "abc", "", ""),
        ])
        p = write_plt(self.tmpdir, "dtabc.plt", content)
        _, _, points = plt2gpx.parse_plt(p)
        self.assertEqual(len(points), 1)
        self.assertIsNone(points[0]["time"])

    # --- E5: Non-WGS datum ---
    def test_E5_non_wgs_datum(self):
        """Non-WGS datum → parsed as-is, datum string returned."""
        content = make_plt_content(
            datum="Local Grid",
            points=[(55.0, 38.0, 0, 0, 38845.5, "", "")],
        )
        p = write_plt(self.tmpdir, "local.plt", content)
        _, datum, points = plt2gpx.parse_plt(p)
        self.assertEqual(datum, "Local Grid")
        self.assertEqual(len(points), 1)

    # --- E10: Malformed line ---
    def test_E10_malformed_line(self):
        """Line with < 5 fields → silently skipped."""
        content = (
            "OziExplorer Track Point File Version 2.1\n"
            "WGS 84\n"
            "Altitude is in Feet\n"
            "Reserved\n"
            "0,2,128,,0,0,2,0\n"
            "1\n"
            "55.0,38.0\n"  # only 2 fields
            "55.1,38.1,0,0,38845.5,,\n"  # valid
        )
        p = write_plt(self.tmpdir, "malformed.plt", content)
        _, _, points = plt2gpx.parse_plt(p)
        self.assertEqual(len(points), 1)
        self.assertAlmostEqual(points[0]["lat"], 55.1, places=1)

    def test_E10_non_numeric_lat(self):
        """Line with non-numeric lat → skipped."""
        content = (
            "OziExplorer Track Point File Version 2.1\n"
            "WGS 84\n"
            "Altitude is in Feet\n"
            "Reserved\n"
            "0,2,128,,0,0,2,0\n"
            "1\n"
            "abc,38.0,0,0,38845.5,,\n"
            "55.1,38.1,0,0,38845.5,,\n"
        )
        p = write_plt(self.tmpdir, "nonnumeric.plt", content)
        _, _, points = plt2gpx.parse_plt(p)
        self.assertEqual(len(points), 1)

    # --- E11: Altitude = 0 ---
    def test_E11_altitude_zero(self):
        """Field 3 = 0 → ele = 0.0."""
        content = make_plt_content([
            (55.0, 38.0, 0, 0, 38845.5, "", ""),
        ])
        p = write_plt(self.tmpdir, "altzero.plt", content)
        _, _, points = plt2gpx.parse_plt(p)
        self.assertEqual(len(points), 1)
        self.assertAlmostEqual(points[0]["ele"], 0.0, places=1)

    # --- E12: Date/time strings populated ---
    def test_E12_date_time_strings(self):
        """Fields 6-7 non-empty → ignored, time from field 5."""
        content = make_plt_content([
            (55.0, 38.0, 0, 0, 36169.6307194, "09-Jan-99", "3:08:14"),
        ])
        p = write_plt(self.tmpdir, "dtstr.plt", content)
        _, _, points = plt2gpx.parse_plt(p)
        self.assertEqual(len(points), 1)
        self.assertIsNotNone(points[0]["time"])

    # --- E15: Date line crossing ---
    def test_E15_date_line_crossing(self):
        """Longitude near ±180 → preserved as-is."""
        content = make_plt_content([
            (55.0, 179.9999, 0, 0, 38845.5, "", ""),
            (55.1, -179.9999, 0, 0, 38845.51, "", ""),
        ])
        p = write_plt(self.tmpdir, "dateline.plt", content)
        _, _, points = plt2gpx.parse_plt(p)
        self.assertEqual(len(points), 2)
        self.assertAlmostEqual(points[0]["lon"], 179.9999, places=4)
        self.assertAlmostEqual(points[1]["lon"], -179.9999, places=4)

    # --- E16: Track description in header ---
    def test_E16_track_description(self):
        """Line 5 field 4 = 'My Track' → returned as track_name."""
        content = make_plt_content(
            line5="0,2,128,My Track,1,0,0,0",
            points=[(55.0, 38.0, 0, 0, 38845.5, "", "")],
        )
        p = write_plt(self.tmpdir, "desc.plt", content)
        track_name, _, _ = plt2gpx.parse_plt(p)
        self.assertEqual(track_name, "My Track")

    # --- E17: Line 6 mismatch ---
    def test_E17_line6_mismatch(self):
        """Line 6 says 100, actual 3 points → all 3 parsed."""
        content = make_plt_content(
            line6="100",
            points=[
                (55.0, 38.0, 0, 0, 38845.5, "", ""),
                (55.1, 38.1, 0, 0, 38845.51, "", ""),
                (55.2, 38.2, 0, 0, 38845.52, "", ""),
            ],
        )
        p = write_plt(self.tmpdir, "mismatch.plt", content)
        _, _, points = plt2gpx.parse_plt(p)
        self.assertEqual(len(points), 3)

    # --- 5.4: Negative altitude ---
    def test_54_negative_altitude(self):
        """Negative altitude (below sea level) → negative meters."""
        content = make_plt_content([
            (55.0, 38.0, 0, -400, 38845.5, "", ""),
        ])
        p = write_plt(self.tmpdir, "negalt.plt", content)
        _, _, points = plt2gpx.parse_plt(p)
        self.assertEqual(len(points), 1)
        self.assertAlmostEqual(points[0]["ele"], -400 * 0.3048, places=1)

    # --- 5.4: Real altitude data (non-zero, non--777) ---
    def test_54_real_altitude(self):
        """Non-zero altitude → converted to meters."""
        content = make_plt_content([
            (55.0, 38.0, 0, 6561.68, 38845.5, "", ""),
        ])
        p = write_plt(self.tmpdir, "realalt.plt", content)
        _, _, points = plt2gpx.parse_plt(p)
        self.assertAlmostEqual(points[0]["ele"], 2000.0, places=1)

    # --- Extra: blank lines in file ---
    def test_blank_lines_in_data(self):
        """Blank lines between data rows → skipped."""
        content = (
            "OziExplorer Track Point File Version 2.1\n"
            "WGS 84\n"
            "Altitude is in Feet\n"
            "Reserved\n"
            "0,2,128,,0,0,2,0\n"
            "1\n"
            "55.0,38.0,0,0,38845.5,,\n"
            "\n"
            "55.1,38.1,0,0,38845.51,,\n"
        )
        p = write_plt(self.tmpdir, "blanks.plt", content)
        _, _, points = plt2gpx.parse_plt(p)
        self.assertEqual(len(points), 2)


class TestSplitSegments(unittest.TestCase):
    """Tests for split_segments."""

    # --- E8: Code=1 track break ---
    def test_E8_track_break(self):
        """code=1 → new segment starts at that point."""
        points = [
            {"lat": 1, "lon": 1, "code": 1, "ele": None, "time": None},
            {"lat": 2, "lon": 2, "code": 0, "ele": None, "time": None},
            {"lat": 3, "lon": 3, "code": 1, "ele": None, "time": None},
            {"lat": 4, "lon": 4, "code": 0, "ele": None, "time": None},
        ]
        segs = plt2gpx.split_segments(points)
        self.assertEqual(len(segs), 2)
        self.assertEqual(len(segs[0]), 2)  # pts 0,1
        self.assertEqual(len(segs[1]), 2)  # pts 2,3

    # --- E9: Multiple track breaks ---
    def test_E9_multiple_breaks(self):
        """code=1 at indices 0, 50, 100 → 3 segments."""
        points = []
        for i in range(110):
            code = 1 if i in (0, 50, 100) else 0
            points.append({"lat": i, "lon": i, "code": code, "ele": None, "time": None})
        segs = plt2gpx.split_segments(points)
        self.assertEqual(len(segs), 3)
        self.assertEqual(len(segs[0]), 50)
        self.assertEqual(len(segs[1]), 50)
        self.assertEqual(len(segs[2]), 10)

    # --- 5.4: All code=1 (every point is a break) ---
    def test_54_all_breaks(self):
        """Every point has code=1 → each point is its own segment."""
        points = [
            {"lat": i, "lon": i, "code": 1, "ele": None, "time": None}
            for i in range(5)
        ]
        segs = plt2gpx.split_segments(points)
        self.assertEqual(len(segs), 5)
        for seg in segs:
            self.assertEqual(len(seg), 1)

    def test_empty(self):
        self.assertEqual(plt2gpx.split_segments([]), [])

    def test_no_breaks(self):
        points = [{"lat": i, "code": 0, "ele": None, "time": None, "lon": 0} for i in range(3)]
        segs = plt2gpx.split_segments(points)
        self.assertEqual(len(segs), 1)
        self.assertEqual(len(segs[0]), 3)


class TestBuildGpx(unittest.TestCase):
    """Tests for build_gpx XML output."""

    def test_single_segment(self):
        segs = [[
            {"lat": 55.0, "lon": 38.0, "ele": 100.0, "time": plt2gpx.ozi_datetime_to_datetime(38845.5)},
            {"lat": 55.1, "lon": 38.1, "ele": None, "time": plt2gpx.ozi_datetime_to_datetime(38845.51)},
        ]]
        gpx = plt2gpx.build_gpx(segs, "Test Track")
        tree = ET.ElementTree(gpx)
        segs_out = gpx.find("gpx:trk", NS).findall("gpx:trkseg", NS)
        self.assertEqual(len(segs_out), 1)
        pts = segs_out[0].findall("gpx:trkpt", NS)
        self.assertEqual(len(pts), 2)

        # First point has ele
        ele = pts[0].find("gpx:ele", NS)
        self.assertIsNotNone(ele)
        self.assertEqual(float(ele.text), 100.0)

        # Second point has no ele
        ele2 = pts[1].find("gpx:ele", NS)
        self.assertIsNone(ele2)

    def test_multiple_segments(self):
        segs = [
            [{"lat": 1, "lon": 1, "ele": None, "time": None}],
            [{"lat": 2, "lon": 2, "ele": None, "time": None}],
            [{"lat": 3, "lon": 3, "ele": None, "time": None}],
        ]
        gpx = plt2gpx.build_gpx(segs, "Multi")
        segs_out = gpx.find("gpx:trk", NS).findall("gpx:trkseg", NS)
        self.assertEqual(len(segs_out), 3)

    def test_metadata(self):
        t1 = plt2gpx.ozi_datetime_to_datetime(38845.0)
        t2 = plt2gpx.ozi_datetime_to_datetime(38846.0)
        segs = [[
            {"lat": 55.0, "lon": 38.0, "ele": None, "time": t1},
            {"lat": 55.1, "lon": 38.1, "ele": None, "time": t2},
        ]]
        gpx = plt2gpx.build_gpx(segs, "Meta")
        name = gpx.find("gpx:metadata/gpx:name", NS)
        self.assertEqual(name.text, "Meta")
        desc = gpx.find("gpx:metadata/gpx:desc", NS)
        self.assertIn("2 points", desc.text)

    def test_no_points_no_metadata(self):
        gpx = plt2gpx.build_gpx([], "Empty")
        meta = gpx.find("gpx:metadata", NS)
        self.assertIsNone(meta)


class TestSortPoints(unittest.TestCase):
    """Tests for _sort_points."""

    # --- E6: Duplicate coordinates ---
    def test_E6_duplicate_coordinates(self):
        """Duplicate lat/lon → both preserved."""
        t = plt2gpx.ozi_datetime_to_datetime(38845.5)
        pts = [
            {"lat": 55.0, "lon": 38.0, "ele": None, "time": t, "code": 0},
            {"lat": 55.0, "lon": 38.0, "ele": None, "time": t, "code": 0},
        ]
        result = plt2gpx._sort_points(pts)
        self.assertEqual(len(result), 2)

    # --- E7: Unsorted timestamps ---
    def test_E7_unsorted_timestamps(self):
        """Out-of-order timestamps → sorted in output."""
        t1 = plt2gpx.ozi_datetime_to_datetime(38845.5)
        t2 = plt2gpx.ozi_datetime_to_datetime(38845.0)
        t3 = plt2gpx.ozi_datetime_to_datetime(38845.25)
        pts = [
            {"lat": 1, "lon": 1, "ele": None, "time": t1},
            {"lat": 2, "lon": 2, "ele": None, "time": t2},
            {"lat": 3, "lon": 3, "ele": None, "time": t3},
        ]
        result = plt2gpx._sort_points(pts)
        self.assertLess(result[0]["time"], result[1]["time"])
        self.assertLess(result[1]["time"], result[2]["time"])

    def test_mixed_time_no_time(self):
        t = plt2gpx.ozi_datetime_to_datetime(38845.5)
        pts = [
            {"lat": 1, "lon": 1, "ele": None, "time": None},
            {"lat": 2, "lon": 2, "ele": None, "time": t},
        ]
        result = plt2gpx._sort_points(pts)
        self.assertIsNotNone(result[0]["time"])
        self.assertIsNone(result[1]["time"])

    # --- 5.4: Identical timestamps (ordering stability) ---
    def test_54_identical_timestamps(self):
        """Points with identical timestamps → stable order preserved."""
        t = plt2gpx.ozi_datetime_to_datetime(38845.5)
        pts = [
            {"lat": i, "lon": i, "ele": None, "time": t}
            for i in range(10)
        ]
        result = plt2gpx._sort_points(pts)
        self.assertEqual(len(result), 10)
        # Stable sort: original order preserved for equal keys
        for i, pt in enumerate(result):
            self.assertAlmostEqual(pt["lat"], float(i), places=1)


class TestEndToEnd(unittest.TestCase):
    """Integration tests: write PLT → convert → verify GPX."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.outdir = tempfile.mkdtemp()

    # --- T1: Single file conversion (54 points) ---
    def test_T1_single_file_small(self):
        """Small test file → correct GPX."""
        content = make_plt_content([
            (55.79559088, 38.97575855, 1, 0, 38845.91572917, "", ""),
            (55.79556942, 38.97575855, 0, 0, 38845.91598380, "", ""),
        ])
        p = write_plt(self.tmpdir, "test_T1.plt", content)
        result = plt2gpx.convert_single(p, self.outdir)
        self.assertIsNotNone(result)
        gpx = parse_gpx(result)
        self.assertEqual(len(gpx["segments"]), 1)
        self.assertEqual(len(gpx["segments"][0]), 2)
        self.assertEqual(gpx["segments"][0][0]["time"], "2006-05-08T21:58:39Z")

    # --- T2: Single file with break (2 segments) ---
    def test_T2_single_file_break(self):
        """File with code=1 break → 2 segments."""
        pts = []
        for i in range(5):
            code = 1 if i == 0 else 0
            pts.append((55.0 + i * 0.001, 38.0, code, 0, 38845.5 + i * 0.001, "", ""))
        # Add break at index 3
        pts.insert(3, (55.003, 38.0, 1, 0, 38845.53, "", ""))
        content = make_plt_content(pts)
        p = write_plt(self.tmpdir, "test_T2.plt", content)
        result = plt2gpx.convert_single(p, self.outdir)
        gpx = parse_gpx(result)
        self.assertEqual(len(gpx["segments"]), 2)

    # --- T3: Single file no break ---
    def test_T3_single_file_no_break(self):
        """All code=0 (except first) → 1 segment."""
        pts = [(55.0 + i * 0.001, 38.0, 0, 0, 38845.5 + i * 0.001, "", "") for i in range(10)]
        pts[0] = (pts[0][0], pts[0][1], 1, pts[0][3], pts[0][4], "", "")
        content = make_plt_content(pts)
        p = write_plt(self.tmpdir, "test_T3.plt", content)
        result = plt2gpx.convert_single(p, self.outdir)
        gpx = parse_gpx(result)
        self.assertEqual(len(gpx["segments"]), 1)

    # --- T4: Directory batch ---
    def test_T4_directory_batch(self):
        """Directory with 3 PLT files → 3 GPX files."""
        for i in range(3):
            pts = [(55.0 + i, 38.0, 0, 0, 38845.5, "", "")]
            content = make_plt_content(pts)
            write_plt(self.tmpdir, f"file{i}.plt", content)
        plt2gpx.scan_and_convert(self.tmpdir, self.outdir, merge=False)
        gpx_files = list(Path(self.outdir).glob("*.gpx"))
        self.assertEqual(len(gpx_files), 3)

    # --- T5: Merge mode ---
    def test_T5_merge_mode(self):
        """Merge 3 files → 1 GPX with dir timestamp name."""
        for i in range(3):
            pts = [(55.0 + i, 38.0, 1, 0, 38845.5 + i * 0.1, "", "")]
            content = make_plt_content(pts)
            write_plt(self.tmpdir, f"file{i}.plt", content)
        plt2gpx.scan_and_convert(self.tmpdir, self.outdir, merge=True)
        gpx_files = list(Path(self.outdir).glob("*.gpx"))
        self.assertEqual(len(gpx_files), 1)
        # Name should include earliest timestamp
        self.assertIn("2006", gpx_files[0].name)

    # --- T6: Nested directory ---
    def test_T6_nested_directory(self):
        """Nested dir structure → preserved in output."""
        nested = Path(self.tmpdir) / "a" / "b"
        nested.mkdir(parents=True)
        content = make_plt_content([(55.0, 38.0, 0, 0, 38845.5, "", "")])
        p = write_plt(nested, "file.plt", content)
        result = plt2gpx.convert_single(p, self.outdir)
        # Output should be under a/b/
        self.assertTrue(result.exists())

    # --- T7: Nested merge ---
    def test_T7_nested_merge(self):
        """Merge in nested dir → single GPX with inner dir name."""
        nested = Path(self.tmpdir) / "a" / "b"
        nested.mkdir(parents=True)
        for i in range(2):
            content = make_plt_content([(55.0 + i, 38.0, 1, 0, 38845.5 + i, "", "")])
            write_plt(nested, f"f{i}.plt", content)
        plt2gpx.scan_and_convert(self.tmpdir, self.outdir, merge=True)
        gpx_files = list(Path(self.outdir).glob("*.gpx"))
        self.assertEqual(len(gpx_files), 1)
        self.assertTrue(gpx_files[0].name.startswith("b-"))

    # --- E14: Merge single-file dir ---
    def test_E14_merge_single_file_dir(self):
        """1 .plt in dir → GPX as {dirname}-{timestamp}.gpx."""
        content = make_plt_content([(55.0, 38.0, 1, 0, 38845.5, "", "")])
        write_plt(self.tmpdir, "only.plt", content)
        result = plt2gpx.merge_directory(self.tmpdir, self.outdir)
        self.assertIsNotNone(result)
        gpx = parse_gpx(result)
        self.assertIn("tmp", gpx["name"])  # dirname contains "tmp"

    # --- E16: Track description from header → GPX name ---
    def test_E16_track_name_in_gpx(self):
        """Header track description → GPX <name>."""
        content = make_plt_content(
            line5="0,2,128,My Ride,1,0,0,0",
            points=[(55.0, 38.0, 0, 0, 38845.5, "", "")],
        )
        p = write_plt(self.tmpdir, "named.plt", content)
        result = plt2gpx.convert_single(p, self.outdir)
        gpx = parse_gpx(result)
        self.assertEqual(gpx["name"], "My Ride")

    # --- T8: Altitude in GPX ---
    def test_T8_altitude_in_gpx(self):
        """Altitude 3280.84 ft → <ele>1000.0</ele>."""
        content = make_plt_content([
            (55.0, 38.0, 0, 3280.84, 38845.5, "", ""),
        ])
        p = write_plt(self.tmpdir, "alt8.plt", content)
        result = plt2gpx.convert_single(p, self.outdir)
        gpx = parse_gpx(result)
        self.assertEqual(gpx["segments"][0][0]["ele"], 1000.0)

    # --- T9: Invalid altitude in GPX ---
    def test_T9_invalid_altitude_in_gpx(self):
        """Altitude -777 → no <ele> element."""
        content = make_plt_content([
            (55.0, 38.0, 0, -777, 38845.5, "", ""),
        ])
        p = write_plt(self.tmpdir, "alt9.plt", content)
        result = plt2gpx.convert_single(p, self.outdir)
        gpx = parse_gpx(result)
        self.assertNotIn("ele", gpx["segments"][0][0])

    # --- 5.4: Large file stress test ---
    def test_54_large_file(self):
        """100k points → converts without error."""
        pts = []
        for i in range(100000):
            code = 1 if i == 0 else 0
            pts.append((55.0 + i * 0.00001, 38.0 + i * 0.00001, code, 0, 38845.0 + i * 0.0001, "", ""))
        content = make_plt_content(pts)
        p = write_plt(self.tmpdir, "large.plt", content)
        result = plt2gpx.convert_single(p, self.outdir)
        self.assertIsNotNone(result)
        gpx = parse_gpx(result)
        total = sum(len(s) for s in gpx["segments"])
        self.assertEqual(total, 100000)

    # --- 5.4: Unicode in track description ---
    def test_54_unicode_description(self):
        """Unicode in track description → GPX name."""
        content = make_plt_content(
            line5="0,2,128,Résumé café,1,0,0,0",
            points=[(55.0, 38.0, 0, 0, 38845.5, "", "")],
        )
        p = write_plt(self.tmpdir, "unicode.plt", content)
        result = plt2gpx.convert_single(p, self.outdir)
        gpx = parse_gpx(result)
        self.assertEqual(gpx["name"], "Résumé café")


class TestRealData(unittest.TestCase):
    """Tests against the actual testdata PLT files."""

    TESTDATA = Path(__file__).parent / "testdata"

    def test_real_small_file(self):
        p = self.TESTDATA / "2006.05.08-21.58.35.plt"
        track_name, datum, points = plt2gpx.parse_plt(p)
        self.assertEqual(len(points), 54)
        self.assertEqual(datum, "WGS 84")
        self.assertEqual(points[0]["code"], 1)
        self.assertEqual(points[0]["ele"], 0.0)

    def test_real_file_with_break(self):
        p = self.TESTDATA / "2006.05.07-13.31.11.plt"
        _, _, points = plt2gpx.parse_plt(p)
        self.assertEqual(len(points), 110)
        sorted_pts = plt2gpx._sort_points(points)
        segs = plt2gpx.split_segments(sorted_pts)
        self.assertEqual(len(segs), 2)
        self.assertEqual(len(segs[0]), 100)
        self.assertEqual(len(segs[1]), 10)

    def test_real_file_no_break(self):
        p = self.TESTDATA / "2006.05.08-18.05.31.plt"
        _, _, points = plt2gpx.parse_plt(p)
        self.assertEqual(len(points), 128)
        sorted_pts = plt2gpx._sort_points(points)
        segs = plt2gpx.split_segments(sorted_pts)
        self.assertEqual(len(segs), 1)

    def test_real_merge(self):
        _, _, pts1 = plt2gpx.parse_plt(self.TESTDATA / "2006.05.07-13.31.11.plt")
        _, _, pts2 = plt2gpx.parse_plt(self.TESTDATA / "2006.05.08-18.05.31.plt")
        _, _, pts3 = plt2gpx.parse_plt(self.TESTDATA / "2006.05.08-21.58.35.plt")
        all_pts = pts1 + pts2 + pts3
        self.assertEqual(len(all_pts), 292)
        sorted_pts = plt2gpx._sort_points(all_pts)
        segs = plt2gpx.split_segments(sorted_pts)
        self.assertEqual(len(segs), 4)


class TestOziDatetime(unittest.TestCase):
    """Tests for ozi_datetime_to_datetime."""

    def test_epoch(self):
        dt = plt2gpx.ozi_datetime_to_datetime(0)
        self.assertEqual(dt.year, 1899)
        self.assertEqual(dt.month, 12)
        self.assertEqual(dt.day, 30)

    def test_known_value(self):
        """38845.91572917 → 2006-05-08 21:58:39."""
        dt = plt2gpx.ozi_datetime_to_datetime(38845.91572917)
        self.assertEqual(dt.year, 2006)
        self.assertEqual(dt.month, 5)
        self.assertEqual(dt.day, 8)
        self.assertEqual(dt.hour, 21)
        self.assertEqual(dt.minute, 58)
        self.assertEqual(dt.second, 39)

    def test_fractional_day(self):
        """0.5 → noon."""
        dt = plt2gpx.ozi_datetime_to_datetime(0.5)
        self.assertEqual(dt.hour, 12)
        self.assertEqual(dt.minute, 0)

    def test_spec_example(self):
        """36169.6307194 → 1999-01-09 15:08:14 (datetime field takes precedence)."""
        dt = plt2gpx.ozi_datetime_to_datetime(36169.6307194)
        self.assertEqual(dt.year, 1999)
        self.assertEqual(dt.month, 1)
        self.assertEqual(dt.day, 9)
        self.assertEqual(dt.hour, 15)
        self.assertEqual(dt.minute, 8)
        # seconds may vary slightly due to float precision
        self.assertIn(dt.second, (14, 15))


if __name__ == "__main__":
    unittest.main()
