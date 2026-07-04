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

    def def_ds(self, name: str, field: str, cf: str = "AVERAGE") -> RPNVar:
        self.args.append(f"DEF:{name}={self.rrd_file}:{field}:{cf}")
        return RPNVar(name)

    def cdef(self, name: str, expr: RPNValue) -> RPNVar:
        self.args.append(f"CDEF:{name}={expr}")
        return RPNVar(name)

    def vdef(self, name: str, expr: RPNValue) -> None:
        self.args.append(f"VDEF:{name}={expr}")

    def area(self, value: RPNValue, color: str, legend: str = "", stack: bool = False) -> None:
        stack_suffix = ":STACK" if stack else ""
        self.args.append(f"AREA:{value}#{color}:{legend}{stack_suffix}")

    def line(self, width: int, value: RPNValue, color: str, legend: str = "", extra: str = "") -> None:
        self.args.append(f"LINE{width}:{value}#{color}:{legend}{extra}")

    def gprint(self, value: RPNValue, fmt: str, cf: str = None) -> None:
        if cf is not None:
            self.args.append(f"GPRINT:{value}:{cf}:{fmt}")
        else:
            self.args.append(f"GPRINT:{value}:{fmt}")

    def hrule(self, value: RPNValue, color: str, legend: str = "") -> None:
        self.args.append(f"HRULE:{value}#{color}:{legend}")

    def compile(self) -> list[str]:
        return self.args
