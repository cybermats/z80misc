

CMD_TABLE:
	db "ECHO", US
	dw ECHO
	db "DUMP", US
	dw PRINTMEM_ARG
	db "RUN", US
	dw RUN_ARG
	IF INC_XMODEM
		db "XM", US
		dw XMODEM
	ENDIF
	db 0

	msg MSG_PMT,	"> "
	msg MSG_ERR, 	"Error\n"
	msg MSG_HOW, 	"How?\n"
	msg MSG_WHAT, 	"What?\n"

SH_ERR:
	ld hl, MSG_ERR
	ld bc, MSG_ERR_LEN
	call SH_OUTN
	ret

SH_HOW:
	ld hl, MSG_HOW
	ld bc, MSG_HOW_LEN
	call SH_OUTN
	ret
	
SH_WHAT:
	ld hl, MSG_WHAT
	ld bc, MSG_WHAT_LEN
	call SH_OUTN
	ret
SH_IN:
;	jp (KD_NEXT_KVAL)
	call KD_NEXT_VAL
	ret nc
	
	IF INC_SERIAL
		call SR_NEXT_VAL
	   	ret nc
	ENDIF
	halt
	jr SH_IN

SH_OUT:
	IF INC_SERIAL
		out (OUTPORT), a
		call SER_SEND
	ENDIF
	jp (VD_OUT)

SH_OUTN:
	ld a, (HL)
	or a
	ret z
	call SH_OUT
	inc hl
	dec bc
	ld a, b
	or c
	ret z
	jr SH_OUTN
;	jp (VD_OUTN)


; ***********************************************************
; Title:	A simple shell
; Name: 	SHELL
; Purpose:	Shell that provides
; 		 * Prompt
;		 * Parser
;		 * Command Table
;		It parses the input and starts a matching
; 		command if found.
;
; Entry:	None
; 		
; Exit:		Never exits
;
; Registers used:      A, HL, BC
; ***********************************************************
SHELL:
	ld hl, MSG_PMT
	ld bc, MSG_PMT_LEN
	call SH_OUTN		; Print prompt

	ld hl, IBUFFER
	ld bc, IBUFEND - IBUFFER - 2 ; For an extra null terminator
	call READ_LN		; Read line
	jr z, SHELL		; Jump if no line has been read

	ld hl, IBUFFER
	ld bc, IBUFEND - IBUFFER - 1
	call TOKN_LN		; Tokenize line

	ld hl, IBUFFER
	ld bc, IBUFEND - IBUFFER - 1
	call SH_EXEC		; Execute command

	jr SHELL


; ***********************************************************
; Title:	Reads line from any input
; Name: 	READ_LN
; Purpose:	Reads a line from any input and stores it in
; 		the input buffer (IBUFFER) and adds
;		a null terminator
;
; Entry:	Register HL = Pointer to buffer
; 		Register BC = Size of buffer
; Exit:		If a line has been read it will be in the buffer.
;		   Zero flag = 0
;		else
;		   Zero flag = 1
;
; Registers used:      A, HL, DE
; ***********************************************************
READ_LN:
	ld de, 0
	dec bc			; Make room for a null
.loop:
	call SH_IN		; Get next key
	cp BACKSPC		; Check if back space
	jr z, .back_space
	cp EOF			; Check if EOF
	jr z, .return

	call SH_OUT	
	cp '\n'			; Check if return
	jr z, .return
	ld (hl), a

	inc hl
	inc de
	dec bc
	jr nz, .loop		; Loop if still space
.return:
	ld (hl), NUL		; Add null terminator
	
	ld a, d
	or e
	ret

.back_space:
	dec hl
	inc bc
	dec de
	jr z, .loop
	call SH_OUT
	jr .loop


; ***********************************************************
; Title:	Converts a string into null delimited tokens
; Name: 	TOKN_LN
; Purpose:	Reads a string and tokenizes it inplace into tokens,
; 		which are delimeted by null.
; 		
;
; Entry:	Register HL = Pointer to string
; 		Register BC = Length of buffer
; Exit:		None
;
; Registers used:      a, de
; ***********************************************************
TOKN_LN:
	ld d, h
	ld e, l
.skip_blanks:
	ld a, (hl)
	or a			; End of string?
	jr z, .end_blank	; Yes, quit looping
	cp ' '			; End of delimiters?
	jr nz, .copy_token	; Yes, copy tokens
	inc hl 			; Move the source token
	dec bc			; Adjust size counter
	ld a, b			; Do we still have
	or c  			;  space in buffer?
	jr z, .end_blank	; No, jump to end
	jr .skip_blanks		; Yes, continue

.copy_token:
	ldi			; Move char to front
	jp po, .end		; End of buffer
	ld a, (hl)		; 
	or a  			; End of string?
	jr z, .end		; Yes, quit looping
	cp ' '			; New delimiter?
	jr nz, .copy_token	; No, continue copying.
	ld (hl), RS		; Yes, insert Record Separator
	ldi	 		; Move RS to front
	jp po, .end		; End if no space in buffer.
	jr .skip_blanks		; Skip further blanks

.end_blank:
	or a			; Adjust buffer size in bc
	sbc hl, de		;  by adding remaining space
	add hl, bc		;  from removed delimiters
	ld b, h
	ld c, l
	ex de, hl		; Prepare for postfix (1e + null)
	jr .end2

.end:				; Fill remaining space with nulls
	or a			; Adjust buffer size in bc
	sbc hl, de		;  by adding remaining space
	add hl, bc		;  from removed delimiters
	ld b, h
	ld c, l
	ex de, hl		; Prepare for postfix (1e + null)

	ld a, b			; Still room in buffer?
	or c
	ret z			; No, quit
	ld (hl), RS		; Yes, insert Record Separator
	dec bc	 		; Decrease space
	inc hl
.end2:
	ld a, b			; Still room in buffer?
	or c
	ret z			; No, quit
	ld (hl), NUL		; Yes, insert final null
	ret


; ***********************************************************
; Title:	Executes the string
; Name: 	SH_EXEC
; Purpose:	Executes the string by first mapping to
; 		internal commands and then to any other thing.
; 		
;
; Entry:	Register HL = Pointer to string
; 		Register BC = Length of string
; Exit:		None
;
; Registers used:      A, DE
; ***********************************************************

SH_EXEC:
	ex de, hl
	
	call SH_PARSE
	jr c, .exec_cmd
	call SH_WHAT
	ret
.exec_cmd
	ex de, hl
	ld a, RS
	cpir
	ret po
	ex de, hl
	jp (hl)
	

; ***********************************************************
; Title:	Parses a string and finds if it maps to a command
; Name: 	SH_PARSE
; Purpose:	Searches through the command table to find
; 		a matching command.
;
; Entry:	Register DE = Pointer to string
; Exit:		If found:
; 		   Register HL = Pointer to command
;		   Carry Flag = 1
;		else:
;		   Carry Flag = 0
;
; Registers used:      A
; ***********************************************************
SH_PARSE:
	ld hl, CMD_TABLE-1
.exec:
	push de
.cmdloop:
	ld a, (de)
	call UCASE	; Make upper case
	inc de
	inc hl
	cp (hl)		; Is match?
	jr z, .cmdloop	; Yes, continue to loop
	cp RS		; Check if we're at the end of the string
	jr nz, .ffwd	; Yes, ffwd to next command in table
	ld a, US	; Check if we're at the end of the command
	cp (hl)
	jr z, .findjmp	; Yes, find jump addr
.ffwd:
	ld a, US	; Find next table row
.ffwd_loop:
	cp (hl)
	inc hl
	jr nz, .ffwd_loop	; Loop until end of command
	inc hl 		; Skip jump address
	inc hl
	pop de		; Restore string
	
	xor a		; Check if there are still commands
	cp (hl)
	ret z
	dec hl		; Prepare HL for next loop
	jr .exec	; hl->next item, restart
.findjmp:
	inc hl
	ld a, (hl)
	inc hl
	ld h, (hl)
	ld l, a

	pop de
	scf
	ret

UCASE:
	cp 'a'
	ret c
	cp 'z'+1
	ret nc
	and 00dfh
	ret




; ***********************************************************
; Title:	Read text number from input string
; Name: 	READNUM
; Purpose:	Reads a number in hex representation from an ASCII string
; Entry:	Register HL - Base address of string containing number
; Exit:		Register DE - Containing the number
; 		Register HL - Pointing to next char
;		If successful
;		   Carry = Reset
;		else
;		   Carry = Set
;
; Registers used:      DE, HL
; ***********************************************************
READNUM:
	ld de, 0
	ld a, (hl)
	
.loop:	cp '0'		; Check if number (i.e. 0-9)
	jr c, .done
	cp 3ah		; Test if > 9
	jr nc, .check_alpha	; Yes, check for alpha (i.e. a-f)
	and 0fh		; Convert from ASCII
	jr .add_to_de
	
.check_alpha:
	and 00dfh		; Make upper case
	cp 'A'
	jr c, .invalid
	cp 'G'
	jr nc, .invalid
	sub 'A'-10

.invalid:
	scf
	ret

.add_to_de:		; Store A in HL
	push bc
	ld b, a		; Store A
	ld a, 0f0h
	and d		; Check if enough room in HL
	jr nz, .error	; No, quit with error

	sla e  		; Rotate hl to fit
	rl d
	sla e
	rl d
	sla e
	rl d
	sla e
	rl d
	
	ld a, b		; Restore A
	pop bc
	or e  		; Add it to HL
	ld e, a		;
	inc hl		; Increase pointer
	ld a, (hl)
	jr .loop	; Next char

.error:
	pop bc
	scf
	ret
.done:
	xor a
	ret


; ***********************************************************
; Title:	Print a hex number
; Name: 	PRINTNUM
; Purpose:	Prints the value in A using SH_OUT.
; Entry:	Register A - Value to be printed
; Exit:		None
;
; Registers used:
; ***********************************************************
PRINTNUM:
	push de
	push af
	ld e, a
	
	srl a		; Get the first hex character by
	srl a		; shifting A right four times
	srl a
	srl a

	cp 0ah		; Check if the value is greater than or equal
	   		; to $a
	jp m, .pn1	; No, it's below $a
	add a, 'A'-'0'-10	; Yes, it's 10-15.
	    		; Add the difference between '0' and 'A'

.pn1:	add a, '0'	; Convert into ASCII
	call SH_OUT	; Print first part

	ld a, e		; Restore the original A
	and 0fh		; and mask the lower four bits

	cp 0ah		; Again, check if value is below $a
	jp m, .pn2	; No, it's below $a
	add a, 'A'-'0'-10	; Yes, it's 10-15.
	    		; Add the difference between '0' and 'A'
.pn2:	add a, '0'		; Convert into ASCII
	call SH_OUT	; Print second part
	pop af
	pop de
	ret

