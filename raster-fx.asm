\ ******************************************************************
\ *	RASTER FX FRAMEWORK
\ ******************************************************************

_DEBUG_RASTERS=0
_PRESS_KEY=1
_FILL_NOT_COPY=0
_LINEAR_MODE=1
_OLD_OFFSET=0               ; simpler broken with negative du/dv values.
                            ; but the more complicated solution still isn't right

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

.rot_angle          skip 1

.readptr            skip 2
.writeptr           skip 2

.u                  skip 2
.v                  skip 2
.dudy               skip 2
.dvdy               skip 2
.offset             skip 2

.U0                 skip 2          ; [u,v] coordinates in top-left of screen.
.V0                 skip 2

.u_dash             skip 2
.v_dash             skip 2
.DU                 skip 2
.delta_offset       skip 2

.x_pressed          skip 1
.z_pressed          skip 1

.col_count          skip 1


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

    IF _LINEAR_MODE
	LDA #5
	JSR oswrch

    lda #&C0
    sta &fe20   ; MODE 8?

	LDX #15
	.palloop
	LDA palette, X
	STA &FE21
	DEX
	BPL palloop
    ELSE
	LDA #2
	JSR oswrch
    ENDIF

	\\ Turn off cursor

	LDA #10: STA &FE00
	LDA #32: STA &FE01

	;lda #2:sta &fe00
	;lda #95:sta &fe01

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

    IF _PRESS_KEY
	LDA #&79
	LDX #(&42 EOR &80)      ; X
	JSR osbyte
    STX x_pressed

	LDA #&79
	LDX #(&61 EOR &80)      ; Z
	JSR osbyte
    STX z_pressed
    ENDIF

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


; A=write to byte, X=write to page, Y=#pages
.memfill
{
    stx loop+2
    ldx #0
    .loop
    sta &FF00, X
    inx
    bne loop
    inc loop+2
    dey
    bne loop
    rts
}

.fx_init_function
{
	ldx #LO(file1):ldy #HI(file1):lda #HI(&3000):jsr disksys_load_file
    ; Select SWRAM bank 4
    lda #4:sta &f4:sta &fe30
    ; A=read from PAGE, X=write to page, Y=#pages
    lda #HI(&3000):ldx #HI(xor_texture):ldy #HI(&1000): jsr disksys_copy_block

    IF _FILL_NOT_COPY
    lda #&03:ldx #HI(xor_texture-&1000):ldy #HI(&1000): jsr memfill
    lda #&30:ldx #HI(xor_texture+&1000):ldy #HI(&1000): jsr memfill
    ELSE
    lda #HI(&3000):ldx #HI(xor_texture-&1000):ldy #HI(&1000): jsr disksys_copy_block
    lda #HI(&3000):ldx #HI(xor_texture+&1000):ldy #HI(&1000): jsr disksys_copy_block
    ENDIF

    lda #12
    jsr oswrch              ; cls

    lda #0
    sta rot_angle

    lda &fe34
    and #&fa                ; clear bits
    ora #1                  ; display SHADOW + write MAIN
    sta &fe34

    IF _LINEAR_MODE
	LDX #13
	.loop
	STX &FE00
	LDA crtc_regs_linear,X
	STA &FE01
	DEX
	BPL loop
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

ROT_ROWS=32
ROT_COLS=32     ; for now, will be 50
TEX_WIDTH=64

.fx_update_function
{
    IF _DEBUG_RASTERS
    lda #PAL_blue:sta &fe21
    ENDIF

    \\ - Update rotation angle.
    ldx rot_angle
    IF _PRESS_KEY
    lda x_pressed
    bpl no_x
    ENDIF
    inx
    .no_x
    IF _PRESS_KEY
    lda z_pressed
    bpl no_z
    dex
    ENDIF
    .no_z
    stx rot_angle

    \\ - Calculate du,dv
    lda sin_LO, X                  ; dudy = sin(a)
    sta dudy+0
    lda sin_HI, X                  ; dudy = sin(a)
    sta dudy+1
    lda cos_LO, X                  ; dvdy = cos(a)
    sta dvdy+0
    lda cos_HI, X                  ; dvdy = cos(a)
    sta dvdy+1

    bmi neg_dy
    lda #&E6                ; opcode INC zp
    bne pos_dy
    .neg_dy
    lda #&C6                ; opcode DEC zp
    .pos_dy
    IF _OLD_OFFSET
    sta do_inc+1
    ENDIF

    \\ - Calculate U0, V0
    IF 0
    ; Fix top-left to (0,0)
    lda #0
    sta U0:sta U0+1
    sta V0:sta V0+1
    ELSE
    ldx rot_angle
    ; Lookup so texture rotates around (32,32)
    lda tl_corner_U0_LO, X:sta U0
    lda tl_corner_U0_HI, X:sta U0+1
    lda tl_corner_V0_LO, X:sta V0
    lda tl_corner_V0_HI, X:sta V0+1
    ENDIF

    \\ - Calculate baseptr (top-left texture ptr)
    clc
    ldx V0+1                        ; v [0,63]
    lda v_to_tex_ptr_LO, X
    adc U0+1                        ; u [0,63]
    sta readptr
    lda v_to_tex_ptr_HI, X
    adc #0
    sta readptr+1

    \\ - Calculate texture read offset per column and poke in. 
    lda #0                          ; always starts at [u,v] = (0,0)
    sta offset
    sta u:sta u+1
    sta v:
    lda #0:sta v+1
    lda #0:sta offset+1

    lda #LO(col_loop)
    sta writeptr
    lda #HI(col_loop)
    sta writeptr+1

    ldx #ROT_ROWS

    .row_loop

    lda offset              ; offset_LO
    ldy #1
    sta (writeptr), Y       ; SELF-MOD ldy #offset_LO

    \\ Calculate u+=dudy <=> u+=sin(a)/scale

    clc
    lda u+0
    adc dudy+0
    sta u+0
    lda u+1
    adc dudy+1
    ;and #TEX_WIDTH-1
    tay                     ; sta u_dash+1

    IF _OLD_OFFSET
    sta u+1
    
    ; OLD ==> Calculate offset into texture for new u,v

    \\ Calculate v+=dvdy <=> v+=cos(a)/scale

    clc
    lda v+0
    adc dvdy+0
    sta v+0
    lda v+1
    adc dvdy+1
    ; Remove this for now as this gets used in a lookup table anyway.
    ;and #TEX_WIDTH-1
    tay                     ; sta v_dash+1

    sta v+1                        ; v [0,63]
    clc
    lda v_to_offset_LO, Y
    adc u+1                        ; u [0,63]
    sta offset
    lda v_to_offset_HI, Y
    adc #0

    cmp offset+1            ; new_offset != old_offset?
    sta offset+1
    beq do_equ
    bne do_inc

    ELSE
    ; Calculate integer DU.
    ; Q: Is this just dudy + Carry?

    sec
    sbc u+1
    sta DU+0
    sty u+1                 ; lda u_dash+1:sta u+1

    ; Sign extend DU.       [-128,127]

    asl a                   ; top bit in C
    lda #0
    sbc #0                  ; C=1 => A=0
                            ; C=0 => A=&ff
    eor #&ff
    sta DU+1                ; &0 or &ff

    \\ Calculate v+=dvdy <=> v+=cos(a)/scale

    clc
    lda v+0
    adc dvdy+0
    sta v+0
    lda v+1
    adc dvdy+1
    ; Remove this for now as this gets used in a lookup table anyway.
    ;and #TEX_WIDTH-1
    tay                     ; sta v_dash+1

    ; Calculate integer DV.
    ; Q: Is this just dvdy + Carry?

    sec
    sbc v+1
    sty v+1                 ; lda v_dash+1:sta v+1
    tay                     ; sta DV+1

    ; Calculate address offset for integer DU,DV.

    clc
    lda v_to_offset_LO, Y
    adc DU+0
    sta delta_offset
    lda v_to_offset_HI, Y
    adc DU+1                ; sign extended
    sta delta_offset+1

    ; Calculate new address offset.

    clc
    lda offset
    adc delta_offset
    sta offset
    lda offset+1
    adc delta_offset+1
    cmp offset+1
    sta offset+1

    ; Have we crossed a page?

    beq do_equ
    bpl do_inc
    ENDIF

    .do_dec
    lda #&C6                ; opcode DEC zp
    bne next_row

    .do_inc
    lda #&E6                ; opcode INC zp
    bne next_row

    ; Same page
    .do_equ
    lda #&A0                ; opcode LDY

    .next_row
    ldy #4
    sta (writeptr), Y       ; SELF-MOD ldy #writeptr+1

    clc
    lda writeptr
    adc #9
    sta writeptr
    bcc no_carry
    inc writeptr+1
    .no_carry

    dex
    bne row_loop
    .done_loop

    lda &fe34
    eor #5                  ; flip displays
    sta &fe34

    IF _DEBUG_RASTERS
    lda #PAL_black:sta &fe21
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
{
    IF _DEBUG_RASTERS
    lda #PAL_red:sta &fe21
    ENDIF

\\ Ignore VRUP stuff for now, just get the rotation code correct first. :)

    lda #ROT_COLS
    sta col_count

    ldx #0

    .*col_loop
    {
        FOR row,0,ROT_ROWS-1,1
        ldy #0                      ; 2c        offset MOD 256      **SELF MOD**
        lda (readptr), Y            ; 5/6c 
        inc readptr+1               ; 2c or 5c  inc|dec readptr+1   **SELF MOD**

        IF _LINEAR_MODE
        sta &7C00+row*32, X         ; linear
        ; First row &7C00, &7C41, &7C02, &7C43...
        ; Second    &7C20, &7C61, &7C22, &7C63...
        ;           &7C40, &7C01, &7C42, &7C03
        ;           &7C60, &7C21, &7C62, &7C23
        ;           &7C80, &7CC1, &7C82, &7CC3
        ELSE
        y=row*4
        sta screen_addr+(y DIV 8)*640+(y MOD 8), X  ; 5c
        ENDIF
        NEXT

        ; Update [U0,V0] to start of next column.
        ; Do this full-fat first.

        \\ u+=dudx <> u+=dvdy

        clc                             ; 2c
        lda U0                          ; 3c
        adc dvdy+0                      ; 3c
        sta U0                          ; 3c
        lda U0+1                        ; 3c
        adc dvdy+1                      ; 3c
        sta U0+1                        ; 3c
        \\ 20c (could save 2c)

        \\ v+=dvdx <> v-=dudy
        sec
        lda V0
        sbc dudy+0                      ; CONST FOR LOOP
        sta V0
        lda V0+1
        sbc dudy+1                      ; CONST FOR LOOP
        sta V0+1
        \\ 20c (could save 2c)

        \\ - Calculate readptr (ptr to start of column in texture)
        tay                             ; v [0,63]
        clc
        lda v_to_tex_ptr_LO, Y
        adc U0+1                        ; u [0,63]
        sta readptr
        lda v_to_tex_ptr_HI, Y
        adc #0
        sta readptr+1
        \\ 2+2+4+3+3+4+2+3 = 23c

        \\ TODO: Update R12/R13 every 4 scanlines for VRUP.
        ;LDA #12: STA &FE00				; 8c
        ;LDA rot_vram_table_HI, X	    ; 4c
        ;STA &FE01						; 6c

        ;LDA #13: STA &FE00				; 8c
        ;LDA rot_vram_table_LO, X	    ; 4c
        ;STA &FE01						; 6c
        \\ 36c

        IF _LINEAR_MODE
        inx
        ELSE
        clc
        txa
        adc #8
        tax
        ENDIF
        dec col_count
        beq done                    ; 2c
        jmp col_loop                ; 3c

        \\ Something like 112c overhead per column? :S
    }
    .done

    IF _DEBUG_RASTERS
    lda #PAL_black:sta &fe21
    ENDIF

    rts
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

    IF _LINEAR_MODE
    lda #&F4
    sta &FE20
    ENDIF

	RTS
}

\\ RTW's fast 8x8 multiply routine (made slower by kieranhj :)
IF 0
.mult											; 6c
{
	SEC:LDA num1:SBC num2						; 8c
	BCS positive

	; 2c
	EOR #255:ADC #1								; 4c
	jmp continue								; 3c

	.positive
	; 3c
	WAIT_CYCLES 6

	.continue
	TAY:CLC:LDA num1:ADC num2:TAX				; 12c
	BCS morethan256

	; 2c
	SEC											; 2c
	LDA sqrlo256,X:SBC sqrlo256,Y:STA result	; 11c
	LDA sqrhi256,X:SBC sqrhi256,Y:STA result+1	; 11c
	jmp exit									; 3c

	.morethan256
	; 3c
	LDA sqrlo512,X:SBC sqrlo256,Y:STA result	; 11c
	LDA sqrhi512,X:SBC sqrhi256,Y:STA result+1	; 11c
	WAIT_CYCLES 4

	.exit
	RTS											; 6c
	\\ 70c fixed
}
ENDIF

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

.crtc_regs_linear
{
	EQUB 63 				; R0  horizontal total
	EQUB 32					; R1  horizontal displayed
	EQUB 49					; R2  horizontal position
	EQUB &24				; R3  sync width 40 = &28
	EQUB 38;77					; R4  vertical total
	EQUB 0					; R5  vertical total adjust
	EQUB 32					; R6  vertical displayed
	EQUB 35;70					; R7  vertical position; 35=top of screen
	EQUB &0					; R8  interlace; &30 = HIDE SCREEN
	EQUB 7;3					; R9  scanlines per row
	EQUB 32					; R10 cursor start
	EQUB 8					; R11 cursor end
	EQUB HI(&2800)	; R12 screen start address, high
	EQUB LO(&2800)	; R13 screen start address, low
}

.palette
{
	EQUB &00 + PAL_black
	EQUB &10 + PAL_red
	EQUB &20 + PAL_green
	EQUB &30 + PAL_yellow
	EQUB &40 + PAL_blue
	EQUB &50 + PAL_magenta
	EQUB &60 + PAL_cyan
	EQUB &70 + PAL_white
	EQUB &80 + PAL_black
	EQUB &90 + PAL_red
	EQUB &A0 + PAL_green
	EQUB &B0 + PAL_yellow
	EQUB &C0 + PAL_blue
	EQUB &D0 + PAL_magenta
	EQUB &E0 + PAL_cyan
	EQUB &F0 + PAL_white
}

INCLUDE "lib/disksys.asm"
.file1 EQUS "xor",13
;.file1 EQUS "arrow",13

\ ******************************************************************
\ *	FX DATA
\ ******************************************************************

IF 0
PAGE_ALIGN
.twister_vram_table_LO
FOR n,0,31,1
EQUB LO((&3000 + n*640)/8)
NEXT

.twister_vram_table_HI
FOR n,0,31,1
EQUB HI((&3000 + n*640)/8)
NEXT
ENDIF

IF 0
PAGE_ALIGN
.sqrlo256
FOR n,0,255,1
s256 = (n * n) DIV 4
s512 = ((n + 256) * (n + 256)) DIV 4
EQUB LO(s256)
NEXT

.sqrhi256
FOR n,0,255,1
s256 = (n * n) DIV 4
s512 = ((n + 256) * (n + 256)) DIV 4
EQUB HI(s256)
NEXT

.sqrlo512
FOR n,0,255,1
s256 = (n * n) DIV 4
s512 = ((n + 256) * (n + 256)) DIV 4
EQUB LO(s512)
NEXT

.sqrhi512
FOR n,0,255,1
s256 = (n * n) DIV 4
s512 = ((n + 256) * (n + 256)) DIV 4
EQUB HI(s512)
NEXT
ENDIF

\ Notes
\ Having a 12-bit COSINE table means that the smallest increment in
\ the input (1) results in <= 1 angle output.
PAGE_ALIGN
.cos_LO
FOR n,0,255,1
c=INT(256*COS(2*PI*n/256))
EQUB LO(c)
NEXT

.cos_HI
FOR n,0,255,1
c=INT(256*COS(2*PI*n/256))
EQUB HI(c)
NEXT

.sin_LO
FOR n,0,255,1
s=INT(256*SIN(2*PI*n/256))
EQUB LO(s)
NEXT

.sin_HI
FOR n,0,255,1
s=INT(256*SIN(2*PI*n/256))
EQUB HI(s)
NEXT

PAGE_ALIGN
.v_to_tex_ptr_HI
FOR i,0,255,1
v=i AND TEX_WIDTH-1
EQUB HI(xor_texture+v * TEX_WIDTH)
NEXT

.v_to_tex_ptr_LO
FOR i,0,255,1
v=i AND TEX_WIDTH-1
EQUB LO(xor_texture+v * TEX_WIDTH)
NEXT

IF _OLD_OFFSET
.v_to_offset_HI
FOR i,0,255,1
v=i; AND TEX_WIDTH-1
EQUB HI(v * TEX_WIDTH)
NEXT

.v_to_offset_LO
FOR i,0,255,1
v=i AND TEX_WIDTH-1
EQUB LO(v * TEX_WIDTH)
NEXT
ELSE
.v_to_offset_HI
FOR i,0,255,1
IF i>128
v=-(256-i)
ELSE
v=i
ENDIF
EQUB HI(v * TEX_WIDTH)
NEXT

.v_to_offset_LO
FOR i,0,255,1
IF i>128
v=-(256-i)
ELSE
v=i
ENDIF
EQUB LO(v * TEX_WIDTH)
NEXT
ENDIF

x=-ROT_COLS/2       ; tl corner
y=-ROT_ROWS/2

.tl_corner_U0_LO
FOR a,0,255,1
ca=COS(2*PI*a/256)
sa=SIN(2*PI*a/256)
u=32+x*ca+y*sa
v=32-x*sa+y*ca
U0=INT(256 * u) AND &3FFF       ; TEX_WIDTH HARDCODED TO 64
V0=INT(256 * v) AND &3FFF       ;
PRINT a,u,v,U0,V0
EQUB U0 MOD 256
NEXT

.tl_corner_U0_HI
FOR a,0,255,1
ca=COS(2*PI*a/256)
sa=SIN(2*PI*a/256)
u=32+x*ca+y*sa
v=32-x*sa+y*ca
U0=INT(256 * u) AND &3FFF       ; TEX_WIDTH HARDCODED TO 64
V0=INT(256 * v) AND &3FFF       ;
EQUB U0 DIV 256
NEXT

.tl_corner_V0_LO
FOR a,0,255,1
ca=COS(2*PI*a/256)
sa=SIN(2*PI*a/256)
u=32+x*ca+y*sa
v=32-x*sa+y*ca
U0=INT(256 * u) AND &3FFF       ; TEX_WIDTH HARDCODED TO 64
V0=INT(256 * v) AND &3FFF       ;
EQUB V0 MOD 256
NEXT

.tl_corner_V0_HI
FOR a,0,255,1
ca=COS(2*PI*a/256)
sa=SIN(2*PI*a/256)
u=32+x*ca+y*sa
v=32-x*sa+y*ca
U0=INT(256 * u) AND &3FFF       ; TEX_WIDTH HARDCODED TO 64
V0=INT(256 * v) AND &3FFF       ;
EQUB V0 DIV 256
NEXT

IF 0
PAGE_ALIGN
.xor_texture
; 64x64=4096 bytes here.
INCBIN "beebxor.bin"
; Potentially add a second copy for overflow.
;INCBIN "beebxor.bin"
ELSE
xor_texture=&9000       ; copy to SWRAM
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
PUTFILE "SCREEN1_64.BIN", "1", &3000
PUTFILE "SCREEN2_64.BIN", "2", &3000
PUTFILE "SCREEN1_old.BIN", "N1", &3000
PUTFILE "SCREEN2_old.BIN", "N2", &3000
PUTFILE "beebxor.bin", "XOR", &8000
PUTFILE "arrow.bin", "ARROW", &8000
