	cpu Z80UNDOC

	include "utils/flow_macro.s"

; Constants
WORKSPACE_BEGIN:	equ	09000h
WORKSPACE_END:		equ	09100h
;WORKSPACE_END:		equ	0a000h
STACK_BEGIN:		equ 	0000h

ZERO_T:			equ	00h
SYMBOL_T:			equ	02h
NUMBER_T:			equ	04h
PAIR_T:			equ	06h




;	org 00h
BEGIN:
	ld sp, STACK_BEGIN
SETUP:
	call INIT_ENV
	call INIT_WORKSPACE
REPL:
	call READ
	call EVAL
	push ix
	call WRITE
	ld a, '\n'
	call PUTC
	pop iy
	ld hl, 0
	call VALUE
	call WRITE
	ld a, '\n'
	call PUTC
REPL_ERROR:
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
;	db "(symbols nil t lambda 1 2 3)", 0
	db "((symbols t) (lambda 1))", 0, 0, 0, 0



; ***********************************************************
; Title:	Error handling
; Name: 	ERROR
; Purpose:	Writes out the error code and returns to REPL
;
; Entry:	Register A = Error code
; 		
; Exit:		None
;
; Registers used:	None
; ***********************************************************
ERROR:
	ld de, BUFFER_BEGIN
	ld bc, 16
	ld l, a
	xor a
	ld h, a
	call ITOA

	ld sp, STACK_BEGIN
	ld de, BUFFER_BEGIN
.loop:
	ld a, (de)
	inc de
	or a
	jp z, REPL_ERROR
	call PUTC
	jr .loop


; ***********************************************************
; Title:	Get value for symbol
; Name: 	VALUE
; Purpose:	Resolve the value for a symbol from a
; 		given environment
;
; Entry:	Register HL = Symbol Name
; 		Register IY = Environment
; 		
; Exit:		Register IX = Object
;
; Registers used:	None
; ***********************************************************
VALUE:
	ld ix, 0
.loop:
	ld a, iyl	; Check empty env
	or iyh
	jr z, .done
	ld d, (iy+1)	; Car(env)	
	ld e, (iy+0)
	ld a, d		; Check if car(env) == null
	or e
	jr z, .inc
	
	ld ixh, d
	ld ixl, e
	
	ld d, (ix+1)	; car(car(env)) 
	ld e, (ix+0)

	ex hl, de
	ld a, (hl)	; Check type
	cp SYMBOL_T
	jr nz, .error	; Malformed. Should be of type SYMBOL
	inc hl
	ld a, (hl)
	or a
	jr nz, .error	; Malformed. This should be null.
	inc hl 		; It's all good. Get the actual value and compare
	ld a, (hl)
	inc hl
	ld h, (hl)
	ld l, a
	
	sbc hl, de	; Compare name of value
	add hl, de
	ex hl, de
	jr z, .done

.inc:
	ld d, (iy+3)	; env = cdr(env)
	ld e, (iy+2)
	ld iyh, d
	ld iyl, e
	jp .loop
.done:
	ret
.error:
	ld a, 5
	jp ERROR

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
; Registers used:	AF
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
; Registers used:      DE, IX
; ***********************************************************
CONS:
	push hl
	push bc
	ld b, ixu
	ld c, ixl
	call MALLOC
	jr z, .done

	ld (ix), c
	ld (ix+1), b
	ld (ix+2), e
	ld (ix+3), d
.done:
	pop bc
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
; Exit:		Register IX = Cons
;
; Registers used:      A, HL, BC
; ***********************************************************
READ_LIST:
	ld iy, 0	; Head
	push iy
	call READ
	pop iy

	; Check if EOF
	ld a, ixu
	or ixl
	jr z, .eof1

	; Create new cons
	ld de, 0
	call CONS
	ld b, ixu	; Tail
	ld c, ixl
	ld iyu, b
	ld iyl, c
	push iy		; Save head for later
.loop:
	push iy
	call READ
	pop iy

	ld a, ixu
	or ixl
	jr z, .eof2

	ld de, 0
	call CONS
	
	ld b, ixu	; Tail
	ld c, ixl

	ld (iy+2), c
	ld (iy+3), b

	ld iyh, b
	ld iyl, c
	
	jp .loop
	
.eof2:
	pop ix
.eof1:
	call GETC
	cp ')'
	ret z
	ld a, 4
	jp ERROR
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
; Exit:		Register IX = Cons
;
; Registers used:      AF, HL, BC, DE, IX
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
			jp nz, .digit_cont
			ld a, 1
			jp ERROR
.digit_cont:	
			call GETC
			call ISDIGIT
			jr c, .digit_loop

			call UNGETC
			xor a
			ld (de), a

			ld de, BUFFER_BEGIN
	
			call ATOI
			jp NUMBER	; Return from Number
		_endcase

		cp '('			; Check if start of list
		_case z
			jp READ_LIST	; Return from READLIST
		_endcase

		cp ')'			; Error if end of list
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
			jr nz, .string_cont
			ld a, 2
			jp ERROR
.string_cont:
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
			jr c, .string_symbol
			ld a, 3
			jp ERROR
.string_symbol:
			jp NEW_SYMBOL
		_endcase

_READ_default:
		; Default
		ld a, 4
		jp ERROR
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
GC_ROOT:
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