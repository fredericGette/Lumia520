#!/usr/bin/env python3
"""Decode WNF state names into the "Owner, sequence" column used in content/*/*.md.

Usage:
    python wnf.py 0x418A063EA3BD9075 0x418A063EA3BC3075 ...
    python wnf.py 0xA3BD9075:0x418A063E      (low:high dwords, as seen in ARM code)
"""
import sys

XOR = 0x41C64E6DA3BC0074
LIFETIME = ["well-known", "permanent", "persistent", "temporary"]
SCOPE = ["system", "session", "user", "process", "machine"]


def decode(name: int) -> str:
    v = name ^ XOR
    version = v & 0xF
    lifetime = (v >> 4) & 0x3
    scope = (v >> 6) & 0xF
    permanent = (v >> 10) & 0x1
    sequence = (v >> 11) & 0x1FFFFF
    owner = (v >> 32).to_bytes(4, "little").rstrip(b"\0").decode("ascii", "replace")
    return (f"0x{name:016X}: owner `{owner}`, sequence {sequence}, version {version}, "
            f"{LIFETIME[lifetime]}, {SCOPE[scope] if scope < len(SCOPE) else scope} scope, "
            f"{'permanent' if permanent else 'not permanent'}")


def parse(arg: str) -> int:
    if ":" in arg:
        lo, hi = (int(x, 0) & 0xFFFFFFFF for x in arg.split(":"))
        return (hi << 32) | lo
    return int(arg, 0) & 0xFFFFFFFFFFFFFFFF


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    for a in sys.argv[1:]:
        print(decode(parse(a)))
