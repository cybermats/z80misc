	cpu Z80UNDOC

	include "utils/flow_macro.s"

; Constants
WORKSPACE_BEGIN:	equ	09000h
WORKSPACE_END:		equ	09100h
;WORKSPACE_END:		equ	0a000h

ZERO_T:			equ	00h
SYMBOL_T:			equ	02h
NUMBER_T:			equ	04h
PAIR_T:			equ	06h




;	org 00h
BEGIN:
	ld sp, 0000h
SETUP:
	call INIT_ENV
	call INIT_WORKSPACE
REPL:
	call READ
	call EVAL
	call WRITE
	halt
	jr REPL
	

INIT_ENV:
	xor a
	ld h, a
	ld l, a

	ld (FREESPACE), hl
	ld (FREELIST), hl
	ld (GLOBALENV), hl

	ld hl, INPUT_BUFFER
	ld (INPUT_CURSOR), hl
	ret		


EVAL:
PRINTOBJ:
	ret


INPUT_CURSOR:
	dw INPUT_BUFFER
INPUT_BUFFER:
	db "(symbols nil t lambda 1 2 3)", 0






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
; Entry:	Register IX = First of pair
; 		Register DE = Second of pair
; 		
; Exit:		Register IX = Object
;
; Registers used:      HL
; ***********************************************************
CONS:
	push hl
	ld b, ixu
	ld c, ixl
	call MALLOC
	jr z, .done

	ld (ix), c
	ld (ix+1), b
	ld (ix+2), e
	ld (ix+3), d
.done:
	pop hl
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
	; TODO: Only check the active cells. Not everything.

	; Check if something already exists.
	ex hl, de
	ld hl, (FREELIST)
	ld bc, (-WORKSPACE_BEGIN)& 0ffffh
	add hl, bc
	ld b, h
	ld c, l
	ex hl, de
	ld a, b
	or c
	jp z, SYMBOL
	
	srl b
	rr c
	srl b
	rr c
	ld de, 4

	ld ix, WORKSPACE_BEGIN

.loop:
	ld a, (ix)
	cp SYMBOL_T
	jp nz, .inc

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
	jp nz, .loop

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
; Title:	Read a full list
; Name: 	READ_LIST
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
READ_LIST:
	ld ix, 0	; Obj
	ld iy, 0	; Head
	call READ
	ret c

	; Check if EOF
	ld a, ixu
	or ixl
	jr z, .eof

	; Create new cons
	ld de, 0
	call CONS
	ld b, ixu	; Tail
	ld c, ixl
	ld iyu, b
	ld iyl, c
	push iy		; Save head for later
.loop:
	call READ
	ret c

	ld a, ixu
	or ixl
	jr z, .eof

	ld de, 0
	call CONS
	
	ld b, ixu	; Tail
	ld c, ixl

	ld (iy+2), c
	ld (iy+3), b

	ld iyh, b
	ld iyl, c
	
	jp .loop
	
	
.eof:
	call GETC
	cp ')'
	jp z, .done
	scf
.done:
	pop ix
	ret


; ***********************************************************
; Title:	Read input
; Name: 	READ
; Purpose:	Parses input and returns an object
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
	ld ix, 0
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
			jp READ_LIST	; Return from READLIST
		_endcase

		cp ')'		; Error if end of list
		_case z
			call UNGETC
			ld ix, 0
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
			jr nz, .string_pack	; If h!=0, no internal func.
			ld a, l
			cp LOOKUP_TABLE_SIZE
			jr c, .string_symbol
.string_pack:
			; Convert to Radix40
			; Check that string length is <= 3
			ld de, BUFFER_BEGIN
			call PACK40
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
; Title:	Write object to output
; Name: 	WRITE
; Purpose:	Outputs the object to stdout
;
; Entry:	Register IX = Object
; 		
; Exit:		None
;
; Registers used:      
; ***********************************************************
WRITE:
	; Check nil
	ld a, ixu
	or ixl
	jr nz, .check_types
	ld a, '('
	call PUTC
	ld a, ')'
	call PUTC
	ret
	
.check_types:
	ld a, (IX+1)	; Check MSB. If non-zero
	or a  		; it is a PAIR
	jr nz, .pair
	ld a, (IX)	; Check which type
	cp SYMBOL_T
	jr z, .symbol
	cp NUMBER_T
	jr z, .number

.pair:
	ld a, '('
	call PUTC
	push ix
	ld b, (ix+1)
	ld c, (ix)
	ld ixh, b
	ld ixl, c
	call WRITE
	ld a, ' '
	call PUTC
	pop ix
	ld b, (ix+3)
	ld c, (ix+2)
	ld ixh, b
	ld ixl, c
	ld a, '.'
	call PUTC
	ld a, ' '
	call PUTC
	call WRITE
	ld a, ')'
	call PUTC
	ret

.symbol:
	ld l, (ix+2)
	ld h, (ix+3)
	call SYMBOL_NAME
.s_loop:
	ld a, (de)
	or a
	ret z
	call PUTC
	inc de
	jr .s_loop

.number:
	ld l, (ix+2)
	ld h, (ix+3)
	ld bc, 16
	ld de, BUFFER_BEGIN
	call ITOA
	ld de, BUFFER_BEGIN
.n_loop:
	ld a, (de)
	or a
	ret z
	call PUTC
	inc de
	jr .n_loop
	
	


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


PUTC:
	out (00), a
	ret


	include "utils/char_helper.s"
	include "lisp/memory.s"
	include "utils/stdlib.s"
	include "utils/math.s"



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




STR_FN_SYMBOLS:
	db "symbols", 0
STR_FN_NIL:
	db "nil", 0
STR_FN_T:
	db "t", 0
STR_FN_LAMBDA:
	db "lambda", 0
STR_FN_QUOTE:
	db "quote", 0
STR_FN_DEFUN:
	db "defun", 0
STR_FN_DEFVAR:
	db "defvar", 0
STR_FN_SETQ:
	db "setq", 0
STR_FN_IF:
	db "if", 0
STR_FN_NOT:
	db "not", 0
STR_FN_NULLFN:
	db "null", 0
STR_FN_CONS:
	db "cons", 0
STR_FN_ATOM:
	db "atom", 0
STR_FN_LISTP:
	db "listp", 0
STR_FN_CONSP:
	db "consp", 0
STR_FN_SYMBOLP:
	db "symbolp", 0
STR_FN_EQ:
	db "eq", 0
STR_FN_CAR:
	db "car", 0
STR_FN_CDR:
	db "cdr", 0
STR_FN_EVAL:
	db "eval", 0
STR_FN_GLOBALS:
	db "globals", 0
STR_FN_LOCALS:
	db "locals", 0



 

LOOKUP_TABLE_BEGIN:
	dw STR_FN_SYMBOLS, 0
	dw STR_FN_NIL, 0
	dw STR_FN_T, 0
	dw STR_FN_LAMBDA, 0
	dw STR_FN_QUOTE, 0
	dw STR_FN_DEFUN, 0
	dw STR_FN_DEFVAR, 0
	dw STR_FN_SETQ, 0
	dw STR_FN_IF, 0
	dw STR_FN_NOT, 0
	dw STR_FN_NULLFN, 0
	dw STR_FN_CONS, 0
	dw STR_FN_ATOM, 0
	dw STR_FN_LISTP, 0
	dw STR_FN_CONSP, 0
	dw STR_FN_SYMBOLP, 0
	dw STR_FN_EQ, 0
	dw STR_FN_CAR, 0
	dw STR_FN_CDR, 0
	dw STR_FN_EVAL, 0
	dw STR_FN_GLOBALS, 0
	dw STR_FN_LOCALS, 0
	
LOOKUP_TABLE_END:
	dw 0		  ; End of table
LOOKUP_TABLE_SIZE:   equ	(LOOKUP_TABLE_END - LOOKUP_TABLE_BEGIN) / 4

	end