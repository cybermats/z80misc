	include "utils/jumptbl.s"

; Start up
RESET:
	ifdef POST
	ld a, 1h
	out (OUTPORT), a
	endif
	ld sp, STACK_START
	call INITIALIZE


; Jump table
	org INITIALIZE
	jp INIT_SUB
	org OUTCH
	jp OUTCH_SUB
	org INCH
	jp INCH_SUB
	nop



; ***********************************************************
; Title:	Initialize
; Name: 	INIT_SUB
; Purpose:	Initializes a few things at start up:
; 		  - Tests VRAM
;		  - Initializes Serial port
;		  - Initializes Video card
; Entry:	None
; Exit:		Everything is reset
;
; Registers used:
; ***********************************************************
	
INIT_SUB:
	ifdef POST
	ld a, 2h
	out (OUTPORT), a
	endif
	ld hl, VRAMBEG	
	ld de, VRAMEND - VRAMBEG
	call RAMTST		; Check VRAM
	jr nc, .vram_test_succ	; Is it working?

.vram_test_fail:		; VRAM isn't working
	ifdef POST
	ld a, 0aah 
	out (OUTPORT), a
	endif
	halt
	jr .vram_test_fail

.vram_test_succ:		; VRAM is working
	ifdef POST
	ld a, 3h
	out (OUTPORT), a
	endif
	call SER_CONFIGURE	; Configure Serial port
	ifdef POST
	ld a, 4h
	out (OUTPORT), a
	endif
	call VD_CONFIGURE	; Configure Video
	ifdef POST
	ld a, 5h
	out (OUTPORT), a
	endif
	ret

; ***********************************************************
; Title:	Outputs a char to Serial and Video
; Name: 	OUTCH_SUB
; Purpose:	Outputs the char in register A to
; 		both the serial port and the video screen.
;
;		For new lines, it outputs \r\n to serial.
; Entry:	Register A - Char to output
; Exit:		None
;
; Regs used:	A
; ***********************************************************
	

OUTCH_SUB:			
	cp '\n'
	jr nz, .done
	ld a, '\r'
	call SER_SEND
	ld a, '\n'
.done:
	call SER_SEND
	jp VD_OUT

; ***********************************************************
; Title:	Inputs a char from Serial or Keyboard
; Name: 	INCH_SUB
; Purpose:	Reads the Serial and Keyboard for input.
; 		Blocks until input has been received.
;
; Entry:	None
; Exit:		Register A - input character
;
; Regs used:	A
; ***********************************************************
	

INCH_SUB:
	call SER_POLL		; Check input from Serial
	jr nc, .done		; Is there input?
	call KD_POLL_CHAR	; No, check Keyboard for input
	jr c, INCH_SUB		; Is there input?
.done:	ret   			; Input available, return



	include "utils/constants.s"
	include "utils/ramtest.s"
	include "utils/video_driver.s"
	include "utils/serial_driver.s"
	include "utils/keyboard_driver.s"



	end