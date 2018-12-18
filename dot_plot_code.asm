.dot_0000	;x=000 y=000
STA screen_ptr
STY screen_ptr+1
LDY #1
LDA #&CC
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #2
LDA #&CC
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0100	;x=001 y=000
STA screen_ptr
STY screen_ptr+1
LDY #1
LDA #&66
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #2
LDA #&66
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0200	;x=002 y=000
STA screen_ptr
STY screen_ptr+1
LDY #1
LDA #&33
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #2
LDA #&33
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0300	;x=003 y=000
STA screen_ptr
STY screen_ptr+1
LDY #1
LDA #&11
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #9
LDA #&88
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #2
LDA #&11
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #10
LDA #&88
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0001	;x=000 y=001
STA screen_ptr
STY screen_ptr+1
LDY #2
LDA #&CC
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #3
LDA #&CC
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0101	;x=001 y=001
STA screen_ptr
STY screen_ptr+1
LDY #2
LDA #&66
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #3
LDA #&66
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0201	;x=002 y=001
STA screen_ptr
STY screen_ptr+1
LDY #2
LDA #&33
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #3
LDA #&33
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0301	;x=003 y=001
STA screen_ptr
STY screen_ptr+1
LDY #2
LDA #&11
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #10
LDA #&88
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #3
LDA #&11
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #11
LDA #&88
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0002	;x=000 y=002
STA screen_ptr
STY screen_ptr+1
LDY #3
LDA #&CC
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #4
LDA #&CC
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0102	;x=001 y=002
STA screen_ptr
STY screen_ptr+1
LDY #3
LDA #&66
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #4
LDA #&66
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0202	;x=002 y=002
STA screen_ptr
STY screen_ptr+1
LDY #3
LDA #&33
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #4
LDA #&33
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0302	;x=003 y=002
STA screen_ptr
STY screen_ptr+1
LDY #3
LDA #&11
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #11
LDA #&88
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #4
LDA #&11
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #12
LDA #&88
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0003	;x=000 y=003
STA screen_ptr
STY screen_ptr+1
LDY #4
LDA #&CC
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #5
LDA #&CC
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0103	;x=001 y=003
STA screen_ptr
STY screen_ptr+1
LDY #4
LDA #&66
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #5
LDA #&66
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0203	;x=002 y=003
STA screen_ptr
STY screen_ptr+1
LDY #4
LDA #&33
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #5
LDA #&33
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0303	;x=003 y=003
STA screen_ptr
STY screen_ptr+1
LDY #4
LDA #&11
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #12
LDA #&88
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #5
LDA #&11
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #13
LDA #&88
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0004	;x=000 y=004
STA screen_ptr
STY screen_ptr+1
LDY #5
LDA #&CC
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #6
LDA #&CC
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0104	;x=001 y=004
STA screen_ptr
STY screen_ptr+1
LDY #5
LDA #&66
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #6
LDA #&66
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0204	;x=002 y=004
STA screen_ptr
STY screen_ptr+1
LDY #5
LDA #&33
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #6
LDA #&33
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0304	;x=003 y=004
STA screen_ptr
STY screen_ptr+1
LDY #5
LDA #&11
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #13
LDA #&88
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #6
LDA #&11
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #14
LDA #&88
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0005	;x=000 y=005
STA screen_ptr
STY screen_ptr+1
LDY #6
LDA #&CC
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #7
LDA #&CC
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0105	;x=001 y=005
STA screen_ptr
STY screen_ptr+1
LDY #6
LDA #&66
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #7
LDA #&66
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0205	;x=002 y=005
STA screen_ptr
STY screen_ptr+1
LDY #6
LDA #&33
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #7
LDA #&33
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0305	;x=003 y=005
STA screen_ptr
STY screen_ptr+1
LDY #6
LDA #&11
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #14
LDA #&88
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #7
LDA #&11
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #15
LDA #&88
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0006	;x=000 y=006
STA screen_ptr
STY screen_ptr+1
LDY #7
LDA #&CC
EOR (screen_ptr), Y
STA (screen_ptr), Y
CLC
LDA screen_ptr
ADC #LO(640)
STA screen_ptr
LDA screen_ptr+1
ADC #HI(640)
STA screen_ptr+1
LDY #0
LDA #&CC
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0106	;x=001 y=006
STA screen_ptr
STY screen_ptr+1
LDY #7
LDA #&66
EOR (screen_ptr), Y
STA (screen_ptr), Y
CLC
LDA screen_ptr
ADC #LO(640)
STA screen_ptr
LDA screen_ptr+1
ADC #HI(640)
STA screen_ptr+1
LDY #0
LDA #&66
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0206	;x=002 y=006
STA screen_ptr
STY screen_ptr+1
LDY #7
LDA #&33
EOR (screen_ptr), Y
STA (screen_ptr), Y
CLC
LDA screen_ptr
ADC #LO(640)
STA screen_ptr
LDA screen_ptr+1
ADC #HI(640)
STA screen_ptr+1
LDY #0
LDA #&33
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0306	;x=003 y=006
STA screen_ptr
STY screen_ptr+1
LDY #7
LDA #&11
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #15
LDA #&88
EOR (screen_ptr), Y
STA (screen_ptr), Y
CLC
LDA screen_ptr
ADC #LO(640)
STA screen_ptr
LDA screen_ptr+1
ADC #HI(640)
STA screen_ptr+1
LDY #0
LDA #&11
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #8
LDA #&88
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0007	;x=000 y=007
STA screen_ptr
STY screen_ptr+1
CLC
LDA screen_ptr
ADC #LO(640)
STA screen_ptr
LDA screen_ptr+1
ADC #HI(640)
STA screen_ptr+1
LDY #0
LDA #&CC
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #1
LDA #&CC
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0107	;x=001 y=007
STA screen_ptr
STY screen_ptr+1
CLC
LDA screen_ptr
ADC #LO(640)
STA screen_ptr
LDA screen_ptr+1
ADC #HI(640)
STA screen_ptr+1
LDY #0
LDA #&66
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #1
LDA #&66
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0207	;x=002 y=007
STA screen_ptr
STY screen_ptr+1
CLC
LDA screen_ptr
ADC #LO(640)
STA screen_ptr
LDA screen_ptr+1
ADC #HI(640)
STA screen_ptr+1
LDY #0
LDA #&33
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #1
LDA #&33
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
.dot_0307	;x=003 y=007
STA screen_ptr
STY screen_ptr+1
CLC
LDA screen_ptr
ADC #LO(640)
STA screen_ptr
LDA screen_ptr+1
ADC #HI(640)
STA screen_ptr+1
LDY #0
LDA #&11
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #8
LDA #&88
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #1
LDA #&11
EOR (screen_ptr), Y
STA (screen_ptr), Y
LDY #9
LDA #&88
EOR (screen_ptr), Y
STA (screen_ptr), Y
RTS
