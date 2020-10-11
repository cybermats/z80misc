
INC_XMODEM:	equ TRUE
INC_SERIAL:	equ TRUE
INC_ECHO:	equ TRUE


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

SERIAL_INT:
	call SER_CALLBACK
	ei
	reti



	include "utils/constants.s"
	include "utils/ramtest.s"
	include "utils/timing.s"
	include "utils/video_driver.s"
	include "utils/keyboard_driver.s"
	
	IF INC_SERIAL
		include "utils/serial_driver.s"
	ENDIF
	
	include "utils/shell.s"
	IF INC_ECHO
		include "cmds/echo.s"
	ENDIF
	include "cmds/dump.s"
	include "cmds/run.s"
	IF INC_XMODEM
		include "cmds/xmodem.s"
	ENDIF




;	org 0780h
;INT_TABLE:			; Interrupt table
;	dw INIT			; Initialize
;INT_KEYBOARD_IDX:		equ ($-INT_TABLE)
;	dw KEYBOARD_INT		; Keyboard handler

	org 07feh
	dw 0ffffh

	end

