# Mode 0 Multi-Colour Display Techniques

## Overview

BBC Micro Mode 0 is conventionally described as a 2-colour mode at 640×256 pixels. This document analyses the hardware constraints on palette use in Mode 0, explains why the `palsearch`-style per-strip palette technique (as used in the Mode 1 `showimage` effect) applies differently here, and proposes two complementary techniques — mid-scanline horizontal colour splits and interlaced MAIN/SHADOW RAM field switching — that together could enable a convincing multi-colour image display at effective 640×512 resolution.

---

## 1. Mode 0 Hardware Characteristics

| Property | Mode 0 | Mode 1 (showimage reference) |
|---|---|---|
| Screen resolution | 640×256 | 320×256 |
| Bytes per row | 80 | 80 |
| Pixels per byte | 8 | 4 |
| Conventional colour depth | 2 (1bpp) | 4 (2bpp) |
| ULA pixel clock (relative) | 2× Mode 1 | baseline |
| Active display | 40µs = 80 CPU cycles | 40µs = 80 CPU cycles |
| Hblank | 24µs = 48 CPU cycles | 24µs = 48 CPU cycles |
| CPU cycles per pixel | 0.125c (8 pixels/cycle) | 0.25c (4 pixels/cycle) |

The hblank window is identical to Mode 1 because both use the same CRTC horizontal timing. The active display duration is also the same. What differs is how many pixels are packed into each screen byte, and how the ULA shifts them out.

---

## 2. Palette Index Constraints Per Pixel in Mode 0

*Note: The following analysis extrapolates the ULA's interleaved bit-extraction mechanism — confirmed for Mode 1 — to Mode 0. Whether the ULA applies the same shift-and-tap mechanism at double speed in Mode 0 requires verification against the ULA schematics or empirical testing.*

If the ULA uses the same serial shift-and-extract pattern as Mode 1 (shift the byte left by 1, OR with 1, tap bits 7,5,3,1 for the 4-bit palette index), then for each screen byte the 8 pixel palette indices are:

| Pixel | Index bits from byte | Forced bits | Accessible palette entries |
|---|---|---|---|
| p0 | b7, b5, b3, b1 | none | 0–15 (all 16) |
| p1 | b6, b4, b2, b0 | none | 0–15 (all 16) |
| p2 | b5, b3, b1, **1** | LSB=1 | 8 odd entries: 1,3,5,7,9,11,13,15 |
| p3 | b4, b2, b0, **1** | LSB=1 | 8 odd entries |
| p4 | b3, b1, **1, 1** | lower 2 bits=1 | 4 entries: 3,7,11,15 |
| p5 | b2, b0, **1, 1** | lower 2 bits=1 | 4 entries: 3,7,11,15 |
| p6 | b1, **1, 1, 1** | lower 3 bits=1 | 2 entries: **7 or 15 only** |
| p7 | b0, **1, 1, 1** | lower 3 bits=1 | 2 entries: **7 or 15 only** |

Crucially, Mode 0 is **not** a simple 2-entry palette mode at the hardware level — all 16 palette entries are potentially addressable. However, the access distribution is highly skewed: palette entries 7 and 15 are the only ones accessible by pixels 6 and 7 of every byte, making them mandatory workhorses that must serve as useful display colours. The OS convention of programming only 2 logical colours is an abstraction on top of a richer hardware capability.

### Palette entry usage summary

| Palette entries | Pixels that can access them | Fraction of pixels per byte |
|---|---|---|
| 0–15 (all) | p0, p1 | 2 of 8 = 25% |
| Odd entries only (1,3,5,7,9,11,13,15) | p0–p3 | 4 of 8 = 50% |
| 3,7,11,15 | p0–p5 | 6 of 8 = 75% |
| **7, 15 only** | **all pixels** | **8 of 8 = 100%** |

Entries 7 and 15 are addressed by every pixel regardless of screen byte value. This means:
- They cannot be "reserved" for special purposes — they define baseline background/foreground tones visible everywhere
- Any palette strategy must assign useful, globally appropriate colours to entries 7 and 15
- The solver has no freedom to sacrifice these entries for local optimisation

### Comparison with Mode 1

In Mode 1, p0 and p1 are fully free (16 entries each), p2 and p3 are odd-only (8 entries each). All 4 pixels contribute meaningfully to the palette search. In Mode 0, the additional pixels p4–p7 progressively constrain the accessible entries down to just {7, 15}. The solver's effective degree of freedom per byte is **lower** in Mode 0 than Mode 1, despite Mode 0 having more pixels per byte.

---

## 3. Per-Strip Palette Technique in Mode 0

The Mode 1 `showimage` approach changes up to 9 palette entries per 2-scanline strip during hblank, allowing different colour palettes on each strip. Applied to Mode 0, the same hblank timing applies (48 cycles, same write budget: 7 entries safe, 9 with overflow).

However, the returns are diminished because:
- The 7 "safe" writes per strip do nothing useful for p6/p7 unless they modify entries 7 or 15
- Modifying entries 7 and 15 per strip changes the colour of 100% of pixels — a blunt instrument
- Modifying other entries per strip affects only 25–75% of pixels, and only in specific bit-pattern positions

The solver can still optimise palette assignments per strip, but the search space is more constrained. The best strategy would reserve entries 7 and 15 for the dominant tones in each strip, then use the remaining free entries (accessible by p0/p1) for accent colours. The p2–p5 pixels (accessing odd and mod-4 entries) act as a graduated set of intermediate tones.

---

## 4. Mid-Scanline Horizontal Colour Splits

The complementary technique for Mode 0 exploits the active display period rather than hblank. Writing to `PALCONTROL` mid-scanline changes the displayed colour for all subsequent pixels on that line.

### Timing

At 2MHz CPU during active display (no cycle stealing from ULA in standard operation):
- Active display: 80 CPU cycles
- Palette write: 6 cycles (LDA imm + STA abs, with 1MHz bus stretch)
- Overhead between splits (loop/counter management): ~4 cycles minimum
- **Maximum horizontal splits per scanline: ~8 (leaving ~16 cycles for screen update work)**

At 8 pixels per CPU cycle in Mode 0, each split is positioned to ±8 pixels without stable rasters, and ±1–2 cycles (±8–16 pixels) with them.

### Minimum zone width

Each CPU cycle spans 8 Mode 0 pixels. A mid-scanline palette write takes 6 cycles, during which 48 pixels are drawn with the current (old) colour before the write completes and the new colour takes effect. The practical minimum zone width is therefore around **48–56 pixels** (6–7 CPU cycles), giving approximately **11–13 distinct horizontal zones** per scanline.

### Which entries to change per zone

Since entries 7 and 15 affect all pixels (p0–p7), changing them at zone boundaries has the broadest impact. A split strategy that updates entries 7 and 15 at each zone boundary gives:
- 2 writes per split = 12 cycles
- 80 cycles active display / (12c write + 4c overhead) = **5 colour zone transitions = 6 zones** at comfortable pace
- With tighter code (zero overhead): 80 / 12 = **6 transitions = 7 zones**

Entries 7 and 15 define the "floor and ceiling" colours for each horizontal zone. Within each zone, the per-strip vertical palette establishes which additional colours (via p0/p1's free entry access) are visible.

---

## 5. Interlaced MAIN/SHADOW RAM for 640×512

The BBC Master 128 has two independent display RAM banks — MAIN and SHADOW — switchable via the ACCCON register (bit 0). CRTC register 8 controls interlace mode. When set to interlace sync + interlace video (`0b00000011`), the CRTC alternates between fields: odd fields read from one RAM bank, even fields from the other.

At 50Hz PAL with true interlace:
- **Field 1** (odd lines, 25Hz): MAIN RAM displayed, rows 1,3,5,…511 of the 625-line frame
- **Field 2** (even lines, 25Hz): SHADOW RAM displayed, rows 2,4,6,…512

Effective display resolution in Mode 0 with interlace: **640×512**.

### Temporal colour mixing

The human eye's temporal integration threshold is approximately 20Hz. At 25Hz per field, the two alternating images merge perceptually into a single fused image. If MAIN and SHADOW show complementary colours at the same spatial position, the eye sees the **average** of the two:

| MAIN colour | SHADOW colour | Apparent fused colour |
|---|---|---|
| Black (0,0,0) | White (1,1,1) | Mid-grey |
| Red (1,0,0) | Black (0,0,0) | Dark red |
| Red (1,0,0) | Yellow (1,1,0) | Orange |
| Blue (0,0,1) | White (1,1,1) | Light blue |

With 8 BBC colours in each field, the set of distinct apparent fused colours is:

```
{(A+B)/2 | A,B ∈ {black, red, green, yellow, blue, magenta, cyan, white}}
```

Many pairs produce the same average (e.g. black+white = red+cyan = green+magenta), giving approximately **22 distinct apparent colours** from the 64 possible field pairs — a significant expansion from the 8 physical colours.

### Palette independence between fields

Each field's palette update sequence is independent:
- Field 1 (MAIN): 128 strips × up to 7 hblank palette writes per strip
- Field 2 (SHADOW): 128 strips × up to 7 hblank palette writes per strip

The per-strip IRQ timing needs to fire correctly within each field's hblank periods. Since the fields are offset by one scanline, the timer calibration (`fliptime`) differs between fields. This requires the IRQ handler to track which field is active (detectable via the vsync phase or a frame counter) and apply the appropriate palette sequence.

### Combined with horizontal splits

Combining interlaced fields with mid-scanline colour splits gives a three-dimensional colour optimisation space:

| Dimension | Granularity | Mechanism |
|---|---|---|
| Vertical | 2-row strips (128 per frame) | Hblank palette writes |
| Horizontal | ~7 zones per scanline | Mid-scanline writes |
| Temporal | 2 fields (MAIN / SHADOW) | Interlaced field switching |

At each spatial position (zone, strip) the display cycles through up to **2 temporal states** at 25Hz. The apparent colour at that position is the perceptual average of those two states.

---

## 6. Solver Approach for Combined Technique

The `palsearch`-style solver would need to be extended substantially to handle all three dimensions jointly.

### Problem formulation

**Inputs:**
- Target image: 640×512 RGB
- Mode 0 ULA palette constraints (per-pixel index access as tabulated above)
- Hblank write budget: 7 entries per strip per field
- Horizontal zone budget: 6–7 zones per scanline
- Temporal fusion model: apparent colour = (field1\_colour + field2\_colour) / 2

**Variables (per strip, per field):**
- Palette assignment: 16 entries × 8 BBC colours
- Palette delta vs previous strip: ≤7 changed entries
- Zone boundaries: positions of N mid-scanline palette writes
- Zone palette values for entries 7 and 15 at each zone

**Objective:**
Minimise perceptual error between target image and the fused apparent colour at each (zone, strip) position across both fields.

### Simplification: decouple vertical and horizontal passes

A practical two-pass approach:

**Pass 1 (vertical, per-field):** For each field independently, run a variant of the palsearch algorithm to find per-strip palettes that minimise vertical error, ignoring horizontal splits. This is the existing palsearch problem, extended to handle Mode 0's tighter p4–p7 constraints.

**Pass 2 (horizontal, per-zone per-strip):** Given the per-strip palette from Pass 1, optimise mid-scanline writes at zone boundaries to correct the largest local colour errors horizontally. Since only entries 7 and 15 are changed at zone boundaries (for maximum pixel coverage), this pass needs to find the 6–7 entry-7 and entry-15 colour values that minimise error across each zone independently.

**Pass 3 (temporal):** Jointly adjust the MAIN and SHADOW field palettes at each (zone, strip) to better approximate intermediate target colours through temporal averaging. This is a local search over the 22 achievable apparent colours at each position.

### Constraint adjustments for Mode 0

The p6/p7 locking to entries 7 and 15 means the SMT formulation from palsearch requires extra constraints:

```python
# In Mode 0, p6 and p7 can only use palette entries 7 and 15
# p6_index = (b1, 1, 1, 1) → either 0b0111 = 7 or 0b1111 = 15
# p7_index = (b0, 1, 1, 1) → either 0b0111 = 7 or 0b1111 = 15

# This means for any screen byte:
# - pixel 6 always shows palette[7] or palette[15]
# - pixel 7 always shows palette[7] or palette[15]
# - pixels 4,5 always show palette[3], [7], [11], or [15]
# etc.

def mode0_accessible_entries(pixel_position):
    """Return set of palette indices accessible by pixel at this byte position."""
    forced_ones = max(0, pixel_position - 1)  # number of forced 1 bits in LSB
    # Index = {free_bit, ...1s...}
    # Number of free bits = 4 - forced_ones (but min 1)
    free_bits = max(1, 4 - forced_ones)
    step = 1 << forced_ones  # entries separated by 2^forced_ones
    base = (1 << forced_ones) - 1  # minimum accessible entry
    return set(range(base, 16, step))
    # pixel 0,1: step=1, base=0 → {0,1,2,...,15}
    # pixel 2,3: step=2, base=1 → {1,3,5,...,15}
    # pixel 4,5: step=4, base=3 → {3,7,11,15}
    # pixel 6,7: step=8, base=7 → {7,15}
```

---

## 7. Assessment and Comparison

### What is achievable

Combining all three techniques in Mode 0 on BBC Master:

| Technique alone | Effective colours |
|---|---|
| Mode 0, no tricks | 2 |
| Per-strip palette changes (Mode 0) | ~8–12 apparent colours across vertical strips |
| + Horizontal zone splits (6–7 zones) | ~48–84 distinct (strip, zone) colour pairs |
| + Interlaced MAIN/SHADOW temporal mixing | ~22 apparent colours per (strip, zone) position, independently per zone |
| **Combined** | **Potentially 100+ distinct apparent colours across the image** |

The 640×512 effective resolution with ~100+ apparent colours would represent a dramatic step beyond the 8-colour hardware limitation — comparable in ambition to the Mode 1 `palsearch` image display, but at twice the spatial resolution in both axes.

### Requirements not met by the original demo

| Requirement | Status |
|---|---|
| Stable rasters | **Essential** — ±10 cycle jitter causes ±80 pixel horizontal position error, making zone splits useless |
| Precise field-phase detection | **Needed** — to apply correct MAIN vs SHADOW palette sequence per field |
| Extended solver (3D optimisation) | **New work** — palsearch only handles vertical strips |
| IRQ handler for both fields | **New work** — current showimage IRQ doesn't track field parity |
| Mid-scanline write routine | **New work** — needs to be interleaved with strip-based updates |

### Mode 0 vs Mode 1 for this technique

| | Mode 1 (showimage) | Mode 0 (proposed) |
|---|---|---|
| Spatial resolution | 320×256 (×2 with interlace = 320×512) | 640×256 (×2 with interlace = 640×512) |
| Palette freedom per byte | p0/p1 free, p2/p3 odd-only | p0/p1 free, progressively locked to {7,15} |
| Solver complexity | Moderate (existing palsearch) | Higher (tighter p4–p7 constraints) |
| Horizontal splits | Possible; 4px/cycle granularity (320px/80c) | Finer; 8px/cycle granularity (640px/80c) — **wider zones** |
| Stable raster requirement | Beneficial | **Critical** |
| Temporal mixing benefit | Same (22 apparent colours) | Same |

Mode 0's wider per-cycle zone width (48–56 pixels minimum) is less fine-grained than Mode 1 (24–28 pixels minimum for horizontal splits). Mode 1 with interlace (320×512) may therefore be a more practical target: better palette solver freedom, finer horizontal zones, same temporal mixing benefit, and half the spatial data to optimise.
