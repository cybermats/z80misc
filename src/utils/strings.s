; Title:	Strings library
; Purpose:	A general string library


; Title:	STRLEN
; Purpose:	Returns length of null terminated string.
;
; Entry:	Register pair HL = Base address of string
; 		Register pair BC = Length of buffer
;
; Exit:		If the buffer contains a null character:
; 		   Carry flag = 0
;  		   Register BC = Length of string
;		else
;		   Carry flag = 1

STRLEN:
	push hl
	push de

;	ld de, bc
	ld a, 0		; We search for the null value
	cpir  		; Search the string

	jr z, .found	; We found the end

	; We didn't find an end for this string
	scf
	jr .done

.found
	jp pe, .string_is_shorter_than_buffer
;	ld bc, de
	dec bc
	jr .done

.string_is_shorter_than_buffer
;	ld hl, de
	scf
	sbc hl, bc
	ccf
;	ld bc, hl
.done
	pop de
	pop hl
	ret
	

; Title:	ATOI
; Purpose:	Creates a null terminated string representation
; 		of a number. Only HEX for now.
;
; Entry:	Register pair HL = Base address of string buffer
; 		Register pair BC = Size of buffer
; 		Register A = Value to be converted
;
; Exit:		HL is filled with the representation of the
; 		value in A, together with a null termination.
;		If buffer is enough
;		   Carry flag = 0
;		else
;		   Carry flag = 1
;

ITOA:
	push hl
	push bc
	push de
	ld e, a		; Save a for later

	ld a, b		; Check if the size is zero
	or c
	jr nz, .buffer_exists
	scf		; We have an empty buffer. Set flag and exit
	jr .done

.buffer_exists

	dec bc		; Check if the size is one, which means we
	    		; just set the null terminator and exits
	ld a, b
	or c
	jr z, .add_null

	ld a, e		; Restore the original a

			; Get the first hex character by shifting
			; a right four times.
	srl a
	srl a
	srl a
	srl a

	cp $a		; Check if the value is greater than or equal
	   		; to $a
	jp m, .below_a_first
	add 'A'-'0'-10	; Add the difference between '0' and 'A'

.below_a_first

	add '0'
	ld (hl), a
	inc hl
	dec bc

	ld a, b		; Check that we still have room in the buffer
	or c
	jr z, .add_null

	ld a, e		; Restore the original a
	and $0f		; and mask it to the lower four bits


	cp $a		; Check if the value is greater than or equal
	   		; to $a
	jp m, .below_a_second
	add 'A'-'0'-10	; Add the difference between '0' and 'A'

.below_a_second

	add '0'
	ld (hl), a
	inc hl

.add_null
	ld (hl), 0
.done
	pop de
	pop bc
	pop hl
	ret