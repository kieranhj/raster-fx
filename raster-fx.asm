\ ******************************************************************
\ *	RASTER FX FRAMEWORK
\ ******************************************************************

CPU 1

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

PIXEL_LEFT_0 = &00
PIXEL_LEFT_1 = &02
PIXEL_LEFT_2 = &08
PIXEL_LEFT_3 = &0A
PIXEL_LEFT_4 = &20
PIXEL_LEFT_5 = &22
PIXEL_LEFT_6 = &28
PIXEL_LEFT_7 = &2A
PIXEL_LEFT_8 = &80
PIXEL_LEFT_9 = &82
PIXEL_LEFT_A = &88
PIXEL_LEFT_B = &8A
PIXEL_LEFT_C = &A0
PIXEL_LEFT_D = &A2
PIXEL_LEFT_E = &A8
PIXEL_LEFT_F = &AA

PIXEL_RIGHT_0 = &00
PIXEL_RIGHT_1 = &01
PIXEL_RIGHT_2 = &04
PIXEL_RIGHT_3 = &05
PIXEL_RIGHT_4 = &10
PIXEL_RIGHT_5 = &11
PIXEL_RIGHT_6 = &14
PIXEL_RIGHT_7 = &15
PIXEL_RIGHT_8 = &40
PIXEL_RIGHT_9 = &41
PIXEL_RIGHT_A = &44
PIXEL_RIGHT_B = &45
PIXEL_RIGHT_C = &50
PIXEL_RIGHT_D = &51
PIXEL_RIGHT_E = &54
PIXEL_RIGHT_F = &55

\ ******************************************************************
\ *	SYSTEM defines
\ ******************************************************************

MODE1_COL0=&00
MODE1_COL1=&20
MODE1_COL2=&80
MODE1_COL3=&A0

PIXEL_1_MASK = &AA
PIXEL_2_MASK = &55

\ ******************************************************************
\ *	MACROS
\ ******************************************************************

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

\\ FX variables

.fx_colour_index		SKIP 1		; index into our colour palette
.raster_count			SKIP 1
.buffer					SKIP 1

.zoom					SKIP 1
.zdir					SKIP 1
.v_index				SKIP 1

.pixel_column			SKIP 1
.screen_byte			SKIP 1

.readptr				SKIP 2
.readptr_right			SKIP 2
.writeptr				SKIP 2

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

	\\ Set square

	LDA #1: STA &FE00
	LDA #64: STA &FE01

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
    \ Ask OSFILE to load our screen
	LDX #LO(osfile_params)
	LDY #HI(osfile_params)
	LDA #&FF
;    JSR osfile

	LDA #0
	STA zoom
	STA buffer

	LDA #1
	STA zdir

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
	LDA buffer
	BEQ buffer_zero
	\\ Write to screen1

	\\ Display screen1
	LDA #LO(screen1_LO)
	STA screen_disp_LO+1
	STA fx_draw_screen_LO+1
	LDA #HI(screen1_LO)
	STA screen_disp_LO+2
	STA fx_draw_screen_LO+2

	LDA #LO(screen1_HI)
	STA screen_disp_HI+1
	STA fx_draw_screen_HI+1
	LDA #HI(screen1_HI)
	STA screen_disp_HI+2
	STA fx_draw_screen_HI+2

	\\ Write to screen2
	LDA #LO(screen2_addr)
	STA writeptr
	LDA #HI(screen2_addr)
	STA writeptr+1

	JMP buffer_cont

	.buffer_zero

	\\ Display screen1
	LDA #LO(screen2_LO)
	STA screen_disp_LO+1
	STA fx_draw_screen_LO+1
	LDA #HI(screen2_LO)
	STA screen_disp_LO+2
	STA fx_draw_screen_LO+2

	LDA #LO(screen2_HI)
	STA screen_disp_HI+1
	STA fx_draw_screen_HI+1
	LDA #HI(screen2_HI)
	STA screen_disp_HI+2
	STA fx_draw_screen_HI+2

	\\ Write to screen2
	LDA #LO(screen1_addr)
	STA writeptr
	LDA #HI(screen1_addr)
	STA writeptr+1

	.buffer_cont
	LDA buffer
	EOR #1
	STA buffer

	LDA #2
	STA raster_count

\\ Remember that this value is for the zoom being displayed right now
\\ Not the one being written to be the code inside the draw loop!
\\ So this needs to be the previous zoom value

	LDX zoom
	LDA v_table_LO, X
	STA fx_draw_v_lookup+1
	STA v_loop_lookup+1
	LDA v_table_HI, X
	STA fx_draw_v_lookup+2
	STA v_loop_lookup+2

\\ Skip through V table until reach non-zero value
\\ Set initial screen address to last zero'th row
\\ Set v to index of non-zero value

	LDY #0
	.v_loop
	.v_loop_lookup
	LDA texture_v_base, Y
	BNE v_found
	INY
	BNE v_loop
	.v_found
	STA fx_draw_raster_cmp+1
	STY v_index

	DEY

	LDA #13:STA &FE00
	.screen_disp_LO
	LDA screen1_LO, Y:STA &FE01

	LDA #12:STA &FE00
	.screen_disp_HI
	LDA screen1_HI, Y:STA &FE01

\\ Then we update our zoom value

IF 1
	LDA zdir
	BPL pos
	\ neg
	DEX
	BNE dir_ok

	LDA #1
	STA zdir
	BNE dir_ok

	.pos
	INX
	CPX #NUM_ZOOMS-1
	BCC dir_ok

	LDA #&FF
	STA zdir

	.dir_ok
	STX zoom 
ENDIF

\\ Poke in the horizontal tables to the draw fn

	LDA u_table_HI, X
	STA fx_draw_u_lookup0+2
	STA fx_draw_u_lookup0a+2
	STA fx_draw_u_lookup1+2
	STA fx_draw_u_lookup1a+2
	STA fx_draw_u_lookup2+2
	STA fx_draw_u_lookup2a+2
	STA fx_draw_u_lookup3+2
	STA fx_draw_u_lookup3a+2

	LDA u_table_LO, X
	STA fx_draw_u_lookup0+1
	STA fx_draw_u_lookup0a+1
	INC A
	STA fx_draw_u_lookup1+1
	STA fx_draw_u_lookup1a+1
	INC A
	STA fx_draw_u_lookup2+1
	STA fx_draw_u_lookup2a+1
	INC A
	STA fx_draw_u_lookup3+1
	STA fx_draw_u_lookup3a+1

\\ Reset our read pointers to the start of the texture

	LDA #LO(texture_row_0)
	STA readptr
	LDA #HI(texture_row_0)
	STA readptr+1

	LDA #LO(texture_row_0r)
	STA readptr_right
	LDA #HI(texture_row_0r)
	STA readptr_right+1

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
	\\ R4 = 0 : vertical total = 1
	LDA #4: STA &FE00
	LDA #0: STA &FE01

	\\ R7 = &FF : vsync = never
	LDA #7: STA &FE00
	LDA #&FF: STA &FE01

	\\ R6 = 1 : vertical displayed = 1
	LDA #6: STA &FE00
	LDA #1: STA &FE01

	\\ R9 = 0 : scanlines per row = 1
	LDA #9: STA &FE00
	LDA #0: STA &FE01

	\\ 8*8c = 64c

	WAIT_CYCLES 128-64-4

	.fx_draw_scanline1

	LDX #0					; pixel column
	CLC						; 2c

	.fx_draw_loop

	LDA raster_count		; 3c
	.fx_draw_raster_cmp
	CMP #&FF				; 2c
	\\ 5c

	\ Still on same screen buffer line
	BCC plot_texels

	\ Otherwise update R12/R13 to next screen buffer line

	; 2c
	LDY v_index				; 3c
	LDA #13:STA &FE00	; 8c
	.fx_draw_screen_LO
	LDA screen1_LO, Y:STA &FE01 ;10c
	LDA #12:STA &FE00	; 8c
	.fx_draw_screen_HI
	LDA screen1_HI, Y:STA &FE01	;10c

	INY					; 2c
	STY v_index			; 3c	- could be self-mod

	.fx_draw_v_lookup
	LDA texture_v_base, Y		; 4c
	STA fx_draw_raster_cmp+1	; 4c self-mod
	CLC

	\\ NOP to end of line and continue

	WAIT_CYCLES 128 -5 -56 -10 -3	; 59c lost

	JMP continue_line

	.plot_texels
	; 3c

\ read texture look up for pixel - stays same for frame (for constant scale)
	.fx_draw_u_lookup0
	LDY texture_u_base+0, X	; 4c
\ texture data changes when updating to next row of v
\ (could unroll code x8 once for each v coordinate?)
	LDA (readptr), Y		; 5c
	STA screen_byte         ; 3c
	\\ 12c

	.fx_draw_u_lookup1
	LDY texture_u_base+1, X	; 4c
	LDA (readptr_right), Y	; 5c
	ORA screen_byte         ; 3c
	STA (writeptr)			; 6c
	\\ 18c

	.fx_draw_u_lookup2
	LDY texture_u_base+2, X	; 4c
	LDA (readptr), Y		; 5c
	STA screen_byte         ; 3c
	\\ 12c

	.fx_draw_u_lookup3
	LDY texture_u_base+3, X	; 4c
	LDA (readptr_right), Y	; 5c
	ORA screen_byte         ; 3c

	LDY #8					; 2c
	STA (writeptr),Y		; 6c
	\\ 20c

	\ Update pixel column
	TXA						; 2c
	ADC #4					; 2c
	\\ Need to handle TEXTURE_WIDTH here
	AND #(TEXTURE_WIDTH-1)	; 2c
	BNE same_row
	\IF 0 THEN need to update texture lookup
	; 2c
	INC readptr+1			; 5c
	INC readptr_right+1		; 5c
	BNE store_column		; 3c
	.same_row
	; 3c
	NOP:NOP:NOP:NOP:NOP:NOP	; 12c

	.store_column
	TAX						; 2c
	\\ 23c

	\ Update write ptr
	CLC                     ; 2c	- might be able to remove?
	LDA writeptr            ; 3c
	ADC #16                 ; 2c      
	STA writeptr            ; 3c
	LDA writeptr+1          ; 3c
	ADC #0                  ; 2c
	STA writeptr+1          ; 3c
	\\ 18c

	WAIT_CYCLES 7		; amazing!

	.continue_line
	INC raster_count		; 5c
	BEQ fx_draw_scanline256	; 2c
	JMP fx_draw_loop		; 3c
	\\ 10c

	.fx_draw_scanline256
	\\ R4 = vertical total 312 lines
	LDA #4: STA &FE00
	LDA #312 - 255 - 1: STA &FE01

	\\ R7 = vsync at char row 25
	LDA #7: STA &FE00
	LDA #280 - 255: STA &FE01

	\\ If skip raster lines that set new screen address
	\\ then can have max TEXTURE_HEIGHT rows left to process in theory
	\\ = 8x2 bytes
	\\ Actually have more as lose first scanline, clamp line + last two scanlines
	\\ So 12x2 = 24 bytes
IF 1
	CLC
	.fx_draw_fixup_loop

	.fx_draw_u_lookup0a
	LDY texture_u_base+0, X	; 4c
\ texture data changes when updating to next row of v
\ (could unroll code x8 once for each v coordinate?)
	LDA (readptr), Y		; 5c
	STA screen_byte         ; 3c
	\\ 12c

	.fx_draw_u_lookup1a
	LDY texture_u_base+1, X	; 4c
	LDA (readptr_right), Y	; 5c
	ORA screen_byte         ; 3c
	STA (writeptr)			; 6c
	\\ 18c

	.fx_draw_u_lookup2a
	LDY texture_u_base+2, X	; 4c
	LDA (readptr), Y		; 5c
	STA screen_byte         ; 3c
	\\ 12c

	.fx_draw_u_lookup3a
	LDY texture_u_base+3, X	; 4c
	LDA (readptr_right), Y	; 5c
	ORA screen_byte         ; 3c

	LDY #8					; 2c
	STA (writeptr),Y		; 6c
	\\ 20c

	\ Update pixel column
	TXA						; 2c
	ADC #4					; 2c
	\\ Need to handle TEXTURE_WIDTH here
	AND #(TEXTURE_WIDTH-1)	; 2c
	BEQ fx_draw_fixup_done
	TAX						; 2c

	\ Update write ptr
	CLC                     ; 2c	- might be able to remove?
	LDA writeptr            ; 3c
	ADC #16                 ; 2c      
	STA writeptr            ; 3c
	LDA writeptr+1          ; 3c
	ADC #0                  ; 2c
	STA writeptr+1          ; 3c
	\\ 18c

	JMP fx_draw_fixup_loop
	.fx_draw_fixup_done
ENDIF

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

TEXTURE_WIDTH = 128
TEXTURE_HEIGHT = 8

NUM_ZOOMS = 32
MAX_ZOOM = 128

blank_line_addr = screen_addr - 512		; won't work w/ shadow

.v_table_LO
FOR n,0,NUM_ZOOMS-1,1
EQUB LO(texture_v_base + n * TEXTURE_V_SIZE)
NEXT

.v_table_HI
FOR n,0,NUM_ZOOMS-1,1
EQUB HI(texture_v_base + n * TEXTURE_V_SIZE)
NEXT

.u_table_LO
FOR n,0,NUM_ZOOMS-1,1
EQUB LO(texture_u_base + n * TEXTURE_U_SIZE)
NEXT

.u_table_HI
FOR n,0,NUM_ZOOMS-1,1
EQUB HI(texture_u_base + n * TEXTURE_U_SIZE)
NEXT

screen1_addr = screen_addr
screen2_addr = screen_addr + TEXTURE_HEIGHT*512

ALIGN &100
.screen1_LO
EQUB LO(blank_line_addr/8)
FOR n,0,TEXTURE_HEIGHT-1,1
addr = screen1_addr + 512 * n
EQUB LO(addr/8)
NEXT
EQUB LO(blank_line_addr/8)
EQUB LO(blank_line_addr/8)

.screen1_HI
EQUB HI(blank_line_addr/8)
FOR n,0,TEXTURE_HEIGHT-1,1
addr = screen1_addr + 512 * n
EQUB HI(addr/8)
NEXT
EQUB HI(blank_line_addr/8)
EQUB HI(blank_line_addr/8)

.screen2_LO
EQUB LO(blank_line_addr/8)
FOR n,0,TEXTURE_HEIGHT-1,1
addr = screen2_addr + 512 * n
EQUB LO(addr/8)
NEXT
EQUB LO(blank_line_addr/8)
EQUB LO(blank_line_addr/8)

.screen2_HI
EQUB HI(blank_line_addr/8)
FOR n,0,TEXTURE_HEIGHT-1,1
addr = screen2_addr + 512 * n
EQUB HI(addr/8)
NEXT
EQUB HI(blank_line_addr/8)
EQUB HI(blank_line_addr/8)

.texture_data
ALIGN &100
.texture_row_0	; if each row is page aligned could blow out to left&right pixels
FOR c,0,TEXTURE_WIDTH-1,2
	EQUB PIXEL_LEFT_0, PIXEL_LEFT_1
NEXT
.texture_row_0r
FOR c,0,TEXTURE_WIDTH-1,2
	EQUB PIXEL_RIGHT_0, PIXEL_RIGHT_1
NEXT

ALIGN &100
.texture_row_1
FOR c,0,TEXTURE_WIDTH-1,2
	EQUB PIXEL_LEFT_2, PIXEL_LEFT_0
NEXT
.texture_row_1r
FOR c,0,TEXTURE_WIDTH-1,2
	EQUB PIXEL_RIGHT_2, PIXEL_RIGHT_0
NEXT

ALIGN &100
.texture_row_2
FOR c,0,TEXTURE_WIDTH-1,2
	EQUB PIXEL_LEFT_0, PIXEL_LEFT_3
NEXT
.texture_row_2r
FOR c,0,TEXTURE_WIDTH-1,2
	EQUB PIXEL_RIGHT_0, PIXEL_RIGHT_3
NEXT

ALIGN &100
.texture_row_3
FOR c,0,TEXTURE_WIDTH-1,2
	EQUB PIXEL_LEFT_4,PIXEL_LEFT_0
NEXT
.texture_row_3r
FOR c,0,TEXTURE_WIDTH-1,2
	EQUB PIXEL_RIGHT_4,PIXEL_RIGHT_0
NEXT

ALIGN &100
.texture_row_4
FOR c,0,TEXTURE_WIDTH-1,2
	EQUB PIXEL_LEFT_0, PIXEL_LEFT_5
NEXT
.texture_row_4r
FOR c,0,TEXTURE_WIDTH-1,2
	EQUB PIXEL_RIGHT_0, PIXEL_RIGHT_5
NEXT

ALIGN &100
.texture_row_5
FOR c,0,TEXTURE_WIDTH-1,2
	EQUB PIXEL_LEFT_6, PIXEL_LEFT_0
NEXT
.texture_row_5r
FOR c,0,TEXTURE_WIDTH-1,2
	EQUB PIXEL_RIGHT_6, PIXEL_RIGHT_0
NEXT

ALIGN &100
.texture_row_6
FOR c,0,TEXTURE_WIDTH-1,2
	EQUB PIXEL_LEFT_0, PIXEL_LEFT_7
NEXT
.texture_row_6r
FOR c,0,TEXTURE_WIDTH-1,2
	EQUB PIXEL_RIGHT_0, PIXEL_RIGHT_7
NEXT

ALIGN &100
.texture_row_7
FOR c,0,TEXTURE_WIDTH-1,8
	EQUB PIXEL_LEFT_7, PIXEL_LEFT_6, PIXEL_LEFT_5, PIXEL_LEFT_4, PIXEL_LEFT_3, PIXEL_LEFT_2, PIXEL_LEFT_1, PIXEL_LEFT_0
NEXT
.texture_row_7r
FOR c,0,TEXTURE_WIDTH-1,8
	EQUB PIXEL_RIGHT_7, PIXEL_RIGHT_6, PIXEL_RIGHT_5, PIXEL_RIGHT_4, PIXEL_RIGHT_3, PIXEL_RIGHT_2, PIXEL_RIGHT_1, PIXEL_RIGHT_0
NEXT

SCREEN_WIDTH=128
TEXTURE_U_SIZE = SCREEN_WIDTH

MACRO TEXTURE_U_TABLE width

PRINT "TEXTURE WIDTH=", TEXTURE_WIDTH, "SCREEN_WIDTH=", SCREEN_WIDTH, " mapping width=",width," scale=", (width / TEXTURE_WIDTH), " zoom=", (TEXTURE_WIDTH / width), " scanline delta=", INT(256*(width / TEXTURE_WIDTH))

FOR x,0,SCREEN_WIDTH-1,1
u = (TEXTURE_WIDTH/2) + (x - SCREEN_WIDTH/2) * (width / TEXTURE_WIDTH)

EQUB u
NEXT

ENDMACRO

.texture_u_base
FOR n,0,NUM_ZOOMS-1,1
w = TEXTURE_WIDTH - (TEXTURE_WIDTH * n/NUM_ZOOMS)

TEXTURE_U_TABLE w
NEXT

TEXTURE_V_SIZE = 16;TEXTURE_HEIGHT+3

MACRO TEXTURE_V_TABLE width

\\ The scanlines at which the screen address needs to be updated...
zoom = (TEXTURE_WIDTH / width)
height = TEXTURE_HEIGHT * zoom
top = 128 - (height / 2)

EQUB 0			; clamp top to blank

PRINT "zoom=",zoom," height=", height, " top=", top

FOR y,0,TEXTURE_HEIGHT,1

v = top + y * zoom
PRINT "y=",y,"v=",v

IF v <= 0
	EQUB 0
ELIF v >= 255
	EQUB 255
ELSE
	EQUB v+1	; because raster_count starts at 2 for 'reasons'
ENDIF

NEXT

EQUB 255		; clamp bottom to blank
EQUB 0,0,0,0,0	; pad

ENDMACRO

.texture_v_base
FOR n,0,NUM_ZOOMS-1,1
w = TEXTURE_WIDTH - (TEXTURE_WIDTH * n/NUM_ZOOMS)

TEXTURE_V_TABLE w
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
