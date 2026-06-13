# palsearch — Progress Snapshot

## Current Status

The Python palsearch tool and Gradio web UI are working on branch `wip/palsearch`, including deployment on Hugging Face Spaces. Recent work removed three broken options (remap, iterate, vertical dither — all had the same nearest-colour-not-dithering bug), added blue-noise ordered dithering, fixed posterise darkening, and added a "Run on BBC Micro" button that builds an SSD and opens the jsbeeb emulator at bbc.xania.org with the disc image embedded in the URL. The `requirements.txt` was fixed to use `z3-solver` (not `z3`). One minor `.gitignore` change is uncommitted.

---

## Completed Work

### Recent session (this conversation)

- **Removed Options 4, 5, 12** (remap, iterate, vertical dither): all three discarded dithered quads and did nearest-colour byte selection, producing flat undithered output. `_redither_bytes` / `_remap_bytes` and `_vertical_dither_pair` deleted. The fundamental issue is that BBC Mode 1 bytes encode 4 pixels simultaneously, making per-pixel FS error diffusion at byte granularity very difficult.
- **Blue-noise ordered dither** (`--dither bn`): Bundles a 128×128 CC0 blue-noise texture (`palsearch/bluenoise.png` from Calinou/free-blue-noise-textures). `blue_noise_dither_2` replaces the 2×2 Bayer position with a threshold from the texture (>>6 gives 0–3). `dither_section_bn` added. Wired into CLI and Gradio UI.
- **Posterise fix**: `ImageOps.posterize` zeroes low bits without rescaling (1-bit max was 128, not 255). Replaced with a LUT that quantises to N bits then rescales to full 0–255. Fixed in both `palsearch.py` and `gradio_ui.py` preview pipeline.
- **Converted image 3× upscale**: `_convert` resizes the preview `Image.NEAREST` to 960×768 before returning to Gradio, so BBC pixels are large enough to inspect.
- **Run on BBC Micro button**: Pure-Python DFS catalog parser (`_patch_ssd`) overwrites PIC/PAL data in the pre-built `raster-fx.ssd` template — no beebasm needed at runtime. The SSD is zipped, base64-encoded, and embedded in a `bbc.xania.org/#autoboot&model=master&disc1=data:<b64>` URL. Rendered as a styled HTML link (not a `gr.Button`) to work on both localhost and HF Spaces. Uses `gr.State` + `.then(show_progress="hidden")` to avoid a progress bar on the link.
- **HF Spaces support**: `app.py` entry point, `requirements.txt` (gradio, Pillow, numpy, z3-solver). All platform-specific code (beebasm.exe, webbrowser.open) removed from the runtime path.
- **UI layout**: Convert button, emulator link, status, and downloads all grouped under the converted image in the right column. The empty "Output Options" tab was removed.

### Earlier work (previous sessions, already committed)

- Binary format: 256-byte palette header (page-crossing fix)
- Solver options: restarts, annealing, beam search, look-ahead, smooth
- Dither options: ordered, FS, auto (adaptive per-section), blue-noise
- Preprocessing pipeline: autolevel → gamma → contrast → brightness → saturation → hue → denoise → posterise → sharpen
- Section 0 initialisation from image dominant colours
- Gradio web UI with live preprocessing preview
- showbin.py: updated for 256-byte header

---

## Cleanup Needed

- **`.gitignore` change uncommitted**: 1 line added. Should be committed.
- **`examples/` directory untracked**: Appears new, needs review and possible commit.
- **`.claude/` directory untracked**: Contains skills/snapshot.md. Should be committed or gitignored.
- **Stash entries**: 11 old GitHub Desktop stashes on other branches — not blocking but worth housekeeping.
- **Empty Output Options tab**: The tab was emptied when vertical dither was removed but the `with gr.Tab("Output Options"):` block may still exist as a no-op. Should be removed if so.

---

## Immediate Next Steps

1. **Commit the `.gitignore` change** and any other uncommitted tidying.
2. **Test HF Spaces deployment** with the `z3-solver` fix — confirm z3 solver works end-to-end.
3. **Test blue-noise dither quality** side-by-side with ordered and FS on a variety of images (parrot, landscape, portrait) to decide on a good default.
4. **Remove the empty Output Options tab** if it still exists in the Gradio layout.

---

## Longer-term Backlog

- **Byte-level FS dithering**: The remap/redither concept is sound (re-render with FS after palette solve) but requires FS that understands the 4-pixel-per-byte constraint. Each byte's 4 pixels are chosen together, so error must diffuse to the same pixel slot in the next byte. The previous attempt had the right idea but also suffered from preprocess_pixel/BBC-colour space mismatch and missing dampening. Could be revisited with care.
- **chunk_size=1 SSD template**: The 6502 code is compiled with `CHUNK_SIZE=2`. Supporting chunk_size=1 in the Run button would need a second template or runtime assembly.
- **Beam + restarts interaction**: `--beam N` currently ignores `--restarts`.
- **Numpy vectorise dithering**: Ordered and FS dithering still use Python loops.
- **Parameter presets** in the UI (e.g. "fast", "quality").

---

## Key Notes

- **Output binary format**: `256 + changes_per_row × num_sections + 20480` bytes. The 256-byte padding ensures 6502 `LDA abs,X` never crosses a page boundary.
- **SSD template patching**: `_patch_ssd` parses the DFS catalog at bytes 0x000–0x1FF to find PIC (sector 23, 20480 bytes) and PAL (sector 103, variable length). It updates the PAL length in the catalog. The template must be rebuilt with beebasm if the 6502 code changes.
- **Emulator URL**: Uses the hash fragment (`#` not `?`) to avoid CloudFront's query-string length limit. jsbeeb parses both `location.search` and `location.hash`. The `data:` schema expects a ZIP containing the .ssd.
- **`z3` vs `z3-solver`**: The pip package is `z3-solver`, not `z3`. The wrong one has no `z3.Solver`.
- **Branch**: All work is on `wip/palsearch`.
