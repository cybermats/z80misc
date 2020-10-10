	CPU z80
	include "utils/macro.s"
	
	org 0
	
	include "utils/init.s"

MAIN:
	call SHELL
	
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
	include "utils/shell.s"





	org 0700h
INT_TABLE:			; Interrupt table
	dw INIT			; Initialize
INT_KEYBOARD_IDX:		equ ($-INT_TABLE)
	dw KEYBOARD_INT		; Keyboard handler

	org 07feh
	dw 0000h

	end

