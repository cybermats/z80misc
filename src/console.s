	CPU z80
	include "utils/macro.s"

RESET:
	di
	ld a, 1h
	out (OUTPORT), a
	ld SP, STACK_START		; Set Stack to end of memory
	ld a, 07h			; Set up interrupt page
	ld i, a				; 
	im 2				; Set interrupt mode 2
	jp INIT


; ********************************************
;
; Init
;
; ********************************************


INIT:
	; Prepare system
	ld a, 2h			; Indicate that the system starts
	out (OUTPORT), a

	; Do ram test
	ld hl, VRAMBEG
	ld de, VRAMEND - VRAMBEG
	call RAMTST
	jr nc, .ramtest_succ

.ramtest_err:
	ld a, 00aah
	out (OUTPORT), a
	halt
	jr .ramtest_err

.ramtest_succ:
.configure:

	ld a, 3h		; Indicate that the system starts
	out (OUTPORT), a

	call VD_CONFIGURE
	
	ld a, 4h		; Indicate that the video has been configured
	out (OUTPORT), a

	ld hl, MSG_INIT
	ld bc, MSG_INIT_LEN
	call VD_OUTN

	ld a, INT_KEYBOARD_IDX
	call KD_CONFIGURE

.tell:
	ld a, 5h		; Indicate that the system is ok
	out (OUTPORT), a

	ld hl, MSG_DONE
	ld bc, MSG_DONE_LEN
	call VD_OUTN

	ei

MAIN:
	halt
	call KD_NEXT_KVAL
	jr c, MAIN
	call VD_OUT
	
	jr MAIN			; Loop back



; Keyboard interrupt received
KEYBOARD_INT:
	call KD_CALLBACK
	ei
	reti




	include "utils/constants.s"
	include "utils/ramtest.s"
	include "utils/timing.s"
	include "utils/video_driver.s"
	include "utils/keyboard_driver.s"
	include "utils/strings.s"

MESSAGES:
	msg MSG_INIT, "Init..."
	msg MSG_DONE, "Ok\n"




	org 0700h
INT_TABLE:			; Interrupt table
	dw RESET		; Reset
INT_KEYBOARD_IDX:		equ ($-INT_TABLE)
	dw KEYBOARD_INT

	org 07feh
	dw 0000h

	end

