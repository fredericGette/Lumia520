#!/usr/bin/env python3
"""Decode Windows IOCTL codes (CTL_CODE) into the Property/Value table used in content/drivers/*.md.

Usage:
    python ioctl.py 0x80180FA0 0x22003 ...
    python ioctl.py --encode <device> <function> <method> <access>
"""
import sys

METHODS = ["METHOD_BUFFERED", "METHOD_IN_DIRECT", "METHOD_OUT_DIRECT", "METHOD_NEITHER"]
ACCESS = ["FILE_ANY_ACCESS", "FILE_READ_ACCESS", "FILE_WRITE_ACCESS", "READ_AND_WRITE"]


def decode(code: int) -> str:
    device = (code >> 16) & 0xFFFF
    access = (code >> 14) & 0x3
    function = (code >> 2) & 0xFFF
    method = code & 0x3
    return "\n".join([
        f"IOCTL 0x{code:X}",
        "",
        "| Property | Value |",
        "|----------|-------|",
        f"| Device | 0x{device:X} |",
        f"| Function | 0x{function:X} ({function}) |",
        f"| Access | {ACCESS[access]} |",
        f"| Method | {METHODS[method]} |",
    ])


def encode(device: int, function: int, method: int, access: int) -> int:
    return (device << 16) | (access << 14) | (function << 2) | method


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(1)
    if args[0] == "--encode":
        d, f, m, a = (int(x, 0) for x in args[1:5])
        print(f"0x{encode(d, f, m, a):X}")
    else:
        print("\n\n".join(decode(int(a, 0)) for a in args))
