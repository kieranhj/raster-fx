10 MODE 2
20 COLOUR 132:CLS
30 FOR N%=0 TO 31:PRINT TAB(16,N%)"R";N%;:NEXT
40 FOR N%=0 TO 255
50 L%=N% AND 7
60 GCOL 0,L%
70 IF L%=4 GCOL 0,0
80 IF L%=0 GCOL 0,7
70 IF L%=0 MOVE 12,1023-N%*4:PLOT1,256,0 ELSE FOR X%=1 TO L%:MOVE 12+(X%-1+L%)*72, 1023-N%*4:PLOT 1,56,0:NEXT
80 NEXT
90 IF GET
100 *SAVE SCREEN 3000 +5000
