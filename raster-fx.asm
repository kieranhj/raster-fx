\ ******************************************************************
\ *	RASTER FX FRAMEWORK
\ ******************************************************************

SPRITE_HEIGHT=44

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

MACRO PAGE_ALIGN_FOR_SIZE size
IF HI(P%+size) <> HI(P%)
	PAGE_ALIGN
ENDIF
ENDMACRO

MACRO CHECK_SAME_PAGE_AS base
IF HI(P%-1) <> HI(base)
PRINT "WARNING! Table or branch base address",~base, "may cross page boundary at",~P%
ENDIF
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
TimerValue = 32*64 - 2*64 - 2 - 22 - 9 + 8

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

.writeptr		skip 2
.row_count		skip 1
.temp			skip 1

.x_zoom			skip 1
.x_dir			skip 1
.scanline		skip 1
.v				skip 2

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

	\\ Set MODE

	LDA #22
	JSR oswrch
	LDA #2
	JSR oswrch

	\\ Turn off cursor

	LDA #10: STA &FE00
	LDA #32: STA &FE01

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
	lda #0
	sta x_zoom
	sta v:sta v+1
	lda #1:sta x_dir

	\ Ensure MAIN RAM is writeable
    LDA &FE34:AND #&FB:STA &FE34
	ldx #LO(file1):ldy #HI(file1):lda #HI(&3000):jsr disksys_load_file
	IF 0
	\ Ensure SHADOW RAM is writeable
    LDA &FE34:ORA #&4:STA &FE34
	ldx #LO(file2):ldy #HI(file2):lda #HI(&3000):jsr disksys_load_file
	\ Ensure MAIN RAM is writeable
    LDA &FE34:AND #&FB:STA &FE34
	ENDIF
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
	{
		\\ Update zoom factor.
		clc
		lda x_zoom
		adc x_dir
		bpl not_min
		lda #1
		sta x_dir
		lda #0
		.not_min
		cmp #64
		bcc not_max
		lda #&ff
		sta x_dir
		lda #63
		.not_max
		sta x_zoom
	}

	\\ Set screen address for zoom.
	lsr a:lsr a		; 64 zooms, 2 scanlines each = 4 per row
	tax
	lda #13:sta &fe00
	lda twister_vram_table_LO, X
	sta &fe01
	lda #12:sta &fe00
	lda twister_vram_table_HI, X
	sta &fe01

	\\ Scanline 0,2,4,6
	lda x_zoom
	and #3
	eor #3
	asl a
	sta scanline

	\\ Want centre of screen to be centre of sprite.
	lda #0:sta v
	lda #SPRITE_HEIGHT/2:sta v+1

	\\ Set dv.
	ldx x_zoom
	lda dv_table, X
	sta add_dv+1

	\\ Subtract dv 128 times to set starting v.
	ldy #64
	.sub_loop
	sec
	lda v
	sbc dv_table, X
	sta v
	lda v+1
	sbc #0
	sta v+1

	\\ Wrap sprite height.
	bpl sub_ok
	clc
	adc #SPRITE_HEIGHT
	sta v+1

	.sub_ok
	dey
	bne sub_loop

	\\ Hi byte of V * 16
	clc
	lda #0:sta temp
	lda v+1
	asl a:rol temp
	asl a:rol temp
	asl a:rol temp
	asl a:rol temp
	clc
	adc #LO(frak_data)
	sta pal_loop+1
	lda temp
	adc #HI(frak_data)
	sta pal_loop+2

	\\ Set palette for first line.
	ldx #15
	.pal_loop
	lda frak_data, X
	sta &fe21
	dex
	bpl pal_loop

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

\\ To repeat just one scanline, need to burn 6 scanlines.
\\ 6x4c = 24c hsync at 98,
\\ <-- 104 cycles w/ 80 visible hsync at 98 --> <4c> <4c> ... <4c>
\\ Need R0=4 at HCC=104
\\ Need R0=100 at HCC=0

PAGE_ALIGN
.fx_draw_function
{
	\\ R4=0, R7=&ff, R6=1
	lda #4:sta &fe00			; 8c
	lda #0:sta &fe01			; 8c

	\\ vsync at row 35 = scanline 280.
	lda #7:sta &fe00			; 8c
	lda #3:sta &fe01			; 8c

	lda #6:sta &fe00			; 8c
	lda #1:sta &fe01			; 8c

	lda #126:sta row_count		; 5c

	WAIT_CYCLES 61

		\\ <=== HCC=0
		.scanline_1_hcc0
		lda #0:sta &fe00		; 8c
		lda #101:sta &fe01		; 8c

		\\ Need to set correct scanline here.
		\\ 0=>0 R9=13 burn 12
		\\ 0=>2 R9=11 burn 12
		\\ 0=>4 R9=9 burn 12
		\\ 0=>6 R9=7 burn 12

		lda #9:sta &fe00		; 8c
		sec						; 2c
		lda #13					; 2c
		sbc scanline			; 3c
		sta &fe01				; 6c <== 5c
		lda #0:sta &fe00		; 8c

		WAIT_CYCLES 50
		
		\\ R0=1 <2c> x13
		lda #1:sta &fe01		; 8c
		\\ <=== HCC=102

		WAIT_CYCLES 18
		lda #127:sta &fe01		; 8c <== 7c
		\\ <=== HCC=0

		WAIT_CYCLES 16
		jmp scanline_even_hcc0	; 3c

	\\ Now 2x scanlines per loop.
	.scanline_loop
	{
		WAIT_CYCLES 11

		.^scanline_even_hcc0
		clc						; 2c
		lda v					; 3c
		.*add_dv
		adc #128				; 2c
		sta v					; 3c
		lda v+1					; 3c
		adc #0					; 2c

		cmp #SPRITE_HEIGHT		; 2c
		bcc ok
		; 2c
		sbc #SPRITE_HEIGHT		; 2c
		jmp store				; 3c
		.ok
		; 3c
		WAIT_CYCLES 4
		.store
		sta v+1					; 3c
		\\ 27c

		tax						; 2c
		lda frak_lines_LO, X	; 4c
		sta set_palette+1		; 4c
		lda frak_lines_HI, X	; 4c
		sta set_palette+2		; 4c
		\\ 18c

		WAIT_CYCLES 4

		\\ Ideally call at HCC=68
		.set_palette
		jsr frak_line0			; 60c

		.*scanline_odd_hcc_0
		\\ <=== HCC=0
		lda #0:sta &fe00		; 8c
		lda #103:sta &fe01		; 8c

		lda #9:sta &fe00		; 8c
		lda #7:sta &fe01		; 8c
		lda #0:sta &fe00		; 8c	

		WAIT_CYCLES 56

		lda #3:sta &fe01		; 8c
		\\ <=== HCC=104

		WAIT_CYCLES 16
		lda #127:sta &fe01		; 8c
		\\ <=== HCC=0

		dec row_count			; 5c
		bne scanline_loop		; 3c
	}
	CHECK_SAME_PAGE_AS scanline_loop
	.scanline_last

	\\ Need to recover back to correct scanline count.
	lda #9:sta &fe00
	clc
	lda scanline
	adc #1
	sta &fe01

	lda #6:sta &fe00			; 8c
	lda #0:sta &fe01			; 8c

	ldx #2:jsr cycles_wait_scanlines

	\\ R9=7
	.scanline_end_of_screen
	lda #9:sta &fe00
	lda #7:sta &fe01

	\\ Total 312 line - 256 = 56 scanlines
	LDA #4: STA &FE00
	LDA #6: STA &FE01

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

INCLUDE "lib/disksys.asm"
INCLUDE "frak.asm"

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

.file1 EQUS "1",13
.file2 EQUS "2",13

\ ******************************************************************
\ *	FX DATA
\ ******************************************************************

PAGE_ALIGN_FOR_SIZE 16
.twister_vram_table_LO
FOR n,15,0,-1
EQUB LO((&3140 + (n)*1280)/8)
NEXT

PAGE_ALIGN_FOR_SIZE 16
.twister_vram_table_HI
FOR n,15,0,-1
EQUB HI((&3140 + (n)*1280)/8)
NEXT

PAGE_ALIGN_FOR_SIZE 64
.dv_table
FOR n,63,0,-1
; u=128*d/80
; d=1+n*(79/31))
PRINT 2 / ((1 + n*79/63) / 80)
EQUB 255 * (1 + n*79/63) / 80		; 128
NEXT

.frak_data
INCBIN "frak.bin"

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

PUTFILE "SCREEN1_2by160.BIN", "1", &3000
