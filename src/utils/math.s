
; ***********************************************************
; Title:	Divide 16/8 bits.
; Name: 	DIV_HL_C
; Purpose:	
;
; Entry:	Register HL = Dividend
; 		Register C = Divisor
; 		
; Exit:		Register HL = Quotient
; 		Register A = Remainder
;
; Registers used: A, BC, HL
; ***********************************************************

DIV_HL_C:
	xor a
	ld b, 16

.loop:
	add hl, hl
	rla
	jr c, $+5
	cp c
	jr c, $+4

	sub c
	inc l

	djnz .loop

	ret

; ***********************************************************
; Title:	Divide 16/8 bits.
; Name: 	DIV_D_E
; Purpose:	
;
; Entry:	Register D = Dividend
; 		Register E = Divisor
; 		
; Exit:		Register D = Quotient
; 		Register A = Remainder
;
; Registers used: A, B, DE
; ***********************************************************
DIV_D_E:
	xor a
	ld b, 8

.loop:
	sla d
	rla
	cp e
	jr c, $+4
	sub e
	inc d

	djnz .loop

	ret


; ***********************************************************
; Title:	Divide 16/16 bits.
; Name: 	DIV_BC_DE
; Purpose:	
;
; Entry:	Register BC = Dividend
; 		Register DE = Divisor
; 		
; Exit:		Register BC = Quotient
; 		Register HL = Remainder
;
; Registers used: HL, BC, DE, A   
; ***********************************************************
DIV_AC_DE:
	ld hl, 0
	ld a, b
	ld b, 8
.loop1:
	rla
	adc hl, hl
	sbc hl, de
	jr nc, .noadd1
	add hl, de
.noadd1:
	djnz .loop1
	rla
	cpl
	ld b, a
	ld a, c
	ld c, b
	ld b, 8
.loop2:
	rla
	adc hl, hl
	sbc hl, de
	jr nc, .noadd2
	add hl, de
.noadd2:
	djnz .loop2
	rla
	cpl
	ld b, c
	ld c, a
	ret
