	include "utils/flow_macro.s"

; Constants
WORKSPACE_BEGIN:	equ	09000h
WORKSPACE_END:		equ	09008h
;WORKSPACE_END:		equ	0a000h

ZERO_T:			equ	00h
SYMBOL_T:			equ	02h
NUMBER_T:			equ	04h
PAIR_T:			equ	06h




;	org 00h
BEGIN:
	ld sp, 0000h
SETUP:
	call INIT_WORKSPACE
	call INIT_ENV
REPL:
	call READ
	call EVAL
	call PRINTOBJ
	halt
	jr REPL
	

INIT_ENV:
EVAL:
PRINTOBJ:
READLIST:
	ret








; ***********************************************************
; Title:	Create symbol
; Name: 	NUMBER
; Purpose:	Makes a new Symbol
;
; Entry:	Register HL = Symbol Name
; 		
; Exit:		Register IX = Object
;
; Registers used:	None
; ***********************************************************
SYMBOL:
	call MALLOC
	ret z

	ld (ix), SYMBOL_T
	ld (ix+1), 0
	ld (ix+2), l
	ld (ix+3), h

	ret
	
	
; ***********************************************************
; Title:	Create Number
; Name: 	NUMBER
; Purpose:	Makes a new Number
;
; Entry:	Register HL = Value of number
; 		
; Exit:		Register IX = Object
;
; Registers used:	HL
; ***********************************************************
NUMBER:
	call MALLOC
	ret z

	ld (ix), NUMBER_T
	ld (ix+1), 0
	ld (ix+2), l
	ld (ix+3), h

	ret
	
	
; ***********************************************************
; Title:	Create Cons
; Name: 	CONS
; Purpose:	Makes a new Cons
;
; Entry:	Register HL = First of pair
; 		Register DE = Second of pair
; 		
; Exit:		Register IX = Object
;
; Registers used:      HL
; ***********************************************************
CONS:
	call MALLOC
	ret z

	ld (ix), l
	ld (ix+1), h
	ld (ix+2), e
	ld (ix+3), d

	ret


; ***********************************************************
; Title:	New Symbol
; Name: 	NEW_SYMBOL
; Purpose:	Takes a name for a symbol and checks if it
; 		already exists. If it does, it's reused,
; 		otherwise a new one is created.
;
; Entry:	Register HL = Name
; 		
; Exit:		Register IX = Object
;
; Registers used:      IX, BC, A, DE
; ***********************************************************
NEW_SYMBOL:

	; Check if something already exists.
	ld ix, WORKSPACE_BEGIN
	ld bc, (WORKSPACE_END - WORKSPACE_BEGIN) / 4
	ld de, 4

.loop:
	ld a, (ix)
	cp SYMBOL_T
	jr nz, .inc

	ld a, (ix+1)
	cp 0
	jr nz, .inc

	ld a, (ix+2)
	cp l
	jr nz, .inc
	
	ld a, (ix+3)
	cp h
	jr nz, .inc
	
	ret

.inc:
	add ix, de
	dec bc
	ld a, b
	or c
	jr nz, .loop

	; It doesn't exist. Create new.
	jp SYMBOL

	

; ***********************************************************
; Title:	Lookup built in functions
; Name: 	BUILTIN
; Purpose:	Looks through the lookup table to find
; 		if we have a built in function.
;
; Entry:	Register DE = Pointer to buffer
; 		
; Exit:		Register HL = Symbol name
;
; Registers used:      A, HL, BC, DE, IX
; ***********************************************************
BUILTIN:
	ex hl, de
	push hl
	ld de, 0	; Entry counter
	ld ix, LOOKUP_TABLE_BEGIN

.row_loop:
	ld c, (ix)
	ld b, (ix + 1)
.item_loop:
	ld a, (bc)

	or a
	jr z, .item_end

	cp (hl)
	inc bc
	inc hl
	
	jr z, .item_loop
	; Not same
.next_row:
	inc de	; Increase 
	
	inc ix	; Next item
	inc ix
	inc ix
	inc ix

	ld a, (ix)	; Check if we're at the end.
	ld c, (ix+1)
	or c
	jr z, .not_found

	pop hl
	push hl
	jr .row_loop

.item_end:
	cp (hl)
	jr nz, .next_row
.not_found:
	pop hl
	ex hl, de
	ret




; ***********************************************************
; Title:	Read input
; Name: 	READ
; Purpose:	Parses input and returns a list
;
; Entry:	None
; 		
; Exit:		If successful
; 		   Register IX = Cons
;		   Flag C = 0
;		Else
;		   Flag C = 1
;
; Registers used:      A, HL, BC
; ***********************************************************
READ:
	call GETC
	
	_switch

		or a		; End of file?
		_case z
		      ret
		_endcase

		cp ' '		; Skip white spaces
		_case z		; Todo: Add \t, \n
			jp READ
		_endcase

		call ISDIGIT
		_case c
.do_digits:

			ld de, BUFFER_BEGIN
			ld bc, BUFFER_END - BUFFER_BEGIN
.digit_loop:
			ld (de), a
			inc de
	
			dec bc
			ld a, b
			or c
			jp z, _READ_default
	
			call GETC
			call ISDIGIT
			jr c, .digit_loop

			call UNGETC
			xor a
			ld (de), a

			ld de, BUFFER_BEGIN
	
			call ATOI
			call NUMBER

			or a		; Reset flags
			ret
		_endcase

		cp '('		; Check if start of list
		_case z
			jp READLIST	; Return from READLIST
		_endcase

		cp ')'		; Error if end of list
		_case z
			scf
		      	ret
		_endcase

		cp '-'
		_case z
			push de
			ld e, a
			call GETC
			call UNGETC
			call ISDIGIT
			ld a, e
			pop de
			jr c, .do_digits
			jp .do_string
		_endcase

		call ISLETTER
		_case c
			; Handle string
.do_string:
			; Prewarm the string if it's too short.
			ld e, a
			xor a
			ld ((BUFFER_BEGIN+2)), a
			ld a, e
			
			ld de, BUFFER_BEGIN
			ld bc, BUFFER_END - BUFFER_BEGIN
			
.string_loop:
			ld (de), a
			inc de

			dec bc
			ld a, b
			or c
			jr z, _READ_default

			call GETC
			call ISALNUM
			jr c, .string_loop

			call UNGETC
			xor a
			ld (de), a

			ld de, BUFFER_BEGIN
			call BUILTIN
			ld a, h
			or a
			jr nz, .string_pack
			ld a, l
			cp LOOKUP_TABLE_SIZE
			jr nc, .string_symbol
.string_pack:
			; Convert to Radix40
			; Check that string length is <= 3
			ld de, BUFFER_BEGIN
			ld a, (de)
			or a
			jr z, _READ_default
			call ISALNUM
			jr nc, _READ_default
			
			


.string_symbol:
			call NEW_SYMBOL

			or a
			ret
		_endcase

_READ_default:
		; Default
		scf		; Unknown string. Return error
		ret

	_endswitch


; ***********************************************************
; Title:	Get next character from input
; Name: 	GETC
; Purpose:	Reads the next character from the input
;
; Entry:	None
; 		
; Exit:		If character is available:
; 		   Register A = value
;		   Carry flag = 0
;		else
;		   Carry flag = 1
;
; Registers used:      
; ***********************************************************
GETC:
	push hl
	ld hl, (INPUT_CURSOR)
	ld a, (hl)
	inc hl
	ld (INPUT_CURSOR), hl
	pop hl
	ret

UNGETC:
	push hl
	ld hl, (INPUT_CURSOR)
	dec hl
	ld (INPUT_CURSOR), hl
	pop hl
	ret

	include "utils/char_helper.s"
	include "lisp/memory.s"
	include "utils/stdlib.s"



; Data
BUFFER_BEGIN:
	ds 10h
BUFFER_END:
FREESPACE:
	dw 0h
FREELIST:
	dw 0h
GLOBALENV:
	dw 0h


INPUT_CURSOR:
	dw INPUT_BUFFER
INPUT_BUFFER:
	db "+1", 0


STR_FN_SYMBOLS:
	db "symbols", 0
STR_FN_NIL:
	db "nil", 0
STR_FN_T:
	db "t", 0
STR_FN_LAMBDA:
	db "lambda", 0


LOOKUP_TABLE_BEGIN:
	dw STR_FN_SYMBOLS, 0
	dw STR_FN_NIL, 0
	dw STR_FN_T, 0
	dw STR_FN_LAMBDA, 0
LOOKUP_TABLE_END:
	dw 0		  ; End of table
LOOKUP_TABLE_SIZE:   equ	(LOOKUP_TABLE_END - LOOKUP_TABLE_BEGIN) / 4

	end