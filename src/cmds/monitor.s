; ***********************************************************
; Title:	Prints the register states
; Name: 	MONITOR
; Purpose:	
;
; Entry:	Register DE = Pointer to string
; 		Register BC = Size of string
; Exit:		None
;
; Registers used:      A, HL
; ***********************************************************

MONITOR:
	; Start by pushing all values
	push bc
	push de
	push hl
	push af


	; Print AF
	ex (sp), hl
	call .print_top_stack
	ex (sp), hl
	call .del

	pop af
	
	; Print HL
	ex (sp), hl
	call .print_top_stack
	ex (sp), hl
	call .del

	pop hl
	
	; Print DE
	ex (sp), hl
	call .print_top_stack
	ex (sp), hl
	call .del

	pop de
	
	; Print BC
	ex (sp), hl
	call .print_top_stack
	ex (sp), hl
	call .del

	pop bc

	; Print SP
	push hl
	ld hl, 4
	add hl, sp
	call .print_top_stack
	pop hl

	; Print \n
	push af
	ld a, '\n'
	call SH_OUT
	pop af

	ret





.print_top_stack:
	push af
	
	ld a, h
	call PRINTNUM
	ld a, l
	call PRINTNUM
	
	pop af
	ret


.del:
;	ret
	push af
	ld a, ':'
	call SH_OUT
	pop af
	ret
