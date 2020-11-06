; ***********************************************************
; Title:	Checks if ASCII char in A is a digit 0-9
; Name: 	ISDIGIT
; Purpose:	
;
; Entry:	Register A = Character
; 		
; Exit:		If A is a digit
;		   Carry flag = 1
;		else
;		   Carry flag = 0
;
; Registers used:	None 
; ***********************************************************
ISDIGIT:
	push de
	ld e, a
	sub a, '0'
	cp 0ah
	ld a, e
	pop de
	ret
	

; ***********************************************************
; Title:	Checks if ASCII char in A is a letter (A-Za-z)
; Name: 	ISLETTER
; Purpose:	
;
; Entry:	Register A = Character
; 		
; Exit:		If A is a letter
;		   Carry flag = 1
;		else
;		   Carry flag = 0
;
; Registers used:	None
; ***********************************************************
ISLETTER:
	push de
	ld e, a
	and 0dfh	; Make upper case
	sub a, 'A'
	cp 1ah
	ld a, e
	pop de
	ret

; ***********************************************************
; Title:	Checks if ASCII char in A is alpha numberic
; Name: 	ISALPHANUM
; Purpose:	Checks if ASCII char is one of A-Z, a-z or
; 		0-9
;
; Entry:	Register A = Character
; 		
; Exit:		If A is an alphanum
;		   Carry flag = 1
;		else
;		   Carry flag = 0
;
; Registers used:	None
; ***********************************************************
ISALNUM:
	call ISLETTER
	ret c
	jp ISDIGIT




; ***********************************************************
; Title:	Pack string to Radix 40
; Name: 	PACK40
; Purpose:	Converts a 3 letter string to a number using
; 		Radix 40
;
; Entry:	Register DE = Buffer start
; 		
; Exit:		If string fits within Radix40
; 		   Register HL = Radix40
;		   Carry flag = 1
;		else
;		   Carry flag = 0
;
; Registers used:	None
; ***********************************************************
PACK40:
	ld hl, 0
	
	call .toradix
	ret nc

	ld l, a
	
	add hl, hl	; x2
	add hl, hl	; x4
	add hl, hl	; x8
	ld b, h
	ld c, l
	add hl, hl	; x16
	add hl, hl	; x32
	add hl, bc	; x40
	
	inc de

	call .toradix
	ret nc

	add a, l
	ld l, a
	jr nc, .pack40_1
	inc h

.pack40_1:
	add hl, hl	; x2
	add hl, hl	; x4
	add hl, hl	; x8
	ld b, h
	ld c, l
	add hl, hl	; x16
	add hl, hl	; x32
	add hl, bc	; x40

	inc de

	call .toradix
	ret nc

	add a, l
	ld l, a
	jr nc, .done
	inc h
.done:
	scf
	ret

.toradix:
	ld a, (de)
	or a
	scf
	ret z

	sub '0'
	cp 0ah
	jr nc, .char
	add a, 30
	scf
	ret

.char:
	add a, '0'
	or 20h	; Make lower case
	sub a, 'a'
	cp 1ah
	jr nc, .nothing
	inc a
	ret

.nothing:
	or a
	ret
	
	
	
	
	
	
; ***********************************************************
; Title:	Resolve symbol name
; Name: 	SYMBOL_NAME
; Purpose:	Resolves the symbol name if internal function,
; 		converts number to the 3 letter string Radix 40
;
; Entry:	Register HL
; 		
; Exit:		Register DE = Buffer start
;
; Registers used:	HL
; ***********************************************************
SYMBOL_NAME:
	; Check if built in function
	ld a, h
	or a
	jr nz, .unpack
	ld a, l
	cp LOOKUP_TABLE_SIZE
	jr nc, .unpack

	; It's a built in function.
	ld a, l
	add a, a	; Multiply with 4
	add a, a	; Since table entry is 4 bytes
	add a, LOOKUP_TABLE_BEGIN & 0ffh
	ld l, a
	adc a, LOOKUP_TABLE_BEGIN / 100h
	sub l
	ld h, a
	ld e, (hl)
	inc hl
	ld d, (hl)
	ret
	
.unpack:
	ld de, BUFFER_BEGIN
	
	ld c, 40; Divide by 40
	call DIV_HL_C ; HL = Quotient, A=Remainer
	call .from_radix

	ld (de), a
	inc de

	call DIV_HL_C
	call .from_radix

	ld (de), a
	inc de

	call DIV_HL_C
	call .from_radix

	ld (de), a
	inc de

	xor a
	ld (de), a

	ret


.from_radix:
	or a
	ret z

	cp 27
	jr nc, .signs
	add a, 'a'-1
	ret

.signs:
	cp 30
	jr nc, .numbers
	xor a
	ret
.numbers:
	cp 40
	jr nc, .end
	add a, '0'-30
	ret
.end:
	xor a
	ret
	
	
	
