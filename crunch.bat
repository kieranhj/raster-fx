@echo off
rem bin\exomizer.exe level -c -M256 build/text.masked.bin@0x3000 -o build/text.exo
rem bin\exomizer.exe level -c -M256 build/text2.masked.bin@0x3000 -o build/text2.exo
rem bin\exomizer.exe level -c -M256 build/text3.masked.bin@0x3000 -o build/text3.exo
rem bin\exomizer.exe level -c -M256 build/patarty.masked.bin@0x3000 -o build/patarty.exo

bin\exomizer.exe raw -c -m 256 build/text.masked.bin -o build/text.exo
bin\exomizer.exe raw -c -m 256 build/text2.masked.bin -o build/text2.exo
bin\exomizer.exe raw -c -m 256 build/text3.masked.bin -o build/text3.exo
bin\exomizer.exe raw -c -m 256 build/patarty.masked.bin -o build/patarty.exo
