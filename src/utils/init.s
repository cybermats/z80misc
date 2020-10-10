; ********************************************
;
; Init
;
; ********************************************


INIT:
	di
	ld a, 1h
	out (OUTPORT), a
	ld SP, STACK_START		; Set Stack to end of memory
	ld a, 07h			; Set up interrupt page
	ld i, a				; 
	im 2				; Set interrupt mode 2
	
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
	; Set up Video
	ld a, 3h		; Indicate that the system starts
	out (OUTPORT), a

	call VD_CONFIGURE
	
	ld a, 4h		; Indicate that the video has been configured
	out (OUTPORT), a

	ld hl, MSG_INIT
	ld bc, MSG_INIT_LEN
	call VD_OUTN

	; Set up keyboard
	ld a, INT_KEYBOARD_IDX
	call KD_CONFIGURE


	; All done
	ld a, 5h		; Indicate that the system is ok
	out (OUTPORT), a

	ld hl, MSG_DONE
	ld bc, MSG_DONE_LEN
	call VD_OUTN

	ei
	jp MAIN



MESSAGES:
	msg MSG_INIT, "Init..."
	msg MSG_DONE, "Ok\n"
