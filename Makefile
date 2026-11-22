# Wrapper so that `make` works from PowerShell / Windows Terminal.
# GNU make runs recipes with cmd.exe here (no sh on PATH).
# make.bat assembles raster-fx.asm into raster-fx.ssd with ..\..\Bin\beebasm.exe.
.PHONY: all build help
all: build

build:
	cmd /c .\make.bat

help:
	@echo make        - build raster-fx.ssd (runs make.bat; output in compile.txt)
	@echo make help   - this list
	@echo run.bat / jsbeeb.bat launch an emulator (not wrapped). See START_HERE.md
