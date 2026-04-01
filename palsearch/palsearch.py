#!/usr/bin/env python3
"""
palsearch.py  —  Python reimplementation of palsearch.ml

Converts a PNG image to BBC Master Mode 1 screen data with per-2-scanline
palette changes, using a greedy palette solver with numpy-accelerated fallback.

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
    pip install Pillow numpy
"""

import sys
import argparse
import random
from collections import Counter

import numpy as np

try:
    from PIL import Image
except ImportError:
    print("ERROR: Pillow not installed.  Run: pip install Pillow", file=sys.stderr)
    sys.exit(1)

try:
    import z3 as _z3_mod
    _Z3_AVAILABLE = True
except ImportError:
    _Z3_AVAILABLE = False

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


# ── Fast quad achievability check (used by 2-step look-ahead) ────────────────

def _quad_achievable(palette, c0, c1, c2, c3):
    """
    Return True if quad (c0,c1,c2,c3) is achievable with the given palette.

    Uses the group structure that mirrors the Z3 constraint encoding:
      group g (0–7) has odd slot g*2+1 and free slots g and g+8.
    A quad is achievable iff:
      ∃ group g1: palette[g1*2+1]=c2 AND (palette[g1]=c0 OR palette[g1+8]=c0)
      ∃ group g2: palette[g2*2+1]=c3 AND (palette[g2]=c1 OR palette[g2+8]=c1)
    O(8) — much faster than scanning all 256 byte values.
    """
    found1 = any(palette[g*2+1] == c2 and (palette[g] == c0 or palette[g+8] == c0)
                 for g in range(8))
    if not found1:
        return False
    return any(palette[g*2+1] == c3 and (palette[g] == c1 or palette[g+8] == c1)
               for g in range(8))


# ── Precomputed slot→bytes map (used by hill-climbing greedy) ─────────────────

def _compute_slot_bytes():
    """For each palette slot s, which byte values b reference palette[s]?"""
    slot_bytes = [set() for _ in range(16)]
    for b in range(256):
        byte = b
        for _ in range(4):
            idx = (((byte & 0x80) >> 4) |
                   ((byte & 0x20) >> 3) |
                   ((byte & 0x08) >> 2) |
                   ((byte & 0x02) >> 1))
            slot_bytes[idx].add(b)
            byte = ((byte << 1) | 1) & 0xFF
    return [sorted(s) for s in slot_bytes]

_SLOT_BYTES = _compute_slot_bytes()


# ── Numpy colour table (used by best-effort vectorised fallback) ───────────────

_BBC_RGB_NP = np.array([[255 if c & 1 else 0,
                          255 if c & 2 else 0,
                          255 if c & 4 else 0] for c in range(8)], dtype=np.float32)
_PERC_WEIGHTS = np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)


def _best_effort_numpy(palette, unmatched_quads):
    """
    Option B: numpy-vectorised best-effort fallback.

    For each quad in unmatched_quads, find the byte value 0-255 whose
    lookup_cols result has the smallest perceptual distance to that quad.
    Replaces the O(256 × n_unmatched) Python loop with numpy operations.
    """
    if not unmatched_quads:
        return {}
    # (256, 4) — BBC colour index for each byte value × 4 pixels
    all_arr = np.array([lookup_cols(palette, b) for b in range(256)], dtype=np.int32)
    # (256, 4, 3) — RGB for each (byte, pixel)
    all_rgb = _BBC_RGB_NP[all_arr]
    besteffort = {}
    for quad in unmatched_quads:
        quad_rgb = _BBC_RGB_NP[np.array(quad, dtype=np.int32)]   # (4, 3)
        diffs = np.abs(all_rgb - quad_rgb[np.newaxis, :, :])      # (256, 4, 3)
        dists = (diffs * _PERC_WEIGHTS).sum(axis=(1, 2))           # (256,)
        besteffort[quad] = int(np.argmin(dists))
    return besteffort


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

def dither_section_ordered(img: np.ndarray, section: int, randomness: int = 64):
    """
    Colour-aware ordered dither for 2 rows of section using the mixes table.

    Matches the OCaml default 'ordered' mode (ordered_dither_2, mixno=0).
    Each pixel is mapped to a 5-level RGB bucket; a 4-BBC-colour combination
    is selected from the precomputed mixes table and assigned to spatial
    positions via a Bayer pattern over the sorted colour list.

    randomness (0–255): per-pixel correlated random bias applied before bucket
    assignment, matching OCaml's -random flag (default 64).  A single random
    value is drawn per pixel and scaled by perceptual channel weights
    (R×54/256, G×183/256, B×18/256), then added to the preprocessed colour.
    Set to 0 to disable.

    Returns a list of 160 quads in screen order:
    [row0_byte0, …, row0_byte79, row1_byte0, …, row1_byte79].
    """
    r_rand = (randomness * 54) // 256
    g_rand = (randomness * 183) // 256
    b_rand = (randomness * 18) // 256

    quads = []
    for row in range(CHUNKSIZE):
        y = section * CHUNKSIZE + row
        for bp in range(BYTES_PER_ROW):
            pix = []
            for p in range(4):
                x = bp * 4 + p
                pr, pg, pb = preprocess_pixel(
                    int(img[y, x, 0]), int(img[y, x, 1]), int(img[y, x, 2]))
                if randomness:
                    rnd = random.randint(0, 255) - 128
                    pr = max(0, min(255, pr + (rnd * r_rand) // 256))
                    pg = max(0, min(255, pg + (rnd * g_rand) // 256))
                    pb = max(0, min(255, pb + (rnd * b_rand) // 256))
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


# ── Greedy palette solver (Option A) ──────────────────────────────────────────

_LOOK_AHEAD_K = 3       # top-K unmatched quads considered for 2-step look-ahead
_LOOK_AHEAD_FACTOR = 1.0  # weight of look-ahead gain relative to direct gain


def _greedy_palette(sorted_quads_with_counts, previous_palette=None,
                    look_ahead=False):
    """
    Option A: hill-climbing greedy palette solver replacing Z3.

    At each of up to CHANGE_PER_ROW budget steps, evaluates every possible
    single-slot change (16 slots × 7 values = 112 candidates) and applies the
    one that maximises the frequency-weighted coverage of required quads.

    Two-step look-ahead: for the top-K highest-frequency unmatched quads,
    checks whether any follow-up single-slot change (given this step applied)
    would make the quad achievable.  If so, credits the quad's frequency as a
    look-ahead bonus.  This prevents the greedy from always choosing orange when
    a two-change sequence (e.g. odd-slot→7 then free-slot→7) would unlock white.

    Achievability is tested with _quad_achievable() in O(8) using the BBC ULA
    group structure, so the look-ahead adds only modest overhead per section.

    sorted_quads_with_counts : list of (quad, count) sorted by count descending.
    Returns (palette, matched_dict).  Never exceeds CHANGE_PER_ROW budget;
    unmatched quads fall through to best-effort.
    """
    prev = list(previous_palette) if previous_palette else [0] * 16
    palette = list(prev)
    has_budget = previous_palette is not None
    budget = CHANGE_PER_ROW if has_budget else 16

    freq = {q: cnt for q, cnt in sorted_quads_with_counts}
    required_set = set(freq)
    if not required_set:
        return palette, {}

    # Current quad for each byte value, and a coverage counter
    quads = [lookup_cols(palette, b) for b in range(256)]
    achievable_cnt = Counter(quads)   # quad → number of bytes producing it

    # Slots already changed from prev (for budget tracking)
    changed: set = set()

    for _step in range(budget):
        # Top-K unmatched quads for look-ahead (re-evaluated each step)
        top_unmatched = sorted(
            [(q, freq[q]) for q in required_set if achievable_cnt[q] == 0],
            key=lambda x: -x[1]
        )[:_LOOK_AHEAD_K]

        # Precompute follow-up candidates per unmatched quad: any (slot, val)
        # where val is one of the target colours for that quad.  The
        # achievability check will filter out combinations that don't help.
        quad_follow_ups: dict = {}
        for q, _ in top_unmatched:
            c0, c1, c2, c3 = q
            targets = {c0, c1, c2, c3}
            quad_follow_ups[q] = [(s, v) for s in range(16)
                                  for v in targets if palette[s] != v]

        best_gain  = 0.0
        best_slot  = None
        best_val   = None

        for slot in range(16):
            for val in range(8):
                if val == palette[slot]:
                    continue
                # Budget guard: only count as a change if slot not already changed
                # and new value differs from prev
                if has_budget:
                    if slot not in changed and val != prev[slot]:
                        if len(changed) >= budget:
                            continue   # out of budget

                # Compute coverage delta for this candidate change
                old_slot_val = palette[slot]
                palette[slot] = val

                delta: dict = {}
                for b in _SLOT_BYTES[slot]:
                    old_q = quads[b]
                    new_q = lookup_cols(palette, b)
                    if old_q != new_q:
                        delta[old_q] = delta.get(old_q, 0) - 1
                        delta[new_q] = delta.get(new_q, 0) + 1

                # Direct gain (frequency-weighted)
                gain = 0.0
                for q, d in delta.items():
                    if q in required_set:
                        was = achievable_cnt[q] > 0
                        now = achievable_cnt[q] + d > 0
                        gain += freq[q] * ((1 if now else 0) - (1 if was else 0))

                # 2-step look-ahead: credit quads that a follow-up step could
                # unlock given this step is applied first.
                if look_ahead and top_unmatched:
                    step1_is_new = slot not in changed and val != prev[slot]
                    budget_after = budget - len(changed) - (1 if step1_is_new else 0)

                    for q, fq in top_unmatched:
                        # Skip quads already covered by this step
                        if delta.get(q, 0) > 0:
                            continue
                        c0, c1, c2, c3 = q
                        # Try each follow-up candidate
                        for s2, v2 in quad_follow_ups[q]:
                            if s2 == slot:
                                continue
                            if palette[s2] == v2:
                                continue
                            # Budget guard for the follow-up step
                            if has_budget:
                                if s2 not in changed and v2 != prev[s2]:
                                    if budget_after <= 0:
                                        continue
                            old_v2 = palette[s2]
                            palette[s2] = v2
                            achievable = _quad_achievable(palette, c0, c1, c2, c3)
                            palette[s2] = old_v2
                            if achievable:
                                gain += fq * _LOOK_AHEAD_FACTOR
                                break  # one valid follow-up is enough

                palette[slot] = old_slot_val

                if gain > best_gain:
                    best_gain = gain
                    best_slot = slot
                    best_val  = val

        if best_slot is None or best_gain <= 0:
            break   # no improvement possible within budget

        # Apply the best change
        old_val = palette[best_slot]
        palette[best_slot] = best_val

        # Update achievable_cnt and quads incrementally
        for b in _SLOT_BYTES[best_slot]:
            old_q = quads[b]
            new_q = lookup_cols(palette, b)
            if old_q != new_q:
                achievable_cnt[old_q] -= 1
                achievable_cnt[new_q]  += 1
                quads[b] = new_q

        # Track budget
        if has_budget:
            if best_slot not in changed and best_val != prev[best_slot]:
                changed.add(best_slot)
            elif best_slot in changed and best_val == prev[best_slot]:
                changed.discard(best_slot)   # reverted to prev

    # Build matched dict
    matched = {}
    for quad in required_set:
        bv = find_byte_for_quad(palette, quad)
        if bv is not None:
            matched[quad] = bv

    return palette, matched


# ── Z3 palette solver (legacy, used when --solver z3) ─────────────────────────

def _add_quad_constraint(solver, pal, quad):
    """Add Z3 constraints asserting that quad (c0,c1,c2,c3) is achievable."""
    z3 = _z3_mod
    c0, c1, c2, c3 = quad
    alts_02, alts_13 = [], []
    for g in range(8):
        idx_odd = g * 2 + 1
        for idx_free in (g, g + 8):
            alts_02.append(z3.And(pal[idx_free] == c0, pal[idx_odd] == c2))
            alts_13.append(z3.And(pal[idx_free] == c1, pal[idx_odd] == c3))
    solver.add(z3.Or(*alts_02))
    solver.add(z3.Or(*alts_13))


def _solve_palette_z3(required_quads, previous_palette=None):
    """
    Find a 16-entry BBC palette satisfying all required_quads using Z3.

    Returns (palette_list, matched_dict) on SAT, or None on UNSAT.
    """
    z3 = _z3_mod
    s   = z3.Solver()
    pal = [z3.Int(f'p{i}') for i in range(16)]
    for p in pal:
        s.add(p >= 0, p <= 7)
    for quad in required_quads:
        _add_quad_constraint(s, pal, quad)
    if previous_palette is not None:
        same = [z3.If(pal[i] == int(previous_palette[i]),
                      z3.IntVal(1), z3.IntVal(0)) for i in range(16)]
        s.add(z3.Sum(same) >= 16 - CHANGE_PER_ROW)
    if s.check() != z3.sat:
        return None
    model   = s.model()
    palette = [model[pal[i]].as_long() for i in range(16)]
    matched = {}
    for quad in required_quads:
        bv = find_byte_for_quad(palette, quad)
        if bv is not None:
            matched[quad] = bv
    return palette, matched


# ── Per-section palette search ────────────────────────────────────────────────

def find_palette_for_section(sorted_quads, previous_palette,
                              verbose=True, solver='greedy', look_ahead=False):
    """
    Find a palette for this section.

    solver : 'greedy' (default) — hill-climbing greedy with numpy best-effort
             'z3'               — Z3 SMT binary search (requires z3-solver)

    Both paths share Option C (early exit when palette is already sufficient)
    and Option B (numpy-vectorised best-effort for unmatched quads).

    sorted_quads : list of (quad, count) sorted by count descending.
    Returns (palette, matched_dict, besteffort_dict).
    """
    all_quads = [q for q, _ in sorted_quads]
    n = len(all_quads)

    if n == 0:
        palette = list(previous_palette) if previous_palette else [0] * 16
        return palette, {}, {}

    # ── Option C: skip solver if current palette already covers all quads ─────
    if previous_palette is not None:
        achievable = {lookup_cols(previous_palette, b) for b in range(256)}
        if all(q in achievable for q in all_quads):
            matched = {}
            for quad in all_quads:
                bv = find_byte_for_quad(previous_palette, quad)
                if bv is not None:
                    matched[quad] = bv
            if verbose:
                print(f"    All {n} unique quads achievable (palette unchanged)")
            return list(previous_palette), matched, {}

    if solver == 'z3':
        palette, matched, besteffort = _find_palette_z3(
            all_quads, previous_palette, verbose)
    else:
        # ── Option A: greedy hill-climbing solver ─────────────────────────────
        palette, matched = _greedy_palette(sorted_quads, previous_palette,
                                           look_ahead=look_ahead)
        unmatched = [q for q in all_quads if q not in matched]
        if verbose:
            if unmatched:
                print(f"    Greedy: {n - len(unmatched)}/{n} quads satisfied; "
                      f"{len(unmatched)} best-effort")
            else:
                print(f"    All {n} unique quads satisfied by greedy")
        # ── Option B: numpy-vectorised best-effort ────────────────────────────
        besteffort = _best_effort_numpy(palette, unmatched)

    return palette, matched, besteffort


def _find_palette_z3(all_quads, previous_palette, verbose):
    """Z3 binary-search solver path (mirrors the original OCaml approach)."""
    if not _Z3_AVAILABLE:
        raise RuntimeError("z3-solver is not installed.  "
                           "Run: pip install z3-solver")
    n = len(all_quads)

    # Try satisfying everything first
    result = _solve_palette_z3(all_quads, previous_palette)
    if result:
        palette, matched = result
        if verbose:
            print(f"    Z3: all {n} unique quads satisfied")
        return palette, matched, {}

    # Binary search for maximum satisfiable prefix
    prev_pal = previous_palette
    r1 = _solve_palette_z3(all_quads[:1], prev_pal)
    if r1 is None:
        r1 = _solve_palette_z3(all_quads[:1], None)
        if r1 is None:
            raise RuntimeError("Single-quad Z3 solve failed even without continuity")
        if verbose:
            print("    Z3 warning: continuity constraint dropped for 1-quad fallback")
        prev_pal = None

    best_result, best_split = r1, 0
    lo, hi = 1, n
    while lo < hi - 1:
        mid = (lo + hi) // 2
        if verbose:
            print(f"    Z3 binary search {lo}–{hi}: trying {mid+1} quads ...",
                  end=' ', flush=True)
        r = _solve_palette_z3(all_quads[:mid + 1], prev_pal)
        if r is not None:
            if verbose: print("SAT")
            best_result, best_split = r, mid
            lo = mid
        else:
            if verbose: print("UNSAT")
            hi = mid

    palette, matched = best_result
    if verbose:
        print(f"    Z3: satisfied {best_split + 1}/{n} quads; "
              f"{n - best_split - 1} best-effort")

    besteffort = _best_effort_numpy(palette, all_quads[best_split + 1:])
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


# ── Image resize / crop ───────────────────────────────────────────────────────

def _fit_image(img: Image.Image, mode: str) -> Image.Image:
    """
    Resize and/or crop img to exactly SCREEN_W × SCREEN_H.

    mode:
      'fit'          — scale to fit inside 320×256, preserve aspect ratio,
                       centre on a black canvas (letterbox / pillarbox).
      'crop-left'    — scale so height == 256 (may make width > 320),
                       then discard the left-hand excess.
      'crop-right'   — same, discard the right-hand excess.
      'crop-top'     — scale so width == 320 (may make height > 256),
                       then discard the top excess.
      'crop-bottom'  — same, discard the bottom excess.
    """
    src_w, src_h = img.size

    if mode == 'fit':
        scale  = min(SCREEN_W / src_w, SCREEN_H / src_h)
        new_w  = round(src_w * scale)
        new_h  = round(src_h * scale)
        scaled = img.resize((new_w, new_h), Image.LANCZOS)
        canvas = Image.new('RGB', (SCREEN_W, SCREEN_H), (0, 0, 0))
        canvas.paste(scaled, ((SCREEN_W - new_w) // 2, (SCREEN_H - new_h) // 2))
        return canvas

    if mode in ('crop-left', 'crop-right'):
        scale  = SCREEN_H / src_h
        new_w  = round(src_w * scale)
        scaled = img.resize((new_w, SCREEN_H), Image.LANCZOS)
        excess = new_w - SCREEN_W
        x0     = excess if mode == 'crop-left' else 0
        return scaled.crop((x0, 0, x0 + SCREEN_W, SCREEN_H))

    if mode in ('crop-top', 'crop-bottom'):
        scale  = SCREEN_W / src_w
        new_h  = round(src_h * scale)
        scaled = img.resize((SCREEN_W, new_h), Image.LANCZOS)
        excess = new_h - SCREEN_H
        y0     = excess if mode == 'crop-top' else 0
        return scaled.crop((0, y0, SCREEN_W, y0 + SCREEN_H))

    raise ValueError(f"Unknown resize mode: {mode!r}")


# ── Section 0 palette initialisation ─────────────────────────────────────────

def _initial_palette_from_image(arr: np.ndarray) -> list:
    """
    Seed an initial 16-slot palette from the image's dominant BBC colours.

    Preprocesses every pixel (gamma + border clamp), quantises to the nearest
    BBC colour (0–7), and counts occurrences.  The 8 BBC colours ranked by
    frequency are then distributed across all 16 palette slots:

        slots[i] = dominant_colours[i % 8]

    This ensures every dominant colour appears in both even and odd slots,
    giving the greedy solver a much better starting point than all-black.
    """
    counts = Counter()
    for y in range(arr.shape[0]):
        for x in range(arr.shape[1]):
            pr, pg, pb = preprocess_pixel(
                int(arr[y, x, 0]), int(arr[y, x, 1]), int(arr[y, x, 2]))
            counts[closest_colour(pr, pg, pb)] += 1

    # All 8 colours ranked by frequency; fill any absent colours at the end
    ranked = [c for c, _ in counts.most_common()]
    for c in range(8):
        if c not in ranked:
            ranked.append(c)

    return [ranked[i % 8] for i in range(16)]


# ── Main pipeline ─────────────────────────────────────────────────────────────

def process_image(png_path: str, output_path: str,
                  dither: str = 'ordered', verbose: bool = True,
                  preview_path: str = None, solver: str = 'greedy',
                  resize: str = 'fit', randomness: int = 64,
                  look_ahead: bool = False):
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
    # Load and resize / crop to 320×256
    img = Image.open(png_path).convert('RGB')
    if img.size != (SCREEN_W, SCREEN_H):
        if verbose:
            print(f"Resizing {img.size} → ({SCREEN_W}×{SCREEN_H})  [{resize}]")
        img = _fit_image(img, resize)
    arr = np.array(img, dtype=np.uint8)

    output_palettes = bytearray(16 + CHANGE_PER_ROW * 128)  # 1168 bytes
    screen_bytes    = bytearray(20480)

    if verbose:
        print("Computing initial palette from image dominant colours...")
    previous_palette = _initial_palette_from_image(arr)
    if verbose:
        print(f"  Initial palette: {previous_palette}")
    fs_err = np.zeros((3, SCREEN_W), dtype=float)   # FS error diffusion state

    # Preview buffer: RGB pixels at native 320×256
    preview_arr = np.zeros((SCREEN_H, SCREEN_W, 3), dtype=np.uint8) if preview_path else None

    for section in range(NUM_SECTIONS):
        if verbose:
            print(f"\nSection {section}/{NUM_SECTIONS - 1}:")
            sys.stdout.flush()

        # ── Dither ────────────────────────────────────────────────────────────
        if dither == 'ordered':
            quads = dither_section_ordered(arr, section, randomness=randomness)
        else:
            quads = dither_section_fs(arr, section, fs_err)

        counts      = Counter(quads)
        sorted_quads = sorted(counts.items(), key=lambda x: -x[1])

        if verbose:
            print(f"  {len(sorted_quads)} unique quads from 160 bytes")

        # ── Solve ─────────────────────────────────────────────────────────────
        palette, matched, besteffort = find_palette_for_section(
            sorted_quads, previous_palette, verbose=verbose, solver=solver,
            look_ahead=look_ahead)

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
    python palsearch.py photo.png -o frog.bin -s z3
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
    ap.add_argument('-r', '--resize',
                    choices=['fit', 'crop-left', 'crop-right',
                             'crop-top', 'crop-bottom'],
                    default='fit',
                    help=('How to fit the input to 320×256: '
                          'fit = letterbox/pillarbox centred (default); '
                          'crop-left/right = fill height, crop excess width; '
                          'crop-top/bottom = fill width, crop excess height'))
    ap.add_argument('-s', '--solver', choices=['greedy', 'z3'], default='greedy',
                    help=('Palette solver: '
                          'greedy = fast hill-climbing (default), '
                          'z3 = SMT binary search (requires pip install z3-solver)'))
    ap.add_argument('--randomness', type=int, default=64, metavar='N',
                    help=('Per-pixel random bias for ordered dither, 0–255 '
                          '(default 64, matching OCaml -random 64). '
                          'Higher values break up flat colour regions more. '
                          'Use 0 to disable.'))
    ap.add_argument('--look-ahead', action='store_true', default=False,
                    help=('Enable 2-step look-ahead in the greedy solver. '
                          'For the top-3 highest-frequency unmatched quads, '
                          'checks whether a follow-up slot change would make '
                          'the quad achievable and credits that frequency as '
                          'a bonus. Fixes colours that require two coordinated '
                          'slot changes (e.g. white duck head). Slower but '
                          'produces better results for such images.'))
    ap.add_argument('-q', '--quiet', action='store_true',
                    help='Suppress per-section progress output')
    args = ap.parse_args()

    process_image(args.input, args.output,
                  dither=args.dither, verbose=not args.quiet,
                  preview_path=args.preview, solver=args.solver,
                  resize=args.resize, randomness=args.randomness,
                  look_ahead=args.look_ahead)


if __name__ == '__main__':
    main()
