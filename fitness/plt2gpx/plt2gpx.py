#!/usr/bin/env python3
"""Convert OziExplorer PLT files to GPX format.

Two modes:
  -- convert (default): convert each .plt to a .gpx, preserving directory structure
  -- merge: merge all .plt files in a subdirectory into a single .gpx
"""

import argparse
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta
from pathlib import Path
from xml.dom import minidom

OZI_EPOCH = datetime(1899, 12, 30)
FEET_TO_METERS = 0.3048
INVALID_ALTITUDE = -777


def ozi_datetime_to_datetime(ozi_value):
    """Convert OziExplorer datetime (days since 1899-12-30) to Python datetime."""
    return OZI_EPOCH + timedelta(days=ozi_value)


def parse_plt_header(lines):
    """Parse the 6-line PLT header. Returns (track_name, datum)."""
    track_name = ""
    datum = ""

    if len(lines) > 0:
        pass  # Line 1: version, not used

    if len(lines) > 1:
        datum = lines[1].strip()

    if len(lines) > 4:
        # Line 5: field1,field2,field3,field4(desc),field5,field6,field7,field8
        parts = lines[4].strip().split(",")
        if len(parts) > 3 and parts[3].strip():
            track_name = parts[3].strip()

    return track_name, datum


def parse_plt(filepath):
    """Parse a PLT file and return (track_name, datum, points).

    Each point is a dict with keys:
      lat, lon, ele (meters), time (datetime), code (0=normal, 1=break).

    Altitude is always in feet per spec (-777 = not valid).
    Code=1 indicates a break in track line.
    """
    points = []

    with open(filepath, "r", encoding="utf-8", errors="replace") as f:
        lines = f.readlines()

    if not lines:
        return "", "", points

    track_name, datum = parse_plt_header(lines)

    # Per spec: lines 1-6 are header, line 7+ are data points.
    # Skip the first 6 non-blank lines.
    non_blank_count = 0
    for i, line in enumerate(lines):
        line = line.strip()
        if not line:
            continue
        non_blank_count += 1
        if non_blank_count <= 6:
            continue

        # Strip only trailing comma (don't use rstrip which removes all trailing commas)
        if line.endswith(","):
            line = line[:-1]
        parts = line.split(",")
        if len(parts) < 5:
            continue

        try:
            lat = float(parts[0])
            lon = float(parts[1])
        except (ValueError, IndexError):
            continue

        if not (-90 <= lat <= 90) or not (-180 <= lon <= 180):
            continue

        # Field 2: code (0=normal, 1=break in track line)
        code = 0
        if len(parts) > 2 and parts[2].strip():
            try:
                code = int(parts[2])
            except ValueError:
                pass

        # Field 3: altitude in feet (-777 = not valid)
        ele = None
        if len(parts) > 3 and parts[3].strip():
            try:
                alt_ft = float(parts[3])
                if alt_ft != INVALID_ALTITUDE:
                    ele = alt_ft * FEET_TO_METERS
            except ValueError:
                pass

        # Field 4: OziExplorer date (days since 1899-12-30)
        pt_time = None
        if len(parts) > 4 and parts[4].strip():
            try:
                ozi_dt = float(parts[4])
                if ozi_dt > 0:
                    pt_time = ozi_datetime_to_datetime(ozi_dt)
            except ValueError:
                pass

        points.append({
            "lat": lat,
            "lon": lon,
            "ele": ele,
            "time": pt_time,
            "code": code,
        })

    return track_name, datum, points


def split_segments(points):
    """Split points into segments at code=1 (track break) boundaries.

    Returns list of segments, each segment is a list of points.
    A code=1 point starts a new segment (it belongs to the new segment).
    """
    if not points:
        return []

    segments = [[]]
    for pt in points:
        if pt.get("code") == 1 and segments[-1]:
            segments.append([])
        segments[-1].append(pt)

    return [seg for seg in segments if seg]


GPX_NS = "http://www.topografix.com/GPX/1/1"
GPX_TAG = f"{{{GPX_NS}}}"


def _tag(name):
    return f"{{{GPX_NS}}}{name}"


def _add_trkpt(seg, pt):
    trkpt = ET.SubElement(seg, _tag("trkpt"), {
        "lat": f"{pt['lat']:.8f}",
        "lon": f"{pt['lon']:.8f}",
    })

    if pt["ele"] is not None:
        ele_elem = ET.SubElement(trkpt, _tag("ele"))
        ele_elem.text = f"{pt['ele']:.1f}"

    if pt["time"] is not None:
        time_elem = ET.SubElement(trkpt, _tag("time"))
        time_elem.text = pt["time"].strftime("%Y-%m-%dT%H:%M:%SZ")


def build_gpx(segments, track_name="Track"):
    """Build a GPX XML document from a list of track segments.

    segments: list of lists of points.
    """
    all_points = [pt for seg in segments for pt in seg]

    gpx = ET.Element(_tag("gpx"), {
        "version": "1.1",
        "creator": "plt2gpx",
    })

    if all_points:
        meta = ET.SubElement(gpx, _tag("metadata"))
        name_elem = ET.SubElement(meta, _tag("name"))
        name_elem.text = track_name
        times = [p["time"] for p in all_points if p.get("time")]
        if times:
            desc = ET.SubElement(meta, _tag("desc"))
            desc.text = f"{len(all_points)} points from {min(times)} to {max(times)}"

    trk = ET.SubElement(gpx, _tag("trk"))
    trk_name = ET.SubElement(trk, _tag("name"))
    trk_name.text = track_name

    for seg_points in segments:
        seg = ET.SubElement(trk, _tag("trkseg"))
        for pt in seg_points:
            _add_trkpt(seg, pt)

    return gpx


def prettify_xml(element):
    """Return a pretty-printed XML string."""
    rough = ET.tostring(element, encoding="unicode", xml_declaration=False)
    parsed = minidom.parseString(rough)
    return parsed.toprettyxml(indent="  ", encoding="utf-8").decode("utf-8")


def _sort_points(points):
    points_with_time = [p for p in points if p.get("time")]
    points_no_time = [p for p in points if not p.get("time")]
    points_with_time.sort(key=lambda p: p["time"])
    return points_with_time + points_no_time


def convert_single(plt_path, output_dir=None):
    """Convert a single PLT file to GPX. Returns the output filepath."""
    plt_path = Path(plt_path)
    gpx_path = plt_path.with_suffix(".gpx")

    if output_dir:
        out_dir = Path(output_dir) / plt_path.relative_to(plt_path.parent).parent
        out_dir.mkdir(parents=True, exist_ok=True)
        gpx_path = out_dir / plt_path.with_suffix(".gpx").name

    track_name, datum, points = parse_plt(plt_path)
    if not points:
        print(f"  No points in {plt_path}, skipping.", file=sys.stderr)
        return None

    # Use header track name if available, otherwise fall back to filename
    if not track_name:
        track_name = plt_path.stem

    sorted_points = _sort_points(points)
    segments = split_segments(sorted_points)

    gpx = build_gpx(segments, track_name)

    gpx_path = Path(gpx_path)
    gpx_path.parent.mkdir(parents=True, exist_ok=True)

    xml_str = prettify_xml(gpx)
    with open(gpx_path, "w", encoding="utf-8") as f:
        f.write(xml_str)

    print(f"  {plt_path} -> {gpx_path} ({len(sorted_points)} points, {len(segments)} segments)")
    return gpx_path


def merge_directory(dirpath, output_dir=None):
    """Merge all PLT files in a directory into a single GPX."""
    dirpath = Path(dirpath)
    plt_files = sorted(dirpath.glob("*.plt"))

    if not plt_files:
        print(f"  No .plt files in {dirpath}", file=sys.stderr)
        return None

    all_points = []
    for plt_file in plt_files:
        _, _, points = parse_plt(plt_file)
        all_points.extend(points)

    if not all_points:
        print(f"  No points in any file in {dirpath}, skipping.", file=sys.stderr)
        return None

    # Sort all points by time, then split at track breaks
    sorted_points = _sort_points(all_points)
    segments = split_segments(sorted_points)

    # Build output filename from directory name + first point timestamp
    times = [p["time"] for p in sorted_points if p.get("time")]
    first_time = min(times) if times else None
    time_str = first_time.strftime("%Y.%m.%d-%H.%M.%S") if first_time else "unknown"
    track_name = f"{dirpath.name}-{time_str}"

    gpx_filename = f"{track_name}.gpx"

    if output_dir:
        out_dir = Path(output_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        gpx_path = out_dir / gpx_filename
    else:
        gpx_path = dirpath / gpx_filename

    gpx = build_gpx(segments, track_name)

    xml_str = prettify_xml(gpx)
    with open(gpx_path, "w", encoding="utf-8") as f:
        f.write(xml_str)

    print(f"  Merged {len(plt_files)} files -> {gpx_path} ({len(sorted_points)} points, {len(segments)} segments)")
    return gpx_path


def scan_and_convert(root_path, output_dir=None, merge=False):
    """Scan root path for .plt files and convert them.

    If merge=True, all .plt files in each subdirectory are merged into one GPX.
    Otherwise, each .plt is converted individually, preserving directory structure.
    """
    root_path = Path(root_path)

    if merge:
        # Find directories containing .plt files
        processed = set()
        for plt_file in root_path.rglob("*.plt"):
            parent = plt_file.parent
            if parent not in processed:
                processed.add(parent)
                merge_directory(parent, output_dir)
    else:
        # Convert each .plt file individually
        for plt_file in root_path.rglob("*.plt"):
            convert_single(plt_file, output_dir)


def main():
    parser = argparse.ArgumentParser(
        description="Convert OziExplorer PLT files to GPX format."
    )
    parser.add_argument(
        "input",
        help="Input file or directory containing PLT files",
    )
    parser.add_argument(
        "-o", "--output",
        help="Output directory (default: alongside input files)",
        default=None,
    )
    parser.add_argument(
        "-m", "--merge",
        action="store_true",
        help="Merge all PLT files in each subdirectory into a single GPX",
    )

    args = parser.parse_args()
    input_path = Path(args.input)

    if not input_path.exists():
        print(f"Error: {input_path} does not exist.", file=sys.stderr)
        sys.exit(1)

    if input_path.is_file():
        if args.merge:
            print("Error: --merge requires a directory input.", file=sys.stderr)
            sys.exit(1)
        convert_single(input_path, args.output)
    else:
        scan_and_convert(input_path, args.output, merge=args.merge)


if __name__ == "__main__":
    main()
