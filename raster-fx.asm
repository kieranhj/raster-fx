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
TimerValue = 32*64 - 2*64 - 2 - 22

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

.fx_colour_index		SKIP 1		; index into our colour palette
.fx_raster_count		SKIP 1		; count our raster lines in draw function
.fx_char_row_count		SKIP 1		; count our character rows in draw function

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
	\\ Reset stack

	LDX #&FF					; X=11111111
	TXS							; reset stack

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

	\\ Initialise and system modules here!

	\ ******************************************************************
	\ *	DEMO START - from here on out there is no OS to help you!!
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

		\\ Wait for Timer1 at scanline 0

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

	\\ TODO: check for Escape key here!

	\\ FX update callback here!

	.call_update
	JSR fx_update_function

	\\ Wait for first scanline

	{
		LDA #&40
		.waitTimer1
		BIT &FE4D				; 4c + 1/2c
		BEQ waitTimer1         	; poll timer1 flag
		STA &FE4D             		; clear timer1 flag ; 4c +1/2c
	}

	\\ Check if our FX has changed?

	LDA escape_pressed
	BEQ call_draw

	\\ FX has changed so get current module to return CRTC to known state

	.call_kill
	JSR fx_kill_function

	\\ Then exit

	JMP exit

	\\ FX draw callback here!

	.call_draw
	JSR fx_draw_function

	\\ Loop as fast as possible

	.done_first_frame
	JMP main_loop

	\\ Maybe one day we'l escape the loop...

	.exit

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
\ The CRTC registers & ULA will be set to default MODE 2 values
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
	INC fx_colour_index

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
\ the default MODE 2 values as per initialisation.
\
\ If messing with CRTC registers, THIS FUNCTION MUST ALWAYS PRODUCE
\ A FULL AND VALID 312 line PAL signal before exiting!
\ ******************************************************************

.fx_draw_function
{
	\\ Set up vertical rupture

	\\ R4=0 - CRTC cycle is one row
	LDA #4: STA &FE00
	LDA #0: STA &FE01

	\\ R7=&FF - no vsync
	LDA #7:	STA &FE00
	LDA #&FF: STA &FE01

	\\ R6=0 - one row displayed
	LDA #6: STA &FE00
	LDA #1: STA &FE01		; 8 * 6c = 48c

	LDA #12: STA &FE00
	LDA #HI((screen_addr + &1400) / 8): STA &FE01

	LDA #13: STA &FE00
	LDA #LO((screen_addr + &1400) / 8): STA &FE01

	; shift timing so palette change happens during hblank as much as possible

	FOR n,1,14,1
	NOP
	NEXT

	LDX #0					; 2c
	LDY fx_colour_index		; 3c

	LDA #254
	STA fx_raster_count

	.raster_loop

	\\ Set colour 1 - requires 4x write to ULA Palette Register

	LDA fx_colour1_table, Y	; 4c
	STA &FE21				; 4c
	EOR #&10				; 2c
	STA &FE21				; 4c
	EOR #&40				; 2c
	STA &FE21				; 4c
	EOR #&10				; 2c
	STA &FE21				; 4c
	\\ Total = 26c

	\\ Set colour 2 - requires 4x write to ULA Palette Register

	LDA fx_colour2_table, Y	; 4c
	STA &FE21				; 4c
	EOR #&10				; 2c
	STA &FE21				; 4c
	EOR #&40				; 2c
	STA &FE21				; 4c
	EOR #&10				; 2c
	STA &FE21				; 4c
	\\ Total = 26c

	FOR n,1,32,1
	NOP
	NEXT
	\\ Wait 64c					

	INY						; 2c
	INX						; 2c

	DEC fx_raster_count		; 5c
	BNE raster_loop			; 3c
	\\ Loop total = 26 + 26 + 64 + 12 = 128c

	\\ Must setup final display cycle with vsync in correct place

	\\ Vertical Total R7 = ((312 - 248) / 8) - 1 = (64 / 8) - 1 = 8 - 1 = 7
	LDA #4: STA &FE00
	LDA #7: STA &FE01		

	\\ Vertical Sync Position R4 = (280 - 248) / 8 = 4 character rows
	LDA #7:	STA &FE00
	LDA #4: STA &FE01

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
\ the default MODE 2 values as per initialisation.
\
\ THIS FUNCTION MUST ALWAYS ENSURE A FULL AND VALID 312 line PAL
\ signal will take place this frame! The easiest way to do this is
\ to simply call crtc_reset.
\
\ ******************************************************************

.fx_kill_function
{
	LDX #13
	.loop
	STX &FE00
	LDA crtc_regs_default,X
	STA &FE01
	DEX
	BPL loop
	RTS

	RTS
}

.fx_end

\ ******************************************************************
\ *	DATA
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

ALIGN &100
.fx_colour1_table
{
	FOR n,1,43,1
	EQUB MODE1_COL1 + PAL_red
	NEXT
	FOR n,1,42,1
	EQUB MODE1_COL1 + PAL_magenta
	NEXT
	FOR n,1,43,1
	EQUB MODE1_COL1 + PAL_blue
	NEXT
	FOR n,1,43,1
	EQUB MODE1_COL1 + PAL_cyan
	NEXT
	FOR n,1,43,1
	EQUB MODE1_COL1 + PAL_green
	NEXT
	FOR n,1,42,1
	EQUB MODE1_COL1 + PAL_yellow
	NEXT
}

ALIGN &100
.fx_colour2_table
{
	FOR n,1,21,1
	EQUB MODE1_COL2 + PAL_red
	NEXT
	FOR n,1,42,1
	EQUB MODE1_COL2 + PAL_magenta
	NEXT
	FOR n,1,43,1
	EQUB MODE1_COL2 + PAL_blue
	NEXT
	FOR n,1,43,1
	EQUB MODE1_COL2 + PAL_cyan
	NEXT
	FOR n,1,43,1
	EQUB MODE1_COL2 + PAL_green
	NEXT
	FOR n,1,42,1
	EQUB MODE1_COL2 + PAL_yellow
	NEXT
	FOR n,1,22,1
	EQUB MODE1_COL2 + PAL_red
	NEXT
}

ALIGN &100
.fx_character_offset
{
	FOR n,0,255,1
	EQUB 10  + 10 * SIN(2 * PI * n / 256)
	NEXT
}

ALIGN &100
.fx_row_address_LO
{
	FOR n,0,31,1
	addr = screen_addr + n * 640
	EQUB LO(addr / 8)
	NEXT
}

.fx_row_address_HI
{
	FOR n,0,31,1
	addr = screen_addr + n * 640
	EQUB HI(addr / 8)
	NEXT
}

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
