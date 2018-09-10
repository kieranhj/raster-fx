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

.fx_ypos				SKIP 2
.fx_raster_count		SKIP 1
.fx_xpos				SKIP 1
.fx_tmp					SKIP 1

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

	LDA #MODE1_COL2 + PAL_yellow
	STA &FE21
	EOR #&10: STA &FE21
	EOR #&40: STA &FE21
	EOR #&10: STA &FE21

	lda #$08
	sta &FE20
	lda #$18
	sta &FE20

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
;	LDX #LO(osfile_params)
;	LDY #HI(osfile_params)
;	LDA #&FF
;   JSR osfile

	LDA #0
	STA fx_ypos

	LDA #88
	STA fx_xpos

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
\\ Set ypos for plot

	LDX fx_ypos
;	DEX
;	DEX
;	BNE ok2
;	LDX #128
	.ok2
	STX fx_ypos

\\ Set xpos for plot

	LDX fx_xpos
;	INX
;	CPX #88
;	BCC ok
;	LDX #0
	.ok
	STX fx_xpos

	STX left_addr+1
	STX left_addr+4
	STX right_addr+1
	STX right_addr+4
	STX middle_addr1+1
	STX middle_addr1+4
	STX middle_addr2+1
	STX middle_addr2+4
	STX middle_addr3+1
	STX middle_addr3+4

\\ Clear line buffer

	LDX #0
	LDA #0
	.loop
	STA &7C58,X
	INX
	CPX #80
	BCC loop

\\ Top clip

	LDY fx_ypos
	DEY

	\\ Left edge
	LDX offset_right, Y		; 4c
	STX fx_tmp

	LDA pixels_left, Y		; 4c
	BEQ do_right
	ORA #1		; merge right pixel

	LDX offset_left, Y		; 4c
	.middle_addr1
	EOR &7C00, X			; 4c
	STA &7C00, X			; 5c

	CPX fx_tmp
	BEQ done_clip

	.clip_loop
	INX
	CPX fx_tmp
	BEQ do_right

	LDA #3
	.middle_addr2
	EOR &7C00, X			; 4c
	STA &7C00, X			; 5c
	JMP clip_loop

	\\ Right edge

	.do_right
	LDA pixels_right, Y		; 4c
	BEQ done_clip
	ORA #2			; merge left pixel

	.middle_addr3
	EOR &7C00, X			; 4c
	STA &7C00, X			; 5c
	.done_clip

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
\{
	\\ We're only ever going to display this one scanline
	LDA #12: STA &FE00
	LDA #HI(&2858): STA &FE01		; &7C00 + 88 bytes

	LDA #13: STA &FE00
	LDA #LO(&2858): STA &FE01		; &7C00 + 88 bytes

	\\ R9=0 - character row = 1 scanline
	LDA #9: STA &FE00
	LDA #0:	STA &FE01

	\\ R4=0 - CRTC cycle is one row
	LDA #4: STA &FE00
	LDA #0: STA &FE01

	\\ R7=&FF - no vsync
	LDA #7:	STA &FE00
	LDA #&FF: STA &FE01

	\\ R6=1 - one row displayed
	LDA #6: STA &FE00
	LDA #1: STA &FE01

	\\ Wait a bit

	FOR n,1,14,1
	NOP
	NEXT

	LDA #254				; 2c
	STA fx_raster_count

	LDY fx_ypos
	
	.raster_loop

	.left_clip
	LDA pixels_left, Y		; 4c
	LDX offset_left, Y		; 4c
	.left_addr
	EOR &7C00, X			; 4c
	STA &7C00, X			; 5c
	; 17c per byte

	.right_clip
	LDA pixels_right, Y		; 4c
	LDX offset_right, Y		; 4c
	.right_addr
	EOR &7C00, X			; 4c
	STA &7C00, X			; 5c

	INY						; 2c

	FOR n,1,40,1
	NOP
	NEXT
	BIT 0

	\\ Loop 254 times

	DEC fx_raster_count		; 5c
	BNE raster_loop			; 3c
	\\ Loop total = 26 + 26 + 69 + 7 = 128c

	\\ R9=7 - character row = 8 scanlines
	LDA #9: STA &FE00
	LDA #1-1:	STA &FE01		; 1 scanline

	\\ R4=6 - CRTC cycle is 32 + 7 more rows = 312 scanlines
	LDA #4: STA &FE00
	LDA #56-1+1: STA &FE01		; 312 - 256 = 56 scanlines

	\\ R7=3 - vsync is at row 35 = 280 scanlines
	LDA #7:	STA &FE00
	LDA #24+1: STA &FE01			; 280 - 256 = 24 scanlines

	\\ R6=1 - got to display just one row
	LDA #6: STA &FE00
	LDA #1: STA &FE01

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
.pixels_left
FOR n,0,63,2
EQUB &C,&30			; right red, left red
NEXT
FOR n,0,63,2
EQUB &30,&C			; left red, right red
NEXT

FOR n,0,127,1
EQUB 0
NEXT

.pixels_right
FOR n,0,63,2
EQUB &30,&C			; right red, left red
NEXT
FOR n,0,63,2
EQUB &C,&30			; left red, right red
NEXT

FOR n,0,127,1
EQUB 0
NEXT

ALIGN &100
.offset_left
EQUB 32
FOR n,31,0,-1
EQUB n,n
NEXT
FOR n,1,31
EQUB n,n
NEXT
EQUB 32

FOR n,0,127,1
EQUB 0
NEXT

.offset_right
EQUB 32
FOR n,1,31,1
EQUB 32+n,32+n
NEXT
FOR n,32,1,-1
EQUB 32+n,32+n
NEXT
EQUB 32

FOR n,0,127,1
EQUB 0
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
