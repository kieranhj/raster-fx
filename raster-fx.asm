\ ******************************************************************
\ *	RASTER FX FRAMEWORK
\ ******************************************************************

CPU 1
_REAL_HW = FALSE

\ ******************************************************************
\ *	OS defines
\ ******************************************************************

osfile = &FFDD
oswrch = &FFEE
osasci = &FFE3
osbyte = &FFF4
osword = &FFF1
osfind = &FFCE
osgbpb = &FFD1
osargs = &FFDA

\\ Palette values for ULA
PAL_black	= (0 EOR 7)
PAL_blue	= (4 EOR 7)
PAL_red		= (1 EOR 7)
PAL_magenta = (5 EOR 7)
PAL_green	= (2 EOR 7)
PAL_cyan	= (6 EOR 7)
PAL_yellow	= (3 EOR 7)
PAL_white	= (7 EOR 7)

\ ******************************************************************
\ *	SYSTEM defines
\ ******************************************************************

MODE1_COL0=&00
MODE1_COL1=&20
MODE1_COL2=&80
MODE1_COL3=&A0

\ ******************************************************************
\ *	MACROS
\ ******************************************************************

MACRO WAIT_CYCLES n

PRINT "WAIT",n," CYCLES"

IF n < 0
	ERROR "Can't wait negative cycles!"
ELIF n=0
	; do nothing
ELIF (n AND 1) = 0
	FOR i,1,n/2,1
	NOP
	NEXT
ELSE
	BIT 0
	FOR i,1,(n-3)/2,1
	NOP
	NEXT
ENDIF

ENDMACRO

\ ******************************************************************
\ *	GLOBAL constants
\ ******************************************************************

; Default screen address
screen_addr = &3000
SCREEN_SIZE_BYTES = &8000 - screen_addr
row_bytes = 640

; Exact time for a 50Hz frame less latch load time
FramePeriod = 312*64-2

; Calculate here the timer value to interrupt at the desired line
TimerValue = 32*64 - 2*64 - 2 - 22 - 9 - 64

\\ 40 lines for vblank
\\ 32 lines for vsync (vertical position = 35 / 39)
\\ interupt arrives 2 lines after vsync pulse
\\ 2 us for latch
\\ XX us to fire the timer before the start of the scanline so first colour set on column -1
\\ YY us for code that executes after timer interupt fires

\ ******************************************************************
\ *	ZERO PAGE
\ ******************************************************************

ORG &70
GUARD &9F

\\ System variables

.vsync_counter			SKIP 2		; counts up with each vsync
.escape_pressed			SKIP 1		; set when Escape key pressed

\\ FX variables

.fx_raster_count		SKIP 1
.second_line			skip 1
.table_idx				skip 1
.table_top				skip 1

\ ******************************************************************
\ *	CODE START
\ ******************************************************************

ORG &1900	      			; code origin (like P%=&2000)
GUARD screen_addr			; ensure code size doesn't hit start of screen memory

.start

.main_start

\ ******************************************************************
\ *	Code entry
\ ******************************************************************

.main
{
	\\ Set interrupts

	SEI							; disable interupts
	LDA #&7F					; A=01111111
	STA &FE4E					; R14=Interrupt Enable (disable all interrupts)
	STA &FE43					; R3=Data Direction Register "A" (set keyboard data direction)
	LDA #&C2					; A=11000010
	STA &FE4E					; R14=Interrupt Enable (enable main_vsync and timer interrupt)
	CLI							; enable interupts

	\\ Load SIDEWAYS RAM modules here!

	\\ Initalise system vars

	LDA #0
	STA vsync_counter
	STA vsync_counter+1
	STA escape_pressed

	\\ Set MODE 1

	LDA #22
	JSR oswrch
	LDA #2
	JSR oswrch

	JSR fx_init_function

	\\ Turn off cursor

	LDA #10: STA &FE00
	LDA #32: STA &FE01

	\\ Shift hsync - IMPORTANT!

	lda #2:sta &fe00
	lda #95:sta &fe01

	\\ Shift vsync - also important!

	lda #7:sta &fe00
	lda #35:sta &fe01

	\\ Turn off interlace

	lda #8:sta &fe00
	lda #0:sta &fe01

	ldx #255:jsr cycles_wait_scanlines
	ldx #255:jsr cycles_wait_scanlines
	ldx #255:jsr cycles_wait_scanlines

	\\ Ensure the CRTC column counter is incrementing starting from a
	\\ known state with respect to the cycle stretching. Because the vsync
	\\ signal is reported via the VIA, which is a 1MHz device, the timing
	\\ could be out by 0.5 usec in 2MHz modes.
	\\
	\\ To fix: set R0=0, wait 256 cycles to ensure the horizontal counter
	\\ is stuck at 0, then set the horizontal counter to its correct
	\\ value. The 6845 is always accessed at 1MHz so the cycle counter
	\\ starts running on a 1MHz boundary.
	\\
	\\ Note: when R0=0, DRAM refresh is off. Don't delay too long.
	lda #0
	sta $fe00:sta $fe01
	ldx #2:jsr cycles_wait_scanlines
	sta $fe00:lda #127:sta $fe01

	\\ Initialise system modules here!

	\ ******************************************************************
	\ *	DEMO START - from here on out there are no interrupts enabled!!
	\ ******************************************************************

	SEI

	\\ Exact cycle VSYNC by Hexwab

	{
		lda #2
		.vsync1
		bit &FE4D
		beq vsync1 \ wait for vsync

		\now we're within 10 cycles of vsync having hit

		\delay just less than one frame
		.syncloop
		sta &FE4D \ 4(stretched), ack vsync

		\{ this takes (5*ycount+2+4)*xcount cycles
		\x=55,y=142 -> 39902 cycles. one frame=39936
		ldx #142 \2
		.deloop
		ldy #55 \2
		.innerloop
		dey \2
		bne innerloop \3
		\ =152
		dex \ 2
		bne deloop \3
		\}

		nop:nop:nop:nop:nop:nop:nop:nop:nop \ +16
		bit &FE4D \4(stretched)
		bne syncloop \ +3
		\ 4+39902+16+4+3+3 = 39932
		\ ne means vsync has hit
		\ loop until it hasn't hit

		\now we're synced to vsync
	}

	\\ Set up Timers

	.set_timers
	; Write T1 low now (the timer will not be written until you write the high byte)
    LDA #LO(TimerValue):STA &FE44
    ; Get high byte ready so we can write it as quickly as possible at the right moment
    LDX #HI(TimerValue):STX &FE45             		; start T1 counting		; 4c +1/2c 

  	; Latch T1 to interupt exactly every 50Hz frame
	LDA #LO(FramePeriod):STA &FE46
	LDA #HI(FramePeriod):STA &FE47

	\\ Initialise FX modules here

	.call_init
\\	JSR fx_init_function

	\\ We don't know how long the init took so resync to timer 1

	{
		lda #&42
		sta &FE4D	\ clear vsync & timer 1 flags

		\\ Wait for Timer1 at rasterline 0

		lda #&40
		.waitTimer1
		bit &FE4D
		beq waitTimer1
		sta &FE4D

		\\ Now can enter main loop with enough time to do work
	}

	\\ Update typically happens during vblank so wait 255 lines
	\\ But don't forget that the loop also takes time!!

	{
		LDX #255
		JSR cycles_wait_scanlines
	}

	\ ******************************************************************
	\ *	MAIN LOOP
	\ ******************************************************************

.main_loop

	\\  Do useful work during vblank (vsync will occur at some point)
	{
		INC vsync_counter
		BNE no_carry
		INC vsync_counter+1
		.no_carry
	}

	\\ Service any system modules here!

	\\ Check for Escape key

	LDA #&79
	LDX #(&70 EOR &80)
	JSR osbyte
	STX escape_pressed

	\\ FX update callback here!

	.call_update
	JSR fx_update_function

	\\ Wait for first scanline

	{
		LDA #&40
		.waitTimer1
		BIT &FE4D				; 4c + 1/2c
		BEQ waitTimer1         	; poll timer1 flag


		\\ Reading the T1 low order counter also resets the T1 interrupt flag in IFR

		LDA &FE44					; 4c + 1c - will be even already?

		\\ New stable raster NOP slide thanks to VectorEyes 8)

		\\ Observed values $FA (early) - $F7 (late) so map these from 7 - 0
		\\ then branch into NOPs to even this out.

		AND #15
		SEC
		SBC #7
		EOR #7
		STA branch+1
		.branch
		BNE branch
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		NOP
		.stable
		BIT 0
	}

	\\ Check if Escape pressed

	LDA escape_pressed
	BMI call_kill

	\\ FX draw callback here!

	.call_draw
	JSR fx_draw_function

	\\ Loop as fast as possible

	JMP main_loop

	\\ Get current module to return CRTC to known state

	.call_kill
	JSR fx_kill_function

	\\ Re-enable useful interupts

	LDA #&D3					; A=11010011
	STA &FE4E					; R14=Interrupt Enable
    CLI

	\\ Exit gracefully (in theory)

	RTS
}

\ ******************************************************************
\ *	HELPER FUNCTIONS
\ ******************************************************************

IF 0
.cycles_wait_128		; JSR to get here takes 6c
{
	FOR n,1,58,1		; 58x
	NOP					; 2c
	NEXT				; = 116c
	RTS					; 6c
}						; = 128c
ENDIF

.cycles_wait_scanlines	; 6c
{
	FOR n,1,54,1		; 54x
	NOP					; 2c
	NEXT				; = 108c
	BIT 0				; 3c

	.loop
	DEX					; 2c
	BEQ done			; 2/3c

	FOR n,1,59,1		; 59x
	NOP					; 2c
	NEXT				; = 118c

	BIT 0				; 3c
	JMP loop			; 3c

	.done
	RTS					; 6c
}

.main_end

\ ******************************************************************
\ *	FX MODULE
\ ******************************************************************

.fx_start

\ ******************************************************************
\ Initialise FX
\
\ The initialise function is used to set up all variables, tables and
\ any precalculated screen memory etc. required for the FX.
\
\ This function will be called during vblank
\ The CRTC registers will be set to default MODE 0,1,2 values
\
\ The function can take as long as is necessary to initialise.
\ ******************************************************************

.fx_init_function
{
    \ Ask OSFILE to load our screen
	LDX #LO(osfile_params)
	LDY #HI(osfile_params)
	LDA #&FF
    JSR osfile

	.outer
	lda #0
	ldy #7
	.loop
	sta screen_addr,y
	dey
	bpl loop

	clc
	lda loop+1
	adc #LO(row_bytes)
	sta loop+1
	lda loop+2
	adc #HI(row_bytes)
	sta loop+2
	bpl outer

	lda #0
	sta table_top

	RTS
}

\ ******************************************************************
\ Update FX
\
\ The update function is used to update / tick any variables used
\ in the FX. It may also prepare part of the screen buffer before
\ drawing commenses but note the strict timing constraints!
\
\ This function will be called during vblank, after any system
\ modules have been polled.
\
\ The function MUST COMPLETE BEFORE TIMER 1 REACHES 0, i.e. before
\ raster line 0 begins. If you are late then the draw function will
\ be late and your raster timings will be wrong!
\ ******************************************************************

.fx_update_function
{
	ldx #0
	lda #12:sta &fe00	; 8c
	lda screen_HI, x:sta &fe01	; 10c

	lda #13:sta &fe00	; 8c
	lda screen_LO, x:sta &fe01	; 10c

	LDA #254
	STA fx_raster_count		; fx_draw_loop counter

	dec table_top

	ldx table_top
	stx table_idx

	\\ First line always 0
	lda table_y, X
	sta second_line

	RTS
}

\ ******************************************************************
\ Draw FX
\
\ The draw function is the main body of the FX.
\
\ This function will be exactly at the start* of raster line 0 with
\ a stablised raster. VC=0 HC=0|1 SC=0
\
\ This means that a new CRTC cycle has just started! If you didn't
\ specify the registers from the previous frame then they will be
\ the default MODE 0,1,2 values as per initialisation.
\
\ If messing with CRTC registers, THIS FUNCTION MUST ALWAYS PRODUCE
\ A FULL AND VALID 312 line PAL signal before exiting!
\ ******************************************************************

\\ <--- 96c total w/ 80c visible and hsync at 95c ---> <2c> <2c> ... <2c> = 128c
\\ 1 visible segment + 16 short invisible segments = 17 'scanlines' per 'row' along a single raster line

NOP:NOP:NOP		; shift loop into same page

.fx_draw_function
\{
	\\ Enter fn at 64us before first raster line
	WAIT_CYCLES 128-14-6 -1

	.fx_draw_here
	clc
	ldx second_line		; next scanline
	ldy #0				; this scanline
	stz &fe00			; stz

IF _REAL_HW
	lda #95
ELSE
	lda #97
ENDIF
	\\ 14c
	
	sta &FE01				; R0=97 horizontal total = 98
	\\ 6c

	\\ start of scanline 0 HCC=0 LVC=0 VCC=0
	\\ start segment 0 [0-99]

	lda #4: sta &fe00				; 8c
	stz &FE01			; stz	; R4=0 vertical total = 1
	\\ 14c

	\\ Before end of segmnet 0 need to set R12/R13/R9 and R2!

	\\ Set R9
	LDA #9:STA &fe00				; 8c
	LDA screen_line, X				; 4c
	eor #15							; 2c
	adc screen_line, Y				; 3c
	STA &fe01						; 6c
	\\ 28c

	\\ Set R12/R13
	LDA #12:STA &fe00				; 8c
	LDA screen_HI, X:STA &fe01	; 10c		X=1

	LDA #13:STA &fe00				; 8c
	LDA screen_LO, X:STA &fe01	; 10c		X=1
	\\ 36c

	WAIT_CYCLES 9

IF _REAL_HW=FALSE
	NOP
ENDIF

	\\ start segment 1..
	stz &fe00			; stz		; 6c
	lda #1							; 2c
	\\ This has to be bang on 96c on real hw
	sta &fe01				; R0=1 horizontal total = 2
	\\ 6c

	lda #6:sta &fe00
	lda #1:sta &fe01		; R6=1 vertical displayed
	\\ 16c

	stz &fe00
	\\ 6c

IF _REAL_HW
	NOP
ENDIF

	\\ Start of scanline 1 <phew>
	\\ X is the raster line we want to display
	\\ Use Y to look up a table to increment X

	.fx_draw_loop

IF _REAL_HW
	lda #95
ELSE
	lda #97
ENDIF
	\\ got to catch this before 2c!
	sta &FE01				; R0=95 horizontal total = 96
	\\ 6c

	txa		; next scanline			; 2c
	tay		; becomes current scanline	; 2c

	ldx table_idx					; 3c
	inx								; 2c
	stx table_idx					; 3c

	clc								; 2c
	adc table_y, X					; 4c
	tax		; becomes next scanline	; 2c

	\\ Before end of segmnet 0 need to set R12/R13/R9

	\\ The rule is, set R9 at the start of a displayed line as follows:
	\\ R9 = this_line_number + 15 - next_line_number
	\\ or, conveniently:
	\\ R9 = (next_line_number EOR 15) + this_line_number (edited) 

	\\ Eg. 0->7: 0+15-7 = 8 = (7^15)+0
	\\ Eg. 7->0: 7+15-0 = 22 = (0^15)+7

	\\ Set R9
	LDA #9:STA &fe00				; 8c
	LDA screen_line, X				; 4c
	eor #15							; 2c
	clc								; 2c
	adc screen_line, Y				; 4c
	STA &fe01						; 6c
	\\ 28c

	\\ Set R12/R13
	LDA #12:STA &fe00				; 8c
	LDA screen_HI, X:STA &fe01		; 10c

	LDA #13:STA &fe00				; 8c
	LDA screen_LO, X:STA &fe01		; 10c
	\\ 36c

IF _REAL_HW=FALSE
	NOP
ENDIF

	\\ Set horizontal total
	\\ This has to be bang on 96c!
	stz &fe00						; 6c
	lda #1							; 2c
	sta &fe01				; R0=1 horizontal total = 2
	\\ 6c

	\\ segments 3-14 [104-127]
	WAIT_CYCLES 22 -8

IF _REAL_HW
	NOP
ENDIF

	\\ Time for SHADOW switch in hblank?!

	dec fx_raster_count		; 5c
	bne fx_draw_loop		; 3c
	\\ 7c

	.fx_draw_done

	\\ start of scanline 255
	NOP

	\\ Need to get scanlines & character rows back in sync...
	\\ So if finish on scanline count N
	\\ Set R9 to get us back to 0 on next scanline

	\\ got to catch this before 2c!
IF _REAL_HW
	lda #95
ELSE
	lda #97
ENDIF
	sta &FE01				; R0=95 horizontal total = 96
	\\ 6c

	\\ Set R9 so we get back to scanline 0 next line
	LDA #9:STA &fe00				; 8c
	clc								; 2c
	LDA #15							; 2c
	ADC screen_line, X				; 4c
	STA &fe01						; 6c
	\\ 22c

	WAIT_CYCLES 60

IF _REAL_HW=FALSE
	NOP
ENDIF

	\\ Set horizontal total
	stz &fe00
	\\ 6c
	lda #1							; 2c
	\\ This must happen exactly on 100c
	sta &fe01				; R0=1 horizontal total = 2
	\\ 6c

	\\ segments 3-14 [100-127]
	WAIT_CYCLES 22

IF _REAL_HW
	NOP
ENDIF

	\\ Should be start of scanline 256!

	\\ got to catch this before 2c!
	lda #127
	sta &fe01				; R0=127 back to a full width line!

	lda #9:sta &fe00
	lda #7:sta &fe01		; R9=7 scanlines per row = 8
	\\ 16c

	lda #4:sta &fe00
	lda #6:sta &fe01		; R4=7 more character rows total 39
	\\ 16c

	lda #7:sta &fe00
	lda #3:sta &fe01		; R7=vsync at row 35
	\\ 16c

	lda #6:sta &fe00
	lda #0:sta &fe01		; R6=1 vertical displayed
	\\ 16c

    RTS
\}

\ ******************************************************************
\ Kill FX
\
\ The kill function is used to tidy up any craziness that your FX
\ might have created and return the system back to the expected
\ default state, ready to initialise the next FX.
\
\ This function will be exactly at the start* of raster line 0 with
\ a maximum jitter of up to +10 cycles.
\
\ This means that a new CRTC cycle has just started! If you didn't
\ specify the registers from the previous frame then they will be
\ the default MODE 0,1,2 values as per initialisation.
\
\ THIS FUNCTION MUST ALWAYS ENSURE A FULL AND VALID 312 line PAL
\ signal will take place this frame! The easiest way to do this is
\ to simply call crtc_reset.
\
\ ******************************************************************

.fx_kill_function
{
	\\ Set all CRTC registers back to their defaults for MODE 0,1,2

	LDX #13
	.loop
	STX &FE00
	LDA crtc_regs_default,X
	STA &FE01
	DEX
	BPL loop

	RTS
}

.fx_end

\ ******************************************************************
\ *	SYSTEM DATA
\ ******************************************************************

.data_start

.crtc_regs_default
{
	EQUB 127				; R0  horizontal total
	EQUB 80					; R1  horizontal displayed
	EQUB 98					; R2  horizontal position
	EQUB &28				; R3  sync width 40 = &28
	EQUB 38					; R4  vertical total
	EQUB 0					; R5  vertical total adjust
	EQUB 32					; R6  vertical displayed
	EQUB 35					; R7  vertical position; 35=top of screen
	EQUB &0					; R8  interlace; &30 = HIDE SCREEN
	EQUB 7					; R9  scanlines per row
	EQUB 32					; R10 cursor start
	EQUB 8					; R11 cursor end
	EQUB HI(screen_addr/8)	; R12 screen start address, high
	EQUB LO(screen_addr/8)	; R13 screen start address, low
}

.osfile_filename
EQUS "Screen", 13

.osfile_params
.osfile_nameaddr
EQUW osfile_filename
; file load address
.osfile_loadaddr
EQUD screen_addr
; file exec address
.osfile_execaddr
EQUD 0
; start address or length
.osfile_length
EQUD 0
; end address of attributes
.osfile_endaddr
EQUD 0

\ ******************************************************************
\ *	FX DATA
\ ******************************************************************

ALIGN &100

.screen_LO
FOR n,0,255,1
y = n
row = y DIV 8
EQUB LO((screen_addr + row * row_bytes)/8)
NEXT

.screen_HI
FOR n,0,255,1
y = n
row = y DIV 8
EQUB HI((screen_addr + row * row_bytes)/8)
NEXT

.screen_line
EQUB 0
FOR n,1,255,1
y = n
line = y MOD 8
EQUB line
NEXT

.table_y
FOR n,0,255,1
EQUB 4 * SIN(2 * PI * n / 256)
NEXT

.table_i
FOR n,0,255,1
EQUB 64 * SIN(2 * PI * n / 256)
NEXT

.data_end

\ ******************************************************************
\ *	End address to be saved
\ ******************************************************************

.end

\ ******************************************************************
\ *	Save the code
\ ******************************************************************

SAVE "MyFX", start, end

\ ******************************************************************
\ *	Space reserved for runtime buffers not preinitialised
\ ******************************************************************

.bss_start
.bss_end

\ ******************************************************************
\ *	Memory Info
\ ******************************************************************

PRINT "------"
PRINT "RASTER FX"
PRINT "------"
PRINT "MAIN size =", ~main_end-main_start
PRINT "FX size = ", ~fx_end-fx_start
PRINT "DATA size =",~data_end-data_start
PRINT "BSS size =",~bss_end-bss_start
PRINT "------"
PRINT "HIGH WATERMARK =", ~P%
PRINT "FREE =", ~screen_addr-P%
PRINT "------"

\ ******************************************************************
\ *	Any other files for the disc
\ ******************************************************************

PUTBASIC "circle.bas", "Circle"
PUTFILE "rtw_test.bin", "T", &3000
PUTFILE "screen.bin", "Screen", &3000
PUTFILE "kc_test.bin", "CircTri", &3000
