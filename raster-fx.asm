\ ******************************************************************
\ *	RASTER FX FRAMEWORK
\ ******************************************************************

_DEBUG = FALSE

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

BLUE_BAR_SIZE = 20
BLUE_BAR_GAP = 20
BLUE_BAR_TOTAL = BLUE_BAR_SIZE + BLUE_BAR_GAP
BLUE_BAR_COLOUR = PAL_blue
BLUE_GAP_COLOUR = PAL_black

CYAN_BAR_SIZE = 32
CYAN_BAR_GAP = 32
CYAN_BAR_TOTAL = CYAN_BAR_SIZE + CYAN_BAR_GAP
CYAN_BAR_COLOUR = PAL_cyan
CYAN_GAP_COLOUR = PAL_black

MACRO WAIT_CYCLES n

PRINT "WAIT",n," CYCLES"

IF (n AND 1) = 0
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
STRIP_SIZE_BYTES = 4 * 640

patarty_exo = screen_addr - &900
text1_exo = patarty_exo - &400
text2_exo = &8000
text3_exo = &8000

;vgm_stream_buffers = &300
;vgm_buffer_start = vgm_stream_buffers
;vgm_buffer_end = vgm_buffer_start + &800

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

ORG $30
GUARD &9F

\\ System variables

.vsync_counter			SKIP 2		; counts up with each vsync
.escape_pressed			SKIP 1		; set when Escape key pressed
.delta_time				SKIP 1

.copy_down_active		SKIP 1
.copy_down_count		SKIP 1

\\ FX variables

.smiley_yoff			SKIP 1
.smiley_vadj			SKIP 1
.smiley_vel				SKIP 1

.num_strips				SKIP 1

.back_colour			SKIP 1

.blue_top				SKIP 1
.blue_start_col			SKIP 1		; start with this colour at top
.blue_flip_col			SKIP 1		; flip this colour
.blue_count				SKIP 1		; start with this counter at top
.blue_set_count			SKIP 1		; set to this counter on flip
.blue_flip_count		SKIP 1		; flip the counter on flip

.cyan_top				SKIP 1
.cyan_start_col			SKIP 1		; start with this colour at top
.cyan_flip_col			SKIP 1		; flip this colour
.cyan_count				SKIP 1		; start with this counter at top
.cyan_set_count			SKIP 1		; set to this counter on flip
.cyan_flip_count		SKIP 1		; flip the counter on flip

INCLUDE "lib/vgmplayer.h.asm"
INCLUDE "lib/script.h.asm"

\ ******************************************************************
\ *	SCRATCH SPACE
\ ******************************************************************

ORG &300
.vgm_buffer_start

; reserve space for the vgm decode buffers (8x256 = 2Kb)
ALIGN 256
.vgm_stream_buffers
    skip 256
    skip 256
    skip 256
    skip 256
    skip 256
    skip 256
    skip 256
    skip 256

.vgm_buffer_end

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
	LDA #2
	JSR oswrch

	\\ Turn off cursor

	LDA #10: STA &FE00
	LDA #32: STA &FE01

	\ Set SWRAM BANK
	LDA #4:STA &F4:STA &FE30

    \ Ask OSFILE to load our screen
	LDX #LO(bank4)
	LDY #HI(bank4)
	LDA #HI(text1_exo)
	JSR disksys_load_file

    \ Ask OSFILE to load our screen
	LDA #5:STA &F4:STA &FE30

	LDX #LO(bank5)
	LDY #HI(bank5)
	LDA #HI(&8000)
	JSR disksys_decrunch_file

    \ Ask OSFILE to load our screen
	LDA #6:STA &F4:STA &FE30

	LDX #LO(bank6)
	LDY #HI(bank6)
	LDA #HI(&8000)
	JSR disksys_decrunch_file

    \ Ask OSFILE to load our screen
	LDX #LO(screen)
	LDY #HI(screen)
	LDA #HI(patarty_exo)
	JSR disksys_load_file

    \ Ask OSFILE to load our screen
	LDX #LO(filename)
	LDY #HI(filename)
	LDA #HI(hazel_start)
	JSR disksys_load_file

    ; initialize the vgm player with a vgc data stream
    lda #hi(vgm_stream_buffers)
    ldx #lo(vgm_data)
    ldy #hi(vgm_data)
    sec
    jsr vgm_init

	\\ Initialise system modules here!

	LDA #1
	STA delta_time

	LDX #LO(sequence_script_start)
	LDY #HI(sequence_script_start)
	JSR script_init

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

	JSR vgm_update

	\\ Update the scripting system

	JSR script_update

	\\ Copy down in background

	JSR tick_copy_down

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

.cycles_wait_128		; JSR to get here takes 6c
{
	FOR n,1,58,1		; 58x
	NOP					; 2c
	NEXT				; = 116c
	RTS					; 6c
}						; = 128c

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
	\\ Write to MAIN
	LDA &FE34
	AND #&FF-4
	STA &FE34

	LDX #LO(patarty_exo)
	LDY #HI(patarty_exo)
	JSR decrunch

	\\ Write to SHADOW
	LDA &FE34
	ORA #4
	STA &FE34

	LDX #LO(text1_exo)
	LDY #HI(text1_exo)
	JSR decrunch

	JSR fx_show_potato

	LDA #0
	STA smiley_vadj
	STA smiley_vel

	LDA #31
	STA smiley_yoff

	LDA #0
	STA blue_top
	STA cyan_top

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
    \\ Bounce!

    SEC
    LDA smiley_vel
    SBC #1
    STA smiley_vel

    LDA smiley_vel
    BMI down
    \ Up
    CLC
    LDA smiley_yoff
    ADC smiley_vel
    BCC ok
    JMP bounce

    .down
    CLC
    LDA smiley_yoff
    ADC smiley_vel
    BCS ok

    \\ Bounce
    .bounce
	CLC
    LDA smiley_vel
    EOR #&FF
	ADC #1
;    SBC #3          ; deaden bounce
    STA smiley_vel

    LDA #0
    .ok
    STA smiley_yoff

    \\ Calculate vadj for vsync strip

    LDA smiley_yoff
    AND #&7
    STA smiley_vadj

    LDA #5:STA &FE00
    LDA #8
    SEC
    SBC smiley_vadj
    STA &FE01                       ; 8-vadj

	SEC
	LDA #32
	SBC smiley_yoff
	STA strip_scanlines + 0		; shorter

    LDA smiley_yoff
    LSR A:LSR A:LSR A:TAX		; number of char rows offset

	STX strip_scr_row + 0

	SEC
	LDA #3
	SBC strip_scr_row + 0
	STA strip_total_rows + 0

	CPX #0
	BEQ seven_strips

	\\ Otherwise 8 strips
	\\ Strip 0 = < 4 char rows
	\\ Strip 7 = 4-strip 0 rows + vadj

	LDA #8
	STA num_strips

	LDA smiley_vadj
	STA strip_vadj + 7

	LDA #0
	STA strip_vadj + 6

	LDA #32
	STA strip_scanlines + 6

	LDA smiley_yoff
	STA strip_scanlines + 7

	DEX
	STX strip_total_rows + 7

	LDA #3
	STA strip_total_rows + 6
	BNE set_strip0_addr

	\\ Seven strips
	.seven_strips
	LDA #7
	STA num_strips

	LDA smiley_vadj
	STA strip_vadj + 6
	LDA #0
	STA strip_vadj + 7			; not used
	STA strip_scanlines + 7		; not used
	STA strip_total_rows + 7	; not used

	CLC
	LDA #32
	ADC smiley_vadj
	STA strip_scanlines + 6		; longer

	LDA #3
	STA strip_total_rows + 6

	\\ Set address for strip 0

	.set_strip0_addr
    LDA #13:STA &FE00
	LDX strip_scr_row + 0
    LDA smiley_addr_LO, X
    STA &FE01

    LDA #12:STA &FE00
    LDA smiley_addr_HI, X
    STA &FE01


	\\ Do bar stuff

	LDA #&F0+PAL_black
	STA back_colour

	DEC blue_top

	LDX #(&F0+BLUE_GAP_COLOUR)

	LDA blue_top
	.blue_loop
	CMP #BLUE_BAR_TOTAL
	BCC blue_remainder
	SEC
	SBC #BLUE_BAR_TOTAL
	BNE blue_loop
	.blue_remainder

	CMP #BLUE_BAR_SIZE
	BCS blue_off

	STA blue_count
	SEC
	LDA #BLUE_BAR_SIZE
	SBC blue_count
	STA blue_count

	LDA #(BLUE_BAR_GAP)
	STA blue_set_count

	LDX #(&F0+BLUE_BAR_COLOUR)
	BNE blue_set_col

	.blue_off
	SBC #BLUE_BAR_SIZE

	STA blue_count
	SEC
	LDA #BLUE_BAR_GAP
	SBC blue_count
	STA blue_count

	LDA #(BLUE_BAR_SIZE)
	STA blue_set_count

	LDX #(&F0+BLUE_GAP_COLOUR)

	.blue_set_col
	STX blue_start_col

	LDA #(BLUE_BAR_SIZE EOR BLUE_BAR_GAP)
	STA blue_flip_count

	LDA #(&F0+BLUE_BAR_COLOUR) EOR (&F0+BLUE_GAP_COLOUR)
	STA blue_flip_col

	LDA blue_start_col
	EOR #&F0+PAL_black
	EOR back_colour
	STA back_colour


	INC cyan_top

	LDX #(&F0+PAL_black)

	LDA cyan_top
	.cyan_loop
	CMP #CYAN_BAR_TOTAL
	BCC cyan_remainder
	SEC
	SBC #CYAN_BAR_TOTAL
	BNE cyan_loop
	.cyan_remainder

	CMP #CYAN_BAR_SIZE
	BCS cyan_off

	STA cyan_count
	SEC
	LDA #CYAN_BAR_SIZE
	SBC cyan_count
	STA cyan_count

	LDA #(CYAN_BAR_GAP)
	STA cyan_set_count

	LDX #(&F0+CYAN_BAR_COLOUR)
	BNE cyan_set_col

	.cyan_off
	SBC #CYAN_BAR_SIZE

	STA cyan_count
	SEC
	LDA #CYAN_BAR_GAP
	SBC cyan_count
	STA cyan_count

	LDA #(CYAN_BAR_SIZE)
	STA cyan_set_count

	LDX #(&F0+PAL_black)

	.cyan_set_col
	STX cyan_start_col

	LDA #(CYAN_BAR_SIZE EOR CYAN_BAR_GAP)
	STA cyan_flip_count

	LDA #(&F0+CYAN_BAR_COLOUR) EOR (&F0+PAL_black)
	STA cyan_flip_col

	LDA cyan_start_col
	EOR #&F0+PAL_black
	EOR back_colour
	STA back_colour

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
    \\ Wait until scanlne 8
	LDX #7
    JSR cycles_wait_scanlines

	WAIT_CYCLES 80

    \\ First scanline of displayed cycle
    .here_display

    \\ Display screen
	LDA #8:STA &FE00
    LDA #0:STA &FE01

    \\ Configure display cycle

    LDA #6:STA &FE00
    LDA #5:STA &FE01   			; fixed visible rows

    LDA #7:STA &FE00
    LDA #&FF:STA &FE01          ; no vsync

	LDY #0						; strip

	.strip_loop

    LDA #4:STA &FE00
	LDA strip_total_rows, Y
    STA &FE01           		; total rows for strip

    LDA #5:STA &FE00
	LDA strip_vadj, Y
    STA &FE01   				; vadj for strip

    \\ Set address of strip+1

    LDA #13:STA &FE00
	LDX strip_scr_row + 1, Y
    LDA smiley_addr_LO, X:STA &FE01

    LDA #12:STA &FE00
    LDA smiley_addr_HI, X:STA &FE01

    \\ Now wait 28 rows plus a scanline to make sure we're in next CRTC cycle

	LDX strip_scanlines, Y

	.loop

	LDA back_colour		; 3c
	STA &FE21			; 4c

	DEC blue_count		; 5c
	\\ 19c inc JMP loop

	BNE still_blue
	; 2c

	\\ Blue bar toggle

	LDA back_colour		; 3c
	EOR blue_flip_col	; 3c
	STA back_colour		; 3c

	\\ Next count

	LDA blue_set_count	; 3c
	STA blue_count		; 3c

	\\ One after

	EOR blue_flip_count	; 3c
	STA blue_set_count	; 3c

	JMP done_blue		; 3c
	\\ 26c

	.still_blue		; 3c
	\\ This needs to count the same as the other fork
	WAIT_CYCLES 26-3

	.done_blue

	DEC cyan_count		; 5c
	\\ 5c inc JMP loop

	BNE still_cyan
	; 2c

	\\ Blue bar toggle

	LDA back_colour		; 3c
	EOR cyan_flip_col	; 3c
	STA back_colour		; 3c

	\\ Next count

	LDA cyan_set_count	; 3c
	STA cyan_count		; 3c

	\\ One after

	EOR cyan_flip_count	; 3c
	STA cyan_set_count	; 3c

	JMP done_cyan		; 3c
	\\ 26c

	.still_cyan		; 3c
	\\ This needs to count the same as the other fork
	WAIT_CYCLES 26-3

	.done_cyan

	\\ Wait rest of scanline 128 - part 1 - part 2
	WAIT_CYCLES 128 - 19 - 26 - 5 - 26 - 10

	DEX					; 2c
	BEQ loop_done		; 2c

	WAIT_CYCLES 10

	JMP loop			; 3c

	.loop_done

	\\ May need some padding here

	INY						; 2c
	CPY num_strips			; 3c
	BCS done_strip_loop		; 2c
	JMP strip_loop			; 3c

	.done_strip_loop

	LDA #&F0+PAL_red
	STA &FE21

	\\ Configure vsync cycle

    LDA #4: STA &FE00
    LDA #39 - 28 - 1 - 1: STA &FE01     ; 39 rows - 29 we've had

    LDA #7: STA &FE00
    LDA #35 - 29: STA &FE01         ; row 35 - 29 we've had

    LDA #6: STA &FE00
    LDA #3: STA &FE01               ; display 3 rows

	LDX #(3*8)
	JSR cycles_wait_scanlines

	LDA #&F0+PAL_magenta
	STA &FE21

    \\ Turn display off

	LDA #8:STA &FE00
	LDA #&30:STA &FE01

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

.fx_show_potato
{
	LDA &FE34
	AND #&FF-1
	STA &FE34
	RTS
}

.fx_show_text
{
	LDA &FE34
	ORA #1
	STA &FE34
	RTS
}

.fx_strips_default
{
	LDX #7
	.loop
	LDA strips_default_rows, X
	STA strip_scr_row, X
	DEX
	BPL loop
	RTS
}

.fx_strips_blank
{
	LDX #7
	LDA #0
	.loop
	STA strip_scr_row, X
	DEX
	BPL loop
	RTS
}

.fx_decompress_text2
{
	LDA #5:STA &F4:STA &FE30

	LDX #LO(text2_exo)
	LDY #HI(text2_exo)
	LDA #HI(screen_addr)
	JMP start_copy_down
}

.fx_decompress_text3
{
	LDA #6:STA &F4:STA &FE30

	LDX #LO(text2_exo)
	LDY #HI(text2_exo)
	LDA #HI(screen_addr)
	JMP start_copy_down
}

COPY_BYTES_PER_FRAME = 64

.start_copy_down
{
	STX copy_down_from + 1
	STY copy_down_from + 2

	LDA #HI(screen_addr + 64)
	STA copy_down_to + 2
	LDA #LO(screen_addr + 64)
	STA copy_down_to + 1

	LDA #(512/COPY_BYTES_PER_FRAME)
	STA copy_down_count

	LDA #&FF
	STA copy_down_active

	RTS
}

.tick_copy_down
\{
	LDA copy_down_active
	BEQ tick_copy_down_return

	LDX #0
	.tick_copy_down_loop
	.copy_down_from
	LDA &FFFF, X
	.copy_down_to
	STA &FFFF, X
	INX
	CPX #COPY_BYTES_PER_FRAME
	BCC tick_copy_down_loop

	CLC
	LDA copy_down_from+1
	ADC #COPY_BYTES_PER_FRAME
	STA copy_down_from+1
	BCC no_carry1
	INC copy_down_from+2
	.no_carry1

	CLC
	LDA copy_down_to+1
	ADC #COPY_BYTES_PER_FRAME
	STA copy_down_to+1
	BCC no_carry2
	INC copy_down_to+2
	.no_carry2

	DEC copy_down_count
	BNE tick_copy_down_return

	CLC
	LDA copy_down_to+1
	ADC #128
	STA copy_down_to+1 
	BCC no_carry3
	INC copy_down_to+2
	.no_carry3

	LDA #(512/COPY_BYTES_PER_FRAME)
	STA copy_down_count

	.tick_copy_down_return
	LDA copy_down_to+2
	BPL still_going

	LDA #0
	STA copy_down_active

	.still_going
	RTS
\}

.fx_end

INCLUDE "lib/vgmplayer.asm"
INCLUDE "lib/exo.asm"
INCLUDE "lib/disksys.asm"
INCLUDE "lib/script.asm"
INCLUDE "sequence.asm"

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

.filename EQUS "Hazel", 13
.bank4 EQUS "Text", 13
.bank5 EQUS "Text2", 13
.bank6 EQUS "Text3", 13
.screen EQUS "Screen", 13

\ ******************************************************************
\ *	FX DATA
\ ******************************************************************

; 7 strips of 4 character rows, optional 8th strip when 1st strip is < 4 char rows

.strip_vadj
EQUB 0,0,0,0,0,0,8,8		; vadj added to 7th or 8th

.strip_total_rows			; +1
EQUB 3,3,3,3,3,3,3,0		; must add up to 28 total

.strip_scanlines
EQUB 32,32,32,32,32,32,32,0	; must add up to 224

.strip_scr_row
EQUB 0,24,20,16,12,8,4,0,0	; which screen row to display in strip

.strips_default_rows
EQUB 0,4,8,12,16,20,24,28,0

ALIGN 64
.smiley_addr_LO
FOR n,0,31,1
EQUB LO((screen_addr + n * 640)/8)
NEXT

.smiley_addr_HI
FOR n,0,31,1
EQUB HI((screen_addr + n * 640)/8)
NEXT

ALIGN &100
.wib_table
FOR n, 0, 255, 1
EQUB 10 + 9 * SIN(2 * PI * n / 128)
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
\ *	SWRAM BANK
\ ******************************************************************


CLEAR &C300, &DF00
ORG &C300
GUARD &DF00

.hazel_start
.vgm_data
INCBIN "music/patarty-nohuff.vgc"
.hazel_end

SAVE "Hazel", hazel_start, hazel_end

PRINT "------"
PRINT "HAZEL"
PRINT "------"
PRINT "------"
PRINT "HIGH WATERMARK =", ~P%
PRINT "FREE =", ~&DF00-P%
PRINT "------"

\ ******************************************************************
\ *	Any other files for the disc
\ ******************************************************************

PUTBASIC "circle.bas", "Circle"
;PUTFILE "build/patarty.masked.bin", "Screen", &3000

PUTFILE "build/text.masked.bin", "T1", &3000
PUTFILE "build/text2.masked.bin", "T2", &3000
PUTFILE "build/text3.masked.bin", "T3", &3000

PUTFILE "build/text.exo", "Text", &8000
PUTFILE "build/text2.exo", "Text2", &8000
PUTFILE "build/text3.exo", "Text3", &8000
PUTFILE "build/patarty.exo", "Screen", &3000
