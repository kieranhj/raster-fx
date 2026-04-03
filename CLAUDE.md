# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BBC Micro 6502 assembly framework for real-time raster effects. The output is a `.ssd` floppy disk image that runs on a BBC Microcomputer or emulator. The current branch implements a "twister" effect using CRTC register manipulation for per-scanline horizontal scrolling and width distortion.

## Build

```batch
make.bat
```

This runs:
```batch
bin\beebasm.exe -i raster-fx.asm -do raster-fx.ssd -boot MyFX -v > compile.txt
```

Output: `raster-fx.ssd` (BBC Micro disk image). Build log in `compile.txt`.

## Run / Test

```batch
run.bat
```

Copies the SSD to the jsbeeb emulator directory and opens it in the browser. Requires jsbeeb checked out at `..\jsbeeb-kieranhj`.

To start the jsbeeb HTTP server separately:
```batch
jsbeeb.bat
```

## Architecture

### Framework Loop

`raster-fx.asm` implements a fixed-function harness plus a pluggable FX module:

- **Harness** (`main`): Initialises MODE 1, sets up VIA Timer 1 to fire at raster line 0, then loops every VBLANK calling three FX hooks.
- **`fx_init_function`**: One-shot setup — loads data files from disk, initialises tables.
- **`fx_update_function`**: Called during VBLANK — advance animation state, update palette.
- **`fx_draw_function`**: Called at raster line 0 with cycle-accurate timing — writes CRTC registers per scanline to produce the effect.
- **`fx_kill_function`**: Cleanup — restores CRTC registers, disables interrupts.

### Raster Stabilisation

After the Timer 1 interrupt fires, the code reads the T1 low counter (`&FE44`) to detect ±2 cycle jitter and compensates with a dynamic branch into NOPs. By the end of this stabilisation sequence the raster position is known to cycle accuracy, enabling pixel-perfect per-line CRTC writes.

### Twister Effect

Each of 30 character rows, the draw function:
1. Calls `update_rot` — advances a SIN/COS lookup to get the current rotation angle.
2. Calls `set_rot` — writes CRTC R12/R13 (screen start address) to scroll the row horizontally.
3. Modifies CRTC R0 (horizontal total) to distort row width, creating the 3D twist illusion.
4. Uses palette dithering for shaded bands.

Screen address lookup tables (`twister_vram_table_LO/HI`) and a 4096-entry `cos` table drive the animation.

### Key Constants

| Symbol | Value | Meaning |
|--------|-------|---------|
| `screen_base_addr` | `&3000` | Start of MODE 1 screen |
| Frame period | `312*64-2` | Cycles per 50Hz PAL frame |
| Code origin | `&1900` | Load address |
| Zero page base | `&70` | Framework zero-page variables |

### Library (`lib/`)

| File | Purpose |
|------|---------|
| `bbc.h.asm` | BBC OS constants, keyboard codes |
| `disksys.asm` | OSFILE-based disk loading |
| `exo.asm` | Exomizer decompressor |
| `unpack.asm` | Generic unpacker |
| `vgmplayer.asm` | VGM music replay |

### Data Files (bundled into SSD)

- `parrpic.bin` — precomputed screen pixel data (20 KB)
- `parrpal.bin` — palette entries (1.2 KB)
