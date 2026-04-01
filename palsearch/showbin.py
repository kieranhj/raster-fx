#!/usr/bin/env python3
"""
showbin.py — reconstruct a BBC Master Mode 1 preview PNG from palsearch output.

Accepts either:
  Combined file (21648 bytes):  showbin.py output.bin
  Split files  (1168 + 20480):  showbin.py output.pal output.pic

Palette byte encoding (matches palsearch.py):
    byte = (slot_index << 4) | (bbc_colour ^ 7)

Screen layout: non-linear interleaved — within each 640-byte block, 8 rows
are interleaved byte-by-byte (BBC Mode 1 hardware layout).

Usage:
    python showbin.py output.bin [-o preview.png]
    python showbin.py pal.bin pic.bin [-o preview.png]
"""

import sys
import argparse
import os

try:
    import numpy as np
    from PIL import Image
except ImportError:
    print("ERROR: pip install Pillow numpy", file=sys.stderr)
    sys.exit(1)

# ── Constants ──────────────────────────────────────────────────────────────────

CHUNKSIZE      = 2     # scanlines per section
NUM_SECTIONS   = 128
SCREEN_W       = 320
SCREEN_H       = 256
BYTES_PER_ROW  = 80
CHANGE_PER_ROW = 9
PAL_SIZE       = 16 + CHANGE_PER_ROW * 128   # 1168
SCREEN_SIZE    = 20480


# ── BBC colour / palette helpers ───────────────────────────────────────────────

def col_to_rgb(col: int):
    """BBC colour 0–7 → (R, G, B) each 0 or 255."""
    return (255 if col & 1 else 0,
            255 if col & 2 else 0,
            255 if col & 4 else 0)


def lookup_cols(palette, byte_val: int):
    """ULA bit-extraction: return (c0, c1, c2, c3) for a screen byte."""
    b = byte_val & 0xFF
    out = []
    for _ in range(4):
        idx = (((b & 0x80) >> 4) |
               ((b & 0x20) >> 3) |
               ((b & 0x08) >> 2) |
               ((b & 0x02) >> 1))
        out.append(palette[idx])
        b = ((b << 1) | 1) & 0xFF
    return out


def decode_palette_byte(b: int):
    """Decode a palette byte → (slot_index, bbc_colour)."""
    return b >> 4, (b & 0xF) ^ 7


def screen_offset(section: int, byte_in_section: int) -> int:
    """Byte offset in the 20480-byte screen buffer (matches palsearch.py)."""
    row_start = (section // 4) * 640 + (section % 4) * 2
    return row_start + (byte_in_section % BYTES_PER_ROW) * 8 + (byte_in_section // BYTES_PER_ROW)


# ── Main reconstruction ────────────────────────────────────────────────────────

def reconstruct(pal_data: bytes, pic_data: bytes) -> Image.Image:
    """Build a 320×256 RGB PIL image from palette and screen data."""
    assert len(pal_data) == PAL_SIZE,    f"Expected {PAL_SIZE} palette bytes, got {len(pal_data)}"
    assert len(pic_data) == SCREEN_SIZE, f"Expected {SCREEN_SIZE} screen bytes, got {len(pic_data)}"

    # Decode initial palette (bytes 0–15)
    palette = [0] * 16
    for i in range(16):
        _, colour = decode_palette_byte(pal_data[i])
        palette[i] = colour

    out = np.zeros((SCREEN_H, SCREEN_W, 3), dtype=np.uint8)

    for section in range(NUM_SECTIONS):
        # Apply palette deltas for this section
        if section > 0:
            for slot in range(CHANGE_PER_ROW):
                b = pal_data[16 + slot * 128 + (section - 1)]
                idx, colour = decode_palette_byte(b)
                palette[idx] = colour

        # Render 2 rows of this section
        for row in range(CHUNKSIZE):
            y = section * CHUNKSIZE + row
            for bp in range(BYTES_PER_ROW):
                byte_in_section = row * BYTES_PER_ROW + bp
                off = screen_offset(section, byte_in_section)
                screen_byte = pic_data[off]
                quad = lookup_cols(palette, screen_byte)
                x = bp * 4
                for p, col in enumerate(quad):
                    out[y, x + p] = col_to_rgb(col)

    return Image.fromarray(out, 'RGB')


# ── CLI ────────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(
        description='Reconstruct a BBC Mode 1 preview PNG from palsearch binary output',
        epilog="""
Examples:
    python showbin.py output.bin
    python showbin.py output.bin -o preview.png
    python showbin.py frogpal.bin frogpic.bin -o frog_preview.png
        """,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('files', nargs='+',
                    help='Combined .bin file (21648 bytes), '
                         'or pal.bin + pic.bin (1168 + 20480 bytes)')
    ap.add_argument('-o', '--output',
                    help='Output PNG path (default: input name with .png extension)')
    args = ap.parse_args()

    if len(args.files) == 1:
        path = args.files[0]
        data = open(path, 'rb').read()
        if len(data) != PAL_SIZE + SCREEN_SIZE:
            ap.error(f"{path}: expected {PAL_SIZE + SCREEN_SIZE} bytes, got {len(data)}")
        pal_data = data[:PAL_SIZE]
        pic_data = data[PAL_SIZE:]
        default_out = os.path.splitext(path)[0] + '.png'

    elif len(args.files) == 2:
        pal_path, pic_path = args.files
        pal_data = open(pal_path, 'rb').read()
        pic_data = open(pic_path, 'rb').read()
        default_out = os.path.splitext(pal_path)[0] + '_preview.png'

    else:
        ap.error("Provide one combined file or two files (pal + pic)")

    out_path = args.output or default_out

    img = reconstruct(pal_data, pic_data)
    img.save(out_path)
    print(f"Wrote {out_path}  ({img.width}×{img.height})")


if __name__ == '__main__':
    main()
