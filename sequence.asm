\ ******************************************************************
\ *	Sequence of FX
\ ******************************************************************

.sequence_start

\ ******************************************************************
\ *	SEQUENCE MACROS
\ ******************************************************************

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
    SCRIPT_SEGMENT_UNTIL (p * VGM_FRAMES_PER_PATTERN)
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
\\ **** WIBBLY LOGO ****
\ ******************************************************************

SEQUENCE_WAIT_FRAMES 100

SCRIPT_CALL fx_show_text

SEQUENCE_WAIT_FRAMES 100

SCRIPT_CALL fx_show_potato

SEQUENCE_WAIT_FRAMES 100

SCRIPT_CALL fx_strips_default

;SEQUENCE_WAIT_FRAMES 100
;SCRIPT_CALL fx_decompress_text2

SEQUENCE_WAIT_FRAMES 100

SCRIPT_CALL fx_show_text

SEQUENCE_WAIT_FRAMES 100

SCRIPT_CALL fx_strips_blank

SCRIPT_END

.sequence_script_end

.sequence_end
