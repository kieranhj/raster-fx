\ ******************************************************************
\ *	Sequence of FX
\ ******************************************************************

TICKS_PER_BEAT = (4 * 6)
BEATS_PER_PATTERN = 16
TICKS_PER_PATTERN = TICKS_PER_BEAT * BEATS_PER_PATTERN
TICKS_PER_NOTE = (2 * 6)

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

MACRO ON_NOTE p, n, f, v
    SCRIPT_SEGMENT_UNTIL ((p-1) * TICKS_PER_PATTERN) + (n * TICKS_PER_NOTE)
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

\ ******************************************************************
\\ **** PATTERN 2 ****
\ ******************************************************************

SEQUENCE_WAIT_UNTIL_PATTERN 2

SCRIPT_CALL fx_strips_blank
SCRIPT_CALL fx_show_text

ON_NOTE 2, 1, fx_set_strip_1, TEXT_1
ON_NOTE 2, 2, fx_set_strip_2, TEXT_2
ON_NOTE 2, 3, fx_set_strip_3, TEXT_3
ON_NOTE 2, 4, fx_set_strip_4, TEXT_4

ON_NOTE 2, 16, fx_strips_blank, 0
ON_NOTE 2, 16, fx_set_strip_1, TEXT_1
ON_NOTE 2, 17, fx_set_strip_2, TEXT_3
ON_NOTE 2, 18, fx_set_strip_3, TEXT_5
ON_NOTE 2, 19, fx_set_strip_4, TEXT_7

\ ******************************************************************
\\ **** PATTERN 3 ****
\ ******************************************************************

SEQUENCE_WAIT_UNTIL_PATTERN 3

SCRIPT_CALL fx_show_potato
SCRIPT_CALL fx_decompress_text2

\ ******************************************************************
\\ **** PATTERN 4 ****
\ ******************************************************************

SEQUENCE_WAIT_UNTIL_PATTERN 4

SCRIPT_CALL fx_show_text

\ ******************************************************************
\\ **** PATTERN 5 ****
\ ******************************************************************

SEQUENCE_WAIT_UNTIL_PATTERN 5

\ ******************************************************************
\\ **** PATTERN 6 ****
\ ******************************************************************

SEQUENCE_WAIT_UNTIL_PATTERN 6

SCRIPT_CALL fx_strips_default
SCRIPT_CALL fx_show_potato
SCRIPT_CALL fx_decompress_text3

\ ******************************************************************
\\ **** PATTERN 7 ****
\ ******************************************************************

SEQUENCE_WAIT_UNTIL_PATTERN 7

SCRIPT_CALL fx_show_text

SCRIPT_END

.sequence_script_end

.sequence_end
