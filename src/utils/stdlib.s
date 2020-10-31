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
	