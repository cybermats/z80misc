;SER_SEND: equ 0
;SER_POLL: equ 0

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
XM_SOH_C:	equ 01h	; Start of heading
XM_EOT_C:	equ 04h ; End of Transmission
XM_ACK_C:	equ 06h	; Acknowledge
XM_NAK_C:	equ 15h	; Not Acknowledge
XM_ETB_C:	equ 17h	; End of Transmission Block
XM_CAN_C:	equ 18h	; Cancel
XM_INIT_C:	equ 43h	; ASCII 'C' to start transmission

	ex de, hl
	xor a
	cp (hl)
	ret z

	call READNUM	; Read Address
	ex de, hl
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
	ld a, '\n'
	call SH_OUT
	pop af
	jp SH_ERR




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
	ld a, 21h	; Yes, xor in $1021
	xor c
	ld c, a
	ld a, 10h
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

