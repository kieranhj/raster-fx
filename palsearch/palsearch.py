#!/usr/bin/env python3
"""
palsearch.py  —  Python reimplementation of palsearch.ml

Converts a PNG image to BBC Master Mode 1 screen data with per-2-scanline
palette changes, using Z3 SMT solver for palette constraint solving.

Usage:
    python palsearch.py input.png -o output.bin [-d ordered|fs] [-q]

Output binary format (compatible with showimage.s):
    Bytes 0-15        : Initial palette (16 entries)
    Bytes 16 to 1183  : Per-section deltas:
                          output_palettes[16 + slot*128 + (section-1)]
                          for slot in 0..CHANGE_PER_ROW-1
                          for section in 1..127
    Bytes 1184 onward : Screen data (20480 bytes, BBC non-linear interleaved layout)

Palette byte encoding: (palette_index << 4) | (bbc_colour ^ 7)
    palette_index : which of the 16 ULA palette entries to update
    bbc_colour    : 0-7 (bit0=R, bit1=G, bit2=B), XOR'd with 7 for ULA negative logic

Mode 1 ULA bit-extraction (lookup_cols):
    For each screen byte, 4 pixel colours are extracted by progressively
    shifting left and ORing 1.  Pixel 0 uses bits {b7,b5,b3,b1} as palette
    index; pixel 2 index is (pixel0_index & 7)*2+1 (forced odd); similarly
    pixel 1 is free, pixel 3 index is (pixel1_index & 7)*2+1.

Dependencies:
    pip install z3-solver Pillow numpy
"""

import sys
import argparse
from collections import Counter

import numpy as np

try:
    from PIL import Image
except ImportError:
    print("ERROR: Pillow not installed.  Run: pip install Pillow", file=sys.stderr)
    sys.exit(1)

try:
    import z3
except ImportError:
    print("ERROR: z3-solver not installed.  Run: pip install z3-solver", file=sys.stderr)
    sys.exit(1)

# ── Constants ─────────────────────────────────────────────────────────────────

CHUNKSIZE      = 2    # scanlines per section
CHANGE_PER_ROW = 9    # max palette entries changed between sections
NUM_SECTIONS   = 128  # 256 / CHUNKSIZE
SCREEN_W       = 320  # Mode 1 pixels wide
SCREEN_H       = 256  # scanlines
BYTES_PER_ROW  = 80   # SCREEN_W // 4 pixels-per-byte

INV_GAMMA = 1.7       # inverse gamma applied to input pixels
BORDER    = 0.1       # fraction of range reserved at top and bottom


# ── BBC colour utilities ──────────────────────────────────────────────────────

def col_to_rgb(col: int):
    """BBC colour (0–7) → (R, G, B) each 0 or 255."""
    return (255 if col & 1 else 0,
            255 if col & 2 else 0,
            255 if col & 4 else 0)


def closest_colour(r: int, g: int, b: int) -> int:
    """Quantise 0-255 RGB to nearest BBC colour 0-7."""
    return (1 if r >= 128 else 0) | (2 if g >= 128 else 0) | (4 if b >= 128 else 0)


def lookup_cols(palette, byte_val: int):
    """
    ULA bit-extraction: return (c0, c1, c2, c3) BBC colours for a byte+palette.

    Matches OCaml lookup_cols: tap bits {b7,b5,b3,b1} for the palette index,
    then shift left and OR 1 to advance to the next pixel.
    """
    b = byte_val & 0xFF
    out = []
    for _ in range(4):
        idx = (((b & 0x80) >> 4) |
               ((b & 0x20) >> 3) |
               ((b & 0x08) >> 2) |
               ((b & 0x02) >> 1))
        out.append(palette[idx])
        b = ((b << 1) | 1) & 0xFF
    return tuple(out)


def find_byte_for_quad(palette, quad) -> int | None:
    """Brute-force: find a byte value 0-255 that produces quad with palette."""
    for bv in range(256):
        if lookup_cols(palette, bv) == quad:
            return bv
    return None


def quad_rgb_distance(q1, q2) -> float:
    """Weighted perceptual distance between two colour quads (matches OCaml calc_distance)."""
    total = 0.0
    for a, b in zip(q1, q2):
        r1, g1, b1 = col_to_rgb(a)
        r2, g2, b2 = col_to_rgb(b)
        total += (0.2126 * abs(r1 - r2) +
                  0.7152 * abs(g1 - g2) +
                  0.0722 * abs(b1 - b2))
    return total


# ── Mixes table (matches OCaml mixes()) ──────────────────────────────────────

def _rgb01(col):
    """BBC colour 0-7 → (r,g,b) each 0 or 1 (OCaml rgb_of_col)."""
    return col & 1, (col >> 1) & 1, (col >> 2) & 1

def _intensity01(r, g, b):
    """Perceptual intensity for r,g,b ∈ {0,1} (OCaml intensity)."""
    return 0.2126 * r + 0.7152 * g + 0.0722 * b

def _build_mixes():
    """
    Build the 125-entry mixes table matching OCaml mixes().

    Each entry corresponds to one of the 125 quantised (r/52, g/52, b/52)
    RGB buckets and holds a list of (variance, [c0,c1,c2,c3]) tuples sorted
    by variance ascending.  The four colours in each tuple are ordered
    brightest-to-darkest.

    Deduplication matches OCaml: entries with the same sorted colour list
    (regardless of original ordering) appear only once per bucket.
    """
    buckets = [dict() for _ in range(125)]   # key: sorted-cols tuple → var

    for c1 in range(8):
        for c2 in range(c1, 8):
            for c3 in range(c2, 8):
                for c4 in range(c3, 8):
                    cols = [c1, c2, c3, c4]
                    intensities = [_intensity01(*_rgb01(c)) for c in cols]
                    rv = sum(_rgb01(c)[0] for c in cols)
                    gv = sum(_rgb01(c)[1] for c in cols)
                    bv = sum(_rgb01(c)[2] for c in cols)
                    idx = bv * 25 + gv * 5 + rv
                    mean = sum(intensities) / 4
                    var  = sum((i - mean) ** 2 for i in intensities) / 4
                    # Sort descending by intensity (OCaml: compare i2 i1)
                    sorted_cols = tuple(
                        c for c, _ in sorted(zip(cols, intensities),
                                             key=lambda p: -p[1]))
                    if sorted_cols not in buckets[idx]:
                        buckets[idx][sorted_cols] = var

    result = []
    for bucket in buckets:
        entries = sorted(((var, list(cols)) for cols, var in bucket.items()),
                         key=lambda e: e[0])
        result.append(entries)
    return result

_MIXES_TABLE = _build_mixes()

# Bayer position (dy*2+dx) → index into the descending-intensity colour list.
# Matches OCaml: let offset = [| 0; 3; 2; 1 |]
_DITHER2_POS = [0, 3, 2, 1]


def ordered_dither_2(x: int, y: int, r: int, g: int, b: int, mixno: int = 0) -> int:
    """
    Colour-aware 2×2 ordered dither (matches OCaml ordered_dither_2).

    Quantises (r,g,b) into a 5-level bucket, selects a 4-BBC-colour
    combination from the precomputed mixes table that averages to that bucket,
    then returns the colour for spatial position (x,y) using the Bayer pattern
    applied to the descending-intensity-sorted colour list.
    """
    r5  = r // 52
    g5  = g // 52
    b5  = b // 52
    idx = b5 * 25 + g5 * 5 + r5
    bucket = _MIXES_TABLE[idx]
    _, col_list = bucket[min(mixno, len(bucket) - 1)]
    return col_list[_DITHER2_POS[(y & 1) * 2 + (x & 1)]]


# ── Image preprocessing ───────────────────────────────────────────────────────

def preprocess_pixel(r: int, g: int, b: int):
    """
    Apply inverse gamma and border clamping, matching OCaml get_rgb.
    Returns (r, g, b) in 0-255, with contrast compressed by BORDER.
    """
    cr = BORDER + (1.0 - BORDER * 2.0) * (r / 255.0) ** INV_GAMMA
    cg = BORDER + (1.0 - BORDER * 2.0) * (g / 255.0) ** INV_GAMMA
    cb = BORDER + (1.0 - BORDER * 2.0) * (b / 255.0) ** INV_GAMMA
    return int(cr * 255), int(cg * 255), int(cb * 255)


# ── Dithering ─────────────────────────────────────────────────────────────────

def dither_section_ordered(img: np.ndarray, section: int):
    """
    Colour-aware ordered dither for 2 rows of section using the mixes table.

    Matches the OCaml default 'ordered' mode (ordered_dither_2, mixno=0).
    Each pixel is mapped to a 5-level RGB bucket; a 4-BBC-colour combination
    is selected from the precomputed mixes table and assigned to spatial
    positions via a Bayer pattern over the sorted colour list.

    Returns a list of 160 quads in screen order:
    [row0_byte0, …, row0_byte79, row1_byte0, …, row1_byte79].
    """
    quads = []
    for row in range(CHUNKSIZE):
        y = section * CHUNKSIZE + row
        for bp in range(BYTES_PER_ROW):
            pix = []
            for p in range(4):
                x = bp * 4 + p
                pr, pg, pb = preprocess_pixel(
                    int(img[y, x, 0]), int(img[y, x, 1]), int(img[y, x, 2]))
                col = ordered_dither_2(x, y, pr, pg, pb)
                pix.append(col)
            quads.append(tuple(pix))
    return quads


def dither_section_fs(img: np.ndarray, section: int, err: np.ndarray):
    """
    Floyd-Steinberg dither for 2 rows.

    err : shape (3, SCREEN_W) float array holding accumulated error for the
          current row.  Updated in-place; errors propagate across section
          boundaries (matching OCaml where the error arrays persist across
          calls to attempt()).

    Returns list of 160 quads in screen order.
    """
    quads = []
    for row in range(CHUNKSIZE):
        y = section * CHUNKSIZE + row
        next_err = np.zeros((3, SCREEN_W), dtype=float)
        for bp in range(BYTES_PER_ROW):
            pix = []
            for p in range(4):
                x = bp * 4 + p
                pr, pg, pb = preprocess_pixel(
                    int(img[y, x, 0]), int(img[y, x, 1]), int(img[y, x, 2]))
                this_r = max(0, min(255, pr + int(err[0, x])))
                this_g = max(0, min(255, pg + int(err[1, x])))
                this_b = max(0, min(255, pb + int(err[2, x])))
                col = closest_colour(this_r, this_g, this_b)
                sel_r, sel_g, sel_b = col_to_rgb(col)
                er = this_r - sel_r
                eg = this_g - sel_g
                eb = this_b - sel_b
                if x < SCREEN_W - 1:
                    err[0, x+1]      += er * 7/16
                    err[1, x+1]      += eg * 7/16
                    err[2, x+1]      += eb * 7/16
                    next_err[0, x+1] += er * 1/16
                    next_err[1, x+1] += eg * 1/16
                    next_err[2, x+1] += eb * 1/16
                if x > 0:
                    next_err[0, x-1] += er * 3/16
                    next_err[1, x-1] += eg * 3/16
                    next_err[2, x-1] += eb * 3/16
                next_err[0, x] += er * 5/16
                next_err[1, x] += eg * 5/16
                next_err[2, x] += eb * 5/16
                pix.append(col)
            quads.append(tuple(pix))
        # Propagate: next row's starting error comes from this row's diffused error
        err[:] = next_err
    return quads


# ── Z3 palette solver ─────────────────────────────────────────────────────────

def _add_quad_constraint(solver, pal, quad):
    """
    Add Z3 constraints asserting that quad (c0,c1,c2,c3) is achievable.

    Derivation from ULA bit-extraction coupling:
        p2_index = (p0_index % 8) * 2 + 1
        p3_index = (p1_index % 8) * 2 + 1

    So for a given group g in 0..7:
        idx2 = g*2+1;  p0 index can be g or g+8 (both map to same idx2)
        idx3 = g*2+1;  p1 index can be g or g+8

    The two constraints are independent (p0/p2 and p1/p3 use separate bit
    planes of the byte), so they are added as separate OR clauses.
    """
    c0, c1, c2, c3 = quad

    alts_02 = []
    alts_13 = []
    for g in range(8):
        idx_odd = g * 2 + 1           # forced-odd palette index (for p2/p3)
        for idx_free in (g, g + 8):   # two free indices that both map to idx_odd
            alts_02.append(z3.And(pal[idx_free] == c0, pal[idx_odd] == c2))
            alts_13.append(z3.And(pal[idx_free] == c1, pal[idx_odd] == c3))

    solver.add(z3.Or(*alts_02))
    solver.add(z3.Or(*alts_13))


def solve_palette(required_quads, previous_palette=None):
    """
    Find a 16-entry BBC palette satisfying all required_quads.

    previous_palette : list of 16 colours from the previous section, or None.
                       If given, at least (16 - CHANGE_PER_ROW) entries must
                       remain unchanged (the OCaml constrain_previous_palette).

    Returns (palette_list, matched_dict) on SAT, or None on UNSAT.
    matched_dict maps quad → byte_value.
    """
    s = z3.Solver()
    pal = [z3.Int(f'p{i}') for i in range(16)]
    for p in pal:
        s.add(p >= 0, p <= 7)

    for quad in required_quads:
        _add_quad_constraint(s, pal, quad)

    if previous_palette is not None:
        same = [z3.If(pal[i] == int(previous_palette[i]),
                      z3.IntVal(1), z3.IntVal(0))
                for i in range(16)]
        s.add(z3.Sum(same) >= 16 - CHANGE_PER_ROW)

    if s.check() != z3.sat:
        return None

    model = s.model()
    palette = [model[pal[i]].as_long() for i in range(16)]

    matched = {}
    for quad in required_quads:
        bv = find_byte_for_quad(palette, quad)
        if bv is not None:
            matched[quad] = bv

    return palette, matched


# ── Per-section palette search ────────────────────────────────────────────────

def find_palette_for_section(sorted_quads, previous_palette, verbose=True):
    """
    Find a palette for this section via binary search, then best-effort fallback.

    sorted_quads : list of (quad, count) sorted by count descending.
    Returns (palette, matched_dict, besteffort_dict).

    Strategy (simplified from OCaml search_down / find_splitpoint):
      1. Try satisfying all unique quads.
      2. If UNSAT, binary-search for the longest satisfiable prefix.
      3. For remaining quads, brute-force the closest achievable quad.
    """
    all_quads = [q for q, _ in sorted_quads]
    n = len(all_quads)

    if n == 0:
        palette = list(previous_palette) if previous_palette else [0] * 16
        return palette, {}, {}

    # Try satisfying everything first
    result = solve_palette(all_quads, previous_palette)
    if result:
        palette, matched = result
        if verbose:
            print(f"    All {n} unique quads satisfied")
        return palette, matched, {}

    # Binary search for maximum satisfiable prefix
    best_result = None
    best_split  = -1

    # Check that at least the top-1 quad is satisfiable
    r1 = solve_palette(all_quads[:1], previous_palette)
    if r1 is None:
        # Continuity constraint is too tight even for 1 quad — drop it
        r1 = solve_palette(all_quads[:1], None)
        if r1 is None:
            raise RuntimeError("Single-quad solve failed even without continuity")
        if verbose:
            print("    Warning: continuity constraint dropped for 1-quad fallback")
        previous_palette = None   # drop continuity for the binary search too

    best_result = r1
    best_split  = 0

    lo, hi = 1, n
    while lo < hi - 1:
        mid = (lo + hi) // 2
        if verbose:
            print(f"    Binary search {lo}–{hi}: trying {mid+1} quads ...",
                  end=' ', flush=True)
        r = solve_palette(all_quads[:mid + 1], previous_palette)
        if r is not None:
            if verbose:
                print("SAT")
            best_result = r
            best_split  = mid
            lo = mid
        else:
            if verbose:
                print("UNSAT")
            hi = mid

    palette, matched = best_result
    if verbose:
        print(f"    Satisfied {best_split + 1}/{n} unique quads; "
              f"{n - best_split - 1} best-effort")

    # Best-effort: for each unsatisfied quad, find the closest achievable byte
    besteffort = {}
    for quad in all_quads[best_split + 1:]:
        best_dist = float('inf')
        best_bv   = 0
        for bv in range(256):
            dist = quad_rgb_distance(quad, lookup_cols(palette, bv))
            if dist < best_dist:
                best_dist = dist
                best_bv   = bv
        besteffort[quad] = best_bv

    return palette, matched, besteffort


# ── Screen byte layout ────────────────────────────────────────────────────────

def screen_offset(section: int, byte_in_section: int) -> int:
    """
    Byte offset into the 20480-byte screen buffer for a given section and
    per-section byte index (0..159).

    Matches OCaml:
        row_start = (section / 4) * 640 + (section mod 4) * 2
        offset    = row_start + (idx mod 80) * 8 + (idx / 80)

    This produces the BBC non-linear interleaved layout: within each 640-byte
    block, 8 rows are interleaved byte-by-byte (each row's bytes are 8 apart).
    """
    row_start = (section // 4) * 640 + (section % 4) * 2
    return row_start + (byte_in_section % 80) * 8 + (byte_in_section // 80)


# ── Main pipeline ─────────────────────────────────────────────────────────────

def process_image(png_path: str, output_path: str,
                  dither: str = 'ordered', verbose: bool = True,
                  preview_path: str = None):
    """
    Load a PNG, resize to 320×256, run the palsearch algorithm for all 128
    sections, and write the output binary.

    Output layout:
        Bytes 0–1167  : palette data (16-byte initial + 9*128 delta bytes)
        Bytes 1168+   : 20480 bytes of BBC screen data

    If preview_path is given, also write a 320×256 PNG showing the actual
    colours that will appear on the BBC (i.e. after palette solve and
    best-effort fallback, not the dithered input).
    """
    # Load and resize
    img = Image.open(png_path).convert('RGB')
    if img.size != (SCREEN_W, SCREEN_H):
        if verbose:
            print(f"Resizing {img.size} → ({SCREEN_W}×{SCREEN_H})")
        img = img.resize((SCREEN_W, SCREEN_H), Image.LANCZOS)
    arr = np.array(img, dtype=np.uint8)

    output_palettes = bytearray(16 + CHANGE_PER_ROW * 128)  # 1168 bytes
    screen_bytes    = bytearray(20480)

    previous_palette = None
    fs_err = np.zeros((3, SCREEN_W), dtype=float)   # FS error diffusion state

    # Preview buffer: RGB pixels at native 320×256
    preview_arr = np.zeros((SCREEN_H, SCREEN_W, 3), dtype=np.uint8) if preview_path else None

    for section in range(NUM_SECTIONS):
        if verbose:
            print(f"\nSection {section}/{NUM_SECTIONS - 1}:")
            sys.stdout.flush()

        # ── Dither ────────────────────────────────────────────────────────────
        if dither == 'ordered':
            quads = dither_section_ordered(arr, section)
        else:
            quads = dither_section_fs(arr, section, fs_err)

        counts      = Counter(quads)
        sorted_quads = sorted(counts.items(), key=lambda x: -x[1])

        if verbose:
            print(f"  {len(sorted_quads)} unique quads from 160 bytes")

        # ── Solve ─────────────────────────────────────────────────────────────
        palette, matched, besteffort = find_palette_for_section(
            sorted_quads, previous_palette, verbose=verbose)

        # ── Write screen bytes & preview ───────────────────────────────────────
        for idx, quad in enumerate(quads):
            off = screen_offset(section, idx)
            if off < 20480:
                bv = matched.get(quad, besteffort.get(quad, 0))
                screen_bytes[off] = bv

            if preview_arr is not None:
                # Reconstruct the four pixel colours actually stored
                actual_quad = lookup_cols(palette,
                                          matched.get(quad, besteffort.get(quad, 0)))
                row_in_section = idx // BYTES_PER_ROW
                bp             = idx  % BYTES_PER_ROW
                y = section * CHUNKSIZE + row_in_section
                for p, col in enumerate(actual_quad):
                    x = bp * 4 + p
                    preview_arr[y, x] = col_to_rgb(col)

        # ── Write palette data ─────────────────────────────────────────────────
        if section == 0:
            # Initial palette: one byte per entry
            for i in range(16):
                output_palettes[i] = (i << 4) | (palette[i] ^ 7)
        else:
            # Delta from previous: write only changed (or forced-change) entries.
            # Matches OCaml: once same_no >= (16 - change_per_row) the rest are
            # forced into the change list even if they didn't actually change.
            same_no   = 0
            change_no = 0
            for i in range(16):
                entry_changed = (palette[i] != previous_palette[i])
                force_change  = (same_no >= 16 - CHANGE_PER_ROW)
                if force_change or entry_changed:
                    if verbose and entry_changed:
                        print(f"  Entry {i}: {previous_palette[i]} → {palette[i]}")
                    if change_no >= CHANGE_PER_ROW:
                        raise AssertionError(
                            f"Section {section}: more than {CHANGE_PER_ROW} "
                            "palette changes required — solver bug")
                    output_palettes[16 + change_no * 128 + (section - 1)] = \
                        (i << 4) | (palette[i] ^ 7)
                    change_no += 1
                else:
                    same_no += 1

        previous_palette = list(palette)

    # ── Write output file ──────────────────────────────────────────────────────
    with open(output_path, 'wb') as f:
        f.write(output_palettes)
        f.write(screen_bytes)

    if verbose:
        total = len(output_palettes) + len(screen_bytes)
        print(f"\nWrote {output_path}: {total} bytes "
              f"({len(output_palettes)} palette + {len(screen_bytes)} screen)")

    # ── Write preview PNG ──────────────────────────────────────────────────────
    if preview_path is not None:
        Image.fromarray(preview_arr, 'RGB').save(preview_path)
        if verbose:
            print(f"Wrote preview {preview_path}")


# ── CLI ───────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(
        description='BBC Master Mode 1 palette search (Python port of palsearch.ml)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python palsearch.py photo.png -o frog.bin
    python palsearch.py photo.png -o frog.bin -d fs
    python palsearch.py photo.png -o frog.bin -p preview.png
    python palsearch.py photo.png -o frog.bin -q

The output binary is compatible with showimage.s for playback on BBC Master.
        """)
    ap.add_argument('input',
                    help='Input PNG file (auto-resized to 320×256)')
    ap.add_argument('-o', '--output', default='output.bin',
                    help='Output binary file (default: output.bin)')
    ap.add_argument('-d', '--dither', choices=['ordered', 'fs'], default='ordered',
                    help=('Dithering method: '
                          'ordered = Bayer 2×2 (default), '
                          'fs = Floyd-Steinberg'))
    ap.add_argument('-p', '--preview',
                    help='Write a preview PNG of the converted image')
    ap.add_argument('-q', '--quiet', action='store_true',
                    help='Suppress per-section progress output')
    args = ap.parse_args()

    process_image(args.input, args.output,
                  dither=args.dither, verbose=not args.quiet,
                  preview_path=args.preview)


if __name__ == '__main__':
    main()
