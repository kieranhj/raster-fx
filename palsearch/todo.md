# palsearch.py — improvement ideas

## Greedy solver quality

The greedy hill-climber finds a local optimum within the CHANGE_PER_ROW=9
budget. It can get stuck: the 9-step window isn't enough to escape a bad
configuration inherited from the previous section. These options address that.

---

### ~~Option 1 — Random restarts~~ ✓ DONE

~~Run the greedy k times (e.g. 10–20) for each section, each time starting from
a randomly-perturbed copy of the previous palette. Keep the result with the
highest frequency-weighted coverage score.~~

Implemented as `--restarts N` (default 1). Each restart beyond the first
starts from a randomly-perturbed copy of `previous_palette`; the run with the
highest frequency-weighted coverage wins. Budget is always counted against the
real previous palette (not the perturbed state).

---

### ~~Option 2 — Simulated annealing~~ ✓ DONE

~~Replace the strict "only accept improvements" rule with a temperature schedule.~~

Implemented as `--anneal N` (default 0 = off). `_anneal_palette` runs N SA steps
with exponential cooling from `t_start × total_freq` to `t_end × total_freq`.
Accepts downhill moves with probability `exp(gain / T)`. Budget is enforced as a
hard constraint. Typical values: 100-500 steps.

---

### ~~Option 3 — Beam search~~ ✓ DONE

~~Keep the top-k palettes at each budget step rather than committing to one.~~

Implemented as `--beam N` (default 1 = greedy). `_beam_palette` expands all
beam states with all 112 single-slot candidates each step, retaining the top-N
unique states by frequency-weighted coverage score. Values of 5–10 give
substantially better coverage at N× the solver cost per section.

---

## Overall image quality

### ~~Option 4 — Palette-aware re-dithering~~ ✓ DONE

~~Currently the dither runs first assuming all 8 BBC colours are available, then
the palette solver runs on the result.~~

Implemented as `--redither`. After solving the palette for each section,
`_redither_bytes` scores all 256 byte values against the preprocessed source
pixels and picks the best — eliminating best-effort fallback.

---

### ~~Option 5 — Iterative feedback loop~~ ✓ DONE

~~Extend option 4 by iterating: dither → solve → re-dither → re-solve.~~

Implemented as `--iterate N` (default 1). Each pass beyond the first re-dithers
using only the solved palette (via `_redither_bytes`), then re-solves. Stops
early when the palette is unchanged between passes. Pairs well with `--redither`.

---

### ~~Option 6 — Better section 0 initialisation~~ ✓ DONE

~~The greedy starts from all-black for section 0, which is a poor baseline for
the 127 sections that inherit from it. Seed the initial palette instead from
the image's global dominant colours.~~

---

### ~~Option 7 — Expose `mixno`~~ ✓ DONE

~~The OCaml script has a `-mixno` flag that selects higher-contrast dither mix
combinations.~~

Implemented as `--mixno N` (default 0). Controls which mix combination set is
used in the ordered dither.

---

### ~~Option 8 — Pre-sharpening~~ ✓ DONE

~~Dithered images on low-resolution displays look softer than the source.~~

Implemented as `--sharpen F` (default 0.0). Applies `ImageFilter.UnsharpMask`
to the input image before conversion.

---

### ~~Option 9 — Adaptive dither mode per section~~ ✓ DONE

~~Use ordered dither for smooth sections and FS for high-detail/edge sections.~~

Implemented as `--dither auto`. Computes perceptual luminance variance for each
section; sections above `--auto-threshold` (default 600) use Floyd-Steinberg,
sections below use ordered dither.

---

### ~~Option 10 — Section boundary smoothing~~ ✓ DONE

~~Each section is solved independently, producing banding where the palette
changes sharply between sections.~~

Implemented as `--smooth F` (default 0 = off). Subtracts `F` (pixel-frequency
units) from the greedy gain whenever a new slot change is considered. This
raises the bar for gratuitous changes, promoting palette continuity between
sections. Values of 5–30 are typical.

---

## Per-scanline palette changes (stable raster hardware)

### ~~Option 11 — Switch to per-scanline sections (CHUNKSIZE=1)~~ ✓ DONE

~~Halve CHUNKSIZE from 2 to 1 so each palette is optimised for a single row
instead of a pair.~~

Implemented as `--chunk-size` (1 or 2, default 2) and `--changes` (default 9)
CLI options in both `palsearch.py` and `showbin.py`. Data size at chunk-size=1:
23040 bytes (256 + 9×256 palette + 20480 screen).

---

### ~~Option 12 — Vertical dithering~~ ✓ DONE

~~With per-scanline palettes in place, deliberately alternate a palette slot
between two colours on adjacent scanlines.~~

Implemented as `--vertical-dither` (requires `--chunk-size 1`). Processes
scanline pairs jointly: `_vertical_dither_pair` scores all 256 byte values
against both rows simultaneously, choosing the byte that minimises combined
perceptual error. The same byte value is written to both rows; the independent
per-row palettes produce different colours, which the viewer perceives as a
blend.

---

## Image preprocessing

BBC Mode 1 has 8 colours at the corners of the RGB cube (each channel 0 or
255). Pixels that lie closer to those corners require less dithering to
reproduce — so preprocessing that moves pixels toward the corners directly
improves output quality.  Options are ordered by expected impact.

---

### ~~Prep 1 — Saturation boost~~ ✓ DONE  `--saturation F`

**Value: Very High.**  Unsaturated pixels (pastels, skin tones, greys) are far
from all 8 BBC colour corners, producing large quantisation errors and noisy
dithering.  Boosting saturation pushes pixels toward the corners and reduces
dither noise.  Most photographic images benefit from F=1.3–1.8.

Implemented via `ImageEnhance.Color(img).enhance(F)`.

---

### ~~Prep 2 — Auto-levels~~ ✓ DONE  `--autolevel`

**Value: High.**  Many photos don't use the full 0–255 range.  Per-channel
histogram stretch maps the darkest pixel to 0 and the lightest to 255,
maximising utilisation of the 8 BBC colours and preventing washed-out results.

Implemented via `ImageOps.autocontrast(img)`.

---

### ~~Prep 3 — Contrast adjustment~~ ✓ DONE  `--contrast F`

**Value: High.**  A contrast boost (F > 1) pushes midtones toward the light or
dark extremes — again moving pixels closer to the BBC colour corners.  Pairs
well with auto-levels; apply after.

Implemented via `ImageEnhance.Contrast(img).enhance(F)`.

---

### ~~Prep 4 — Brightness / exposure~~ ✓ DONE  `--brightness F`

**Value: Medium.**  Simple multiplicative brightness adjustment.  Useful for
systematically underexposed or overexposed inputs.

Implemented via `ImageEnhance.Brightness(img).enhance(F)`.

---

### ~~Prep 5 — Input gamma~~ ✓ DONE  `--input-gamma F`

**Value: Medium.**  Exposes an additional gamma step on the image pixels before
scoring. F > 1 brightens midtones; F < 1 darkens them. Separate from the
internal INV_GAMMA=1.7 scoring curve.

Implemented via `img.point(lut)` with a 256-entry curve.

---

### ~~Prep 6 — Hue rotation~~ ✓ DONE  `--hue DEG`

**Value: Medium.**  Rotates all hues by DEG degrees.  Useful when a dominant
hue falls between BBC primaries (e.g. orange → red/yellow).

Implemented via vectorised numpy RGB→HSV→RGB conversion.

---

### ~~Prep 7 — Denoise~~ ✓ DONE  `--denoise`

**Value: Low-Medium.**  Prevents source noise from being encoded into the dither
pattern.

Implemented via `ImageFilter.MedianFilter(size=3)`.

---

### ~~Prep 8 — Posterise~~ ✓ DONE  `--posterise N`

**Value: Low.**  Reduces each channel to N bits (1–7).  Stylistic option for
a flat, graphic-art look.

Implemented via `ImageOps.posterize(img, N)`.

---

## Known bugs

### ~~Bug 1 — `--look-ahead` causes spurious colour bands~~ ✓ FIXED

~~The look-ahead credits a step 1 choice with the full frequency of a quad that
a follow-up step 2 *could* cover — treating future gain as certain.~~

Fixed with option 2: look-ahead bonus only activates when direct gain == 0.
This prevents a speculative step-1 choice from overriding a genuinely useful
direct gain.
