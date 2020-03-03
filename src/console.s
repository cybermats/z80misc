	include "utils/macro.s"

; USE_VIDEO = 1
USE_KEYBOARD = 1

RESET:
	di
	ld a, $1
	out (OUTPORT), a
	ld SP, STACK_START		; Set Stack to end of memory
	ld a, $00			; Set up interrupt page
	ld i, a				; 
	im 2				; Set interrupt mode 2
	ei 				; Enable interrupt
	jp INIT

; Keyboard interrupt received
  	org $0038
KEYBOARD_INT:
	push af
	in a, (SIODATAB)
	out (OUTPORT), a
	ld a, %00010000
	out (SIOCMDB), a
	ld a, %00110000
	out (SIOCMDB), a

;	call KD_CALLBACK
	pop af
	ei
	reti

; Non-maskable interrupt received
  	org $0066
NMI:
	ld a, $0f			; Indicate that an NMI has been received.
	out (OUTPORT), a
	ld a, 250
	call DELAY
	retn




; ********************************************
;
; Init
;
; ********************************************


	org $0100
INIT:
	; Prepare system
	ld a, $2			; Indicate that the system starts
	out (OUTPORT), a

	ifdef USE_VIDEO

	; Do ram test
	ld hl, VRAMBEG
	ld de, VRAMEND - VRAMBEG
	call RAMTST
	jr nc, .ramtest_succ

.ramtest_err:
	ld a, $aa
	out (OUTPORT), a
	halt
	jr .ramtest_err

.ramtest_succ:
.configure:

	endif ; USE_VIDEO

	ld a, $3		; Indicate that the system starts
	out (OUTPORT), a

	ifdef USE_VIDEO
	call VD_CONFIGURE
	endif ; USE_VIDEO
	
	ld a, $4		; Indicate that the video has been configured
	out (OUTPORT), a

	ifdef USE_VIDEO
	
	ld hl, MSG_INIT
	ld bc, MSG_INIT_LEN
	call VD_OUTN

	ld hl, MSG_KB1
	ld bc, MSG_KB1_LEN
	call VD_OUTN
	
	endif ; USE_VIDEO

	ifdef USE_KEYBOARD
	
	call KD_CONFIGURE

	endif ; USE_KEYBOARD
	
	ld a, $5		; Indicate that the keyboard has been configured
	out (OUTPORT), a

	ifdef USE_VIDEO

	ld hl, MSG_KB2
	ld bc, MSG_KB2_LEN
	call VD_OUTN

	ld hl, MSG_DONE
	ld bc, MSG_DONE_LEN
	call VD_OUTN

	endif ; USE_VIDEO

	ld a, 250
	call DELAY

MAIN:
	halt
	jr MAIN

	if 0

	call KD_NEXT_KVAL	; Get next character
	jr c, .done		; Jump if no chars available

	call VD_OUT		; Output next char
	jr MAIN

	ifdef USE_VIDEO
	
	ld a, '.'
	call VD_OUT

	endif ; USE_VIDEO
	
.done:
;	halt			; Wait for next interrupt
	ld a, 250
	call DELAY
	jr MAIN			; Loop back


	endif ; 0

	include "constants.s"
	include "utils/ramtest.s"
	include "utils/timing.s"
	
	ifdef USE_VIDEO
	include "utils/video_driver.s"
	endif ; USE_VIDEO

	ifdef USE_KEYBOARD
	include "utils/keyboard_device.s"
	endif ; USE_KEYBOARD

MESSAGES:
	msg MSG_INIT, "Video initialized.\n"
	msg MSG_KB1, "Keyboard initializing...\n"
	msg MSG_KB2, "Keyboard initialized.\n"
	msg MSG_DONE, "System started\n"

	org $07fe
	word $0000
	end