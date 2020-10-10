RS:	equ 01eh	; Record Separator
US: 	equ 01fh	; Unit Separator
FOO:	equ IBUFEND - IBUFFER - 1

SHELL:
	ld a, 10h
	out (OUTPORT), a
	
	ld hl, SH_PMT
	ld bc, SH_PMT_LEN
	call VD_OUTN		; Print prompt

	ld a, 20h
	out (OUTPORT), a
	
	ld hl, IBUFFER
	ld bc, IBUFEND - IBUFFER - 2 ; For an extra null terminator
	call READ_LN		; Read line
	jr z, SHELL		; Jump if no line has been read

	ld a, 30h
	out (OUTPORT), a

	ld hl, IBUFFER
	ld bc, IBUFEND - IBUFFER - 1
	call TOKN_LN		; Tokenize line

;	jr SHELL

	ld a, 40h
	out (OUTPORT), a

;	ld hl, IBUFFER
	ld de, IBUFFER
	ld bc, IBUFEND - IBUFFER - 1
;	call SH_EXEC		; Execute command
	call ECHO

	ld a, 50h
	out (OUTPORT), a

	jr SHELL


; ***********************************************************
; Title:	Reads line from any input
; Name: 	READ_LN
; Purpose:	Reads a line from any input and stores it in
; 		the input buffer (IBUFFER) and adds
;		a null terminators
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
	call KD_NEXT_KVAL	; Get next key
	cp 08h			; Check if back space
	jr z, .back_space
	cp 1ah			; Check if EOF
	jr z, .return

	call VD_OUT	
	cp '\n'			; Check if return
	jr z, .return
	ld (hl), a

	inc hl
	inc de
	dec bc
	jr nz, .loop		; Loop if still space
.return:
	ld (hl), 0		; Add null terminator
	
	ld a, d
	or e
	ret

.back_space:
	dec hl
	inc bc
	dec de
	jr z, .loop
	call VD_OUT
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
	ld (hl), 1eh		; Yes, insert Record Separator
	dec bc	 		; Decrease space
	inc hl
.end2:
	ld a, b			; Still room in buffer?
	or c
	ret z			; No, quit
	ld (hl), 0		; Yes, insert final null
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
; Registers used:      A
; ***********************************************************

SH_EXEC:
	ld d, h
	ld e, l
	
	call PARSE
	jr c, .exec_cmd
	ld hl, SH_ERR
	ld bc, SH_ERR_LEN
	call VD_OUTN		; Print prompt
	ret
.exec_cmd
	jp (hl)
	

; ***********************************************************
; Title:	Parses a string and finds if it maps to a command
; Name: 	SH_EXEC
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
PARSE:
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
; Title:	Echos all arguments
; Name: 	SH_EXEC
; Purpose:	
;
; Entry:	Register DE = Pointer to string
; 		Register BC = Size of string
; Exit:		None
;
; Registers used:      A, HL
; ***********************************************************
ECHO:
	ld a, 0ffh
	out (OUTPORT), a
	; Ignore first token

	ex de, hl
	ld a, RS
	cpir		; Find first null pointer
	ret po
	xor a
	cp (hl)		; Check null pointer
	ret z		; Yes, exit

.loop:
	ld a, (hl)
	cp RS
	jr z, .next
	call VD_OUT
	inc hl
	jr .loop

.next:
	inc hl
	ld a, (hl)
	or a
	jr z, .end
	ld a, ' '
	call VD_OUT
	jr .loop
	
.end:
	ld a, 0f0h
	out (OUTPORT), a
	ld a, '\n'
	call VD_OUT
	ret

.end1:
	ld a, 0f1h
	out (OUTPORT), a
	halt
	jr .end1

.end2:
	ld a, 0f2h
	out (OUTPORT), a
	halt
	jr .end2


CMD_TABLE:
	db "ECHO", US
	dw ECHO
	db 0

	msg SH_PMT, "> "
	msg SH_ERR, "?\n"

