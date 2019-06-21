\ ******************************************************************
\ *	Sequence of FX
\ ******************************************************************

TICKS_PER_LINE = (6)
LINES_PER_BEAT = 4
TICKS_PER_BEAT = (LINES_PER_BEAT * TICKS_PER_LINE)
LINES_PER_PATTERN = 64
TICKS_PER_PATTERN = TICKS_PER_LINE * LINES_PER_PATTERN

TEXT_1 = (1*4)
TEXT_2 = (2*4)
TEXT_3 = (3*4)
TEXT_4 = (4*4)
TEXT_5 = (5*4)
TEXT_6 = (6*4)
TEXT_7 = (7*4)

.sequence_start

\ ******************************************************************
\ *	SEQUENCE MACROS
\ ******************************************************************

MACRO ON_LINE p, n, f, v
    SCRIPT_SEGMENT_UNTIL ((p-1) * TICKS_PER_PATTERN) + (n * TICKS_PER_LINE)
    ; just wait
    SCRIPT_SEGMENT_END
    SCRIPT_CALLV f, v
ENDMACRO

MACRO SEQUENCE_WAIT_FRAMES frames
    SCRIPT_SEGMENT_START frames/50
    ; just wait
    SCRIPT_SEGMENT_END
ENDMACRO

MACRO SEQUENCE_FX_FOR_SECS fxenum, secs
    SCRIPT_CALLV main_set_fx, fxenum
    SCRIPT_SEGMENT_START secs
    ; just wait
    SCRIPT_SEGMENT_END
ENDMACRO

\\ Or could query the music player..
MACRO SEQUENCE_WAIT_UNTIL_PATTERN p
    SCRIPT_SEGMENT_UNTIL ((p-1) * TICKS_PER_PATTERN)
    ; just wait
    SCRIPT_SEGMENT_END
ENDMACRO

MACRO SEQUENCE_SET_FX fxenum
    SCRIPT_CALLV main_set_fx, fxenum
    SCRIPT_SEGMENT_START 1/50
    ; just wait
    SCRIPT_SEGMENT_END
ENDMACRO

\ ******************************************************************
\ *	COLOUR MACROS
\ ******************************************************************

MACRO MODE1_SET_COLOUR c, p
IF c=1
    SCRIPT_CALLV pal_set_mode1_colour1, p
ELIF c=2
    SCRIPT_CALLV pal_set_mode1_colour2, p
ELSE
    SCRIPT_CALLV pal_set_mode1_colour3, p
ENDIF
ENDMACRO

MACRO MODE1_SET_COLOURS p1, p2, p3
    SCRIPT_CALLV pal_set_mode1_colour1, p1
    SCRIPT_CALLV pal_set_mode1_colour2, p2
    SCRIPT_CALLV pal_set_mode1_colour3, p3
ENDMACRO

MACRO MODE0_SET_COLOURS p0,p1
    SCRIPT_CALLV pal_set_mode0_colour0, p0
    SCRIPT_CALLV pal_set_mode0_colour1, p1
ENDMACRO

\ ******************************************************************
\ *	The script
\ ******************************************************************

.sequence_script_start

\ ******************************************************************
\\ **** PATTERN 1 ****
\ ******************************************************************

SCRIPT_CALL fx_strips_default

ON_LINE 1, 2, fx_decompress_text1, 0

; 18,20
; 24,27

ON_LINE 1, 50, fx_show_text, 0

ON_LINE 1, 58, fx_set_strip_2, TEXT_1        ; it's
ON_LINE 1, 60, fx_set_strip_3, TEXT_2        ; not
ON_LINE 1, 62, fx_set_strip_4, TEXT_3        ; a

\ ******************************************************************
\\ **** PATTERN 2 ****
\ ******************************************************************

SEQUENCE_WAIT_UNTIL_PATTERN 2

ON_LINE 2, 0, fx_set_strip_5, TEXT_4        ; party

ON_LINE 2, 6, fx_strips_blank, 0

ON_LINE 2, 10, fx_set_strip_2, TEXT_1       ; it's
ON_LINE 2, 12, fx_set_strip_3, TEXT_3       ; a
ON_LINE 2, 14, fx_set_strip_4, TEXT_5       ; patarty
ON_LINE 2, 22, fx_set_strip_5, TEXT_7       ; yeah!

ON_LINE 2, 32, fx_show_potato, 0

ON_LINE 2, 46, fx_show_text, 0

ON_LINE 2, 48, fx_set_strip_3, TEXT_5       ; patarty
ON_LINE 2, 54, fx_set_strip_4, TEXT_7       ; yeah!

;ON_LINE 2, 56, fx_set_strip_3, TEXT_5       ; party
ON_LINE 2, 58, fx_set_bar2_col, PAL_red
ON_LINE 2, 60, fx_set_bar2_col, PAL_cyan
ON_LINE 2, 62, fx_set_bar2_col, PAL_red

; flash

\ ******************************************************************
\\ **** PATTERN 3 ****
\ ******************************************************************

SEQUENCE_WAIT_UNTIL_PATTERN 3

ON_LINE 3, 0, fx_set_bar2_col, PAL_cyan

SCRIPT_CALL fx_show_potato

ON_LINE 3, 4, fx_decompress_text3, 0

ON_LINE 3, 50, fx_show_text, 0
ON_LINE 3, 52, fx_set_strip_3, TEXT_1       ; slap that bass!

\ ******************************************************************
\\ **** PATTERN 4 ****
\ ******************************************************************

SEQUENCE_WAIT_UNTIL_PATTERN 4

SCRIPT_CALL fx_show_potato

; change palette
ON_LINE 4, 0, fx_set_bar2_col, PAL_red

ON_LINE 4, 30, fx_show_text, 0
ON_LINE 4, 31, fx_set_bar2_col, PAL_cyan
ON_LINE 4, 32, fx_set_strip_2, TEXT_2       ; imagine
ON_LINE 4, 34, fx_set_strip_3, TEXT_3       ; twister

\ ******************************************************************
\\ **** PATTERN 5 ****
\ ******************************************************************

SEQUENCE_WAIT_UNTIL_PATTERN 5

SCRIPT_CALL fx_show_potato

ON_LINE 5, 2, fx_set_bar2_col, PAL_red

; change palette

ON_LINE 5, 30, fx_show_text, 0
ON_LINE 5, 31, fx_set_bar2_col, PAL_green
ON_LINE 5, 32, fx_set_strip_2, TEXT_4       ; particularly
ON_LINE 5, 34, fx_set_strip_3, TEXT_5       ; clever

\ ******************************************************************
\\ **** PATTERN 6 **** ACTUALLY 32 LINES LONG!
\ ******************************************************************

SEQUENCE_WAIT_UNTIL_PATTERN 6

SCRIPT_CALL fx_show_potato

; disco flash
ON_LINE 6, 1, fx_set_bar1_col, PAL_red
ON_LINE 6, 1, fx_set_bar2_col, PAL_red
ON_LINE 6, 4, fx_set_bar1_col, PAL_green
ON_LINE 6, 4, fx_set_bar2_col, PAL_green
ON_LINE 6, 8, fx_set_bar1_col, PAL_blue
ON_LINE 6, 8, fx_set_bar2_col, PAL_blue
ON_LINE 6, 12, fx_set_bar1_col, PAL_red
ON_LINE 6, 12, fx_set_bar2_col, PAL_red
ON_LINE 6, 16, fx_set_bar1_col, PAL_green
ON_LINE 6, 16, fx_set_bar2_col, PAL_green
ON_LINE 6, 20, fx_set_bar1_col, PAL_blue
ON_LINE 6, 20, fx_set_bar2_col, PAL_blue
ON_LINE 6, 24, fx_set_bar1_col, PAL_red
ON_LINE 6, 24, fx_set_bar2_col, PAL_red
ON_LINE 6, 28, fx_set_bar1_col, PAL_green
ON_LINE 6, 28, fx_set_bar2_col, PAL_green
ON_LINE 6, 32, fx_set_bar1_col, PAL_blue
ON_LINE 6, 32, fx_set_bar2_col, PAL_blue
ON_LINE 6, 36, fx_set_bar1_col, PAL_red
ON_LINE 6, 36, fx_set_bar2_col, PAL_red
ON_LINE 6, 40, fx_set_bar1_col, PAL_green
ON_LINE 6, 40, fx_set_bar2_col, PAL_green
ON_LINE 6, 44, fx_set_bar1_col, PAL_blue
ON_LINE 6, 44, fx_set_bar2_col, PAL_blue
ON_LINE 6, 48, fx_set_bar1_col, PAL_red
ON_LINE 6, 48, fx_set_bar2_col, PAL_red
ON_LINE 6, 52, fx_set_bar1_col, PAL_green
ON_LINE 6, 52, fx_set_bar2_col, PAL_green
ON_LINE 6, 56, fx_set_bar1_col, PAL_blue
ON_LINE 6, 56, fx_set_bar2_col, PAL_blue
ON_LINE 6, 60, fx_set_bar1_col, PAL_red
ON_LINE 6, 60, fx_set_bar2_col, PAL_red

ON_LINE 6, 62, fx_show_text, 0

\ ******************************************************************
\\ **** PATTERN 7 ****
\ ******************************************************************

SEQUENCE_WAIT_UNTIL_PATTERN 7

ON_LINE 7, 1, fx_set_bar1_col, PAL_green
ON_LINE 7, 1, fx_set_bar2_col, PAL_green

ON_LINE 7, 2, fx_set_strip_1, TEXT_6       ; todo
ON_LINE 7, 4, fx_set_strip_2, TEXT_7       ; finish this

ON_LINE 7, 32, fx_show_potato, 0
ON_LINE 7, 34, fx_decompress_text1, 0

\ ******************************************************************
\\ **** PATTERN 8 ****
\ ******************************************************************

ON_LINE 8, 0, fx_show_text, 0
ON_LINE 8, 2, fx_set_bar1_col, PAL_blue
ON_LINE 8, 2, fx_set_bar2_col, PAL_blue

ON_LINE 8, 10, fx_set_strip_1, TEXT_1       ; it's
ON_LINE 8, 12, fx_set_strip_2, TEXT_2       ; not
ON_LINE 8, 14, fx_set_strip_3, TEXT_3       ; a
ON_LINE 8, 16, fx_set_strip_4, TEXT_6       ; tea
ON_LINE 8, 20, fx_set_strip_5, TEXT_4       ; party!

ON_LINE 8, 32, fx_show_potato, 0

ON_LINE 8, 34, fx_decompress_text2, 0

\ ******************************************************************
\\ **** PATTERN 9 ****
\ ******************************************************************

ON_LINE 9, 0, fx_show_text, 0
ON_LINE 9, 2, fx_set_bar1_col, PAL_red
ON_LINE 9, 2, fx_set_bar2_col, PAL_red

CREDITS_ADJUST=32

ON_LINE 9, CREDITS_ADJUST+0, fx_set_strip_1, TEXT_1       ; graphics
ON_LINE 9, CREDITS_ADJUST+4, fx_set_strip_2, TEXT_2       ; aldroid
ON_LINE 9, CREDITS_ADJUST+8, fx_set_strip_3, TEXT_3       ; music
ON_LINE 9, CREDITS_ADJUST+12, fx_set_strip_4, TEXT_4       ; mrs beanbag
ON_LINE 9, CREDITS_ADJUST+16, fx_set_strip_5, TEXT_5       ; code
ON_LINE 9, CREDITS_ADJUST+20, fx_set_strip_6, TEXT_6       ; kieranhj

\ ******************************************************************
\\ **** PATTERN 10 ****
\ ******************************************************************

SEQUENCE_WAIT_UNTIL_PATTERN 10

SCRIPT_CALL fx_show_potato

ON_LINE 10,40, fx_press_escape, 0

SCRIPT_END

.sequence_script_end

.sequence_end
