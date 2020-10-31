; ***********************************************************
; Title:	Bios interface
; Name: 	BIOS
; Purpose:	Entry point for all BIOS functions
;
; Entry:	Register C  = function number
; 		Register DE = argument to function
; 		
; Exit:		None
;
; Registers used:      Probably all
; ***********************************************************

BIOS:
	ld a, c
	cp BIOS_TABLE_LEN / 2
	jr nc, .unknown

	ld b, 0
	sla c
	ld hl, BIOS_TABLE
	add hl, bc

	ld a, (hl)
	inc hl
	ld h, (hl)
	ld l, a

	ld a, e

	jp (hl)

.unknown:
	ld hl, 0ffffh
	ret

	align 2
BIOS_TABLE:
	dw INIT
	dw SH_IN
	dw SH_IN_NH
	dw SH_OUT
	dw SH_OUTN
	dw VD_CURSOR_SHOW
BIOS_TABLE_LEN: equ $ - BIOS_TABLE	