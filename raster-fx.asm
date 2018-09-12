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

\ ******************************************************************
\ *	GLOBAL constants
\ ******************************************************************

; Default screen address
screen_addr = &3000
SCREEN_SIZE_BYTES = &8000 - screen_addr

; Exact time for a 50Hz frame less latch load time
FramePeriod = 312*64-2

; Calculate here the timer value to interrupt at the desired line
TimerValue = 32*64 - 2*64 - 2 - 20

\\ 40 lines for vblank
\\ 32 lines for vsync (vertical position = 35 / 39)
\\ interupt arrives 2 lines after vsync pulse
\\ 2 us for latch
\\ XX us to fire the timer before the start of the scanline so first colour set on column -1
\\ YY us for code that executes after timer interupt fires

BILLB_NUM_ROWS = 16
BILLB_NUM_COLS = 80
BILLB_ROW_BYTES = 40 * 2 * 16	; 40 columns * 2 rows * 16 bytes per char = 1280b

STAR_ROW_ADDR = screen_addr - BILLB_ROW_BYTES		; row '-1'

\ ******************************************************************
\ *	ZERO PAGE
\ ******************************************************************

ORG &70
GUARD &9F

\\ System variables

.vsync_counter			SKIP 2		; counts up with each vsync
.escape_pressed			SKIP 1		; set when Escape key pressed

\\ FX variables

.readptr				SKIP 2
.writeptr				SKIP 2

.billb_offset			SKIP 1		; 0-39

.billb_left_off			SKIP 1		; = offset - 1
.billb_right_off		SKIP 1		; = offset + 40
.billb_mask				SKIP 1

.billb_message_ptr		SKIP 2
.billb_glyph			SKIP 1
.billb_glyph_col		SKIP 1
.billb_glyph_byte		SKIP 1

.billb_row_count		SKIP 1
.billb_top_row			SKIP 1
.billb_top_tmp			SKIP 1
.billb_top_idx			SKIP 1

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
	LDA #1
	JSR oswrch

	\\ Turn off cursor

	LDA #10: STA &FE00
	LDA #32: STA &FE01

	\\ Set Colour 2 to White - MODE 1 requires 4x writes to ULA Palette Register

	LDA #MODE1_COL2 + PAL_blue
	STA &FE21
	EOR #&10: STA &FE21
	EOR #&40: STA &FE21
	EOR #&10: STA &FE21

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
		LDX #245
		.loop
		JSR cycles_wait_128
		DEX
		BNE loop
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
		STA &FE4D             	; clear timer1 flag ; 4c +1/2c
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

.cycles_wait_128		; JSR to get here takes 6c
{
	FOR n,1,58,1		; 58x
	NOP					; 2c
	NEXT				; = 116c
	RTS					; 6c
}						; = 128c

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
	LDA #0
	STA billb_offset
	STA billb_top_row
	STA billb_top_idx

	LDA #7
	STA billb_glyph_col

	LDA #LO(message_text)
	STA billb_message_ptr
	LDA #HI(message_text)
	STA billb_message_ptr+1

	LDY #0
	.loop
 	JSR star_plot
	INY
	CPY #8
	BCC loop

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

.fx_update_function
{
	LDY billb_glyph_col
	INY
	CPY #8
	BCC col_ok

	\\ Next char
	LDY #0
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

	SEC
	SBC #32
	STA billb_glyph

	.col_ok
	STY billb_glyph_col

	\\ Get byte for column of glyph - don't need to calc this every time

	LDA #0
	STA readptr+1

	LDA billb_glyph
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

	LDA (readptr), Y
	STA billb_glyph_byte

	\\ Scroll row left...

	LDX billb_offset
	STX billb_left_off

	INX
	CPX #BILLB_NUM_COLS/2
	BCC offset_ok
	LDX #0
	.offset_ok
	STX billb_offset

	\\ Calc right offset

	TXA
	CLC
	ADC #BILLB_NUM_COLS/2
	STA billb_right_off

	\\ Update top row

	LDX billb_top_idx
	INX
	STX billb_top_idx
	LDA billb_top_table, X
	TAX
	STX billb_top_row

	\\ Set CRTC address for row 0

	STX billb_top_tmp
	JSR billb_set_crtc_addr

	\\ Which bit?

	LDA #1
	STA billb_mask

	\\ Draw row 0

	LDX #0
	LDY billb_right_off			; 3c
	JSR billb_set_writeptr

	LDA billb_glyph_byte
	AND billb_mask
	JSR billb_plot_led

	LDY billb_left_off			; 3c
	JSR billb_set_writeptr

	LDA billb_glyph_byte
	AND billb_mask
	JSR billb_plot_led

	\\ Draw stars - could / should move this to draw fn
	\\ (Would need to be exact timing for each loop)

	LDY #0
	.loop
	JSR star_plot				; 79c

	CLC							; 2c
	LDA stars_XL,Y				; 4c
	ADC stars_S,Y				; 4c
	STA stars_XL,Y				; 5c
	LDA stars_XH,Y				; 4c
	ADC #0						; 2c
	STA stars_XH,Y				; 5c
	CMP #HI(640)				; 2c
	BCC x_ok1					
	; 2c
	LDA stars_XL,Y				; 4c
	CMP #LO(640)				; 2c
	BCC x_ok2
	; 2c
	SBC #LO(640)				; 2c
	STA stars_XL,Y				; 5c
	LDA stars_XH,Y				; 4c
	SBC #HI(640)				; 2c
	STA stars_XH,Y				; 5c
	BCC x_go					; 3c
	\\ 
	.x_ok1						; 3c
	NOP:NOP:BIT 0				\\ Total 10

	.x_ok2						; 3c
	NOP:NOP:NOP:NOP:NOP			\\ NOT CHECKED FOR EXACT TIMING
	NOP:NOP:NOP:NOP:NOP
	\\ Total 23c

	.x_go
	JSR star_plot				; 79c
	INY							; 2c
	CPY #8						; 2c
	BNE loop					; 3c

	RTS
}

.billb_set_crtc_addr		; row X
{
	LDA #13:STA &FE00			; 6c screen HI

	CLC							; 2c
	LDA billb_offset			; 3c
	ASL A						; 2c
	ADC billb_crtc_base_LO, X	; 4c
	STA &FE01					; 4c

	LDA #12:STA &FE00			; 6c screen HI

	LDA billb_crtc_base_HI, X	; 4c
	ADC #0						; 2c
	STA &FE01					; 4c
	RTS							; 12c
}	; 49c

.billb_set_writeptr			; row X
{
	CLC							; 2c
	LDA mult16_LO, Y			; 4c
	ADC billb_scr_base_LO, X	; 4c
	STA writeptr				; 3c

	LDA mult16_HI, Y			; 4c
	ADC billb_scr_base_HI, X	; 4c
	STA writeptr+1				; 3c
	RTS							; 12c
}	; 39c

.billb_plot_led					; 6c
{
	\\ Needs to be fixed cost (ideally)
	CMP #0						; 2c
	BEQ is_zero
	; 2c
	LDA #LO(billb_onsprite)		; 2c
	BEQ continue				; 3c

	.is_zero					; 3c
	LDA #LO(billb_offsprite)	; 2c
	NOP

	.continue
	STA loop+1					; 4c

	LDY #15						; 2c
	.loop
	LDA billb_offsprite, Y		; 4c
	STA (writeptr), Y			; 6c
	DEY							; 2c
	BPL loop					; 15*3c + 2c

	RTS							; 6c
}
\\ 74c

.star_plot		; Y=star no / y pos
{								; 6c
	LDA stars_XH, Y				; 4c
	STA writeptr+1				; 3c

	LDA stars_XL, Y				; 4c
	AND #&FC					; 2c
	STA writeptr				; 3c

	ASL writeptr				; 5c
	ROL writeptr+1				; 5c

	CLC							; 2c
	LDA writeptr				; 3c
	ADC #LO(STAR_ROW_ADDR)		; 2c
	STA writeptr				; 3c
	LDA writeptr+1				; 3c
	ADC #HI(STAR_ROW_ADDR)		; 2c
	STA writeptr+1				; 3c

	LDA stars_XL, Y				; 4c
	AND #&3						; 2c
	TAX							; 2c

	LDA pixels, X				; 4c
	EOR (writeptr), Y			; 5c
	STA (writeptr), Y			; 6c
	RTS							; 6c
}	\\ 79c

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

	\\ CRTC setup for rupture

	LDA #4:STA &FE00			; vertical total
	LDA #0:STA &FE01			; R4 = 1 - 1 = 0

	LDA #6:STA &FE00			; vertical displayed
	LDA #1:STA &FE01			; R6 = 1

	LDA #7:STA &FE00			; vsync
	LDA #&FF:STA &FE01			; R7 = &FF (no vsync)

	\\ 6x 6c = 36c

	\\ Set address row 1

	LDX billb_top_tmp
	INX
	TXA
	AND #BILLB_NUM_ROWS-1
	TAX
	STX billb_top_tmp
	JSR billb_set_crtc_addr		; 49c

	\\ 38c

	\\ Draw row 1

	LDX #1

	ROL billb_mask	; next row

	LDY billb_right_off			; 3c
	JSR billb_set_writeptr		; 39c

	LDA billb_glyph_byte				; 3c
	AND billb_mask
	JSR billb_plot_led			; 74c

	LDY billb_left_off			; 3c
	JSR billb_set_writeptr

	LDA billb_glyph_byte
	AND billb_mask
	JSR billb_plot_led

	\\ Draw row 1

	JSR cycles_wait_128
	JSR cycles_wait_128
	JSR cycles_wait_128

	\\ REMOVE 45 NOPS

	\\ Loop row rows 2-15

	LDA #2
	STA billb_row_count

	.raster_loop

	LDX billb_top_tmp
	INX
	TXA
	AND #BILLB_NUM_ROWS-1
	TAX
	STX billb_top_tmp

	\\ Raster is displaying row N = X-1

	\\ Set address row N+1 = X

	JSR billb_set_crtc_addr

	\\ 36c

	ROL billb_mask	; next row

	\\ Draw row N

	LDX billb_row_count

	LDY billb_right_off			; 3c
	JSR billb_set_writeptr		; 39c

	LDA billb_glyph_byte				; 3c
	AND billb_mask
	JSR billb_plot_led			; 65c

	LDY billb_left_off			; 3c
	JSR billb_set_writeptr

	LDA billb_glyph_byte				; 3c
	AND billb_mask
	JSR billb_plot_led			; 65c

	\\ 103c

	FOR n,1,27,1
	NOP
	NEXT
	BIT 0

	JSR cycles_wait_128
	JSR cycles_wait_128

	INX
	STX billb_row_count
	CPX #BILLB_NUM_ROWS
	BNE raster_loop			; 3c

	LDX #15

	.star_loop

	\\ Displaying row 15 (counting from 0)

	LDA #13:STA &FE00			; screen LO

	LDA stars_crtc_base_LO, X
	STA &FE01

	LDA #12:STA &FE00			; screen HI
	LDA stars_crtc_base_HI, X
	STA &FE01

	JSR cycles_wait_128
	JSR cycles_wait_128
	JSR cycles_wait_128
	JSR cycles_wait_128
	JSR cycles_wait_128
	JSR cycles_wait_128
	JSR cycles_wait_128
	JSR cycles_wait_128

	DEX
	BPL star_loop

	\\ Very start of row 31, i.e. displayed 31 so far
	\\ Need 39 total so 8 left to go

	\\ Reset for vsync

	LDA #4:STA &FE00			; vertical total
	LDA #7:STA &FE01			; R4 = 7 - 1 = 6

	LDA #6:STA &FE00			; vertical displayed
	LDA #1:STA &FE01			; R6 = 1

	LDA #7:STA &FE00			; vsync
	LDA #4:STA &FE01			; R7 = &FF (no vsync)

	\\ Cross fingers

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

\ ******************************************************************
\ *	FX DATA
\ ******************************************************************

ALIGN &100				; ensure new page boundary
.billb_onsprite
{
	EQUB &03, &37, &6F, &4F, &0F, &07, &03, &00			; &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
	EQUB &08, &0C, &0E, &0E, &0E, &0C, &08, &00			; &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF	
}

.billb_offsprite
{
	EQUB &20, &50, &A0, &50, &A0, &50, &20, &00			; &05, &0A, &05, &0A, &05, &0A, &05, &0A
	EQUB &80, &40, &A0, &40, &A0, &40, &80, &00			; &05, &0A, &05, &0A, &05, &0A, &05, &0A
}

.billb_crtc_base_LO
{
	FOR n,0,BILLB_NUM_ROWS-1,1
	EQUB LO((screen_addr + n * BILLB_ROW_BYTES)/8)
	NEXT
}

.billb_crtc_base_HI
{
	FOR n,0,BILLB_NUM_ROWS-1,1
	EQUB HI((screen_addr + n * BILLB_ROW_BYTES)/8)
	NEXT
}

.billb_scr_base_LO
{
	FOR n,0,BILLB_NUM_ROWS-1,1
	EQUB LO(screen_addr + n * BILLB_ROW_BYTES)
	NEXT
}

.billb_scr_base_HI
{
	FOR n,0,BILLB_NUM_ROWS-1,1
	EQUB HI(screen_addr + n * BILLB_ROW_BYTES)
	NEXT
}

.stars_crtc_base_LO
{
	FOR n,0,BILLB_NUM_ROWS-1,1
;	EQUB LO((STAR_ROW_ADDR + n * (BILLB_ROW_BYTES/2) / BILLB_NUM_ROWS)/8)
;	EQUB LO((STAR_ROW_ADDR)/8)
	EQUB LO((STAR_ROW_ADDR + RND(BILLB_ROW_BYTES/2))/8)
	NEXT
}

.stars_crtc_base_HI
{
	FOR n,0,BILLB_NUM_ROWS-1,1
;	EQUB HI((STAR_ROW_ADDR + n * (BILLB_ROW_BYTES/2) / BILLB_NUM_ROWS)/8)
;	EQUB HI((STAR_ROW_ADDR)/8)
	EQUB HI((STAR_ROW_ADDR + RND(BILLB_ROW_BYTES/2))/8)
	NEXT
}

.pixels
EQUB &88,&44,&22,&11

ALIGN &100
.mult16_LO
FOR n,0,79,1
EQUB LO(n * 16)
NEXT

.mult16_HI
FOR n,0,79,1
EQUB HI(n * 16)
NEXT

.stars_XL
FOR n,0,7,1
;EQUB LO(160*n + n)
EQUB LO((640 * n / 8) + RND(640/8))
NEXT

.stars_XH
FOR n,0,7,1
;EQUB HI(160*n + n)
EQUB HI(640 * n / 7)
NEXT

.stars_S
FOR n,0,7,1
EQUB n+1;
;EQUB RND(8)+1
NEXT

.message_text
EQUS "HELLO WORLD!     ",0

ALIGN &100
.billb_top_table
FOR n,0,255,1
EQUB (12 + 4.5 * SIN(8 * PI * n / 256)) AND 15
NEXT

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
