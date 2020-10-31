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
	call ISDIGIT
	ret c
	jp ISLETTER


