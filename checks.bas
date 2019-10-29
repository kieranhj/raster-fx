10 MODE 1:C%=3
11 cx=0:cy=0:cz=-160
12 ax=0:ay=-128:az=0
13 nx=0:ny=1:nz=0
14 S%=80
15 px=S%:py=ay:pz=0
16 scale=160:vpx=160:vpy=128
16 sx=vpx + scale * (px - cx) / (pz - cz)
17 sy=vpy + scale * (py - cy) / (pz - cz)
18 PRINT sx-vpx,TAB(20);sy
20 REPEAT
21 last_sy=sy
22 pz=pz+S%
30 sx=vpx + scale * (px - cx) / (pz - cz)
40 sy=vpy + scale * (py - cy) / (pz - cz)
50 PRINT sx-vpx,TAB(20);INT(sy);TAB(30);(INT(sy)-INT(last_sy))
80 UNTIL sy-last_sy<2
81 REPEAT UNTIL GET
82 sy=vpy + scale * (py - cy) / (pz - cz)
83 ry=vpy + scale * (py - cy) / (0 - cz)
84 px = cx - vpx * (pz - cz) / scale
85 px = (px DIV S%)*S%
86 last_sx=vpx + scale * (px - cx) / (pz - cz)
87 last_rx=vpx + scale * (px - cx) / (0 - cz)
88 sy=INT(sy)-1
90 REPEAT
100 sx=vpx + scale * (px - cx) / (pz - cz)
120 rx=vpx + scale * (px - cx) / (0 - cz)
131 GCOL 0,C%
140 MOVE sx*4,sy*4:MOVE rx*4,ry*4
150 PLOT 85,(last_rx-1)*4,ry*4
160 MOVE (last_sx-1)*4,sy*4:PLOT 85,sx*4,sy*4
161 last_sx=sx:last_rx=rx
170 C%=C%EOR2
171 px=px+S%
180 UNTIL sx>320
190 sy=0:pz=0
191 C%=2
200 REPEAT
210 last_sy=sy
220 pz=pz+S%
230 sx=vpx + scale * (px - cx) / (pz - cz)
240 sy=vpy + scale * (py - cy) / (pz - cz)
250 GCOL 3,C%
260 FOR y=INT(last_sy) TO INT(sy)-1
270 MOVE 0,y*4:DRAW 1279,y*4
280 NEXT
281 C%=C%EOR2
290 UNTIL sy-last_sy<2
300 REPEAT UNTIL GET
301 px=S%
302 total=0
303 CLS
304 last_wx=0
310 FOR y=INT(sy) TO 0 STEP -1
320 pz=cz + scale * (py - cy) / (y - vpy)
330 sx=vpx + scale * (px - cx) / (pz - cz)
331 wx=sx-vpx
332 IF INT(last_wx)<>INT(wx) THEN bytes=80 + (wx+3)DIV4 ELSE bytes=0
333 last_wx=wx
340 PRINT INT(wx),TAB(15);y;TAB(35);bytes
341 total=total+bytes
350 NEXT
360 PRINT total, total*4, (total*4)/1024
371 F%=1
372 pz=cz + scale * (py - cy) / (INT(sy) - vpy)
373 G%=scale * (px - cx) / (pz - cz)
374 PRINT "Drawing widths from ";G%;" to ";S%
376 REPEAT UNTIL GET
377 CLS
380 A%=&3000: REM address
390 L%=0: REM scanline
420 FOR W%=G% TO S%: REM width in pixels
421 T%=80+(W%+3)DIV4: REM total byte width of the row
422 IF A%+T%>&8000  THEN OSCLI"SAVE check"+STR$(F%)+" 3000 8000":A%=&3000:F%=F%+1:CLS
430 FOR O%=0 TO 3: REM pixel offset
450 FOR X%=0 TO (T%*4)-1
460 C%=((X%+O%) DIV W%) MOD 2: REM pixel on/off
470 P%=X% MOD 4: REM which pixel
471 B%=A%+(X%DIV4)*8+L%
480 IF C%=1 THEN ?B%=?B% OR (&88 DIV 2^P%)
490 NEXT
500 L%=(L%+1)MOD8
501 IF L%=0 THEN A%=A%+T%*8
510 NEXT
540 NEXT
550 OSCLI"SAVE check"+STR$(F%)+" 3000 8000"
