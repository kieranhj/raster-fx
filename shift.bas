10 MODE 1
11 S%=1
20 *LOAD SCREEN 3000
21 M%=0
22 FOR T%=0 TO S%-1
23 M%=M% OR (&11*(2^T%))
24 NEXT
25 N%=255-M%
26 P%=2^S%
27 Q%=2^(4-S%)
30 FOR C%=79 TO 0 STEP -1
40 A%=&3000 + C%*8
50 FOR R%=0 TO 15
60 FOR L%=0 TO 7
70 B%=A% + L% + R%*640
80 E%=(?B% AND N%) DIV P%
90 IF C%=0 THEN F%=0 ELSE F%=(?(B%-8) AND M%) * Q%
100 ?B%=E% OR F%
110 NEXT L%
120 NEXT R%
130 NEXT C%
150 OSCLI"SAVE S"+STR$(S%)+" 3000 +2800"
