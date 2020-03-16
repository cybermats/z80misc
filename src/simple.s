RESET:
	ld a, $1
	out (OUTPORT), a
	ld sp, STACK_START
	jp INIT

	org $0100
INIT:
	ld a, $2
	out (OUTPORT), a
	; Do ram test
	ld hl, VRAMBEG
	ld de, VRAMEND - VRAMBEG
	call RAMTST
	jr nc, .ramtest_succ

.ramtest_err:
	ld a, $aa
	out (OUTPORT), a
	halt
	jr .ramtest_err

.ramtest_succ:
.configure:
	ld a, $3
	out (OUTPORT), a

	ld a, 0 ; Set no int vector and disable ints
	call SER_CONFIGURE

	ld a, $4
	out (OUTPORT), a

	call VD_CONFIGURE
	
	ld a, $5		; Indicate that the video has been configured
	out (OUTPORT), a

	ld de, RDY
	call PRTSTG

MAIN:
	ld a, '>'
	call GETLN
	ld de, IBUFFER
	call PARSE
	jr MAIN


IGNBLK:	; Ignore blanks
	ld a, (de)
	cp ' '
	ret nz
	inc de
	jr IGNBLK

; ***********************************************************
; Title:	Read text number from input string
; Name: 	READNUM
; Purpose:	Reads a number in hex representation from an ASCII string
; Entry:	Register DE - Base address of string containing number
; Exit:		Register HL - Containing the number
; 		Register DE - Pointing to next char
;
; Registers used:      DE, HL
; ***********************************************************
READNUM:
	call IGNBLK
	ld hl, 0
.loop:	cp '0'		; Check if number (i.e. 0-9)
	ret c
	cp $3a		; Test if > 9
	jr nc, .check_alpha	; Yes, check for alpha (i.e. a-f)
	and $0f		; Convert from ASCII
	jr .add_to_hl
.check_alpha:
	and $df		; Make upper case
	cp 'A'
	ret c
	cp 'G'
	ret nc
	sub 'A'-10
.add_to_hl:		; Store A in HL
	push bc
	ld b, a		; Store A
	ld a, $f0
	and h		; Check if enough room in HL
	jp nz, QHOW	; No, quit

	sla l  		; Rotate hl to fit
	rl h
	sla l
	rl h
	sla l
	rl h
	sla l
	rl h
	
	ld a, b		; Restore A
	pop bc
	or l  		; Add it to HL
	ld l, a		;
	inc de		; Increase pointer
	ld a, (de)
	jr .loop	; Next char
	


; ***********************************************************
; Title:	Print memory content
; Name: 	PRINTMEM_ARG
; Purpose:	Does a hex dump of the specified memory
; 		using OUTCH.
; Entry:	Register DE - Base address of string containing arguments
; Exit:		None
;
; Registers used: DE, HL
; ***********************************************************
PRINTMEM_ARG:
	call READNUM
	push hl
	call READNUM
	ld c, l
	pop hl
	ld a, h
	call PRINTNUM
	ld a, l
	call PRINTNUM
	ld a, ' '
	call OUTCH
	ld a, c
	call PRINTNUM
	call CRLF
	jr PRINTMEM

; ***********************************************************
; Title:	Print memory content
; Name: 	PRINTMEM
; Purpose:	Does a hex dump of the specified memory
; 		using OUTCH.
; Entry:	Register HL - Base address
; 		Register C - Length
; Exit:		None
;
; Registers used:      HL, BC
; ***********************************************************

PRINTMEM:
	xor a
	or c
	ret z

	ld b, 16
	ld a, c
	cp b
	jr nc, .pm1
	ld b, c
	
	; Print header
.pm1:	ld a, h
	call PRINTNUM
	ld a, l
	call PRINTNUM
	ld a, ' '
	call OUTCH
	ld a, ' '
	call OUTCH
	
	; Print memory dump in hex
.pm2:	ld a, (hl)
	call PRINTNUM
	ld a, ' '
	call OUTCH
	ld a, b
	cp 9
	jr nz, .pm3
	ld a, ' '
	call OUTCH
	

.pm3:	inc hl
	dec c
	dec b
	jr nz, .pm2
	call CRLF
	jr PRINTMEM
	
; ***********************************************************
; Title:	Print a hex number
; Name: 	PRINTNUM
; Purpose:	Prints the value in HL using OUTCH.
; Entry:	Register A - Value to be printed
; Exit:		None
;
; Registers used:      A
; ***********************************************************
PRINTNUM:
	push de
	ld e, a
	
	srl a		; Get the first hex character by
	srl a		; shifting A right four times
	srl a
	srl a

	cp $a		; Check if the value is greater than or equal
	   		; to $a
	jp m, .pn1	; No, it's below $a
	add 'A'-'0'-10	; Yes, it's 10-15.
	    		; Add the difference between '0' and 'A'

.pn1:	add '0'		; Convert into ASCII
	call OUTCH	; Print first part

	ld a, e		; Restore the original A
	and $0f		; and mask the lower four bits

	cp $a		; Again, check if value is below $a
	jp m, .pn2	; No, it's below $a
	add 'A'-'0'-10	; Yes, it's 10-15.
	    		; Add the difference between '0' and 'A'
.pn2:	add '0'		; Convert into ASCII
	call OUTCH	; Print second part
	pop de
	ret

ECHO:	call IGNBLK
PRTSTG:	xor a
	ld b, a
.ps2:	ld a, (de)
	inc de
	cp b
	ret z
	call OUTCH
	cp '\n'
	jr nz, .ps2
	ret


; ***********************************************************
; Title:	Parse command
; Name: 	PARSE
; Purpose:	Parses a string for commands and compares
; 		this to the list of available commands
;		in the CMD_TABLE. Once found the command is
;		executed.
; Entry:	Register DE - Point to String
; Exit:		None
;
; Registers used:      HL, A
; ***********************************************************

PARSE:	ld hl, CMD_TABLE-1
.exec:	call IGNBLK
	push de		; Save pointer 
.cmdloop:
	ld a, (de)
	call UCASE	; Make upper case
	inc de
	inc hl
	cp (hl)		; Is match?
	jr z, .cmdloop	; Yes, continue to loop
	xor a 		; No, check if we're at the end
	cp (hl)
	jr z, .findjmp	; Yes, find jump addr
.ffwd:	inc hl		; No, find next table row
	cp (hl)
	jr nz, .ffwd
	inc hl
	inc hl
	pop de
	jr .exec	; hl->next item, restart
.findjmp:
	inc hl
	
	ld a, (hl)
	inc hl
	ld h, (hl)
	ld l, a

	pop af
	jp (hl)
	
UCASE:	cp 'a'
	ret c
	cp 'z'+1
	ret nc
	and $df
	ret


CRLF:	ld a, '\n'
OUTCH:	cp '\n'
	jr nz, .done
	ld a, '\r'
	call SER_SEND
	ld a, '\n'
	jp VD_OUT
.done:
	call SER_SEND
	jp VD_OUT
GETLN:
	ld de, IBUFFER
.gl1:	call OUTCH
.gl2:	call SER_POLL	; Get a character
	jr c, .gl2	; Wait for input
	cp $03		; Is it Ctrl-C?
	jp z, RESET	; Yes, restart
	cp '\n'		; Ignore LF
	jr z, .gl2
.gl3:	ld (de), a	; Save Ch
	cp $08	 	; Is it back-space?
	jr nz, .gl4	; No, more tests
	ld a, e		; Yes, delete?
	cp IBUFFER & $00ff
	jr z, .gl2	; Nothing to delete
	ld a, (de)	; Delete
	dec de
	jr .gl1
.gl4:	cp '\r'		; Was it CR?
	jr z, .gl5	; Yes, end of line
	ld a, e		; else, more free room?
	cp IBUFEND & $00ff
	jr z, .gl2	; No, wait for CR/rub-out
	ld a, (de)	; Yes, bump pointer
	inc de
	jr .gl1
.gl5:	ld a, '\n'	; Convert CR to LF
	ld (de), a
	inc de		; End of line
	inc de		; Bump pointer
	ld a, 0		; Put marker after it
	ld (de), a
	dec d
	jp CRLF
	



QWHAT:	ld de, WHAT
	jr ERROR
QHOW:	ld de, HOW
	jr ERROR
ERROR:	call CRLF
	call PRTSTG
	ret
	
	




WHAT:	string "What?\n"
HOW:	string "How?\n"
RDY:	string "Ready!\n"
	

CMD_TABLE:
	string "DUMP"
	dw PRINTMEM_ARG
	string "ECHO"
	dw ECHO
	db 0
	dw QWHAT
CMD_TABLE_END:

	
	include "constants.s"
	include "utils/serial_driver.s"
	include "utils/timing.s"
	include "utils/ramtest.s"
	include "utils/video_driver.s"
	include "utils/strings.s"

	org $07fe
	word $0000
	end