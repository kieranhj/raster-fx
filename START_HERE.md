# raster-fx: start here

Raster FX Framework: a BBC Micro (6502, BeebAsm) framework for per-scanline raster effects, with
many effects each on its own branch (twisters, ruptures, wibbles, zoomers, logos, Doom-style
screens). Effects playground / demo parts, 2017-2021.

| | |
|---|---|
| GitHub | https://github.com/kieranhj/raster-fx (public) |
| Local path | D:\beeb\mine\raster-fx (moved from OneDrive\BEEB\Repos\raster-fx on 2026-11-22) |
| Branch | width-spans-mode1 (25 commits ahead of master, 1 behind) |
| Other branches | master plus ~30 effect branches (dot-tunnell, frak-zoomer, mode0-twister*, mode2-twister, vertical-rupture, wibble-*, width-span-*, ...); wip/palsearch, wip/rot-and-scale-offset, wip/rot-and-scale-vrup, wip/rotate-and-scale (pushed snapshots) |
| Last commit | 2021-03-06: Fix line number. |

## What's in here
- `raster-fx.asm` the framework/top level; `examples/` the effects; `lib/` support code
- `screens/`, `pics/`, `*.png`, `*.bin` logo and screen data (BitShifters logos in modes 0/1/2, doom.bin ...)
- `basic/`, `circle.bas`, `mangle.bas` BASIC helpers
- `make.bat` build; `run.bat` / `jsbeeb.bat` / `runme.url` run it in jsbeeb
- Untracked: `palsearch/` (only `__pycache__` now; the work is on wip/palsearch), `__pycache__/`, `.vscode/`

## Build and run
- `make`: runs `make.bat` via the wrapper Makefile (added 2026-11-22): `..\..\Bin\beebasm.exe`
  assembles `raster-fx.asm` -> `raster-fx.ssd` (gitignored), log in compile.txt. **Works**
  (checked 2026-11-22, on width-spans-mode1).
- `run.bat` copies the .ssd into `..\jsbeeb-kieranhj\discs` and opens runme.url
  (http://localhost:8000/...model=Master); `jsbeeb.bat` starts that server with
  `python -mSimpleHTTPServer` (Python 2, gone) from the **old path**
  `C:\Users\khcon\OneDrive\BEEB\Repos\jsbeeb-kieranhj` (now D:\beeb\mine\jsbeeb-kieranhj).

## Local changes
- No tracked changes; untracked folders as above. No stashes.
- `mode2-twister` is local only (not on GitHub; tip is "Create LICENSE", 2020-05-27).
- The four `wip/*` branches hold palette-search and rotate-and-scale experiments.

## Status and next steps
- Last work 2019-10 (MODE 1 width spans: scaled logo, quads, rotating cuboid) and a 2021 fix.
  No TODO/plan found; the README is one line.

## See also
README.md; D:\beeb\mine\jsbeeb-kieranhj (the emulator run.bat uses).
