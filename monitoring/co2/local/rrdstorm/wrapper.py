#!/usr/bin/env python3
"""rrdstorm decomposed - main wrapper (Python port)

Mirrors wrapper.sh command line interface exactly. Reads meta files
dynamically so new data sources can be added without touching this file.

Usage:
  wrapper.py create   0 1 2 3 4 5 6 7 8 9
  wrapper.py update   0 1 2 3 4 5 6 7 8 9
  wrapper.py graph    0 1 2 3 4 5 6 7 8 9
  wrapper.py graph_cron s 0 1 2 3 4 5 6
  wrapper.py graph_cron h 0 1 2 3 4 5 6
  wrapper.py graph_cron d 0 1 2 3 4 5 6
  wrapper.py graph_cron w 0 1 2 3 4 5 6
  wrapper.py graph_cron m 0 1 2 3 4 5 6
  wrapper.py graph_cron y 0 1 2 3 4 5 6
  wrapper.py help
"""

import argparse
import os
import re
import shlex
import subprocess
import sys
from datetime import datetime as _datetime
from pathlib import Path

# ── Meta file parser ──────────────────────────────────────────────────────────
# Reads bash-style meta files that define RRDcFILE[N], RRDcDEF[N], etc.
# Returns a dict: { 'RRDcFILE': {'0': 'load:60:System load graphs', ...}, ... }


def parse_meta_file(path):
    """Parse a .meta file and return a dict of named lists/strings."""
    data = {
        "RRDcFILE": {},
        "RRDcDEF": {},
        "RRDuSRC": {},
        "RRDgUM": {},
        "RRDgLIST": {},
        "RRDgGRAPH": {},
    }

    with open(path) as f:
        content = f.read()

    for key in data:
        pattern = re.compile(
            rf"""{key}\[([0-9]+)\]\s*=\s*(?:"([^"]*)"|'([^']*)')""",
            re.DOTALL,
        )
        for match in pattern.finditer(content):
            idx = match.group(1)
            value = match.group(2) if match.group(2) is not None else match.group(3)
            data[key][idx] = value

    return data


# ── Condition evaluator ───────────────────────────────────────────────────────


def evaluate_condition(cond, M, H):
    """Evaluate a bash-style condition like '[ "$M" = 30 ]' or
    '[ "$H" = 04 ] && [ "$M" = 30 ]'.

    Returns True/False.
    """
    if not cond:
        return True

    # Replace "$M" and "$H" with their actual values
    expr = cond.replace('"$M"', f'"{M}"').replace('"$H"', f'"{H}"')

    # Remove the surrounding brackets
    expr = re.sub(r'\[\s*([^]]*)\s*\]', r'\1', expr)

    # Replace bash operators with Python equivalents
    expr = expr.replace(' = ', ' == ')
    expr = expr.replace(' != ', ' != ')
    expr = expr.replace(' -ge ', ' >= ')
    expr = expr.replace(' -le ', ' <= ')
    expr = expr.replace(' -gt ', ' > ')
    expr = expr.replace(' -lt ', ' < ')

    # Replace bash logical operators with Python equivalents
    expr = expr.replace(' && ', ' and ')
    expr = expr.replace(r' \|\| ', ' or ')

    try:
        return bool(eval(expr))
    except Exception:
        return False


# ── Main application ──────────────────────────────────────────────────────────


class RRDStorm:
    def __init__(self, script_dir):
        self.script_dir = script_dir
        self.datadir = Path(script_dir) / "data"
        self.defsdir = Path(script_dir) / "defs"

        self.rrdtool = os.environ.get("RRDTOOL", "/usr/bin/rrdtool")
        self.rrdupdate = os.environ.get("RRDUPDATE", "/usr/bin/rrdupdate")
        self.rrddata = Path(os.environ.get("RRDDATA", "/var/lib/rrd/storj"))
        self.rrdoutput = Path(os.environ.get("RRDOUTPUT", "/dev/shm/rrd.img"))
        self.forcegraph = os.environ.get("FORCEGRAPH", "no")

        self.RRDcFILE = {}
        self.RRDcDEF = {}
        self.RRDuSRC = {}
        self.RRDgUM = {}
        self.RRDgLIST = {}
        self.RRDgGRAPH = {}

        self.load_meta_files()

    def load_meta_files(self):
        """Discover and load all *.meta files from the defs directory."""
        meta_files = sorted(self.defsdir.glob("*.meta"))
        for meta_file in meta_files:
            parsed = parse_meta_file(meta_file)
            for key in ["RRDcFILE", "RRDcDEF", "RRDuSRC", "RRDgUM", "RRDgLIST", "RRDgGRAPH"]:
                for idx, val in parsed[key].items():
                    self.__dict__[key][idx] = val

    def create_rrd(self, rrdfile, step, definition):
        args = " ".join(definition.strip().split())
        print(f"{self.rrdtool} create {rrdfile} --step {step} {args}", flush=True)
        subprocess.run(
            [self.rrdtool, "create", rrdfile, "--step", step] + definition.strip().split(),
            check=True,
        )

    def create_graph(self, N, P, rrdf, M, H, mode="visual"):
        p_str = str(P)
        if p_str not in self.RRDgGRAPH:
            return

        g = self.RRDgGRAPH[p_str]
        parts = g.split("|")
        back = parts[0]
        imgbase = parts[1]
        title = parts[2]
        cond = parts[3] if len(parts) > 3 else ""
        extra = parts[4] if len(parts) > 4 else ""

        if mode == "visual":
            title = f"{title} @ \"{H}\":\"{M}\""

        if self.forcegraph == "yes":
            ret = 1
        elif not cond:
            ret = 1
        else:
            ret = 1 if evaluate_condition(cond, M, H) else 0

        if ret != 1:
            return

        print(f"Making graph ({N}:{P}) {self.rrdoutput / f'{imgbase}.svg'} ..", flush=True)

        # Determine FILEBASE from RRDcFILE[N]
        n_str = str(N)
        if n_str not in self.RRDcFILE:
            return
        filebase = self.RRDcFILE[n_str].split(":")[0]
        def_file = self.defsdir / f"{N}-{filebase}.sh"

        if not def_file.is_file():
            print(f"DEF file not found: {def_file}", file=sys.stderr)
            return

        # Read DEF definitions
        graph_args = []
        with open(def_file) as f:
            for line in f:
                line = line.rstrip("\n")
                if not line or line.startswith("#"):
                    continue
                line = line.replace("$RRD", str(rrdf))
                graph_args.append(line)

        # Build extra args
        all_extra = []
        if extra:
            try:
                extra_args = shlex.split(extra)
                all_extra.extend(extra_args)
            except ValueError:
                pass

        if mode == "visual":
            all_extra += ["--graph-render-mode", "normal"]

        all_extra += [
            "--color", "CANVAS#000000",
            "--color", "FONT#FFFFFF",
            "--color", "BACK#000000",
        ]

        subprocess.run(
            [
                self.rrdtool,
                "graph",
                str(self.rrdoutput / f"{imgbase}.svg"),
            ]
            + all_extra
            + [
                "-M",
                "-a",
                "SVG",
                "-s", f"-{back}",
                "-e", "-20",
                "-w", "550",
                "-h", "240",
                "-v", self.RRDgUM.get(n_str, ""),
                "-t", title,
            ]
            + graph_args,
            check=True,
        )

    def create_html_index(self):
        self.rrdoutput.mkdir(parents=True, exist_ok=True)
        htmlindex = self.rrdoutput / "storj.html"
        if not htmlindex.is_file():
            with open(htmlindex, "w") as f:
                f.write(
                    "<head><title>RRDStorm</title>\n"
                    "    <style>body{background:white;color:black}</style></head>\n"
                    "    <body><h1>RRDStorm</h1><ul>\n"
                )

    def handle_create(self, N):
        n_str = str(N)
        meta_files = list(self.defsdir.glob(f"{N}-*.meta"))
        meta_file = meta_files[0] if meta_files else None
        if not meta_file:
            print(f"Warning: No metadata file found for index {N}", file=sys.stderr)
            return

        filebase = self.RRDcFILE[n_str].split(":")[0]
        rrdf = self.rrddata / f"{filebase}.rrd"
        htmlfile = self.rrdoutput / f"{filebase}.html"
        step = self.RRDcFILE[n_str].split(":")[1]
        htitle = self.RRDcFILE[n_str].split(":")[2]

        override = os.environ.get("WRAP_TIME_OVERRIDE")
        if override:
            H, M = override.split(":")
            date_str = f"{H}:{M}"
        else:
            date_str = _datetime.now().strftime("%x %R")

        print(f"Vars: HTMLFILE {htmlfile}, STEP {step}, HTITLE {htitle}", flush=True)

        self.rrddata.mkdir(parents=True, exist_ok=True)
        if not rrdf.is_file():
            self.create_rrd(rrdf, step, self.RRDcDEF[n_str])

        if not htmlfile.is_file():
            with open(htmlfile, "w") as f:
                f.write(
                    f"<head><title>{htitle}</title>\n"
                    "    <style>body{background:white;color:black}</style></head>\n"
                    f'<body style="background-color:black;color:lightgray"><h1>{htitle}</h1><center>\n'
                )
                for p_str in self.RRDgLIST.get(n_str, "").split():
                    if p_str not in self.RRDgGRAPH:
                        continue
                    imgbase = self.RRDgGRAPH[p_str].split("|")[1]
                    p = int(p_str)
                    print(f"{p} in ({N}): <img src=\"{imgbase}.svg\"><br>", flush=True)
                    f.write(f"<img src=\"{imgbase}.svg\"><br>\n")
                f.write(f"</center><p>RRDStorm for {self._version()} / {date_str}</p></body>\n")

            # Create timed dashboards
            for timed_line in ["4h:4 Hours dashboard:12 19 54 24 30 48 36 42", "1d:1 Day dashboard:13 20 56 26 32 50 38 44"]:
                parts = timed_line.split(":")
                timed_filename = parts[0]
                timed_file_title = parts[1]
                timed_file_sources = parts[2]
                dash_file = self.rrdoutput / f"{timed_filename}.html"
                with open(dash_file, "w") as f:
                    f.write(
                        f"<head><title>{timed_file_title}</title>\n"
                        "    <style>body{background:white;color:black}</style></head>\n"
                        f'<body style="background-color:black;color:lightgray"><h1>{timed_file_title}</h1><center>\n'
                    )
                    for p_str in timed_file_sources.split():
                        if p_str not in self.RRDgGRAPH:
                            continue
                        imgbase = self.RRDgGRAPH[p_str].split("|")[1]
                        html_base_idx = int(p_str) // 6
                        html_base = self.RRDcFILE[str(html_base_idx)].split(":")[0]
                        f.write(f"<a href=\"{html_base}.html\"><img src=\"{imgbase}.svg\"></a><br>\n")
                    f.write(f"</center><p>RRDStorm for {self._version()} / {date_str}</p></body>\n")

        # Update HTML index
        return True

    def handle_update(self, N):
        n_str = str(N)
        meta_files = list(self.defsdir.glob(f"{N}-*.meta"))
        meta_file = meta_files[0] if meta_files else None
        if not meta_file:
            print(f"Warning: No metadata file found for index {N}", file=sys.stderr)
            return
        if n_str not in self.RRDcFILE:
            return
        filebase = self.RRDcFILE[n_str].split(":")[0]
        rrdf = self.rrddata / f"{filebase}.rrd"

        extractor = self.datadir / f"{N}-{filebase}.sh"
        if extractor.is_file():
            try:
                result = subprocess.run(
                    [extractor],
                    capture_output=True,
                    text=True,
                    timeout=30,
                )
            except Exception as e:
                print(f"ERROR: Extractor {extractor} failed: {e}", file=sys.stderr)
                return

            if result.returncode != 0:
                print(
                    f"ERROR: Extractor {extractor} failed with exit code {result.returncode}",
                    file=sys.stderr,
                )
                return

            val = result.stdout.strip()
            if not val:
                print(f"Warning: Extractor {extractor} returned empty data. Skipping update.", file=sys.stderr)
                return

            print(f"Updating ({N}) {rrdf} with {val} ..", flush=True)

            # Run update_rrd_db.sh
            update_script = Path(self.script_dir) / "update_rrd_db.sh"
            subprocess.run(
                ["bash", update_script, rrdf, self.RRDuSRC.get(n_str, ""), val],
                check=True,
            )
        else:
            print(f"ERROR: Data extractor not found: {extractor}", file=sys.stderr)

    def _get_time(self):
        """Get current hour and minute using native datetime.

        Respects WRAP_TIME_OVERRIDE for test parity with bash (which uses
        the system `date` command). Format: "HH:MM" (e.g. "12:30").
        """
        override = os.environ.get("WRAP_TIME_OVERRIDE")
        if override:
            H, M = override.split(":")
            return M, H
        now = _datetime.now()
        return now.strftime("%M"), now.strftime("%H")

    def handle_graph(self, N):
        n_str = str(N)
        if n_str not in self.RRDcFILE:
            return
        filebase = self.RRDcFILE[n_str].split(":")[0]
        rrdf = self.rrddata / f"{filebase}.rrd"
        M, H = self._get_time()
        for p_str in self.RRDgLIST.get(n_str, "").split():
            self.create_graph(N, int(p_str), rrdf, M, H, "visual")

    def handle_graph_cron(self, cron_time, N):
        M, H = self._get_time()

        cron_map = {"s": 0, "h": 1, "d": 2, "w": 3, "m": 4, "y": 5}
        if cron_time not in cron_map:
            print(f"ERROR: Invalid cron graph time '{cron_time}'", file=sys.stderr)
            sys.exit(1)

        cron_sub = cron_map[cron_time]
        P = (((N + 1) * 6) - 6) + cron_sub

        n_str = str(N)
        if n_str in self.RRDcFILE:
            filebase = self.RRDcFILE[n_str].split(":")[0]
            rrdf = self.rrddata / f"{filebase}.rrd"
        else:
            rrdf = None

        self.create_graph(N, P, rrdf, M, H, "cron")

    def _version(self):
        """Get version string from config.sh."""
        config_path = Path(self.script_dir) / "config.sh"
        if config_path.is_file():
            with open(config_path) as f:
                for line in f:
                    m = re.match(r'^VERSION="([^"]*)"', line)
                    if m:
                        return m.group(1)
        return "raio"




def _make_handler(method_name):
    """Create a handler that calls the given method for each number."""
    method = getattr(RRDStorm, method_name)
    def handler(app, numbers):
        for N in numbers:
            method(app, N)
    return handler


def _make_cron_handler():
    """Create a cron handler that iterates over numbers."""
    def handler(app, numbers):
        for N in numbers:
            RRDStorm.handle_graph_cron(app, app.args.cron_graph_time, N)
    return handler


class _Parser(argparse.ArgumentParser):
    """Custom parser that produces bash-compatible error messages."""

    def error(self, message):
        # Handle "invalid choice" errors for subcommands
        if "invalid choice:" in message:
            m = re.search(r"invalid choice: '([^']+)'", message)
            if m:
                bad_cmd = m.group(1)
                print(
                    f"ERROR: Unknown command '{bad_cmd}'. Run 'wrapper.sh help' for usage.",
                    file=sys.stderr,
                )
                sys.exit(1)
        super().error(message)


def main():
    parser = _Parser(description="RRDStorm Wrapper")

    # Global flags
    parser.add_argument("--rrdtool", default=None)
    parser.add_argument("--rrddata", default=None)
    parser.add_argument("--rrdoutput", default=None)
    parser.add_argument("--forcegraph", default=None)

    # Subparsers for commands
    subparsers = parser.add_subparsers(dest="command")

    # help: prints usage and exits (no positional args)
    subparsers.add_parser("help")

    # create, update, graph: command + one or more numbers
    for cmd, method in (("create", "handle_create"), ("update", "handle_update"), ("graph", "handle_graph")):
        p = subparsers.add_parser(cmd)
        p.add_argument("numbers", type=int, nargs="+")
        # Wrap the unbound method to iterate over numbers
        p.set_defaults(func=_make_handler(method))

    # graph_cron: command + cron_time + one or more numbers
    p_cron = subparsers.add_parser("graph_cron")
    p_cron.add_argument("cron_graph_time", choices=["s", "h", "d", "w", "m", "y"])
    p_cron.add_argument("numbers", type=int, nargs="+")
    p_cron.set_defaults(func=_make_cron_handler())

    args = parser.parse_args()

    if args.command is None:
        print("Usage: wrapper.sh {create|update|graph|graph_cron[s h d w m y]} 0 1 2 ..")
        sys.exit(1)

    app = RRDStorm(str(Path(__file__).parent))
    app.args = args

    # Dispatch to the appropriate handler
    if args.command == "help":
        print("Usage: wrapper.sh {create|update|graph|graph_cron[s h d w m y]} 0 1 2 ..")
        print(
            "graph_cron is for cron to quickly update just one graph "
            "per time range [1h=s 4h=h 24h=d 1week=w 1 month=m 1year=y]}"
        )
        sys.exit(0)

    args.func(app, args.numbers)


if __name__ == "__main__":
    main()
