\ ******************************************************************
\ *	RASTER FX FRAMEWORK
\ ******************************************************************

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

MACRO WAIT_NOPS n
PRINT "WAIT",n," CYCLES AS NOPS"

IF n < 0
	ERROR "Can't wait negative cycles!"
ELIF n=0
	; do nothing
ELIF n=1
	EQUB $33
	PRINT "1 cycle NOP is Master only and not emulated by b-em."
ELIF (n AND 1) = 0
	FOR i,1,n/2,1
	NOP
	NEXT
ELSE
	BIT 0
	IF n>3
		FOR i,1,(n-3)/2,1
		NOP
		NEXT
	ENDIF
ENDIF
ENDMACRO

MACRO WAIT_CYCLES n

PRINT "WAIT",n," CYCLES"

IF n >= 12
	FOR i,1,n/12,1
	JSR return
	NEXT
	WAIT_NOPS n MOD 12
ELSE
	WAIT_NOPS n
ENDIF

ENDMACRO

MACRO PAGE_ALIGN
    PRINT "ALIGN LOST ", ~LO(((P% AND &FF) EOR &FF)+1), " BYTES"
    ALIGN &100
ENDMACRO

\ ******************************************************************
\ *	GLOBAL constants
\ ******************************************************************

; Default screen address
screen_addr = &3000
SCREEN_SIZE_BYTES = &8000 - screen_addr
disksys_loadto_addr = &3000

; Exact time for a 50Hz frame less latch load time
FramePeriod = 312*64-2

; Calculate here the timer value to interrupt at the desired line
TimerValue = 32*64 - 2*64 - 2 - 22 - 9

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

.writeptr	skip 2
.row_count	skip 1
.temp		skip 1

\\ FX variables

.twister_spin_index		skip 2		; index into spin table for top line
.twister_spin_step		skip 2		; rate at which spin index is updated each frame

.twister_twist_index	skip 2		; index into twist table for top line
.twister_twist_step		skip 2		; rate at which twist index is update each frame

.twister_knot_index		skip 2		; index into knot table for top line
.twister_knot_step		skip 2		; rate at which knot index is updated each frame

.twister_spin_brot		skip 2		; rotation amount of top line
.twister_twist_brot		skip 2		; rotation amount per row

.twister_knot_i			skip 2		; per row index into knot table
.twister_knot_y			skip 2		; rate at which knot index is updated vertical

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
	LDA #0
	JSR oswrch

	\\ Turn off cursor

	LDA #10: STA &FE00
	LDA #32: STA &FE01

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
	JSR fx_init_function

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
}
.return
	RTS

\ ******************************************************************
\ *	HELPER FUNCTIONS
\ ******************************************************************

.cycles_wait_128		; JSR to get here takes 6c
{
	WAIT_CYCLES 128-6-6
	RTS					; 6c
}						; = 128c

.cycles_wait_scanlines	; 6c
{
	WAIT_CYCLES 128-6-2-3-6

	.loop
	DEX					; 2c
	BEQ done			; 2/3c

	WAIT_CYCLES 121

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
	\\ Init vars.
	lda #1:sta twister_spin_step
	lda #0:sta twister_spin_step+1

	\ Ensure MAIN RAM is writeable
    LDA &FE34:AND #&FB:STA &FE34
	ldx #LO(file1):ldy #HI(file1):lda #HI(&3000):jsr disksys_load_file
	\ Ensure SHADOW RAM is writeable
    LDA &FE34:ORA #&4:STA &FE34
	ldx #LO(file2):ldy #HI(file2):lda #HI(&3000):jsr disksys_load_file
	\ Ensure MAIN RAM is writeable
    LDA &FE34:AND #&FB:STA &FE34

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
	\\ Update rotation of the top line by indexing into the spin table
	CLC
	LDA twister_spin_brot
	LDX twister_spin_index+1
	ADC twister_spin_table_LO,X
	STA twister_spin_brot

	LDA twister_spin_brot+1
	ADC twister_spin_table_HI,X
	STA twister_spin_brot+1

	\\ Set the first scanline
	AND #&7F:lsr a:tax			; 0-63
	lsr a:TAY					; 0-31

	LDA #12: STA &FE00			; 2c + 4c++
	LDA twister_vram_table_HI, Y		; 4c
	STA &FE01					; 4c++

	LDA #13: STA &FE00			; 2c + 4c++
	LDA twister_vram_table_LO, Y		; 4c
	STA &FE01					; 4c++

	txa:lsr a:lsr a:lsr a:lsr a:lsr a:sta temp	; main/shadow
	lda &fe34:and #&fe:ora temp:sta &fe34

	\\ Update the index into the spin table
	CLC
	LDA twister_spin_index
	ADC twister_spin_step
	STA twister_spin_index

	LDA twister_spin_index+1
	ADC twister_spin_step+1
	STA twister_spin_index+1

	\\ Update the index into the twist table
	CLC
	LDA twister_twist_index
	ADC twister_twist_step
	STA twister_twist_index

	LDA twister_twist_index+1
	ADC twister_twist_step+1
	STA twister_twist_index+1

	\\ Update the index into the knot table
	CLC
	LDA twister_knot_index
	ADC twister_knot_step
	STA twister_knot_index

	LDA twister_knot_index+1
	ADC twister_knot_step+1
	STA twister_knot_index+1

	\\ Calculate rotation of 2nd scanline by indexing twist table
	CLC
	LDA twister_spin_brot
	LDY twister_twist_index+1
	ADC twister_twist_table_LO, Y
	STA twister_twist_brot

	LDA twister_spin_brot+1
	ADC twister_twist_table_HI, Y
	STA twister_twist_brot+1

	\\ Copy the twist index into a local variable for drawing
	LDA twister_knot_index
	STA twister_knot_i
	LDA twister_knot_index+1
	STA twister_knot_i+1

	\\ Add knot for second line
	CLC
	LDA twister_twist_brot
	LDY twister_knot_i+1
	ADC twister_knot_table_LO, Y
	STA twister_twist_brot

	LDA twister_twist_brot+1
	ADC twister_knot_table_HI, Y
	STA twister_twist_brot+1

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

.fx_draw_function
{
	\\ R4=0, R7=&ff, R6=1
	lda #4:sta &fe00
	lda #0:sta &fe01

	lda #7:sta &fe00
	lda #3:sta &fe01

	lda #6:sta &fe00
	lda #1:sta &fe01

	lda #31:sta row_count
	\\ 52c

	jsr cycles_wait_128
	jsr cycles_wait_128
	jsr cycles_wait_128
	jsr cycles_wait_128
	jsr cycles_wait_128
	jsr cycles_wait_128

	\\ Start of scanline 7

	\\ Do first row manually
	LDA twister_twist_brot+1
	AND #&7F:lsr a:tax			; 0-63
	lsr a:TAY					; 0-31

	\\ R12,13 - frame buffer address
	LDA #12: STA &FE00			; 2c + 4c++
	LDA twister_vram_table_HI, Y		; 4c
	STA &FE01					; 4c++

	LDA #13: STA &FE00			; 2c + 4c++
	LDA twister_vram_table_LO, Y		; 4c
	STA &FE01					; 4c++

	txa:lsr a:lsr a:lsr a:lsr a:lsr a:sta temp	; main/shadow
	lda &fe34:and #&fe:ora temp:sta &fe34

	WAIT_CYCLES 50

	\\ Effect here!
	.char_row_loop
	{
		jsr cycles_wait_128
		jsr cycles_wait_128
		jsr cycles_wait_128
		jsr cycles_wait_128
		jsr cycles_wait_128
		jsr cycles_wait_128
		WAIT_CYCLES 106

		\\ Apply the (global) twist value to the row first
		CLC
		LDA twister_twist_brot
		LDY twister_twist_index+1
		ADC twister_twist_table_LO, Y
		STA twister_twist_brot

		LDA twister_twist_brot+1
		ADC twister_twist_table_HI, Y
		STA twister_twist_brot+1

		\\ Update local twist index value by incrementing by step
		CLC
		LDA twister_knot_i
		ADC twister_knot_y
		STA twister_knot_i
		LDA twister_knot_i+1
		ADC twister_knot_y+1
		STA twister_knot_i+1
		TAY

		\\ Use the local twist index to calculate additional rotation value 'knot'
		CLC
		LDA twister_twist_brot
		ADC twister_knot_table_LO, Y
		STA twister_twist_brot

		LDA twister_twist_brot+1
		ADC twister_knot_table_HI, Y
		STA twister_twist_brot+1
		
		AND #&7F:lsr a:tax			; 0-63
		lsr a:TAY					; 0-31

		LDA #12: STA &FE00			; 2c + 4c++
		LDA twister_vram_table_HI, Y		; 4c
		STA &FE01					; 4c++

		LDA #13: STA &FE00			; 2c + 4c++
		LDA twister_vram_table_LO, Y		; 4c
		STA &FE01					; 4c++
		
		txa:lsr a:lsr a:lsr a:lsr a:lsr a:sta temp	; main/shadow
		lda &fe34:and #&fe:ora temp:sta &fe34

		DEC row_count						; 5c
		BEQ done							; 2c
		JMP char_row_loop					; 3c
		.done
		\\ 8c
	}

	\\ R4=6 - CRTC cycle is 32 + 7 more rows = 312 scanlines
	LDA #4: STA &FE00
	LDA #6: STA &FE01			; 312 - 256 = 56 scanlines

    RTS
}

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

INCLUDE "lib/disksys.asm"
.file1 EQUS "1",13
.file2 EQUS "2",13

\ ******************************************************************
\ *	FX DATA
\ ******************************************************************

PAGE_ALIGN
.twister_vram_table_LO
FOR n,0,31,1
EQUB LO((&3000 + n*640)/8)
NEXT

.twister_vram_table_HI
FOR n,0,31,1
EQUB HI((&3000 + n*640)/8)
NEXT

MACRO TWISTER_TWIST_LO deg_per_frame
	brads = 256 * 128 * (deg_per_frame / 256) / 360
	EQUB LO(brads)
ENDMACRO
;	PRINT "TWIST: deg/frame=", deg_per_frame, " brads=", ~brads

MACRO TWISTER_TWIST_HI deg_per_frame
	brads = 256 * 128 * (deg_per_frame / 256) / 360
	EQUB HI(brads)
ENDMACRO

MACRO TWISTER_SPIN_LO deg_per_sec
	brads = 256 * 128 * (deg_per_sec / 50) / 360
	EQUB LO(brads)
ENDMACRO
;	PRINT "SPIN: deg/sec=", deg_per_sec, " brads=", ~brads

MACRO TWISTER_SPIN_HI deg_per_sec
	brads = 256 * 128 * (deg_per_sec / 50) / 360
	EQUB HI(brads)
ENDMACRO

\\ Vary twist over time and/or vertical

PAGE_ALIGN
.twister_twist_table_LO			; global rotation increment per row of the twister
FOR n,0,255,1
{
	IF n < 128
	m = (64 - ABS(n-64))/64
	ELSE
	m = -(64 - ABS(n-192))/64
	ENDIF
;	t = 480 * m
	t = 480 * SIN(2 * PI * n / 256)	; thanks IP!
	TWISTER_TWIST_LO t
}
NEXT

.twister_twist_table_HI			; global rotation increment per row of the twister
FOR n,0,255,1
{
	IF n < 128
	m = (64 - ABS(n-64))/64
	ELSE
	m = -(64 - ABS(n-192))/64
	ENDIF
;	t = 480 * m
	t = 480 * SIN(2 * PI * n / 256)	; thanks IP!
	TWISTER_TWIST_HI t
}
NEXT

.twister_knot_table_LO			; local rotation increment per row of the twister
FOR n,0,255,1
{
	m = (128 - ABS(n-128))/128
	t = 720 * m * m
	TWISTER_TWIST_LO t
}
NEXT

.twister_knot_table_HI			; local rotation increment per row of the twister
FOR n,0,255,1
{
	m = (128 - ABS(n-128))/128
	t = 720 * m * m
	TWISTER_TWIST_HI t
}
NEXT

\\ Vary spin over time

.twister_spin_table_LO			; rotation increment of top angle per frame
FOR n,0,255,1
{
;	v = 210						; spin at 210 deg/sec
	v = 360 * SIN(2 * PI * n/ 256)
	TWISTER_SPIN_LO v
}
NEXT

.twister_spin_table_HI			; rotation increment of top angle per frame
FOR n,0,255,1
{
;	v = 210						; spin at 210 deg/sec
	v = 360 * SIN(2 * PI * n/ 256)
	TWISTER_SPIN_HI v
}
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
PUTFILE "screen.bin", "Screen", &3000
PUTFILE "SCREEN1.BIN", "1", &3000
PUTFILE "SCREEN2.BIN", "2", &3000
