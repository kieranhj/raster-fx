# The Partial Palette Technique: How `palsearch` Achieves >4 Colours Per Line

## Overview

The BBC Master runs a 6502 CPU with a custom ULA (Uncommitted Logic Array) chip driving the display. In its standard "chunky mode" configuration used by this demo, the hardware limits any given scanline to exactly 16 simultaneously active palette entries, each holding one of 8 possible RGB colours (1-bit per channel). The palette search algorithm (`palsearch/palsearch.ml`) solves a constraint satisfaction problem to display far more apparent colours by reprogramming up to 9 palette entries at the start of each 2-row strip.

---

## 1. The BBC ULA Pixel Encoding

### Screen memory layout

In the custom chunky mode used by this demo:
- Screen is 320×256 pixels
- 80 bytes per row, 4 pixels per byte
- 16-entry palette, each entry holding one of 8 BBC colours (RGB bitmask 0–7)

### How one byte encodes four pixels

Given a byte with bits labelled `b7 b6 b5 b4 b3 b2 b1 b0`, the ULA extracts 4 palette indices as:

| Pixel | Index bits           | Constraint         |
|-------|----------------------|--------------------|
| p0    | `b7, b5, b3, b1`     | Free: 0–15         |
| p1    | `b6, b4, b2, b0`     | Free: 0–15         |
| p2    | `b5, b3, b1, 1`      | Always **odd**: 1,3,5,7,9,11,13,15 |
| p3    | `b4, b2, b0, 1`      | Always **odd**: 1,3,5,7,9,11,13,15 |

The critical relationship: p2 and p3 are entirely determined by p0 and p1:

```
p2 = ((p0 & 0b111) << 1) | 1
p3 = ((p1 & 0b111) << 1) | 1
```

So a byte has only 256 possible values, giving 256 possible (p0,p1,p2,p3) index tuples — not 16⁴. The 4 apparent "colours" at a byte position are tightly coupled.

### Python implementation

```python
def decode_byte(byte, palette):
    """Return the 4 BBC colours displayed for this screen byte value."""
    def extract_index(b):
        return ((b >> 7 & 1) << 3 | (b >> 5 & 1) << 2 |
                (b >> 3 & 1) << 1 | (b >> 1 & 1))

    p0 = extract_index(byte)
    byte2 = ((byte << 1) | 1) & 0xFF
    p1 = extract_index(byte2)
    byte3 = ((byte2 << 1) | 1) & 0xFF
    p2 = extract_index(byte3)
    byte4 = ((byte3 << 1) | 1) & 0xFF
    p3 = extract_index(byte4)
    return palette[p0], palette[p1], palette[p2], palette[p3]

def all_quads_for_palette(palette):
    """Enumerate all 256 (c0,c1,c2,c3) quads achievable with this palette."""
    seen = {}
    for byte_val in range(256):
        quad = decode_byte(byte_val, palette)
        if quad not in seen:
            seen[quad] = byte_val
    return seen  # maps quad → byte_val
```

---

## 2. The Scanline Palette Reprogramming Trick

### The hardware mechanism

The BBC Master fires an interrupt at the start of each display scanline (via the Video ULA's 6845 CRTC chip). The demo's IRQ handler reprograms palette registers during the beam retrace period between lines. Because the palette is a shared hardware register set, changing it mid-frame affects only subsequent scanlines.

### The continuity constraint

To make the per-line palette update feasible in real time (the 6502 only has ~64 cycles per scanline), the hardware update routine changes at most **9** of the 16 palette entries per scanline strip. The remaining 7 entries carry over from the previous line.

This is the `change_per_row = 9` constant. At runtime, the precomputed data stores exactly which entries change and to what value, laid out for direct playback by the IRQ handler.

### Output binary format

```
Byte 0..15:   Initial palette (16 entries, written once at demo start)
Byte 16+:     Per-section delta table
              For section s (0-indexed), change slot c (0..8):
              output_palettes[16 + c*128 + s] = (palette_index << 4) | (new_colour XOR 7)
```

The XOR 7 is because the BBC's ULA uses an inverted colour representation.

---

## 3. The Palette Search Algorithm

Processing happens in **sections** of 2 consecutive scanlines (`chunksize = 2`). For each section, the algorithm must find a 16-entry palette such that all 160 byte positions (80 bytes × 2 rows) in the section can be represented, subject to at most 9 palette entries changing from the previous section.

### Phase 1: Dithering to 8-colour quads

Each pixel's true RGB value is mapped to one of the 8 BBC colours (each a 1-bit-per-channel RGB value 0–7). Four adjacent pixels in a byte position become a **(c0, c1, c2, c3)** colour quad, where each `ci ∈ {0..7}`.

The code supports multiple dithering methods:
- **Ordered dithering** (Bayer-style, 2×2 matrix with offsets `[-96, 32, 96, -32]`)
- **Floyd-Steinberg** error diffusion
- **Multimix**: generates multiple dithering alternatives per byte position and lets the SMT solver pick the best-fitting combination

### Phase 2: SMT problem formulation

The `find_palette` function encodes the search as an SMT-LIB2 problem using Z3:

**Variables:**
- `pal`: array of 16 4-bit values (the palette mapping: index → BBC colour 0..7)
- `pixels`: array of 8-bit byte values (one per unique colour quad)

**Constraints for each colour quad `(c0,c1,c2,c3)` that must be satisfied:**
```
pal[p0_index(pixel[i])] == c0
pal[p1_index(pixel[i])] == c1
pal[p2_index(pixel[i])] == c2
pal[p3_index(pixel[i])] == c3
```
where `p0_index`, `p1_index`, `p2_index`, `p3_index` are the bit-extraction functions above, expressed as bitvector operations.

**Continuity constraint (when `section > 0`):**
```
sum(pal[i] == prev_pal[i] for i in 0..15) >= 16 - change_per_row
```
i.e. at least 7 entries must remain unchanged.

If Z3 returns **SATISFIABLE**, the model gives the palette and the byte value for each quad. If **UNSATISFIABLE**, the problem is overconstrained (too many distinct quads for one palette to cover).

### Phase 3: Binary search for the maximum satisfiable subset

Not all colour quads in a section can always be satisfied simultaneously. The algorithm uses binary search over how many distinct quads to include:

```
find_splitpoint(cols_array, lo=1, hi=num_cols):
    mid = (lo + hi) / 2
    if find_palette(cols_array[:mid]) == SAT:
        scan(mid, hi)   # can we include more?
    else:
        scan(lo, mid)   # too many, try fewer
```

Quads that don't fit are handled by best-effort: the closest achievable quad (by weighted RGB distance) is substituted.

When the simple approach fails entirely (the initial search returns UNSAT even for many quads), the algorithm falls back to **multimix** mode, which tries multiple dithering combinations per byte position simultaneously.

### Phase 4: Error-driven fallback

After solving, the quality of the best-effort approximations is evaluated as a sum of perceptual colour errors (weighted Euclidean distance in RGB with luminance weighting: R×0.2126, G×0.7152, B×0.0722). If the total error exceeds `mmix_err_threshold` (default 2.0), the algorithm retries the entire section using the multimix approach with increasing search depth (cutoff 1, 2, 3, 4, 5, 20).

---

## 4. Runtime Implementation (`palsearch/showimage.s`)

The runtime palette playback is handled by `showimage.s`, which displays the palsearch-generated images with per-scanline palette updates. The `chunkymode` plasma effect uses a **fixed** palette set once at startup; the per-scanline technique is specific to the image display phase.

### Interrupt architecture

Two interrupt sources are used:

| Source | Purpose |
|--------|---------|
| System VIA CA1 (vsync) | Detects frame start, arms the VIA timer |
| User VIA Timer 1 | Fires every 2 scanlines to trigger palette writes |

On vsync, the timer is primed with `fliptime = 64×38+29 = 2461` VIA counts (the VIA runs at 1MHz, so 1 count = 1µs). This positions the first palette write at approximately scanline 38, aligning subsequent writes to land during hblank. The timer then reloads with `64×2 − 2 = 126` counts (the −2 corrects for VIA reload latency), firing every 2 scanlines — matching the `chunksize = 2` of the offline solver.

### Self-modifying code for minimum write time

The palette write section uses self-modifying code. On each IRQ, the handler writes 9 palette entries using values baked directly into LDA immediate instructions from the **previous** IRQ's prep work:

```asm
palette_write:
    ldx #$xx          ; 2c  ← immediate operand modified by previous IRQ (entry 7)
    ldy #$xx          ; 2c  ← immediate operand modified by previous IRQ (entry 8)
    lda #$xx : sta PALCONTROL   ; 6c  entry 0
    lda #$xx : sta PALCONTROL   ; 6c  entry 1
    lda #$xx : sta PALCONTROL   ; 6c  entry 2
    lda #$xx : sta PALCONTROL   ; 6c  entry 3
    lda #$xx : sta PALCONTROL   ; 6c  entry 4
    lda #$xx : sta PALCONTROL   ; 6c  entry 5
    lda #$xx : sta PALCONTROL   ; 6c  entry 6
    stx PALCONTROL               ; 4c  entry 7
    sty PALCONTROL               ; 4c  entry 8
```

**Total: 54 cycles** for 9 palette writes. Each `STA PALCONTROL` accesses the 1MHz I/O bus and can be stretched by +1 cycle (phase alignment), giving a worst case of **63 cycles**.

After the critical section, still within the same IRQ, the handler self-modifies the immediate operands using `LDA abs,X` (5c) + `STA abs` (4c) = 9c per slot to prepare the 9 values for the *next* IRQ call. This prep work is not timing-critical as it occurs after the writes.

### Cycle budget analysis

The BBC Master's PAL scanline is **64µs = 128 CPU cycles** at 2MHz. The horizontal blanking period is **24µs = 48 cycles**.

| Phase | Cycles |
|-------|--------|
| CPU interrupt response (finish instruction + push PC/SR) | 7c |
| ROM IRQ dispatcher (FFFE → OS → IRQV at $0204) | ~20c |
| Handler preamble (`lda $fc; pha; bit USR_IFR; bne`) | 15c |
| Clear timer interrupt (`lda USR_T1C_L`) | 4c |
| Save registers (`phx; phy`) | 6c |
| **Subtotal overhead before palette_write** | **~52c** |
| **palette_write (9 entries, best case)** | **54c** |
| **Total** | **~106c** |

The overhead (~52c) is calibrated to consume the tail of the active display period, so that `palette_write` begins near the start of hblank. However, the write section itself (54c) **exceeds the 48-cycle hblank window by 6 cycles**, meaning approximately the last palette write (or the final 6 cycles of the last two writes) lands during the first 3µs of the next active display line — roughly the first 24 pixels.

Comparison of write strategies within the 48-cycle window:

| Strategy | Cycles per write | Max writes in 48c (with 4c preamble) |
|----------|-----------------|--------------------------------------|
| `LDA abs,X` + `STA abs` (naive) | 9c | ≤4 |
| `LDA abs` + `STA abs` | 8c | ≤5 |
| `LDA imm` + `STA abs` (self-modifying) | 6c | ≤7 |
| `STX`/`STY abs` (pre-loaded, no LDA) | 4c | saves 2c per entry |

The self-modifying approach achieves approximately **7 writes safely within hblank**, with the 8th and 9th overflowing. The 9-entry constraint in palsearch was set empirically — 9 writes were observed to produce acceptable output despite the overflow.

### Jitter and its effect

Without stable raster synchronisation, the VIA timer fires with up to **±10 cycles of jitter** relative to the beam position. This means the entire palette_write block wanders by ±5µs (~40 pixels horizontally) across frames. Combined with the 6-cycle hblank overflow, the visible artefact — incorrect colours at one edge of affected rows — varies in width and position per frame, producing a flickering fringe. The `SYS_ACR = 0` setting (disabling system VIA timer interrupts) reduces one jitter source (keyboard scanning) but does not resolve the fundamental timing uncertainty.

---

## 5. What Stable Rasters Would Enable

Stable rasters (discovered on the BBC Micro after this demo was written) allow the CPU instruction stream to be phase-locked to the CRTC dot clock by exploiting the memory contention cycle-stealing pattern. This reduces timing jitter from ~10 cycles to **0–1 cycles**.

### Guaranteed hblank writes

With 0–1 cycle jitter and precise calibration, the 48-cycle hblank window can be fully exploited. Given 4 cycles of overhead (just `lda USR_T1C_L` to clear the interrupt, after pre-positioning the IRQ entry via a known-cycle-count spin loop rather than the ROM dispatcher), the budget becomes:

| | Cycles |
|--|--------|
| Hblank window | 48c |
| Minimum IRQ clear | 4c |
| Available for writes | **44c** |
| Writes at 6c each (LDA imm + STA) | **7 writes** |
| Writes at 4c each (STX/STY, pre-loaded) | +Nc if X/Y pre-loaded from previous cycle |

With a tight, ROM-bypassing IRQ entry (using a busy-wait sync loop instead of the ROM dispatcher), all 7 writes land cleanly within hblank with 2 cycles to spare. Two additional registers (X and Y) can carry pre-loaded values for 2 more entries at 4c each, giving **up to 9 entries in 44+8 = 52c** — still 4c over budget at 9 entries.

To reliably fit 9 writes with no jitter:

```
44c available / 6c per write = 7.3 → 7 LDA imm + STA writes (42c, 2c spare)
```

Adding entries 8 and 9 via STX/STY (4c each, values pre-loaded in a prior scanline's non-critical section):
```
42c + 4c + 4c = 50c > 44c  → still overflows by 6c
```

So **7 guaranteed clean writes** per 2-scanline strip is the realistic stable-raster ceiling for this encoding, allowing `change_per_row = 7` in palsearch. This is 2 fewer than the demo uses, at the cost of eliminating all visible fringe artefacts.

### Tighter strip granularity

With stable rasters, palette writes could safely target **every scanline** (not every 2) by using a more aggressive IRQ entry. The 128-cycle total scanline period breaks down as:

| Phase | Cycles |
|-------|--------|
| Active display (40µs) | 80c |
| Hblank (24µs) | 48c |

A stable-raster implementation firing every scanline would deliver 7 palette changes per scanline × 256 scanlines = **1,792 palette writes per frame**, vs the demo's 9 × 128 = 1,152. This would allow palsearch to solve each row independently rather than pairs, halving the palette continuity constraint window and enabling finer colour gradients in the image.

### Increased colour depth

With 7 clean changes per scanline and independent per-scanline palettes, the effective colour count per row rises. At the extreme (all 16 palette entries replaced each row, 2 scanlines each): the display can show a different set of up to ~256 representable quads per 2-row strip. With stable rasters and per-scanline updates, the solver could potentially target a larger per-row colour budget — though the fundamental hardware constraint (p2/p3 palette index coupling) remains unchanged.

---

## 7. Python Re-implementation

The OCaml+Z3 implementation can be replaced entirely with Python using the `z3-solver` pip package, which exposes the same Z3 API.

### Core data structures

```python
# BBC palette: 8 colours, each 3-bit RGB (bit 0=R, bit 1=G, bit 2=B)
# palette[i] ∈ 0..7, i ∈ 0..15
# Colour value to (R255, G255, B255):
def bbc_colour_to_rgb(col):
    return (col & 1) * 255, ((col >> 1) & 1) * 255, ((col >> 2) & 1) * 255
```

### Palette index extraction (pure Python, no SMT needed)

```python
def quad_indices_for_byte(byte_val):
    """Return the 4 palette indices (i0,i1,i2,i3) used by this byte value."""
    def idx(b):
        return ((b >> 7 & 1) << 3 | (b >> 5 & 1) << 2 |
                (b >> 3 & 1) << 1 | (b >> 1 & 1))
    b0 = byte_val
    b1 = ((b0 << 1) | 1) & 0xFF
    b2 = ((b1 << 1) | 1) & 0xFF
    b3 = ((b2 << 1) | 1) & 0xFF
    return idx(b0), idx(b1), idx(b2), idx(b3)

# Precompute: for each byte value, what are its 4 palette indices?
BYTE_INDICES = [quad_indices_for_byte(b) for b in range(256)]

# And the relationship: given (i0, i1), what are (i2, i3)?
# i2 = ((i0 & 7) << 1) | 1
# i3 = ((i1 & 7) << 1) | 1
```

### Z3-based palette solver

```python
import z3

CHANGE_PER_ROW = 9

def find_palette_z3(required_quads, previous_palette=None):
    """
    Find a 16-entry palette (each entry = BBC colour 0..7) that satisfies
    as many of required_quads as possible, with at most CHANGE_PER_ROW
    entries changed from previous_palette.

    required_quads: list of (c0,c1,c2,c3) tuples, each ci ∈ 0..7
    previous_palette: list of 16 ints or None
    Returns: (palette_list, byte_for_quad_dict) or None
    """
    ctx = z3.Context()
    solver = z3.Solver(ctx=ctx)

    # Palette: 16 entries, each 0..7 (3-bit colour)
    pal = [z3.BitVec(f'pal_{i}', 4, ctx=ctx) for i in range(16)]
    # Constrain each palette entry to 0..7
    for p in pal:
        solver.add(z3.ULE(p, z3.BitVecVal(7, 4, ctx=ctx)))

    # Pixel bytes: one per required quad (8-bit)
    pixels = [z3.BitVec(f'pix_{i}', 8, ctx=ctx) for i in range(len(required_quads))]

    def extract_idx(bv, shift):
        """Extract the 4-bit palette index from an 8-bit pixel byte."""
        # bits [7,5,3,1] after 'shift' left-shifts with 1 fill
        # After k shifts: bits [7-k, 5-k, 3-k, 1-k] of original,
        # but lower k bits are 1. The tap is always on bits [7,5,3,1] of
        # the shifted byte.
        # Simpler: precompute using the known formula.
        bits = []
        for bit_pos in [7, 5, 3, 1]:
            effective = bit_pos - shift
            if effective >= 0:
                bits.append(z3.Extract(effective, effective, bv))
            else:
                bits.append(z3.BitVecVal(1, 1, ctx=ctx))  # forced 1
        return z3.Concat(bits[0], bits[1], bits[2], bits[3])

    for i, (c0, c1, c2, c3) in enumerate(required_quads):
        pv = pixels[i]
        i0 = extract_idx(pv, 0)
        i1 = extract_idx(pv, 1)
        i2 = extract_idx(pv, 2)
        i3 = extract_idx(pv, 3)
        solver.add(pal[z3.BV2Int(i0, False)] == z3.BitVecVal(c0, 4, ctx=ctx))
        solver.add(pal[z3.BV2Int(i1, False)] == z3.BitVecVal(c1, 4, ctx=ctx))
        solver.add(pal[z3.BV2Int(i2, False)] == z3.BitVecVal(c2, 4, ctx=ctx))
        solver.add(pal[z3.BV2Int(i3, False)] == z3.BitVecVal(c3, 4, ctx=ctx))

    # Continuity constraint
    if previous_palette is not None:
        same = z3.Sum([
            z3.If(pal[i] == z3.BitVecVal(previous_palette[i], 4, ctx=ctx),
                  z3.IntVal(1, ctx=ctx), z3.IntVal(0, ctx=ctx))
            for i in range(16)
        ])
        solver.add(same >= 16 - CHANGE_PER_ROW)

    if solver.check() == z3.sat:
        model = solver.model()
        palette = [model.eval(pal[i]).as_long() for i in range(16)]
        byte_for_quad = {}
        for i, quad in enumerate(required_quads):
            bv = model.eval(pixels[i]).as_long()
            byte_for_quad[quad] = bv
        return palette, byte_for_quad
    return None
```

### SAT-free palette search (no Z3)

Because the constraint structure is small (16 palette entries, 8 possible values each), an exhaustive or heuristic search without an SMT solver is also viable:

```python
from itertools import product

def brute_force_palette(required_quads, previous_palette=None, max_changes=9):
    """
    Without Z3: iterate candidate palettes and check feasibility.
    Only practical for small numbers of required quads or with good pruning.
    """
    # Precompute: for each byte, what (i0,i1,i2,i3) tuple does it use?
    # Note i2 = ((i0&7)<<1)|1,  i3 = ((i1&7)<<1)|1
    # So if we fix palette, check whether each quad is achievable by
    # trying all 256 byte values.

    def palette_can_represent(palette, quad):
        c0, c1, c2, c3 = quad
        for i0 in range(16):
            if palette[i0] != c0:
                continue
            i2 = ((i0 & 7) << 1) | 1
            if palette[i2] != c2:
                continue
            for i1 in range(16):
                if palette[i1] != c1:
                    continue
                i3 = ((i1 & 7) << 1) | 1
                if palette[i3] == c3:
                    # Found! Reconstruct byte value:
                    # i0 = {b7,b5,b3,b1}, i1 = {b6,b4,b2,b0}
                    b = 0
                    for bit_idx, src_idx in enumerate([i1 & 1, i0 & 1,
                                                        (i1>>1)&1, (i0>>1)&1,
                                                        (i1>>2)&1, (i0>>2)&1,
                                                        (i1>>3)&1, (i0>>3)&1]):
                        b |= src_idx << bit_idx
                    return b
        return None

    # This brute force is O(8^16) in the worst case — use with constraint propagation
    # or a smarter enumeration strategy for production use.
    ...
```

---

## 8. Algorithmic Improvements

### 5.1 Reformulate as Integer Linear Programming (ILP)

Instead of SMT, the palette assignment can be modelled as an ILP:
- Binary variable `x[i][c]` = 1 if palette entry `i` maps to colour `c`
- For each required quad, add constraints on index combinations
- Objective: maximise the number of satisfied quads
- Libraries: `scipy.optimize.milp`, `pulp`, or `ortools`

ILP solvers (GLPK, CBC, HiGHS) are generally faster than general SMT for this type of problem.

### 5.2 Precompute the reachable quad space

For a fixed 16-entry palette, the set of representable quads is fully enumerable from 256 byte values in O(256) time. This makes it cheap to:
1. Generate a candidate palette
2. Check if all required quads are covered
3. If not, identify which quads are missing and adjust the palette

A greedy palette construction can build entries one-by-one to maximise coverage, avoiding the SMT solver entirely for well-conditioned inputs.

```python
def quads_for_palette(palette):
    """O(256): return dict of all (c0,c1,c2,c3) → byte_val for this palette."""
    result = {}
    for bv in range(256):
        i0, i1, i2, i3 = BYTE_INDICES[bv]
        quad = (palette[i0], palette[i1], palette[i2], palette[i3])
        if quad not in result:
            result[quad] = bv
    return result

def greedy_palette(required_quads, previous_palette=None, max_changes=9):
    """Build a palette greedily to maximise quad coverage."""
    palette = list(previous_palette) if previous_palette else [0] * 16
    free_entries = set(range(16)) if previous_palette is None else \
                   set(sorted(range(16),
                              key=lambda i: palette[i] != previous_palette[i])[-max_changes:])

    # Try all colour assignments for free entries
    # ...
    pass
```

### 5.3 Exploit the i2/i3 dependency structure

Since `i2 = ((i0 & 7) << 1) | 1` and `i3 = ((i1 & 7) << 1) | 1`, the 16 palette indices split into groups:

- Even-indexed entries (0,2,4,6,8,10,12,14): appear as i0 or i1 freely
- Odd-indexed entries (1,3,5,7,9,11,13,15): appear as i2 or i3 (constrained by i0/i1)

The 8 even palette entries control p0 colours freely.
The 8 odd entries control p2 (via i0's lower 3 bits): odd entry `2k+1` is used as i2 exactly when `i0 ∈ {k, k+8}`. This means:

- Odd entry 1 is i2 when i0 ∈ {0, 8}
- Odd entry 3 is i2 when i0 ∈ {1, 9}
- Odd entry 5 is i2 when i0 ∈ {2, 10}
- Odd entry 7 is i2 when i0 ∈ {3, 11}
- Odd entry 9 is i2 when i0 ∈ {4, 12}
- Odd entry 11 is i2 when i0 ∈ {5, 13}
- Odd entry 13 is i2 when i0 ∈ {6, 14}
- Odd entry 15 is i2 when i0 ∈ {7, 15}

This means: **choosing palette[i0] forces palette[2*(i0&7)+1]** to determine the only possible p2 colour when that i0 is selected. A palette search can exploit this by treating (even_entry, paired_odd_entry) as a unit, reducing the search space from 8^16 to 8^8 × (dependency propagation).

### 5.4 Multi-section lookahead

The original algorithm processes sections greedily (no lookahead). A beam search or dynamic programming approach could plan palette changes over N future sections simultaneously, trading computation time for better colour fidelity on sections with difficult-to-satisfy colour transitions.

### 5.5 Better colour quantisation

Before palette search, the 8-colour dithering step determines which quads the solver must satisfy. Improving this step has more impact than optimising the solver:
- Use perceptual colour spaces (OKLab, CIELAB) for dithering distance metrics instead of linear RGB
- Use blue noise dithering instead of ordered dithering to reduce visible patterns
- Use temporal dithering (alternating frames at video rate) to achieve more apparent colours at the cost of some flicker

---

## 9. Summary of Key Numbers

| Parameter | Value | Meaning |
|-----------|-------|---------|
| `chunksize` | 2 | Rows per section (palette update granularity) |
| `change_per_row` | 9 | Max palette entries changed per section |
| palette size | 16 entries | Total palette registers |
| BBC colours | 8 | Physical output colours (3-bit RGB) |
| bytes per row | 80 | Screen bytes horizontally |
| pixels per byte | 4 | ULA pixel encoding |
| screen size | 320×256 | Effective resolution |
| sections per frame | 128 | 256 rows / 2 rows per section |
| max palette updates | 128×9 = 1152 | Palette writes per frame |
