# palsearch.py — improvement ideas

## Greedy solver quality

The greedy hill-climber finds a local optimum within the CHANGE_PER_ROW=9
budget. It can get stuck: the 9-step window isn't enough to escape a bad
configuration inherited from the previous section. These options address that.

---

## Option 1 — Random restarts

Run the greedy k times (e.g. 10–20) for each section, each time starting from
a randomly-perturbed copy of the previous palette. Keep the result with the
highest frequency-weighted coverage score.

- **Cost:** k× runtime per section (still seconds total at k=10–20)
- **Effort:** Low — wrap `_greedy_palette` in a loop, compare scores
- **Benefit:** Escapes local optima that depend on a bad starting point

---

## Option 2 — Simulated annealing

Replace the strict "only accept improvements" rule with a temperature schedule
that occasionally accepts downhill moves early on, cooling to greedy behaviour
by the end of the budget.

- **Cost:** Same asymptotic cost as greedy (one pass per budget step)
- **Effort:** Medium — add temperature schedule, acceptance probability
- **Benefit:** Can escape local optima without running the solver multiple times

---

## Option 3 — Beam search

Keep the top-k palettes at each budget step rather than committing to one.
At each step, expand every candidate in the beam with all 112 single-slot
changes, score them all, and retain the top-k.

- **Cost:** k× per step (k=5–10 is practical)
- **Effort:** Medium — refactor `_greedy_palette` to maintain a list of states
- **Benefit:** Much less likely to commit to a globally bad choice early;
  closer to optimal without full enumeration

---

## Overall image quality

### Option 4 — Palette-aware re-dithering (highest impact)

Currently the dither runs first assuming all 8 BBC colours are available, then
the palette solver runs on the result. Pixels that can't be matched fall
through to best-effort (nearest byte). Instead, after solving the palette,
re-run the dither for that section using only the colours actually present in
the solved palette. This eliminates best-effort fallback and produces dither
patterns tuned to what the hardware can actually display.

- **Cost:** ~2× dither time per section (small compared to solver)
- **Effort:** Medium — pass the solved palette back into a palette-constrained
  dither function; replace `ordered_dither_2` lookup with palette-filtered mixes
- **Benefit:** Eliminates best-effort fallback; biggest single quality win

---

### Option 5 — Iterative feedback loop

Extend option 4 by iterating: dither → solve → re-dither with actual palette →
re-solve → repeat until stable. Usually converges in 2–3 passes.

- **Cost:** 2–3× total pipeline time per section
- **Effort:** Low once option 4 is done — wrap section processing in a loop
  with a convergence check (palette unchanged between passes)
- **Benefit:** Further improves on option 4 for sections where the palette
  changes significantly between passes

---

### ~~Option 6 — Better section 0 initialisation~~ ✓ DONE

~~The greedy starts from all-black for section 0, which is a poor baseline for
the 127 sections that inherit from it. Seed the initial palette instead from
the image's global dominant colours (histogram of the top 8 most-common BBC
colour approximations across the whole image, or k-means on the preprocessed
pixel values).~~

---

### Option 7 — Expose `mixno`

The OCaml script has a `-mixno` flag that selects higher-contrast dither mix
combinations (e.g. black+white alongside mid-tones rather than only adjacent
colours). Currently hardcoded to 0 in Python.

- **Cost:** None at runtime
- **Effort:** Trivial — add `--mixno` CLI flag, thread through to
  `ordered_dither_2` / `dither_section_ordered`
- **Benefit:** Lets you trade smoothness for contrast; useful for images with
  strong highlights or shadows

---

### Option 8 — Pre-sharpening

Dithered images on low-resolution displays look softer than the source.
A mild unsharp mask before conversion can recover perceived detail, especially
with ordered dither which tends to blur edges.

- **Cost:** Negligible
- **Effort:** Trivial — apply `ImageFilter.UnsharpMask` (or similar) to the
  input image before converting to numpy array; add `--sharpen` flag
- **Benefit:** Improved perceived sharpness, especially on edges

---

### Option 9 — Adaptive dither mode per section

Use ordered dither for smooth/gradient sections and FS for high-detail/edge
sections. The section's pixel variance is cheap to compute.

- **Cost:** Negligible
- **Effort:** Low — compute per-section variance, switch dither mode above a
  threshold; add `--dither auto` mode alongside existing `ordered`/`fs`
- **Benefit:** Best of both dither modes without manual tuning per image

---

### Option 10 — Section boundary smoothing

Each 2-row section is solved independently, which can produce visible
horizontal banding where the palette changes sharply. Constraining adjacent
sections' palettes to share more slots (beyond the current 9-change limit)
would smooth transitions.

- **Cost:** Increases solver constraint complexity slightly
- **Effort:** Medium — add a "shared slots" soft constraint to the greedy
  scoring that penalises palette divergence between neighbouring sections
- **Benefit:** Reduces horizontal banding artifacts at section boundaries

---

## Per-scanline palette changes (stable raster hardware)

The stable raster implementation provides enough cycles to change 9 palette
entries on every scanline, not just every 2. The current CHUNKSIZE=2 design
was a hardware concession that can now be removed.

### ~~Option 11 — Switch to per-scanline sections (CHUNKSIZE=1)~~ ✓ DONE

~~Halve CHUNKSIZE from 2 to 1 so each palette is optimised for a single row
instead of a pair. Sections increase from 128 to 256; each section's palette
no longer compromises between two rows with potentially different colour
content.~~

Implemented as `--chunk-size` (1 or 2, default 2) and `--changes` (default 9)
CLI options in both `palsearch.py` and `showbin.py`. Data size at chunk-size=1:
22816 bytes (16 + 9×256 palette + 20480 screen).

---

### Option 12 — Vertical dithering

With per-scanline palettes in place, deliberately alternate a palette slot
between two colours on adjacent scanlines. A pixel using that slot appears as
colour A on row N and colour B on row N+1 — perceived as a blend of A and B at
normal viewing distance. Combined with the existing horizontal Bayer dither
(4 pixels wide), this creates a 4×2 dither cell and roughly doubles the number
of representable colours.

To exploit this fully, palsearch would process scanline pairs jointly: given
two adjacent rows, find palette assignments for each that together cover
colours neither can represent alone, and choose screen bytes for both rows with
that alternation in mind.

- **Cost:** Roughly 2× solver complexity per pair (joint optimisation over two
  rows simultaneously)
- **Effort:** High — new joint section solver; the mixes table and dither
  function need extending to consider vertical colour pairs; requires option 11
- **Benefit:** Approximately doubles the effective colour depth; the largest
  possible quality improvement given the hardware constraints

---

## Known bugs

### Bug 1 — `--look-ahead` causes spurious colour bands (e.g. magenta at top)

The look-ahead credits a step 1 choice with the full frequency of a quad that
a follow-up step 2 *could* cover — treating future gain as certain.  But the
greedy evaluates step 2 independently and may choose something with higher
direct gain instead.  Step 1 then leaves an unusual colour (e.g. magenta) in
a palette slot for no benefit, and the best-effort fallback maps surrounding
unmatched quads to that colour.

The white head fix works because white quads are dominant enough that step 2
naturally wins the next step too.  For sections where the anticipated quad is
not dominant enough, step 2 goes elsewhere and step 1's choice is wasted.

**Fix options (in order of simplicity):**

1. **Reduce `_LOOK_AHEAD_FACTOR`** (e.g. 0.3–0.5) — makes look-ahead a
   tiebreaker rather than an override.  Prevents zero-direct-gain step 1
   choices from being selected purely on speculative future gain.

2. **Only look ahead when step 1 has zero direct gain** — if step 1 already
   covers something useful, don't add speculative bonus on top.  Limits
   look-ahead to the exact case it was designed for.

3. **Commit to both steps as a pair** — when a 2-step combo is chosen, apply
   both changes immediately and consume 2 budget slots.  Guarantees step 2
   follows, eliminating over-optimism entirely.  Requires restructuring the
   greedy loop to support variable-size steps.
