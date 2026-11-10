#!/usr/bin/env python3
"""Generate an unmistakable amber Book Preview icon using Python stdlib only."""
from pathlib import Path
import struct
import zlib

def icon(path, size=1024):
    if size < 32:
        raise ValueError("Icon size too small")
    rows = []
    for y in range(size):
        row = bytearray()
        for x in range(size):
            u, v = x / size, y / size
            # Amber cover, gold book silhouette, cream open pages.
            color = (82, 43, 28, 255)
            if 0.11 < u < 0.89 and 0.14 < v < 0.85:
                color = (165, 95, 39, 255)
            if 0.18 < u < 0.82 and 0.25 < v < 0.74:
                color = (221, 171, 83, 255)
            if 0.22 < u < 0.49 and 0.30 < v < 0.69:
                color = (255, 232, 185, 255)
            if 0.51 < u < 0.78 and 0.30 < v < 0.69:
                color = (255, 232, 185, 255)
            if 0.49 <= u <= 0.51 and 0.28 < v < 0.72:
                color = (95, 45, 24, 255)
            # Strong contrasting top-left preview marker.
            if 0.08 < u < 0.30 and 0.07 < v < 0.19:
                color = (255, 211, 63, 255)
            row.extend(color)
        rows.append(b"\x00" + row)
    def chunk(tag, payload):
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", zlib.crc32(tag + payload) & 0xffffffff)
    data = b"\x89PNG\r\n\x1a\n"
    data += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress(b"".join(rows), 9))
    data += chunk(b"IEND", b"")
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)

if __name__ == "__main__":
    icon("native/REACH/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
