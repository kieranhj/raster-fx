\ ******************************************************************
\ *	RASTER FX FRAMEWORK
\ ******************************************************************

CPU 1
_USE_SHADOW = TRUE

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

IF _USE_SHADOW
TOGGLE_VALUE_ON  = 1
TOGGLE_VALUE_OFF = 0
TOGGLE_REGISTER	 = &fe34
ELSE
TOGGLE_VALUE_ON  = PAL_red
TOGGLE_VALUE_OFF = PAL_black
TOGGLE_REGISTER	 = &fe21
ENDIF

TEST_DELAY = 25

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
	IF n>3
	FOR i,1,(n-3)/2,1
	NOP
	NEXT
	ENDIF
ENDIF

ENDMACRO

\ ******************************************************************
\ *	GLOBAL constants
\ ******************************************************************

; Default screen address
screen_addr = &3000
SCREEN_SIZE_BYTES = &8000 - screen_addr

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

.startx					skip 1
.starty					skip 1

.endx					skip 1
.endy					skip 1

.dx						skip 1
.dy						skip 1

.count					skip 1
.accum					skip 1


.startx_dir				skip 1
.starty_dir				skip 1
.endx_dir				skip 1
.endy_dir				skip 1

.miny					skip 1
.delay					skip 1
.test_index				skip 1

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

	\\ Shift hsync - IMPORTANT for RVI!

;	lda #2:sta &fe00
;	lda #95:sta &fe01

	\\ Shift vsync - also important!

	lda #7:sta &fe00
	lda #35:sta &fe01

	\\ Turn off interlace

	lda #8:sta &fe00
	lda #0:sta &fe01

	\\ Wait at least two frames to let vsync, hsync and interlace changes shake out:

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
	IF 1
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
	ENDIF
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

	\ Select SHADOW to write
	lda &fe34:ora #4:sta &fe34

	lda #lo(shadow_filename):sta osfile_nameaddr+0
	lda #hi(shadow_filename):sta osfile_nameaddr+1
	LDX #LO(osfile_params)
	LDY #HI(osfile_params)
	LDA #&FF
    JSR osfile

	\ Select MAIN to write
	lda &fe34:and #&ff-4:sta &fe34
	
	lda #0
	sta test_index
	jsr load_test
	jsr drawline
	jsr setup_draw

	RTS
}

.load_test
{
	ldx test_index
	lda test_table, x
	sta startx
	inx
	lda test_table, x
	sta starty
	inx
	lda test_table, x
	sta endx
	inx
	lda test_table, x
	sta endy
	inx

	cpx #LO(test_end)
	bcc index_ok
	ldx #0
	.index_ok
	stx test_index

	lda #TEST_DELAY
	sta delay
	rts
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

\\ Assume lines always reach to the extents of the screen so
\\ a --- b
\\ |     |
\\ c --- d
\\

.setup_draw
{
	\\ Set up any smc for the draw fn
	{
		lda starty
		cmp endy
		bcs swap_ys
		
		sta miny
		lda endy
		sta fx_draw_ymax+1
		bra done_ends

		.swap_ys
		sta fx_draw_ymax+1
		lda endy
		sta miny

		.done_ends
	}

\\ If starty=0 (a->b)
\\   endx=0   initial=don't care, reset=0, toggle=1, final=1
\\   endy=255 initial=don't care, reset=0, toggle=1, final=don't care
\\   endx=255 initial=don't care, reset=0, toggle=1, final=0
	{
		lda starty
		bne not_a_b

		lda #TOGGLE_VALUE_OFF
		sta fx_draw_initial_value+1
		sta fx_draw_reset_value+1

		ldx endx
		bne end_d_b
		lda #TOGGLE_VALUE_ON
		.end_d_b
		sta fx_draw_final_value+1
		BRA done

		.not_a_b
	}

\\ If startx=0 (a->c)
\\   endy=0   initial=don't care, reset=1, toggle=0, final=0
\\	 endx=255 initial=1, reset=dy<0?1:0, toggle=!reset, final=0
\\   endy=255 initial=1, reset=0, toggle=1, final=don't care
	{
		lda startx
		bne not_a_c

		ldx #TOGGLE_VALUE_ON
		stx fx_draw_initial_value+1

		ldx #TOGGLE_VALUE_OFF
		stx fx_draw_final_value+1

		lda starty
		cmp endy
		bcc dy_pos
		ldx #TOGGLE_VALUE_ON
		.dy_pos
		stx fx_draw_reset_value+1
		BRA done

		.not_a_c
	}

\\ If starty=255 (c->d)
\\	 endx=0   initial=0, reset=1, toggle=0, final=don't care
\\   endy=0   initial=don't care, reset=1, toggle=0, final=don't care
\\   endx=255 initial=1, reset=1, toggle=0, final=don't care
	{
		lda starty
		cmp #255
		bne not_c_d

		lda #TOGGLE_VALUE_ON
		sta fx_draw_reset_value+1
		sta fx_draw_final_value+1

		ldx endx
		bne not_end_a_c
		lda #TOGGLE_VALUE_OFF

		.not_end_a_c
		sta fx_draw_initial_value+1
		BRA done

		.not_c_d	
	}

\\ If startx=255 (d->b)
\\   endy=255 initial=0, reset=0, toggle=1, final=don't care
\\   endx=0   initial=0, reset=dy<0?1:0, toggle=!reset, final=1
\\	 endy=0	  initial=don't care, reset=1, toggle=0, final=1
	{
		lda startx
		cmp #79
		bne not_d_b

		lda #TOGGLE_VALUE_ON
		sta fx_draw_final_value+1

		ldx #TOGGLE_VALUE_OFF
		stx fx_draw_initial_value+1

		lda starty
		cmp endy
		bcc dy_pos
		ldx #TOGGLE_VALUE_ON
		.dy_pos
		stx fx_draw_reset_value+1
		BRA done

		.not_d_b
		BRK			; shouldn't happen!
	}

	.done
	lda fx_draw_reset_value+1
	eor #(TOGGLE_VALUE_ON EOR TOGGLE_VALUE_OFF)
	sta fx_draw_toggle_value+1

	rts
}

.fx_update_function
{
	dec delay
	bne wait

	jsr load_test
	jsr drawline
	jsr setup_draw

	.wait

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

ALIGN &100
.fx_draw_function
\{
	\\ Enter fn at 64us before first raster line
	\\ Minus setup, clockslide calc, minimum slide, toggle, hadj
	WAIT_CYCLES 128 -19 -24 -5 -4 -1

	.fx_draw_initial_value
	lda #PAL_black				; 2c	; toggle off value
	sta TOGGLE_REGISTER			; 4c	; start off
	\\ 6c

	\\ Potentially wait N scanlines until y_min

	ldx miny					; 3c
	beq y_min_is_zero			
	; 2c
	jsr cycles_wait_scanlines	; N scanlines
	bra fx_draw_here			; 3c
	\\ branch = 5c (effectively)

	.y_min_is_zero
	; 3c
	nop							; 2c
	\\ branch = 5c

	.fx_draw_here
	ldy miny					; 3c	; y index
	.fx_draw_toggle_value
	ldx #PAL_red				; 2c	; toggle on value
	\\ 5c

	\\ To here = 6+3+5+5=19c

	.fx_draw_loop

	.fx_draw_reset_value
	lda #PAL_blue				; 2c
	sta TOGGLE_REGISTER			; 4c

	\\ Load next X value and calculate clockslide
	lda table_x, y				; 4c
	sta clockslide_right+1		; 4c
	eor #&ff					; 2c
	sec							; 2c
	adc #79						; 2c
	sta clockslide_left+1		; 4c
	\\ 24c

	.clockslide_left
	{
		BRA clockslide_left		; 3c
		\\ Between 2 and 81 cycle delay
		FOR n,1,39,1		
		cmp #&c9				; 2c
		NEXT
		cmp &ea					; 3c, 2c
	}
	\\ Min 5c, max 84c

	\\ Toggle on - this should be at C0=0 when table_x=0
	stx TOGGLE_REGISTER			; 4c

	.clockslide_right
	{
		BRA clockslide_right	; 3c
		\\ Between 2 and 81 cycle delay
		FOR n,1,39,1		
		cmp #&c9				; 2c
		NEXT
		cmp &ea					; 3c, 2c
	}
	\\ Min 5c, max 84c

	.fx_draw_ymax
	cpy #&ff					; 2c
	beq fx_draw_done			; 2c

	\\ Don't spend them all at once
	WAIT_CYCLES 2

	\\ Next line
	iny							; 2c
	jmp fx_draw_loop			; 3c
	\\ 13c

	\\ May finish before y=256

	.fx_draw_done

	\\ Remainder is on
	.fx_draw_final_value
	lda #PAL_green				; 2c
	sta TOGGLE_REGISTER			; 4c

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

.drawline
{
	; don't need a screen address
	; calc screen row of starty
	LDY starty
	
	; calc pixel within byte of startx
	LDX startx

	; calc dx = ABS(startx - endx)
	SEC
	LDA startx
	SBC endx
	BCS posdx
	EOR #255
	ADC #1
	.posdx
	STA dx
	
	; C=0 if dir of startx -> endx is positive, otherwise C=1
	PHP
	
	; calc dy = ABS(starty - endy)
	SEC
	LDA starty
	SBC endy
	BCS posdy
	EOR #255
	ADC #1
	.posdy
	STA dy
	
	; C=0 if dir of starty -> endy is positive, otherwise C=1
	PHP
	
	; Coincident start and end points exit early
	ORA dx
	BEQ exitline
	
	; determine which type of line it is
	LDA dy
	CMP dx
	BCC shallowline
		
.steepline

	; self-modify code so that line progresses according to direction remembered earlier
	PLP
	lda #&c8		; INY	\\ going down
	BCC P%+4
	lda #&88		; DEY	\\ going up
	sta branchupdown
	
	PLP
	lda #&e8		; INX	\\ going right
	BCC P%+4
	lda #&ca		; DEX	\\ going left
	sta branchleftright

	sty steep_write+1

	lda endy
	sta steep_check+1

	; initialise accumulator for 'steep' line
	LDA dy
;	STA count

	LSR A

.steeplineloop

	\\ Keep accum in A
	
	; plot 'pixel'
	.steep_write
	stx table_x				; 4c	SELF-MOD low byte

	; check if done
;	DEC count				; 5c
	.steep_check
	cpy #&ff				; 2c
	BEQ exitline			; 2c

	.branchupdown
	nop						; 2c	SELF-MOD INY/DEY
	sty steep_write+1		; 4c
	
	; check move to next pixel column
	.movetonextcolumn
	SEC						; 2c
	\\ Keep accum in A
	SBC dx					; 3c
	BCS steeplineloop		; 2c
	ADC dy					; 3c
	
	.branchleftright
	nop						; 2c	SELF-MOD INX/DEX
	BRA steeplineloop		; 3c

	.exitline
	RTS
	
.shallowline

	; self-modify code so that line progresses according to direction remembered earlier
	PLP
	lda #&c8		; INY	\\ going down
	BCC P%+4
	lda #&88		; DEY	\\ going up
	sta branchupdown2

	PLP
	lda #&e8		; INX	\\ going right
	BCC P%+4
	lda #&ca		; DEX	\\ going left
	sta branchleftright2

	sty shallow_write+1

	; initialise accumulator for 'shadllow' line
	LDA dx
	STA count
	LSR A

	INC count

.shallowlineloop
;	STA accum

	; plot 'pixel'
;	txa
	.shallow_write
;	sta table_x, Y			; SELF-MOD low byte
	stx table_x

	; check if done
	DEC count
	beq exitline

	.branchleftright2
	nop						; SELF-MOD INX/DEX
	
	; check whether we move to the next line
	.movetonextline
	SEC
;	LDA accum
	SBC dy
	BCS shallowlineloop
	ADC dx

	.branchupdown2
	nop						; SELF-MOD INY/DEY
	sty shallow_write+1

	BRA shallowlineloop		; always taken
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

.shadow_filename
EQUS "Doom", 13

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
.test_table
{
	\\ startx, starty, endx, endy
	EQUB 0, 0, 79, 128
	EQUB 0, 0, 79, 255
	EQUB 0, 0, 40, 255

	EQUB 79, 0, 0, 128
	EQUB 79, 0, 0, 255
	EQUB 79, 0, 40, 255

	EQUB 79, 255, 0, 128
	EQUB 79, 255, 0, 0
	EQUB 79, 255, 40, 0

	EQUB 0, 255, 79, 128
	EQUB 0, 255, 79, 0
	EQUB 0, 255, 40, 0

	EQUB 40, 0, 0, 128		; ab -> ac
	EQUB 40, 0, 20, 255		; ab -> cd
	EQUB 40, 0, 60, 255		; ab -> cd
	EQUB 40, 0, 79, 128		; ab -> db

	EQUB 0, 128, 40, 0		; ac -> ab
	EQUB 0, 128, 79, 64		; ac -> db
	EQUB 0, 128, 79, 192	; ac -> db	; takes too long?
	EQUB 0, 128, 40, 255	; ac -> cd

	EQUB 40, 255, 0, 128	; cd -> ac
	EQUB 40, 255, 20, 0		; cd -> ab
	EQUB 40, 255, 60, 0		; cd -> ab
	EQUB 40, 255, 79, 128	; cd -> db

	EQUB 79, 128, 40, 255	; db -> cd
	EQUB 79, 128, 0, 192	; db -> ac
	EQUB 79, 128, 0, 64		; db -> ac	; takes too long?
	EQUB 79, 128, 40, 0		; db -> ab	
}
.test_end

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

ALIGN &100
.table_x
skip &100

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

PUTFILE "title.bin", "Screen", &3000
PUTFILE "screen.bin", "Doom", &3000
