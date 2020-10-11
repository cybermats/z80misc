

; ***********************************************************
; Title:	Print memory content
; Name: 	PRINTMEM_ARG
; Purpose:	Does a hex dump of the specified memory
; 		using OUTCH.
; Entry:	Register DE - Base address of string containing arguments
; 		Register BC = Size of string
; Exit:		None
;
; Registers used: DE, HL
; ***********************************************************
PRINTMEM_ARG:
	ex de, hl	; Ignore first token
	xor a
	cp (hl)		; Check if there is a first arg
	ret z		; No, exit

	
	call READNUM	; Parse address arg into short
	push de		; Save value
	jr c, .error	; Check if we could parse

	ld a, RS
	cpir
	jp po, .error
	
	call READNUM	; Parse size arg into byte
	jr c, .error	; Check if we could parse
	ld c, e		; Second arg is < 256.
	pop hl		; Restore address
	jr PRINTMEM
.error:
	pop hl
	call SH_HOW
	ret


; ***********************************************************
; Title:	Print memory content
; Name: 	PRINTMEM
; Purpose:	Does a hex dump of the specified memory
; 		using SH_OUT.
; Entry:	Register HL - Base address
; 		Register C - Length
; Exit:		None
;
; Registers used:      HL, BC
; ***********************************************************

PRINTMEM:
	xor a			; Check length
	or c
	ret z			; If zero, quit

	ld b, 16
	ld a, c
	cp b
	jr nc, .pm1
	ld b, c

	; Print header
.pm1:	ld a, h
	call PRINTNUM
	ld a, l
	call PRINTNUM
	ld a, ' '
	call SH_OUT
	ld a, ' '
	call SH_OUT

	; Print memory dump in hex
.pm2:	ld a, (hl)
	call PRINTNUM
	ld a, ' '
	call SH_OUT
	ld a, b
	cp 9
	jr nz, .pm3
	ld a, ' '
	call SH_OUT
	

.pm3:	inc hl
	dec c
	dec b
	jr nz, .pm2
	ld a, '\n'
	call SH_OUT
	jr PRINTMEM


