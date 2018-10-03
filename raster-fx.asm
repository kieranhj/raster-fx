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

\ ******************************************************************
\ *	ZERO PAGE
\ ******************************************************************

ORG &70
GUARD &9F

\\ System variables

.vsync_counter			SKIP 2		; counts up with each vsync
.escape_pressed			SKIP 1		; set when Escape key pressed

\\ FX variables

.tri_char_x				SKIP 1
.tri_offset_x			SKIP 1
.tri_colour_index		SKIP 1
.tri_quarters			SKIP 1

.tri_rnd_colour			SKIP 1
.tri_rnd_index			SKIP 1

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

	\\ Turn off cursor

	LDA #10: STA &FE00
	LDA #32: STA &FE01

	\\ Set Colour 2 to White - MODE 1 requires 4x writes to ULA Palette Register

	LDA #MODE1_COL2 + PAL_white
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
    \ Ask OSFILE to load our screen
	LDX #LO(osfile_params)
	LDY #HI(osfile_params)
	LDA #&FF
    JSR osfile

	LDA #0
	STA tri_char_x
	STA tri_offset_x
	STA tri_colour_index
	STA tri_rnd_index

	LDA #PAL_black
	STA tri_rnd_colour

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
	\\ Do some amazing pattern on the tiles

	LDX tri_rnd_index
	LDA random, X
	AND #127
	TAY

;	LDA fb_cols, Y
;	CLC
;	ADC #1
;	AND #7
	LDA tri_rnd_colour
	STA fb_cols, Y

	TYA
	EOR #10
	TAY

;	LDA fb_cols, Y
;	CLC
;	ADC #1
;	AND #7
	
	LDA tri_rnd_colour
;	EOR #7
	STA fb_cols, Y

	INX
	CPX #128
	BCC rnd_ok
	LDX #0

	LDA tri_rnd_colour
	SEC
	SBC #1
	AND #7
	STA tri_rnd_colour

	.rnd_ok
	STX tri_rnd_index

	\\ Scroll tiles

	LDY tri_offset_x

	\\ Increment byte offset (two pixels in X)

	LDX tri_char_x
	INX
	CPX #20
	BCC x_ok
	LDX #0

	\\ Increment repeat offset

	INY
	INY	; triangles means two tiles per repeat

	CPY #10;14
	BCC x_ok

	LDY #0

	.x_ok
	STX tri_char_x

	\\ Set colours for top line

	LDA fb_cols + 0, Y: ORA #&10: STA &FE21
	LDA fb_cols + 1, Y: ORA #&20: STA &FE21
	LDA fb_cols + 2, Y: ORA #&30: STA &FE21
	LDA fb_cols + 3, Y: ORA #&40: STA &FE21
	LDA fb_cols + 4, Y: ORA #&50: STA &FE21
	LDA fb_cols + 5, Y: ORA #&60: STA &FE21
	LDA fb_cols + 6, Y: ORA #&70: STA &FE21
	LDA fb_cols + 7, Y: ORA #&80: STA &FE21
	LDA fb_cols + 8, Y: ORA #&90: STA &FE21
	LDA fb_cols + 9, Y: ORA #&a0: STA &FE21
	LDA fb_cols + 10, Y: ORA #&b0: STA &FE21
	LDA fb_cols + 11, Y: ORA #&c0: STA &FE21

	STY tri_offset_x
	STY tri_colour_index

	\\ Set screen address for tile

	.no_anim
	LDA #13:STA &FE00
	LDA screen_row_addr_LO + 0
	CLC
	ADC tri_char_x
	STA &FE01

	LDA #12:STA &FE00
	LDA screen_row_addr_HI + 0
	ADC #0
	STA &FE01

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
	\\ Rupture

	LDA #4: STA &FE00
	LDA #0: STA &FE01			; R4=vertical total = 1-1 = 0

	LDA #6: STA &FE00
	LDA #1: STA &FE01			; R6=vertical displayed = 8

	LDA #7: STA &FE00
	LDA #&FF: STA &FE01			; R7=vsync = &FF (never)

	\\ Shift timing so palette change happens during hblank as much as possible

	FOR n,1,7,1
	NOP
	NEXT

	LDA #4
	STA tri_quarters

	LDX #0

	.raster_loop

;	JSR cycles_wait_63_scanlines

	INX
	TXA
	AND #15
	TAX
	.row_loop

	\\ Set screen address for next row / cycle

	LDA #13:STA &FE00			; 6c
	LDA screen_row_addr_LO, X	; 4c
	CLC							; 2c
	ADC tri_char_x				; 3c
	STA &FE01					; 4c

	LDA #12:STA &FE00			; 6c
	LDA screen_row_addr_HI, X	; 4c
	ADC #0						; 2c
	STA &FE01					; 4c

	; wait 7 scanlines
	JSR cycles_wait_128
	JSR cycles_wait_128
	JSR cycles_wait_128
	JSR cycles_wait_128
	JSR cycles_wait_128
	JSR cycles_wait_128
	JSR cycles_wait_128

	FOR n,1,39,1
	NOP
	NEXT

	INX							; 2c

	TXA
	AND #7
;	CPX #8						; 2c
	BNE row_loop				; 3c

	DEC tri_quarters
	BNE continue
	JMP raster_loop_done

	.continue

	\\ Set screen address for next row / cycle

	LDA #13:STA &FE00			; 6c
	LDA screen_row_addr_LO,X	; 4c
	CLC							; 2c
	ADC tri_char_x				; 3c
	STA &FE01					; 4c

	LDA #12:STA &FE00			; 6c
	LDA screen_row_addr_HI,X	; 4c
	ADC #0						; 2c
	STA &FE01					; 4c

	FOR n,1,17,1
	NOP
	NEXT

	JSR cycles_wait_128
	JSR cycles_wait_128
	JSR cycles_wait_128
	JSR cycles_wait_128
	JSR cycles_wait_128
	JSR cycles_wait_128

	; = 63 scanline

	; Change 10 colours
	; Starting colour # is the X offset DIV 10
	; So 1 - 3 through to 10 - 12
	; But still mappin

	LDY tri_quarters
	LDA tri_colour_index
	ADC quarter_offsets, Y
	CLC
	STA tri_colour_index
	TAY

	LDA fb_cols + 0, Y: ORA #&10: STA &FE21
	LDA fb_cols + 1, Y: ORA #&20: STA &FE21
	LDA fb_cols + 2, Y: ORA #&30: STA &FE21
	LDA fb_cols + 3, Y: ORA #&40: STA &FE21
	LDA fb_cols + 4, Y: ORA #&50: STA &FE21
	LDA fb_cols + 5, Y: ORA #&60: STA &FE21
	LDA fb_cols + 6, Y: ORA #&70: STA &FE21
	LDA fb_cols + 7, Y: ORA #&80: STA &FE21
	LDA fb_cols + 8, Y: ORA #&90: STA &FE21
	LDA fb_cols + 9, Y: ORA #&a0: STA &FE21
	LDA fb_cols + 10, Y: ORA #&b0: STA &FE21
	LDA fb_cols + 11, Y: ORA #&c0: STA &FE21

	\\ Wait to EOL
	FOR n,1,4,1
	NOP
	NEXT
	BIT 0

	INY
	JMP raster_loop
	.raster_loop_done

	\\ Complete frame

	LDA #4: STA &FE00
	LDA #7: STA &FE01			; R4=vertical total = 39-31 = 8-1 = 7

	; R6=vertical displayed = 1

	LDA #7: STA &FE00
	LDA #4: STA &FE01			; R7=vsync = 35-31 = 4


;	JSR cycles_wait_63_scanlines

	; Make sure we're off screen before doing any more processing

	JSR cycles_wait_128
	JSR cycles_wait_128
	JSR cycles_wait_128
	JSR cycles_wait_128
	JSR cycles_wait_128
	JSR cycles_wait_128
	JSR cycles_wait_128
	JSR cycles_wait_128

    RTS
}

.cycles_wait_63_scanlines
{
	FOR n,1,63,1
	JSR cycles_wait_128
	NEXT
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

.osfile_filename
EQUS "Tris", 13

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
.fb_cols
IF 0
FOR i,0,31,1
EQUB ((i MOD 7)+1) EOR 7
NEXT
FOR i,0,31,1
EQUB ((i MOD 7)+1) EOR 7
NEXT
FOR i,0,31,1
EQUB ((i MOD 7)+1) EOR 7
NEXT
FOR i,0,31,1
EQUB ((i MOD 7)+1) EOR 7
NEXT
ENDIF

FOR i,0,31,1
IF i % 2=0
c=PAL_red
ELSE
c=PAL_yellow
ENDIF
EQUB c
NEXT


FOR i,0,31,1
IF i % 2=0
c=PAL_blue
ELSE
c=PAL_green
ENDIF
EQUB c
NEXT

FOR i,0,31,1
IF i % 2=0
c=PAL_magenta
ELSE
c=PAL_cyan
ENDIF
EQUB c
NEXT

FOR i,0,31,1
IF i % 2=0
c=PAL_black
ELSE
c=PAL_white
ENDIF
EQUB c
NEXT

.screen_row_addr_LO
FOR n,0,16,1
m = n % 8
EQUB LO((screen_addr + m*8*110)/8 + ((n DIV 8)%2)*10)
NEXT

.screen_row_addr_HI
FOR n,0,16,1
m = n % 8
EQUB HI((screen_addr + m*8*110)/8 + ((n DIV 8)%2)*10)
NEXT

.quarter_offsets
EQUB 0,31,33,31

ALIGN &100
.random
FOR i,0,127,1
EQUB RND(128)
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

PUTFILE "triangles.bas", "mtri", &e00, &e00
PUTFILE "tris3.bin", "Tris", &3000
