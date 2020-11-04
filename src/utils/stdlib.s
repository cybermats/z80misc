; ***********************************************************
; Title:	Ascii to Integer
; Name: 	ATOI
; Purpose:	Converts a number represented in Ascii
;
; Entry:	Register DE = char*
; 		
; Exit:		Register DE = Next Char*
; 		Register HL = Signed result
;		Carry set on overflow
;
; Registers used:
; ***********************************************************
ATOI:
	ld a, (de)
	inc de
	cp '+'
	jp z, ATOU	; Positive number

	dec de
	cp '-'
	jp nz, ATOU	; Not a negative number

	inc de 		; Negative number, so move 
	call ATOU	; pointer to the actual number.
	jp NEG
	

; ***********************************************************
; Title:	Ascii to Unsigned Integer
; Name: 	ATOU
; Purpose:	Converts a number represented in Ascii
;
; Entry:	Register DE = char*
; 		
; Exit:		Register DE = Next Char*
; 		Register HL = Unsigned result
;		Carry set on unsigned overflow
;
; Registers used:
; ***********************************************************
ATOU:
	ld hl, 0
	dec de		; Set up for loop
	push hl		; Dummy push to prepare for loop

.loop:
	pop af		; Restore stack

	inc de
	ld a, (de)

	sub '0'
	cp 10
	ret nc

	push hl		; Save before 10x

	add hl, hl	; 2x
	jr c, .overflow	; Exit if overflowing

	ld c, l
	ld b, h		; Save 2x

	add hl, hl	; 4x
	jr c, .overflow	; Exit if overflowing

	add hl, hl	; 8x
	jr c, .overflow	; Exit if overflowing


	add hl, bc	; Add back 2x = 10x
	jr c, .overflow	; Exit if overflowing

	add a, l	; Add in new number
	ld l, a		
	jr nc, .loop	; Check if we've got a carry

	inc h  		; Adjust h if carry
	jr nz, .loop

.overflow:
	pop hl
	scf
	ret

; ***********************************************************
; Title:	Negate number
; Name: 	NEG
; Purpose:	Unary negative for shorts
;
; Entry:	Register HL = Short
; 		
; Exit:		Register HL = - HL
;
; Registers used:
; ***********************************************************
NEG:
	ld a, h
	cpl
	ld h, a
	ld a, l
	cpl
	ld l, a
	inc hl
	ret


; ***********************************************************
; Title:	Unsigned Integer to ASCII
; Name: 	UTOA
; Purpose:	Converts a number represented in Ascii
;
; Entry:	Register HL = Uint num
; 		Register BC = int radix [2,36]
;		Register DE = Buffer
; 		
; Exit:		Register DE = Address of terminating 0
;		Carry reset no errors
;
; Registers used:
; ***********************************************************
UTOA:
	xor a
	push af		; End of digits marked by carry reset
.compute_lp:
	call DIV_HL_C
	call .num2char
	scf
	push af		; Digit onto stack

	ld a, h
	or l
	jr nz, .compute_lp

.write_lp:
	pop af
	ld (de), a
	inc de

	jr c, .write_lp

	; Last write above was NUL

	dec de
	ret

.num2char:
	cp 10
	jr nc, .alpha

	add a, '0'
	ret

.alpha:
	add a, 'A'-10
	ret
	
	


; ***********************************************************
; Title:	Signed Integer to ASCII
; Name: 	ITOA
; Purpose:	Converts a number represented in Ascii
;
; Entry:	Register HL = int num
; 		Register BC = radix
;		Register DE = Buffer
; 		
; Exit:		Register HL = Address of terminating 0
;
; Registers used: AF, BC, DE, HL, IX
; ***********************************************************
ITOA:
	ld a, c
	cp 10
	jp nz, UTOA

	bit 7, h	; Number positive?
	jp z, UTOA

	call NEG

	ld a, '-'
	ld (de), a
	inc de

	ld a, 10
	jp UTOA