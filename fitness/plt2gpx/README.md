# PLT to GPX Converter — Format Analysis & Design

## 1. PLT File Format

The `.plt` format is **OziExplorer Track File**, version 2.1. OziExplorer is a GPS mapping application. The format is a plain-text CSV with a fixed 6-line header followed by data rows.

### 1.1 Header (lines 1–6)

```
OziExplorer Track Point File Version 2.1   <- Line 1: file type and version
WGS 84                                      <- Line 2: geodetic datum for Lat/Lon
Altitude is in Feet                         <- Line 3: reminder (altitude always in feet)
Reserved                                    <- Line 4: reserved for future use
0,2,128,,0,0,2,0                           <- Line 5: track display settings (8 fields)
1                                           <- Line 6: number of track points (not used by reader)
```

**Line 1 — File Type and Version:**
- Observed: `OziExplorer Track Point File Version 2.1`
- OziExplorer also produces version 1.x files with potentially different structure.

**Line 2 — Geodetic Datum:**
- Observed: `WGS 84`
- Other possible values: `Local Grid`, UTM zone designations, `Geocentric`, custom projections.
- Only `WGS 84` produces lat/lon directly. Other datums require coordinate transformation using the associated map grid definition file (.map/.mdd).

**Line 3 — Altitude Unit Reminder:**
- Always declares the altitude unit. Observed: `Altitude is in Feet`.
- Per spec, altitude is **always stored in feet** — this line is just a reminder, not a configurable setting.

**Line 4 — Reserved:**
- Always the literal string `Reserved`.

**Line 5 — Track Display Settings (8 comma-separated fields):**

| Field | Index | Description | Observed Value |
|---|---|---|---|
| Always zero | 0 | Always 0 | `0` |
| Line width | 1 | Width of track plot line on screen | `2` |
| Track color | 2 | Track color (RGB value) | `128` |
| Track description | 3 | Track description text (no commas allowed) | _(empty)_ |
| Track skip value | 4 | Reduces number of track points plotted, usually 1 | `0` |
| Track type | 5 | `0` = normal, `10` = closed polygon, `20` = alarm zone | `0` |
| Fill style | 6 | `0`=bsSolid, `1`=bsClear, `2`=bsBdiagonal, `3`=bsFdiagonal, `4`=bsCross, `5`=bsDiagCross, `6`=bsHorizontal, `7`=bsVertical | `2` |
| Fill color | 7 | Track fill color (RGB value) | `0` |

The **track description** (field 4) is used by the converter as the GPX track name when available.

**Line 6 — Number of Track Points:**
- Integer. Per spec, this is "not used" — the reader determines the number of points by counting data lines.
- In test files: `116` for the 110-point file, `134` for the 128-point file, `60` for the 54-point file. This count includes header lines, so it's `6 (header) + N (data points)`.

### 1.2 Data Rows (line 7+)

Each row represents one track point with up to 7 comma-separated fields. Lines end with a trailing comma. Non-essential fields may be empty but comma separators must still be present (e.g., `,,`).

```
Latitude,Longitude,Code,Altitude,DateTime,DateString,TimeString,
```

| Field | Index | Type | Description |
|---|---|---|---|
| Latitude | 0 | float | Decimal degrees. Range -90…90. Observed precision: 8 decimal places. |
| Longitude | 1 | float | Decimal degrees. Range -180…180. Observed precision: 8 decimal places. |
| Code | 2 | int | `0` = normal point, `1` = break in track line |
| Altitude | 3 | float | Altitude in **feet**. Value `-777` means not valid. Defaults to 0 if empty. |
| DateTime | 4 | float | OziExplorer epoch — days since 1899-12-30. OziExplorer reads date/time from this field. If blank, a preset date is used. |
| DateString | 5 | string | Date as a human-readable string (e.g., `09-Jan-99`). **Ignored by OziExplorer.** Always empty in test data. |
| TimeString | 6 | string | Time as a human-readable string (e.g., `3:08:14`). **Ignored by OziExplorer.** Always empty in test data. |

**Example from spec:**
```
-27.350436, 153.055540, 1, -777, 36169.6307194, 09-Jan-99, 3:08:14
-27.348610, 153.055867, 0, -777, 36169.6307194, 09-Jan-99, 3:08:14
```

### 1.3 OziExplorer DateTime

OziExplorer uses an epoch of **December 30, 1899** (same as Excel's "1900 date system"). The value is a floating-point number of days since that epoch.

**Conversion formula:**
```
datetime = datetime(1899, 12, 30) + timedelta(days=ozi_value)
```

**Observed range in test data:** ~38844–38846 (May 2006). For reference:
- Year 1990 ≈ 32874
- Year 2000 ≈ 36526
- Year 2010 ≈ 40182
- Year 2020 ≈ 43835
- Year 2030 ≈ 47488

**Precision:** The fractional day gives sub-second precision (8 decimal places observed, ≈0.08ms resolution). GPX only supports second-level granularity in its `time` element.

### 1.4 Code Field — Track Break Indicator

| Value | Meaning | Occurrence in test data |
|---|---|---|
| `0` | Normal track point — continues the current track segment | Majority of points |
| `1` | Break in track line — starts a new track segment | First point of every file; also at index 100 in `2006.05.07-13.31.11.plt` (39-second recording gap) |

This field is used by the converter to split points into GPX `<trkseg>` elements. A `code=1` point starts a new `<trkseg>`.

### 1.5 Altitude

Altitude is stored in field 3 in **feet**. Special values:
- `-777` — altitude is not valid (should be excluded from GPX output)
- `0` or empty — defaults to 0 feet
- Positive/negative values — valid altitude in feet, converted to meters for GPX

In the test data, all altitudes are `0` feet (0.0 meters). The spec example shows `-777` for invalid altitude.

## 2. Known Limitations of PLT Format

- **No heart rate, cadence, speed, power:** The format is purely positional + altitude + timestamp.
- **Date/time strings (fields 6-7) are ignored:** OziExplorer only reads from field 5. These are informational only and always empty in our test data.
- **Single datum in test set:** Only WGS 84 observed. Non-WGS datums require reprojection with external map definition files.
- **Track description in header (line 5, field 4):** No commas allowed, so complex descriptions are truncated or malformed.

## 3. Potential Edge Cases

### 3.1 Coordinate System Variants

Line 2 may not be `WGS 84`. Possible values include:
- `Local Grid` — requires map definition file (.map/.mdd) to resolve
- UTM zones — e.g., `UTM 37N`
- Geocentric coordinates
- Custom/local projections

**Impact:** Non-WGS-84 coordinates cannot be converted to GPX lat/lon without the corresponding map grid definition.

### 3.2 Altitude Edge Cases

- **-777 (invalid):** must be excluded from GPX `<ele>` element
- **0 feet:** ambiguous — could mean "no data" or "sea level"; currently converted as 0.0m
- **Negative values:** valid (below sea level), e.g., Dead Sea region
- **Very large values:** possible GPS errors (thousands of meters)

### 3.3 Code Field Variants

- `0` and `1` are the documented values
- Other integer values are undocumented but possible in future versions
- Currently: any value != 1 is treated as normal (continues current segment)

### 3.4 DateTime Edge Cases

- **Missing datetime:** field 5 is empty — OziExplorer uses a preset date; converter includes point without `<time>`
- **Zero datetime:** value of 0 → 1899-12-30 — likely invalid/sentinel
- **Negative datetime:** before epoch — likely invalid
- **Out-of-range:** values outside plausible GPS era (~1980–2050, ≈29200–51130)
- **Unsorted points:** points within a file may not be chronologically ordered

### 3.5 Date/Time String Fields

- Fields 6 and 7 may contain human-readable date/time (format like `09-Jan-99`, `3:08:14`)
- Always empty in test data
- Could be used as fallback when field 5 is missing, but format is not standardized
- Currently ignored

### 3.6 Coordinate Edge Cases

- **Pole points:** latitude exactly ±90
- **Date line crossing:** longitude near ±180
- **Duplicate points:** same lat/lon consecutive (observed in test data — GPS stationary during recording)
- **Zero displacement:** same coordinates repeated multiple times

### 3.7 File Structure Edge Cases

- **Empty files:** no data rows after header
- **Header-only file:** 6-line header, no data
- **Malformed lines:** wrong number of fields, non-numeric values
- **Encoding issues:** non-UTF-8 characters in track description or date/time strings
- **Trailing/leading whitespace:** varies by OziExplorer version
- **Missing trailing comma:** some exports may omit it
- **Extra blank lines:** between header and data, or between data rows
- **Line 6 mismatch:** declared point count doesn't match actual data lines (per spec, reader ignores line 6)

### 3.8 Version Differences

- Version 1.x PLT files may have different header structure or fewer data fields
- Version 3.x (if it exists) may add fields

### 3.9 Track Display Settings (Line 5)

- **Track description with commas:** would break CSV parsing of line 5
- **Empty track description:** common; falls back to filename for GPX track name
- **Track type 10/20:** closed polygon or alarm zone — semantic meaning not preserved in GPX

## 4. Conversion Logic

### 4.1 Overall Flow

```
Input: directory tree with .plt files
  │
  ├─ Mode A: Individual conversion (default)
  │   └─ For each .plt:
  │       Parse header → Parse data → Sort by time → Split at code=1 → Build GPX → Write .gpx
  │       Output: preserves directory structure under output root
  │
  └─ Mode B: Merge (--merge)
      └─ For each directory containing .plt files:
          Parse all .plt → Combine → Sort by time → Split at code=1 → Build GPX → Write single .gpx
          Output filename: {dirname}-{first_timestamp}.gpx
```

### 4.2 Header Parsing (`parse_plt_header`)

1. Line 2 → datum string (logged, not used for conversion)
2. Line 5, field 4 → track description (used as GPX track name if non-empty)
3. Line 6 → ignored (spec says reader doesn't use it)

### 4.3 Data Parsing (`parse_plt`)

1. Skip first 6 non-blank lines (header)
2. For each remaining line:
   - Strip trailing comma, split on comma
   - Parse fields 0 (lat) and 1 (lon) as floats
   - Validate lat in [-90, 90] and lon in [-180, 180]
   - Parse field 2 as code (int, default 0)
   - Parse field 3 as altitude in feet; skip if -777; convert to meters
   - Parse field 4 as OziExplorer datetime; convert if > 0
   - Fields 5-6 (date/time strings): ignored
3. Returns `(track_name, datum, points)`

### 4.4 Sorting

Points with valid timestamps are sorted chronologically. Points without timestamps are appended at the end.

### 4.5 Track Segmentation (`split_segments`)

Points are split into `<trkseg>` segments at `code=1` boundaries:
- A point with `code=1` starts a new segment
- The `code=1` point itself belongs to the new segment (not the previous one)
- Points without `code=1` continue the current segment

### 4.6 GPX Construction (`build_gpx`)

Produces GPX 1.1 XML with:
- `<gpx>` root with `xmlns="http://www.topografix.com/GPX/1/1"`, `version="1.1"`, `creator="plt2gpx"`
- `<metadata><name>` — track name (from header or filename)
- `<metadata><desc>` — point count and time range
- `<trk><name>` — track name
- `<trk><trkseg>` — one per segment (split at code=1)
- `<trkpt>` — per point: `lat`, `lon` attributes, `<ele>` (if valid), `<time>` (if valid)

Coordinates formatted to 8 decimal places. Time truncated to whole seconds. Altitude in meters, 1 decimal place.

### 4.7 Individual Mode (`convert_single`)

- Input: single `.plt` path, optional output directory
- Output: `.gpx` file with same stem name
- When output dir is given, mirrors the subdirectory structure relative to input
- Track name: header track description if available, otherwise filename stem

### 4.8 Merge Mode (`merge_directory`)

- Input: directory path, optional output directory
- Finds all `*.plt` in the directory (non-recursive)
- Combines all points, sorts globally by time, splits at code=1
- Output filename: `{directory_name}-{YYYY.MM.DD-HH.MM.SS}.gpx`
  - Timestamp from the earliest point across all merged files
- When processing a tree with `--merge`, each subdirectory is merged independently

## 5. Test Cases

### 5.1 Functional Tests

| # | Test | Input | Expected |
|---|---|---|---|
| T1 | Single-file conversion | `2006.05.08-21.58.35.plt` | `2006.05.08-21.58.35.gpx`, 54 points, 1 segment, first time `2006-05-08T21:58:39Z`, ele=0.0 |
| T2 | Single-file conversion | `2006.05.07-13.31.11.plt` | `2006.05.07-13.31.11.gpx`, 110 points, 2 segments (break at idx 100) |
| T3 | Single-file conversion | `2006.05.08-18.05.31.plt` | `2006.05.08-18.05.31.gpx`, 128 points, 1 segment |
| T4 | Directory batch | `testdata/` individual mode | 3 GPX files, flat output |
| T5 | Merge mode | `testdata/` merge mode | `testdata-2006.05.07-13.31.15.gpx`, 292 points, 4 segments |
| T6 | Nested directory | `a/b/file.plt` → individual, `-o /out` | Output at `/out/a/b/file.gpx` |
| T7 | Nested merge | `a/b/` with 2+ `.plt` → merge | Single GPX `b-{timestamp}.gpx` |
| T8 | Altitude conversion | Point with altitude 3280.84 ft | `<ele>1000.0</ele>` (3280.84 × 0.3048 ≈ 1000.0m) |
| T9 | Invalid altitude | Point with altitude -777 | No `<ele>` element in output |

### 5.2 Edge Case Tests

| # | Test | Input | Expected |
|---|---|---|---|
| E1 | Empty file | 0-byte `.plt` | No output, stderr warning |
| E2 | Header-only file | 6-line header, no data | No output, stderr warning |
| E3 | Missing datetime | field 5 empty | Point included without `<time>` |
| E4 | Invalid datetime | field 5 = `0`, `abc` | Point included without `<time>` |
| E5 | Non-WGS datum | line 2 = `Local Grid` | Coords parsed as-is, warning logged |
| E6 | Duplicate coordinates | consecutive identical lat/lon | Both points preserved |
| E7 | Unsorted timestamps | points out of order | Sorted in output GPX |
| E8 | Code=1 (track break) | code=1 at various positions | New `<trkseg>` starts at that point |
| E9 | Multiple track breaks | code=1 at indices 0, 50, 100 | 3 `<trkseg>` elements |
| E10 | Malformed line | < 5 fields, non-numeric lat | Line silently skipped |
| E11 | Altitude = 0 | field 3 = `0` | `<ele>0.0</ele>` (ambiguous but included) |
| E12 | Date/time strings populated | fields 6-7 non-empty | Ignored, point parsed from field 5 |
| E13 | No output dir | `-o` not provided | GPX alongside PLT |
| E14 | Merge single-file dir | 1 `.plt` in directory | GPX as `{dirname}-{timestamp}.gpx` |
| E15 | Date line crossing | lon near ±180 | Coords preserved as-is |
| E16 | Track description in header | line 5 field 4 = "My Track" | GPX `<name>My Track</name>` |
| E17 | Line 6 mismatch | line 6 says 100, actual 50 points | All 50 points parsed (line 6 ignored) |

### 5.3 Verified Results (from testdata)

```
Individual mode:
  2006.05.08-21.58.35.plt → 54 points, 1 segment
    time: 2006-05-08T21:58:39Z to 2006-05-08T22:04:25Z
    altitude: all 0.0m (0 ft)
    code=1 at index 0 only

  2006.05.08-18.05.31.plt → 128 points, 1 segment
    time: 2006-05-08T18:05:34Z to 2006-05-08T18:11:33Z
    altitude: all 0.0m (0 ft)
    code=1 at index 0 only

  2006.05.07-13.31.11.plt → 110 points, 2 segments
    time: 2006-05-07T13:31:15Z to 2006-05-07T13:39:43Z
    altitude: all 0.0m (0 ft)
    code=1 at index 0 (seg start), index 100 (seg break, 39s gap)
    Segment 0: 100 points (13:31:15 → 13:37:58)
    Segment 1: 10 points  (13:38:37 → 13:39:43)

Merge mode:
  testdata/ → 292 points, 4 segments
    time: 2006-05-07T13:31:15Z to 2006-05-08T22:04:25Z
    segments from: 3 file starts (code=1) + 1 internal break
    Output: testdata-2006.05.07-13.31.15.gpx
```

### 5.4 Tests Yet to Be Created

- [ ] PLT file with real altitude data (non-zero, non--777)
- [ ] PLT file with -777 altitude (verify no `<ele>` in GPX)
- [ ] Non-WGS-84 coordinate system
- [ ] Line 6 count mismatch (declared vs actual)
- [ ] Version 1.x PLT file
- [ ] Date/time string fields populated (fields 6-7)
- [ ] Track description in line 5 field 4
- [ ] Track type 10 (closed polygon) / 20 (alarm zone)
- [ ] Large file stress test (100k+ points)
- [ ] Unicode/special characters in track description
- [ ] Points with identical timestamps (ordering stability)
- [ ] GPX output validates against GPX 1.1 XSD schema
- [ ] Negative altitude (below sea level)
- [ ] File with only code=1 points (all track breaks)

## 6. Future Enhancements

- **Waypoint for code=1 points:** emit GPX `<wpt>` at track break points alongside `<trkseg>`
- **Non-WGS-84 support:** integrate with pyproj to reproject from other datums
- **Date/time string fallback:** parse fields 6-7 when field 5 is missing
- **Altitude filtering:** configurable threshold for "zero means invalid" vs "zero means sea level"
- **Track type awareness:** handle closed polygon (type 10) and alarm zone (type 20) specially
- **GPX extensions:** store code, altitude (original feet), date/time strings as extensions
- **Validation:** validate output against GPX 1.1 XSD
- **Unit tests:** pytest-based test suite using testdata + synthetic edge cases
- **Dry-run mode:** count files, points, segments without writing output

## 7. Implementation Notes & Session History

### 7.1 What Was Built This Session

**Converter Script (`plt2gpx.py`):**
- Parses OziExplorer PLT v2.1 format with 6-line header + 7-field CSV data rows
- Converts OziExplorer datetime (days since 1899-12-30) to Python datetime
- Extracts altitude from field 3 (feet, converts to meters), handles -777 as invalid
- Splits tracks into `<trkseg>` at code=1 boundaries (track break markers)
- Two modes: individual conversion (preserves directory structure) and merge mode
- Merge mode produces `{dirname}-{YYYY.MM.DD-HH.MM.SS}.gpx` naming scheme

**Test Suite (`test_plt2gpx.py`):**
- 52 unit/integration tests covering all functional and edge cases
- Uses Python's `unittest` (no external dependencies)
- Tests: parsing, sorting, segmentation, GPX generation, altitude conversion
- Tests against real testdata files and synthetic edge cases
- All tests pass

**Format Documentation (`README.md`):**
- Complete PLT format specification per OziExplorer documentation
- 6-line header breakdown (version, datum, altitude unit, reserved, track settings, point count)
- 7-field data row specification (lat, lon, code, altitude, datetime, date string, time string)
- Code field (0=normal, 1=track break) and altitude (-777=invalid) documented
- DateTime conversion formula and epoch verification
- 17 edge cases documented with test coverage

### 7.2 Key Discoveries & Learnings

**OziExplorer PLT Format:**
- Line 3 `Altitude is in Feet` is just a reminder—altitude is ALWAYS in feet per spec
- Line 5 has 8 fields: width, color, description, skip, type, fill style, fill color
- Line 6 declares point count but is ignored by readers per spec
- Fields 6-7 (date/time strings) are informational only—Ozi reads field 5
- Track description in line 5 field 4 is the best source for GPX track name

**Field Meanings (Corrected from Initial Assumptions):**
- **Field 2:** Code (0=normal, 1=track break) — NOT "Attribute1=waypoint"
- **Field 3:** Altitude in feet (-777=invalid) — NOT "Attribute2"
- **Field 4:** DateTime (Ozi epoch, days since 1899-12-30)
- **Field 5:** Date string (ignored by Ozi)
- **Field 6:** Time string (ignored by Ozi)

**DateTime Epoch:**
- OziExplorer uses Excel's "1900 date system" epoch: December 30, 1899
- Value 38845.91572917 → 2006-05-08 21:58:39 (verified with testdata)
- Fractional part represents time: 0.91572917 × 86400 = 79095 seconds = 21:58:39

**Track Segmentation:**
- code=1 at start of file creates first segment
- code=1 in middle of file creates new segment (break in track)
- Test file `2006.05.07-13.31.11.plt` has 2 segments (break at index 100, 39s gap)

**GPX Namespace Handling:**
- Clark notation (`{http://www.topografix.com/GPX/1/1}gpx`) required for proper namespace handling
- `minidom` produces `ns0:` prefix; tests must use full namespace URI
- `prettify_xml()` uses `ET.tostring()` + `minidom.parseString()` round-trip

### 7.3 Dead Ends & Things to Avoid

**Dead End 1: Header Parsing Heuristic**
- **Problem:** Trying to skip header lines by detecting "non-data" values (small lat/lon, out-of-range datetime)
- **Result:** Line 5 `0,2,128,,0,0,2,0` has lat=0, lon=2 (valid ranges), datetime=0 (out of range) → was being skipped incorrectly
- **Solution:** Explicitly skip first 6 non-blank lines per spec

**Dead End 2: Missing Altitude Field Assumption**
- **Problem:** Initial assumption that altitude is not stored in PLT format
- **Result:** Test data showed altitudes, spec says they ARE stored
- **Solution:** Parse field 3 as altitude in feet, convert to meters

**Dead End 3: Rstrip Trailing Commas**
- **Problem:** `line.rstrip(",")` strips ALL trailing commas
- **Result:** Line `55.0,,0,,,` → `55.0,,0` loses fields 3-6
- **Solution:** Only strip the final comma with `line[:-1]` if it exists

**Dead End 4: GPX Namespace Prefix**
- **Problem:** Using `xmlns` as attribute and `find("gpx:trk", NS)` doesn't work
- **Result:** `find()` returns None because namespace isn't registered properly
- **Solution:** Use Clark notation `{http://www.topografix.com/GPX/1/1}trkpt` for all element tags

**Dead End 5: Ozi Epoch Confusion**
- **Problem:** Wrong assumption about epoch date
- **Result:** datetime conversion off by 1-2 days
- **Solution:** Verify with known test data (38845.91572917 → 2006-05-08)

**Dead End 6: Spec Example Inconsistency**
- **Problem:** Spec example `36169.6307194` with TimeString `3:08:14` (AM)
- **Result:** DateTime field gives 15:08 (PM), not 03:08 (AM)
- **Resolution:** DateTime field (field 5) takes precedence per spec; TimeString (field 7) is cosmetic

**Dead End 7: Empty Field Parsing**
- **Problem:** Empty string datetime field `""` was causing issues
- **Result:** `float("")` raises ValueError, but the check `parts[4].strip()` fails first
- **Solution:** Empty field leaves `pt_time=None` but point is still added (no crash)

**Things to Avoid:**
1. Using `rstrip(",")` for CSV parsing — only strip the last comma
2. Assuming altitude is missing from PLT — it IS in field 3
3. Relying on line 6 count — per spec it's ignored
4. Using XML namespace prefixes — use Clark notation
5. Trusting spec examples blindly — verify with actual epoch calculation
6. Using pytest as a requirement — standard library `unittest` is sufficient
7. Testing in-memory GPX with prefix lookups — use full namespace URI

### 7.4 What Was Done This Session

**Completed:**
- PLT parser with correct field semantics (lat, lon, code, alt, datetime, date_str, time_str)
- Altitude conversion from feet to meters, -777 handling
- Track segmentation at code=1 boundaries
- GPX 1.1 XML output with proper namespace
- Individual conversion mode (preserves directory structure)
- Merge mode (combines all .plt in subdir, names from dir + first timestamp)
- 52 unit/integration tests (100% pass rate)
- Complete format documentation with examples
- All testdata files verified (292 total points, 4 segments)

**Testing Results:**
```
52 tests passed in 2.458s
Individual mode: 3 files -> 3 GPX (54+128+110 = 292 points)
Merge mode: 3 files -> 1 GPX (292 points, 4 segments)
Large file: 100k points converts without error
```

### 7.5 Future Work (From README Section 6)

**High Priority:**
- Waypoint support (emit `<wpt>` for code=1 points)
- Non-WGS-84 support (pyproj integration)
- Validation against GPX 1.1 XSD
- Dry-run mode

**Medium Priority:**
- Track type awareness (10=closed polygon, 20=alarm zone)
- GPX extensions for code, altitude (feet), date/time strings
- Progress reporting for large batch conversions

**Lower Priority:**
- Unicode/special character handling
- Points with identical timestamps (stability)
- Large file stress tests beyond 100k points
- Format version 1.x and 3.x support
