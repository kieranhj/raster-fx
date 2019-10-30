\ ******************************************************************
\ *	RASTER FX FRAMEWORK
\ ******************************************************************

CPU 1
_REAL_HW = TRUE

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

ULA_Mode1 = &D8

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

.raster_y				skip 1
.image_y				skip 1
.table_idx				skip 1
.count					skip 1
.write_rts				skip 2

.startx					skip 1
.starty					skip 1
.endx					skip 1
.endy					skip 1
.dx						skip 1
.dy						skip 1

.startx_dir				skip 1
.readptr				skip 2

.check_width			skip 1		; [0-66] => 14 to 80 pixels
.check_scanline			skip 1

.check_x_offset_chars	skip 1
.check_x_offset_pix		skip 1

.check_x				skip 1		; offset by X pixels
.check_y				skip 1		; offset by Y lines

.check_N				skip 1
.check_XdivN			skip 2
.check_XmodN			skip 1
.check_YdivN			skip 2
.check_YmodN			skip 1

.check_dir				skip 1
.check_idx				skip 1
.check_idy				skip 1

MAX_CHECK_SIZE=66
MIN_CHECK_SIZE=0

\\ Display the same scanline for now.
\\ Toggle palette on vertical count according to check size
\\ Add in X & Y movement - required parity
\\ Then think about having multiple widths per frame...

\ ******************************************************************
\ *	CODE START
\ ******************************************************************

ORG &E00	      			; code origin (like P%=&2000)
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
	LDA #1
	JSR oswrch

	\\ Set palette
	ldx #15
	.pal_loop
	lda palette, X
	sta &fe21
	dex
	bpl pal_loop

	\\ Turn off cursor

	LDA #10: STA &FE00
	LDA #32: STA &FE01

	JSR fx_init_function

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
	lda &fe34
	and #255-4		; MAIN RAM
	sta &fe34

    \ Ask OSFILE to load our screen
	LDX #LO(osfile_params)
	LDY #HI(osfile_params)
	LDA #&FF
    JSR osfile
;	jsr blank_left_column

	lda &fe34
	ora #4			; SHADOW RAM
	sta &fe34

	lda #LO(shadow_filename)
	sta osfile_nameaddr
	lda #HI(shadow_filename)
	sta osfile_nameaddr+1

    \ Ask OSFILE to load our screen
	LDX #LO(osfile_params)
	LDY #HI(osfile_params)
	LDA #&FF
    JSR osfile
;	jsr blank_left_column

	lda &fe34
	and #255-4		; MAIN RAM
	sta &fe34

	lda #50			; should be 64 pixels
	sta check_width
	lda #1
	sta check_dir

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

.fx_update_function
{
	\\ X = 40 + sin(iy) / 4
    CLC
	LDY check_idx
	LDA checkzoom_table_sin, Y
	ADC #128
	STA check_x

	\\ Y = 37 + cos(iy) / 4
    CLC
	LDY check_idy
	LDA checkzoom_table_cos, Y
	ADC #128
	STA check_y

    \\ Update indices
    INC check_idx
    INC check_idx
    INC check_idy

IF 0
    {
        \\ Update N
        LDA check_dir
        BMI shrink
        \\ Grow
        CLC
        ADC check_width
        CMP #MAX_CHECK_SIZE-1
        BCC ok

        LDX #&FF
        STX check_dir
        BNE ok

        .shrink
        CLC
        ADC check_width
        CMP #MIN_CHECK_SIZE+1
        BCS ok

        LDX #1
        STX check_dir

        .ok
        STA check_width
        .not_today
    }
ENDIF

IF 0
	lda check_width
	clc
	adc #14
	sta check_N

	\\ Divide xoff by N
	LDA check_x
	STA check_XdivN
    STZ check_XdivN+1

	\\ 16bit/8bit math = 16bit result
    {
        LDX #16
        LDA #0
        .div_loop
        ASL check_XdivN
        ROL check_XdivN+1
        ROL A
        CMP check_N
        BCC no_sub
        SBC check_N
        INC check_XdivN
        .no_sub
        DEX
        BNE div_loop
        
        \\ A contains remainder (X MOD N)
        STA check_XmodN
    }

	\\ Divide yoff by N
	LDA check_y
	STA check_YdivN
    STZ check_YdivN+1

	\\ 16bit/8bit math = 16bit result
    {
        LDX #16
        LDA #0
        .div_loop
        ASL check_YdivN
        ROL check_YdivN+1
        ROL A
        CMP check_N
        BCC no_sub
        SBC check_N
        INC check_YdivN
        .no_sub
        DEX
        BNE div_loop
        
        \\ A contains remainder (Y MOD N)
        STA check_YmodN
    }

	\\ Set X & Y offsets
	lda check_XmodN
	lsr a: lsr a
	sta check_x_offset_chars

	lda check_XmodN
	and #3
	sta check_x_offset_pix

	ldx check_width
ENDIF

	ldx #67
	lda #13:sta &fe00	; 8c
	lda start_addr_for_width_LO, x
	clc
	adc check_x_offset_chars
	sta &fe01	; 10c

	lda #12:sta &fe00	; 8c
	lda start_addr_for_width_HI, x
	adc #0
	sta &fe01	; 10c

	lda scanline_for_width, X
	sta check_scanline
	sta image_y

	lda bank_for_width, X
	sta &fe34

IF 0
	lda check_XdivN
	and #1
	sta parity+1
	lda check_YdivN
	and #1
	.parity
	eor #0
	ora #ULA_Mode1
ENDIF
	lda #ULA_Mode1
	sta &fe20

IF 0
	\\ Now need to loop over Y
	ldy #0
	ldx check_YmodN
	.parity_loop
	sta ula_value_for_y, Y
	inx
	cpx check_N
	bcc no_flip
	eor #1
	ldx #0
	.no_flip
	iny
	bne parity_loop
ENDIF

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
\{
	\\ Enter fn at 64us before first raster line
	WAIT_CYCLES 128-14-6 -1

	.fx_draw_here
	clc					; 2c
	ldx check_width		; 3c
	ldy #2				; 2c
	stz &fe00			; 6c

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

	\\ Before end of segmnet 0 need to set R12/R13/R9

	\\ The rule is, set R9 at the start of a displayed line as follows:
	\\ R9 = this_line_number + 15 - next_line_number
	\\ or, conveniently:
	\\ R9 = (next_line_number EOR 15) + this_line_number (edited) 

	\\ Eg. 0->7: 0+15-7 = 8 = (7^15)+0
	\\ Eg. 7->0: 7+15-0 = 22 = (0^15)+7

	\\ Set R9
	LDA #9:STA &fe00				; 8c
	LDA scanline_for_width, x			; 4c
	adc check_x_offset_pix			; 3c
	sta fx_draw_prev_line+1				; 4c
	eor #15							; 2c
	\\ First scanline always 0
	STA &fe01						; 6c-1
	\\ 24c

	\\ Set R12/R13
	LDA #13:STA &fe00				; 8c
	LDA start_addr_for_width_LO, X
	adc check_x_offset_chars		; 3c
	STA &fe01		; 6c-1
	\\ 36c

	LDA #12:STA &fe00				; 8c
	LDA start_addr_for_width_HI, X:STA &fe01		; 10c

	WAIT_CYCLES 4

IF _REAL_HW=FALSE
	NOP
ENDIF

	\\ start segment 1..
	stz &fe00			; stz		; 6c
	lda #1							; 2c
	\\ This has to be bang on 96c on real hw
	sta &fe01				; R0=1 horizontal total = 2
	\\ 14c

	lda #6:sta &fe00
	lda #1:sta &fe01		; R6=1 vertical displayed <-- could this be moved to update?
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
	\\ 8c

	\\ Only 18 cycles available!

	sty raster_y					; 3c

;	ldy index						; 3c
;	dey								; 2c
;	sty index						; 3c - GAH!

	ldx table_check_width, Y		; 4c

	WAIT_CYCLES 1

	\\ Screen start address = screen[image_y]
	lda #13:sta &fe00				; 8c
	lda start_addr_for_width_LO, X				; 4c	Y=image y
;	adc check_x_offset_chars		; 3c
	adc table_x_offset_chars, Y		; 4c
	sta &fe01						; 6c

	lda #12:sta &fe00				; 8c
	lda start_addr_for_width_HI, X				; 4c    Y=image y
	adc #0
	sta &fe01						; 6c

	\\ 52c total

	\\ Set R9=image_y AND 7
	lda #9:sta &fe00				; 8c

	lda scanline_for_width, X		; 4c	Y=image Y
;	adc check_x_offset_pix			; 3c
	adc table_x_offset_pix, Y		; 4c
	tay								; 2c	Y=image scanline
	eor #15							; 2c
	.fx_draw_prev_line
	adc #0							; 2c	SELF-MOD CODE
	sta &fe01						; 6c

	\\ Need to reset prev_line for next time
	sty fx_draw_prev_line+1			; 4c

	\\ Available 20+26+36 = 82c to set R9/12/13 note minimum overhead of 3x14c = 42c to select and set registers

IF _REAL_HW=FALSE
;	nop								; 2c		MUST BE 2c!
	ERROR
ENDIF

	\\ Set horizontal total
	\\ This has to be bang on 96c!
	stz &fe00						; 6c
	lda #1							; 2c
	sta &fe01				; R0=1 horizontal total = 2
	\\ 14c

IF _REAL_HW
;	nop								; 2c		MUST BE 2c!
ENDIF

	\\ Remaining segments until we have 128 chars in total
	\\ 22 cycles in total inc loop +2 inc NOP above
	ldy raster_y					; 3c

	lda ula_value_for_y, Y			; 4c
	sta &fe20						; 4c

	lda bank_for_width, X			; 4c
	sta &fe34						; 4c

	iny								; 2c
	bne fx_draw_loop				; 3c
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
	ADC fx_draw_prev_line+1				; 4c
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

IF 0
.wipe_image_table
{
	lda #0
;	ldx #0
	FOR n,0,255,1
	sta table_image_y+n
;	stx table_image_bank+n
	NEXT
	rts
}	\\ 256 * 4 * 2 = 2048c = 16 scanlines
ENDIF

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
	
	\\ We should be able to guarantee endy>starty for this FX
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
	LSR A

.steeplineloop

	\\ Keep accum in A
	
	; plot 'pixel'
	.steep_write
	stx table_image_y		; 4c	SELF-MOD low byte

	; check if done
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

	; plot 'pixel'
	.shallow_write
	stx table_image_y		; SELF-MOD low byte

	; check if done
	DEC count
	beq exitline

	.branchleftright2
	nop						; SELF-MOD INX/DEX
	
	; check whether we move to the next line
	.movetonextline
	SEC
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

.palette
{
	EQUB &00 + 15
	EQUB &10 + 15
	EQUB &20 + PAL_red
	EQUB &30 + PAL_red
	EQUB &40 + 15
	EQUB &50 + 15
	EQUB &60 + PAL_red
	EQUB &70 + PAL_red
	EQUB &80 + PAL_yellow
	EQUB &90 + PAL_yellow
	EQUB &A0 + 8
	EQUB &B0 + 8
	EQUB &C0 + PAL_yellow
	EQUB &D0 + PAL_yellow
	EQUB &E0 + 8
	EQUB &F0 + 8
}

.osfile_filename
EQUS "Check1", 13

.shadow_filename
EQUS "Check2", 13

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

IF 0
.screen_LO
FOR n,0,255,1
y=n
row = y DIV 8
EQUB LO((screen_addr + row * row_bytes)/8)
NEXT

.screen_HI
FOR n,0,255,1
y=n
row = y DIV 8
EQUB HI((screen_addr + row * row_bytes)/8)
NEXT

.y_to_scanline
EQUB 0
FOR n,1,255,1
y = n
line = y MOD 8
EQUB line
NEXT
ENDIF

ALIGN &100
.start_addr_for_width_LO ; 14 to 80
\\ Two widths per character row
\\ Character row is 80+(w+3)DIV4 chars wide
EQUB LO(width_14/8)
EQUB LO(width_15/8)
EQUB LO(width_16/8)
EQUB LO(width_17/8)
EQUB LO(width_18/8)
EQUB LO(width_19/8)
EQUB LO(width_20/8)
EQUB LO(width_21/8)
EQUB LO(width_22/8)
EQUB LO(width_23/8)
EQUB LO(width_24/8)
EQUB LO(width_25/8)
EQUB LO(width_26/8)
EQUB LO(width_27/8)
EQUB LO(width_28/8)
EQUB LO(width_29/8)
EQUB LO(width_30/8)
EQUB LO(width_31/8)
EQUB LO(width_32/8)
EQUB LO(width_33/8)
EQUB LO(width_34/8)
EQUB LO(width_35/8)
EQUB LO(width_36/8)
EQUB LO(width_37/8)
EQUB LO(width_38/8)
EQUB LO(width_39/8)
EQUB LO(width_40/8)
EQUB LO(width_41/8)
EQUB LO(width_42/8)
EQUB LO(width_43/8)
EQUB LO(width_44/8)
EQUB LO(width_45/8)
EQUB LO(width_46/8)
EQUB LO(width_47/8)
EQUB LO(width_48/8)
EQUB LO(width_49/8)
EQUB LO(width_50/8)
EQUB LO(width_51/8)
EQUB LO(width_52/8)
EQUB LO(width_53/8)
EQUB LO(width_54/8)
EQUB LO(width_55/8)
EQUB LO(width_56/8)
EQUB LO(width_57/8)
EQUB LO(width_58/8)
EQUB LO(width_59/8)
EQUB LO(width_60/8)
EQUB LO(width_61/8)
EQUB LO(width_62/8)
EQUB LO(width_63/8)
EQUB LO(width_64/8)
EQUB LO(width_65/8)
EQUB LO(width_66/8)
EQUB LO(width_67/8)
EQUB LO(width_68/8)
EQUB LO(width_69/8)
EQUB LO(width_70/8)
EQUB LO(width_71/8)
EQUB LO(width_72/8)
EQUB LO(width_73/8)
EQUB LO(width_74/8)
EQUB LO(width_75/8)
EQUB LO(width_76/8)
EQUB LO(width_77/8)
EQUB LO(width_78/8)
EQUB LO(width_79/8)
EQUB LO(width_80/8)
EQUB LO(width_blank/8)

ALIGN &100
.start_addr_for_width_HI ; 14 to 80
\\ Two widths per character row
\\ Character row is 80+(w+3)DIV4 chars wide
EQUB HI(width_14/8)
EQUB HI(width_15/8)
EQUB HI(width_16/8)
EQUB HI(width_17/8)
EQUB HI(width_18/8)
EQUB HI(width_19/8)
EQUB HI(width_20/8)
EQUB HI(width_21/8)
EQUB HI(width_22/8)
EQUB HI(width_23/8)
EQUB HI(width_24/8)
EQUB HI(width_25/8)
EQUB HI(width_26/8)
EQUB HI(width_27/8)
EQUB HI(width_28/8)
EQUB HI(width_29/8)
EQUB HI(width_30/8)
EQUB HI(width_31/8)
EQUB HI(width_32/8)
EQUB HI(width_33/8)
EQUB HI(width_34/8)
EQUB HI(width_35/8)
EQUB HI(width_36/8)
EQUB HI(width_37/8)
EQUB HI(width_38/8)
EQUB HI(width_39/8)
EQUB HI(width_40/8)
EQUB HI(width_41/8)
EQUB HI(width_42/8)
EQUB HI(width_43/8)
EQUB HI(width_44/8)
EQUB HI(width_45/8)
EQUB HI(width_46/8)
EQUB HI(width_47/8)
EQUB HI(width_48/8)
EQUB HI(width_49/8)
EQUB HI(width_50/8)
EQUB HI(width_51/8)
EQUB HI(width_52/8)
EQUB HI(width_53/8)
EQUB HI(width_54/8)
EQUB HI(width_55/8)
EQUB HI(width_56/8)
EQUB HI(width_57/8)
EQUB HI(width_58/8)
EQUB HI(width_59/8)
EQUB HI(width_60/8)
EQUB HI(width_61/8)
EQUB HI(width_62/8)
EQUB HI(width_63/8)
EQUB HI(width_64/8)
EQUB HI(width_65/8)
EQUB HI(width_66/8)
EQUB HI(width_67/8)
EQUB HI(width_68/8)
EQUB HI(width_69/8)
EQUB HI(width_70/8)
EQUB HI(width_71/8)
EQUB HI(width_72/8)
EQUB HI(width_73/8)
EQUB HI(width_74/8)
EQUB HI(width_75/8)
EQUB HI(width_76/8)
EQUB HI(width_77/8)
EQUB HI(width_78/8)
EQUB HI(width_79/8)
EQUB HI(width_80/8)
EQUB HI(width_blank/8)

ALIGN &100
.scanline_for_width
FOR w,14,80,2
EQUB 0,4
NEXT

ALIGN &100
.bank_for_width
FOR w,14,69,1
EQUB 0
NEXT
FOR w,70,81,1
EQUB 1
NEXT

.checkzoom_table_sin
FOR n,0,&13F,1
EQUB 64 + 63 * SIN(2 * PI * n / 256)	; 255 or 256?
NEXT

checkzoom_table_cos = checkzoom_table_sin + 64

MACRO ULA_VALUES v, n
FOR i,1,n,1
EQUB ULA_Mode1+v
NEXT
ENDMACRO

S%=80
py=-128
cx=0:cy=0:cz=-160
scale=160:vpx=160:vpy=128

ALIGN &100
ULA_BASE=0
.ula_value_for_y
ULA_VALUES 0, 149
;ULA_VALUES ULA_BASE EOR 1, 2
;ULA_VALUES ULA_BASE, 2
;ULA_VALUES ULA_BASE EOR 1, 3
;ULA_VALUES ULA_BASE, 3
;ULA_VALUES ULA_BASE EOR 1, 5
;ULA_VALUES ULA_BASE, 6
;ULA_VALUES ULA_BASE EOR 1, 9
;ULA_VALUES ULA_BASE, 12
;ULA_VALUES ULA_BASE EOR 1, 22
;ULA_VALUES ULA_BASE, 43

FOR n,149,255,1
y=255-n
pz = cz + scale * (py - cy) / (y - vpy)
px = cx - vpx * (pz-cz) / scale
dx = -px DIV 80
dz = pz DIV 80
;PRINT dx, dx AND 1
EQUB ULA_Mode1 + ((dx AND 1) EOR (dz AND 1))
NEXT

ALIGN &100
.table_x_offset_chars
FOR n,0,148,1
EQUB 0
NEXT
FOR n,149,255,1
y=255-n
\\ For screen line y what's the Z value of our point on the plane?
pz = cz + scale * (py - cy) / (y - vpy)
\\ For this distance, what's the X value of our point on the plane at the left-hand edge of the screen?
px = cx - vpx * (pz-cz) / scale
\\ How far into the check does this start?
dx = 80 + (px - 80*(px DIV 80))

\\ Now project this fraction of a check into screen space
sx = scale * (dx - cx) / (pz - cz)
wx = INT(-80 * (y - 128) / 128)

x_off = sx
PRINT pz,px,dx,sx,wx,x_off
EQUB x_off DIV 4
NEXT

.table_x_offset_pix
FOR n,0,148,1
EQUB 0
NEXT
FOR n,149,255,1
y=255-n
pz = cz + scale * (py - cy) / (y - vpy)
px = cx - vpx * (pz-cz) / scale
dx = 80 + (px - 80*(px DIV 80))

sx = scale * (dx - cx) / (pz - cz)
wx = INT(-80 * (y - 128) / 128)

x_off = sx
EQUB x_off MOD 4
NEXT

.table_check_width
FOR n,0,148,1
EQUB 67;blank
NEXT
FOR n,149,255,1
y=255-n
\\ Check size 80, plane at y=-128 camera at (0,0,-160)
wx = INT(-80 * (y - 128) / 128)
EQUB wx-14
NEXT

IF 0
MIN_W=52
MAX_W=304
ERR=1e-7

oz=100
vp_scale=256		; was 160
centre_x=160
centre_y=128

MACRO PROJECT_EDGE x1,y1,z1,x2,y2,z2,colour
{
	s1x = centre_x + vp_scale * x1 / (z1 + oz - cz)
	s1y = centre_y + vp_scale * y1 / (z1 + oz - cz)
	s2x = centre_x + vp_scale * x2 / (z2 + oz - cz)
	s2y = centre_y + vp_scale * y2 / (z2 + oz - cz)

;	PRINT "LINE FROM y=",s1y,"to",s2y
	w1 = (s1x - centre_x) * 2
	w2 = (s2x - centre_x) * 2
;	PRINT "WIDTH FROM ",w1,"to",w2

	IF s2y<s1y
		PRINT "CULL EDGE"
	ELSE

		IF w1<MIN_W
			EQUB colour+1
		ELIF w1>MAX_W
			EQUB colour+127
		ELSE
			EQUB colour+(INT(w1)-MIN_W)/2
		ENDIF

		\\ startx,starty, endx,endy
		EQUB INT(s1y)
		
		IF w2<MIN_W
			EQUB colour+1
		ELIF w2>MAX_W
			EQUB colour+127
		ELSE
			EQUB colour+(INT(w2)-MIN_W)/2
		ENDIF
		
		EQUB INT(s2y)
	ENDIF
}
ENDMACRO

\\ Verts on side of a cube (square)
v1x=64:v1y=16:v1z=64
v2x=64:v2y=-16:v2z=64
v3x=64:v3y=-16:v3z=-64
v4x=64:v4y=16:v4z=-64

PRINT "v1=(",v1y,v1z,") v2=(",v2y,v2z,") v3=",v3y,v3z,") v4=",v4y,v4z,")"

.projection_list
FOR a,0,255,2
s = SIN(2 * PI * a / 256)
c = COS(2 * PI * a / 256)
\\ Rotate around X axis
\\ Project onto screen
\\ Pick the 2x visible faces

\\ Rotate around X axis
r1y = c*v1y - s*v1z
r1z = s*v1y + c*v1z
r2y = c*v2y - s*v2z
r2z = s*v2y + c*v2z
r3y = c*v3y - s*v3z
r3z = s*v3y + c*v3z
r4y = c*v4y - s*v4z
r4z = s*v4y + c*v4z

PRINT "a=",(360*a/256)
;PRINT "r1=(",r1y,r1z,") r2=(",r2y,r2z,") r3=",r3y,r3z,") r4=",r4y,r4z,")"

\\ Sides of the square (edge of the cube looking down X axis)
l1y = r2y-r1y : l1z = r2z-r1z
l2y = r3y-r2y : l2z = r3z-r2z
l3y = r4y-r3y : l3z = r4z-r3z
l4y = r1y-r4y : l4z = r1z-r4z

\\ Normals to the edges
n1z = l4z : n2z = l1z : n3z = l2z : n4z = l3z

\\ Only edges with positive Z component of normal are visible (facing camera at +ve Z)

;PRINT "l1y=",l1y,"l2y=",l2y,"l3y=",l3y,"l4y=",l4y
;PRINT "l1z=",l1z,"l2z=",l2z,"l3z=",l3z,"l4z=",l4z

IF n1z<-ERR
	PRINT "Edge 1 visible: (",r1y,r1z,") -> (",r2y,r2z,")"
	PROJECT_EDGE v1x,r1y,r1z,v2x,r2y,r2z, 0
ENDIF
IF n2z<-ERR
	PRINT "Edge 2 visible: (",r2y,r2z,") -> (",r3y,r3z,")"
	PROJECT_EDGE v2x,r2y,r2z,v3x,r3y,r3z, 128
ENDIF
IF n3z<-ERR
	PRINT "Edge 3 visible: (",r3y,r3z,") -> (",r4y,r4z,")"
	PROJECT_EDGE v3x,r3y,r3z,v4x,r4y,r4z, 0
ENDIF
IF n4z<-ERR
	PRINT "Edge 4 visible: (",r4y,r4z,") -> (",r1y,r1z,")"
	PROJECT_EDGE v4x,r4y,r4z,v1x,r1y,r1z, 128
ENDIF
EQUB 0
NEXT
EQUB 128
ENDIF

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
.table_image_y
skip &100

.bss_end

MACRO CHECK_STRIDE width
	skip (80+(width+3)DIV4)*8
ENDMACRO

CLEAR 0,&FFFF
ORG screen_addr
GUARD &8000
.width_14
.width_15
CHECK_STRIDE 15
.width_16
.width_17
CHECK_STRIDE 17
.width_18
.width_19
CHECK_STRIDE 19
.width_20
.width_21
CHECK_STRIDE 21
.width_22
.width_23
CHECK_STRIDE 23
.width_24
.width_25
CHECK_STRIDE 25
.width_26
.width_27
CHECK_STRIDE 27
.width_28
.width_29
CHECK_STRIDE 29
.width_30
.width_31
CHECK_STRIDE 31
.width_32
.width_33
CHECK_STRIDE 33
.width_34
.width_35
CHECK_STRIDE 35
.width_36
.width_37
CHECK_STRIDE 37
.width_38
.width_39
CHECK_STRIDE 39
.width_40
.width_41
CHECK_STRIDE 41
.width_42
.width_43
CHECK_STRIDE 43
.width_44
.width_45
CHECK_STRIDE 45
.width_46
.width_47
CHECK_STRIDE 47
.width_48
.width_49
CHECK_STRIDE 49
.width_50
.width_51
CHECK_STRIDE 51
.width_52
.width_53
CHECK_STRIDE 53
.width_54
.width_55
CHECK_STRIDE 55
.width_56
.width_57
CHECK_STRIDE 57
.width_58
.width_59
CHECK_STRIDE 59
.width_60
.width_61
CHECK_STRIDE 61
.width_62
.width_63
CHECK_STRIDE 63
.width_64
.width_65
CHECK_STRIDE 65
.width_66
.width_67
CHECK_STRIDE 67
.width_68
.width_69
CHECK_STRIDE 69
CLEAR &3000,&8000
ORG &3000
.width_70
.width_71
CHECK_STRIDE 71
.width_72
.width_73
CHECK_STRIDE 73
.width_74
.width_75
CHECK_STRIDE 75
.width_76
.width_77
CHECK_STRIDE 77
.width_78
.width_79
CHECK_STRIDE 79
.width_80
.width_blank
CHECK_STRIDE 80


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
PUTFILE "rtw_test.bin", "RTW", &3000
PUTFILE "check1.bin", "Check1", &3000
PUTBASIC "shift.bas", "Shift"
PUTFILE "check2.bin", "Check2", &3000
PUTBASIC "scale.bas", "Scale"
PUTBASIC "widths.bas", "Widths"
PUTBASIC "checks.bas", "Checks"

IF HI(fx_draw_loop) <> HI(fx_draw_loop)
	PRINT "WARNING: fx_draw_loop crossed page boundary!!"
ENDIF