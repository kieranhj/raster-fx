@echo off
rem C:\Home\Python27\python.exe precomp-dot.py dot_code.asm
rem C:\Home\Python27\python.exe precomp-dot-shifts.py dot_plot_code.asm
rem C:\Home\Python27\python.exe precomp-dot-columns.py dot_column_code.asm
..\..\Bin\beebasm.exe -i raster-fx.asm -do raster-fx.ssd -boot MyFX -v > compile.txt
