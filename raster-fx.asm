\ ******************************************************************
\ *	RASTER FX FRAMEWORK
\ ******************************************************************

_DEBUG_RASTERS = FALSE
_STABLE_RASTER = TRUE

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

MACRO SET_PAL col, pal
	LDA #col + pal
	STA &FE21
	EOR #&10: STA &FE21
	EOR #&40: STA &FE21
	EOR #&10: STA &FE21
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
TimerValue = 32*64 - 2*64 - 2 - 22 - 9

\\ 40 lines for vblank
\\ 32 lines for vsync (vertical position = 35 / 39)
\\ interupt arrives 2 lines after vsync pulse
\\ 2 us for latch
\\ XX us to fire the timer before the start of the scanline so first colour set on column -1
\\ YY us for code that executes after timer interupt fires

WAVE_NUM_CHARS = 80
WAVE_NUM_ROWS = 3
WAVE_SCREEN_BYTES = WAVE_NUM_ROWS * WAVE_NUM_CHARS * 8

WAVE_NUM_GLYPHS = 60
WAVE_GLYPH_WIDTH = 8
WAVE_GLYPH_HEIGHT = 24
WAVE_GLYPH_STRIDE = WAVE_GLYPH_HEIGHT*2
WAVE_GLYPH_BYTES = WAVE_GLYPH_WIDTH * WAVE_GLYPH_STRIDE
WAVE_TOTAL_BYTES = WAVE_GLYPH_BYTES * WAVE_NUM_GLYPHS

glyph_base_addr = &8000 - WAVE_TOTAL_BYTES

\ ******************************************************************
\ *	ZERO PAGE
\ ******************************************************************

ORG &0
GUARD &9F

.dot_fb					SKIP 80

\\ System variables

.vsync_counter			SKIP 2		; counts up with each vsync
.escape_pressed			SKIP 1		; set when Escape key pressed

\\ FX variables

.readptr				SKIP 2
.writeptr				SKIP 2

.billb_message_ptr		SKIP 2
.billb_glyph_col		SKIP 1

.temp_col				SKIP 1
.temp_idx				SKIP 1

.data_byte				SKIP 1
.screen_ptr				SKIP 2

\ ******************************************************************
\ *	CODE START
\ ******************************************************************

ORG &E00	      				; code origin (like P%=&2000)
GUARD screen_addr			; ensure code size doesn't hit start of screen memory

.start

INCLUDE "lib/disksys.asm"

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

	\\ Turn off cursor

	LDA #10: STA &FE00
	LDA #32: STA &FE01

	\\ Set Colour 2 to White - MODE 1 requires 4x writes to ULA Palette Register

	SET_PAL MODE1_COL1, PAL_blue
	SET_PAL MODE1_COL2, PAL_cyan

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
	;	LDX #245
	;	.loop
	;	JSR cycles_wait_128
	;	DEX
	;	BNE loop
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
	IF _STABLE_RASTER
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
	LDA #7
	STA billb_glyph_col

	LDA #LO(message_text)
	STA billb_message_ptr
	LDA #HI(message_text)
	STA billb_message_ptr+1

	LDX #DISPLAY_DOT_WIDTH-1
	LDA #0
	.loop
	STA dot_fb, X
	DEX
	BPL loop

	LDA #4
	STA &F4
	STA &FE30

	LDX #LO(filename)
	LDY #HI(filename)
	LDA #HI(bank_start)
	JSR disksys_load_file

	LDA #0
	LDX #0
	.clear_loop
	STA &4000,X
	INX
	BNE clear_loop
	INC clear_loop+2
	BPL clear_loop

	RTS
}

\ ******************************************************************
\ Update FX
\
\ The update function is used to update / tick any variables used
\ in the FX. It may also prepare part of the screen buffer before
\ drawing commences but note the strict timing constraints!
\
\ This function will be called during vblank, after any system
\ modules have been polled.
\
\ The function MUST COMPLETE BEFORE TIMER 1 REACHES 0, i.e. before
\ raster line 0 begins. If you are late then the draw function will
\ be late and your raster timings will be wrong!
\ ******************************************************************

.get_next_msg_char
{
	.try_again
	LDA (billb_message_ptr), Y
	BNE char_ok

	LDA #LO(message_text)
	STA billb_message_ptr
	LDA #HI(message_text)
	STA billb_message_ptr+1
	BNE try_again

	.char_ok
	INC billb_message_ptr
	BNE no_carry
	INC billb_message_ptr+1
	.no_carry

	RTS
}

.fx_update_function
{
	LDY billb_glyph_col
	INY
	CPY #WAVE_GLYPH_WIDTH
	BCC col_ok

	\\ Next char
	LDY #0
	JSR get_next_msg_char

	.col_ok
	STY billb_glyph_col
	STY temp_col

	RTS
}

\ ******************************************************************
\ Draw FX
\
\ The draw function is the main body of the FX.
\
\ This function will be exactly at the start* of raster line 0 with
\ a maximum jitter of up to +10 cycles.
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
	\\ Raster is displaying row 0

	IF _DEBUG_RASTERS
	SET_PAL MODE1_COL0, PAL_red
	ENDIF

	\\ CRTC setup for rupture

IF 0
	LDA #4:STA &FE00			; vertical total
	LDA #2:STA &FE01			; R4 = 3 - 1 = 2

	LDA #6:STA &FE00			; vertical displayed
	LDA #3:STA &FE01			; R6 = 3

	LDA #7:STA &FE00			; vsync
	LDA #&FF:STA &FE01			; R7 = &FF (no vsync)
ENDIF

	LDY #0
	LDX #0

	.glyph_loop
	STY temp_idx

	LDA #0
	STA readptr+1

	LDA (billb_message_ptr), Y
	BEQ ok
	SEC
	SBC #32
	.ok

	\\ Get byte for column of glyph - don't need to calc this every time

	STA readptr
	ASL readptr
	ROL readptr+1
	ASL readptr
	ROL readptr+1
	ASL readptr
	ROL readptr+1

	CLC
	LDA readptr
	ADC #LO(glyph_data)
	STA readptr
	LDA readptr+1
	ADC #HI(glyph_data)
	STA readptr+1

	\\ Get glyph byte
	LDY temp_col
	.col_loop
	STY temp_col
	LDA (readptr), Y

	TAY
	EOR dot_fb, X
	STY dot_fb, X
	
	JSR plot_dot_col

	INX
	CPX #DISPLAY_DOT_WIDTH
	BCS done_loop

	LDY temp_col
	INY
	CPY #8
	BCC col_loop

	LDY #0
	STY temp_col

	LDY temp_idx
	INY
	BNE glyph_loop
	.done_loop

	IF _DEBUG_RASTERS
	SET_PAL MODE1_COL0, PAL_black
	ENDIF

IF 0
	\\ R4=vertical total = 39
	LDA #4: STA &FE00
	LDA #8: STA &FE01		; 9 - 1

	\\ R7=vsync at row 35
	LDA #7:	STA &FE00
	LDA #5: STA &FE01

	\\ R6=displayed
	LDA #6: STA &FE00
	LDA #2: STA &FE01
ENDIF

	\\ Cross fingers

    RTS
}

.plot_dot_col		; A = byte, X = col
{
	STA data_byte

	LDA dot_col_table_LO, X
	STA plot_dot_jump+1

	LDA dot_col_table_HI, X
	STA plot_dot_jump+2

	.plot_dot_jump
	JMP &FFFF
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

.filename
EQUS "Bank",13

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

\ ******************************************************************
\ *	FX DATA
\ ******************************************************************

; hack wrap
.message_text
EQUS "          HELLO WORLD! BITSHIFTERS SCROLLTEXT PROTOTYPE CHALLENGE... 80x8 = 640 PRECOMPILED DOTS!",0,"          "

ALIGN &100
.glyph_data
INCBIN "square_font_90_deg_cw.bin"

.data_end

\ ******************************************************************
\ *	End address to be saved
\ ******************************************************************

.end

\ ******************************************************************
\ *	Save the code
\ ******************************************************************

SAVE "MyFX", start, end, main

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
PRINT "FREE =", ~glyph_base_addr-P%
PRINT "------"

\ ******************************************************************
\ SWRAM BANK
\ ******************************************************************

CLEAR 0,&FFFF
ORG &8000
GUARD &C000
.bank_start
;INCLUDE "dot_code.asm"
INCLUDE "dot_column_code.asm"
INCLUDE "dot_plot_code.asm"

.bank_end

SAVE "Bank", bank_start, bank_end, 0
PRINT "DOT COLUMN CODE size = ", ~(dot_0000 - bank_start)
PRINT "DOT PLOT CODE size = ", ~(bank_end - dot_0000)
PRINT "BANK size =", ~(bank_end-bank_start)

\ ******************************************************************
\ *	Any other files for the disc
\ ******************************************************************
