RESET:
	ld a, $1
	out (OUTPORT), a
	ld sp, STACK_START
;	im 2
;	ei
	jp INIT



	org $0038
SERIAL_INT:
	ex af, af'
	exx
	call SER_CALLBACK
	exx
	ex af, af'
	ei
	reti
	


	org $0100
INIT:
	ld a, $2
	out (OUTPORT), a
	; Do ram test
	ld hl, VRAMBEG
	ld de, VRAMEND - VRAMBEG
	call RAMTST
	jr nc, .vramtest_succ

.vramtest_err:
	ld a, $aa
	out (OUTPORT), a
	halt
	jr .vramtest_err
	
.vramtest_succ:
	ld a, $3
	out (OUTPORT), a
	; Do ram test
;	ld hl, RAMBEG
;	ld de, RAMEND - RAMBEG - $1000
;	call RAMTST
;	jr nc, .ramtest_succ
	jr .ramtest_succ

.ramtest_err:
	ld a, $55
	out (OUTPORT), a
	halt
	jr .ramtest_err

.ramtest_succ:
.configure:
	ld a, $4
	out (OUTPORT), a

	ld a, 0 ; Set no int vector and disable ints
;	ld a, $ff & SERIAL_INT	    ; Set int vector
	call SER_CONFIGURE

	ld a, $5
	out (OUTPORT), a

	call VD_CONFIGURE
	
	ld a, $6		; Indicate that the video has been configured
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
;		If successful
;		   Carry = Reset
;		else
;		   Carry = Set
;
; Registers used:      DE, HL
; ***********************************************************
READNUM:
	call IGNBLK
	ld hl, 0
.loop:	cp '0'		; Check if number (i.e. 0-9)
	jr c, .done
	cp $3a		; Test if > 9
	jr nc, .check_alpha	; Yes, check for alpha (i.e. a-f)
	and $0f		; Convert from ASCII
	jr .add_to_hl
.check_alpha:
	and $df		; Make upper case
	cp 'A'
	jr c, .done
	cp 'G'
	jr nc, .done
	sub 'A'-10
.add_to_hl:		; Store A in HL
	push bc
	ld b, a		; Store A
	ld a, $f0
	and h		; Check if enough room in HL
	jr nz, .error	; No, quit with error

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

.error:
	pop bc
	scf
	ret
.done:
	xor a
	ret


RUN_ARG:
	call READNUM
	jr c, .error
	jp (hl)
.error:
	call QHOW
	ret


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
	jr c, .error
	call READNUM
	jr c, .error
	ld c, l
	pop hl
	jr PRINTMEM
.error:
	pop hl
	call QHOW
	ret

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
; Purpose:	Prints the value in A using OUTCH.
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
	pop af
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
.done:
	call SER_SEND
	jp VD_OUT
GETLN:
	ld de, IBUFFER
.gl1:	call OUTCH
;.gl2:	call SER_GET	; Get a character
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
	


QERR:	ld de, ERR
	jr ERROR
QWHAT:	ld de, WHAT
	jr ERROR
QHOW:	ld de, HOW
	jr ERROR
ERROR:	call PRTSTG
	ret
	
	
; ***********************************************************
; Title:	Receive XMODEM
; Name: 	RXMODEM
; Purpose:	Listens and decodes XMODEM from the serial.
; Entry:	Register DE - Point to String with arguments.
; 		First argument is memory location where
;		the data will be located.
; Exit:		None
;
; Registers used:      Not sure
; ***********************************************************
XMODEM:
XM_SOH_C:	equ $01	; Start of heading
XM_EOT_C:	equ $04 ; End of Transmission
XM_ACK_C:	equ $06	; Acknowledge
XM_NAK_C:	equ $15	; Not Acknowledge
XM_ETB_C:	equ $17	; End of Transmission Block
XM_CAN_C:	equ $18	; Cancel
XM_INIT_C:	equ $43	; ASCII 'C' to start transmission

	call READNUM	; Read Address
	push hl		; Store Address
	jp c, XM_err	; Is address valid?
	
	ld d, 1		; Packet counter
	ld b, XM_INIT_C	; Send initial ACK
XM_beg:	push bc		; Store so we can use bc for loop variables.
	ld a, b		; Fetch the send char.
	call SER_SEND
	ld bc, 0	; Set up loop variables
	ld e, 0
XM_init:call SER_POLL	; Try a few times
	jr nz, XM_exec	; Check if we got anything
	djnz XM_init	; No, we didn't. Try again.
	dec c
	jr nz, XM_init
	dec e
	pop bc
	jr nz, XM_beg
	ld a, 1
	jp XM_err	; Nothing has happened, give up

XM_exec:pop bc		; Clear stack
	   		; Received char. Investigate.
			; A->Char
			; HL->Store memory addr
			; BC->Free
			; DE->(Packet counter)/(Char counter)
	ld e, 128	; Byte counter
	cp XM_SOH_C
	jr z, XM_hdr
	cp XM_EOT_C
	jr z, XM_end
	cp XM_CAN_C
	jp z, XM_can
	
	ld a, 2
	jp XM_err	; No known code, give up
	
XM_hdr:
;	call SER_GET
	call SER_POLL
	jr z, XM_hdr
	cp d		; Compare to packet counter
	jr z, XM_hdr2	; Is this the next package?
	dec d 		; No, check if prev
	cp d
	jr nz, XM_can	; Is this a retxn of old package?
	pop hl		; Yes, restore old HL
	push hl		; Save HL
XM_hdr2:
;	call SER_GET
	call SER_POLL
	jr z, XM_hdr2
	cpl		; Invert second header
	cp d
	jr nz, XM_can	; Is this the expected package?
	
XM_body:
;	call SER_GET	; Yes, start receiving data
	call SER_POLL	; Yes, start receiving data
	jr z, XM_body
	ld (hl), a
	inc hl		; Bump counters and check if at end
	dec e
	jr z, XM_tl
	jr XM_body

XM_tl:
;	call SER_GET	; Save sender CRC to BC
	call SER_POLL	; Save sender CRC to BC
	jr z, XM_tl
	ld b, a
XM_tl2:
;	call SER_GET
	call SER_POLL
	jr z, XM_tl2
	ld c, a
	ex (sp), hl	; Fetch old buffer
	push de	 	; Save old package counter
	push hl		; Save old buffer
	push bc		; Save sent CRC
	ld de, 128
	call CRC16
	pop hl		; Fetch sent CRC
	    		; HL -> Sent CRC
			; BC -> Calc CRC

	or a		; Reset Carry
	sbc hl, bc	; Check for difference
	pop hl		; Fetch old buffer
	pop de		; Fetch old package counter
	ex (sp), hl	; Restore new buffer
	jr z, XM_ack
XM_nak:	ld b, XM_NAK_C
	pop hl
	push hl
	jp XM_beg
XM_ack:	ld b, XM_ACK_C
	pop af
	push hl
	inc d
	jp XM_beg

XM_end:	ld a, XM_ACK_C
	call SER_SEND

	ex de, hl	; Final package received.
	ld l, 0
	srl h		; Each package is 128 bytes
	rr l   		; so divide package nums by 2.
			
	pop af		; Empty stack from HL
	jp PRINTNUM	; Print size and return.
	
XM_can:
	ld a, XM_CAN_C
	call SER_SEND
	ld a, 3
	jr XM_err	; Cancel everything
	
	
XM_err:
	call PRINTNUM
	call CRLF
	pop af
	jp QERR







; ***********************************************************
; Title:	Calculate CRC16 on data block
; Name: 	CRC16
; Purpose:	Calculates the CRC16 used in XMODEM.
; Entry:	Register HL - Start pointer for Data
; 		Register DE - Length of Data block
; Exit:		Register BC - CRC16 of that data block
;
; Registers used:      HL, BC, DE, AF
; ***********************************************************
CRC16:
	ld bc, 0
CRC_ol:	push de
	ld a, (hl)
	xor b
	ld b, a
	ld e, 8
CRC_il:
	sla c		; Shift BC one left
	rl b
	jr nc, CRC_ld	; Check if CRC & $8000 was True
	ld a, $21	; Yes, xor in $1021
	xor c
	ld c, a
	ld a, $10
	xor b
	ld b, a
CRC_ld:	dec e
	jr nz, CRC_il
	pop de
	inc hl		; Bump counters and check if at end
	dec de
	ld a, d
	or e
	jr nz, CRC_ol
	ret






WHAT:	string "What?\n"
HOW:	string "How?\n"
ERR:	string "Error\n"
RDY:	string "Ready!\n"
	

CMD_TABLE:
	string "DUMP"
	dw PRINTMEM_ARG
	string "ECHO"
	dw ECHO
	string "RUN"
	dw RUN_ARG
	string "RX"
	dw XMODEM

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