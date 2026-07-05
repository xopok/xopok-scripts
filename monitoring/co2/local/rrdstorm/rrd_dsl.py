from __future__ import annotations

from typing import Union


RPNValue = Union[str, float, int, "RPNVar"]


class RPNVar:
    def __init__(self, name: RPNValue) -> None:
        self.name: str = str(name)

    def __add__(self, other: RPNValue) -> RPNVar:
        return RPNVar(f"{self.name},{other},+")

    def __sub__(self, other: RPNValue) -> RPNVar:
        return RPNVar(f"{self.name},{other},-")

    def __mul__(self, other: RPNValue) -> RPNVar:
        return RPNVar(f"{self.name},{other},*")

    def __truediv__(self, other: RPNValue) -> RPNVar:
        return RPNVar(f"{self.name},{other},/")

    def __str__(self) -> str:
        return self.name


class GraphBuilder:
    def __init__(self, rrd_file: str) -> None:
        self.rrd_file: str = rrd_file
        self.args: list[str] = []
        self._cdef_counter: int = 0

    def def_ds(self, name: str, field: str, cf: str = "AVERAGE") -> RPNVar:
        self.args.append(f"DEF:{name}={self.rrd_file}:{field}:{cf}")
        return RPNVar(name)

    def cdef(self, name: str, expr: RPNValue) -> RPNVar:
        self.args.append(f"CDEF:{name}={expr}")
        return RPNVar(name)

    def vdef(self, name: str, expr: RPNValue) -> None:
        self.args.append(f"VDEF:{name}={expr}")

    def _resolve(self, expr: RPNValue) -> str:
        val_str = str(expr)
        if "," not in val_str:
            return val_str
        name = f"_auto_{self._cdef_counter}"
        self._cdef_counter += 1
        self.args.append(f"CDEF:{name}={val_str}")
        return name

    def area(self, value: RPNValue, color: str, legend: str = "", stack: bool = False) -> None:
        vname = str(value)
        stack_suffix = ":STACK" if stack else ""
        legend_suffix = f":{legend}" if legend else ":"
        self.args.append(f"AREA:{vname}#{color}{legend_suffix}{stack_suffix}")

    def line(self, width: int, value: RPNValue, color: str, legend: str = "", extra: str = "") -> None:
        vname = self._resolve(value)
        legend_suffix = f":{legend}" if legend else ""
        self.args.append(f"LINE{width}:{vname}#{color}{legend_suffix}{extra}")

    def gprint(self, value: RPNValue, fmt: str, cf: str = "") -> None:
        vname = self._resolve(value)
        if cf:
            self.args.append(f"GPRINT:{vname}:{cf}:{fmt}")
        else:
            self.args.append(f"GPRINT:{vname}:{fmt}")

    def hrule(self, value: RPNValue, color: str, legend: str = "") -> None:
        vname = self._resolve(value)
        legend_suffix = f":{legend}" if legend else ""
        self.args.append(f"HRULE:{vname}#{color}{legend_suffix}")

    def compile(self) -> list[str]:
        return self.args
