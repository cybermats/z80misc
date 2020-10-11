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


	ld hl, INT_TABLE		; Clear interrupt table
	xor a
	ld (hl), a
	ld d, h
	ld e, l
	inc de
	ld bc, INT_TABLE_END - INT_TABLE - 2
	ldir
					

	ld hl, KEYBOARD_INT		; Prime with keyboard interrupt
	ld (INT_KB), hl

	ld hl, SERIAL_INT		; Prime with serial interrupt
	ld (INT_SR), hl
	
	ld a, INT_TABLE >> 8		; Set up interrupt page
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
	call SH_OUTN

	IF INC_SERIAL
	    	; Set up serial
		ld a, INT_SR - INT_TABLE
		call SER_CONFIGURE

		ld a, 5h		; Indicate that the serial has been configured
		out (OUTPORT), a
	ENDIF

	; Set up keyboard
	ld a, INT_KB - INT_TABLE
	call KD_CONFIGURE

	ld a, 6h		; Indicate that the keyboard has been configured
	out (OUTPORT), a

	
	; All done

	ld hl, MSG_DONE
	ld bc, MSG_DONE_LEN
	call SH_OUTN

	ei
	jp MAIN



MESSAGES:
	msg MSG_INIT, "Init..."
	msg MSG_DONE, "Ok\n"
