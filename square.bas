10 MODE 1
20 *LOAD SCREEN 3000
21 T%=&8000
30 FOR R%=31 TO 0 STEP -1
40 F%=&3040 + R%*640
41 T%=T%-512
50 FOR B%=511 TO 0 STEP -1
60 T%?B%=F%?B%
70 NEXT
80 NEXT
90 *SAVE SQUARE 4000 8000
100 ?&FE00=1:?&FE01=64
