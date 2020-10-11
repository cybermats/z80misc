
; ***********************************************************
; Title:	Echos all arguments
; Name: 	ECHO
; Purpose:	
;
; Entry:	Register DE = Pointer to string
; 		Register BC = Size of string
; Exit:		None
;
; Registers used:      A, HL
; ***********************************************************
ECHO:
	; Ignore first token
	ex de, hl
	xor a
	cp (hl)		; Check null pointer
	ret z		; Yes, exit

.loop:
	ld a, (hl)
	cp RS
	jr z, .next
	call SH_OUT
	inc hl
	jr .loop

.next:
	inc hl
	ld a, (hl)
	or a
	jr z, .end
	ld a, ' '
	call SH_OUT
	jr .loop
	
.end:
	ld a, '\n'
	call SH_OUT
	ret


