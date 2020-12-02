; ***********************************************************
; Title:	Initialize SD Card
; Name: 	INIT_SD
; Purpose:	Initializes an SD Card and configures
; 		it to run SPI. Only needs to be done
;		once, but can be run multiple times.
;
; Entry:	None
; 		
; Exit:		If successful:
; 		   Flag C reset
;		If something went wrong:
;		   Flag C set
;
; Registers used: Plenty
; ***********************************************************
SPI_INIT_SD:
	; Initialize the sd card
	; 1. Let it cycle through at least 74 clks

	ld a, 0ffh  	; MOSI high
	out (SPIDATA), a
	ld b, 0ah	; Loop 10 times
	xor a 		; No Card Select
.init_loop:
	out (SPICTRL), a
	djnz .init_loop

	; 2. Send CMD0, init to SPI mode
	ld a, 0
	ld hl, 0000h
	ld de, 0000h
	call SPI_SEND_CMD
	ret c

	; 3. Send CMD8, check version of card
	ld a, 8
	ld hl, 0000h
	ld de, 01aah	; Voltage and pattern
	call SPI_SEND_CMD
	ret c

	cp a, 00000101b	; Check if command is legal
	jp nz, .ver_2

	; The SD Card is version 1.
	; TODO: Implement support for v1.x

	; Clear response queue
	call SPI_GET_BYTE
	call SPI_GET_BYTE
	call SPI_GET_BYTE
	call SPI_GET_BYTE
	scf
	ret

.ver_2:
	; Command is legal. Fetch 4 bytes since R7
	; Voltage is in the third byte.
	; Pattern is in the fourth byte.
	call SPI_GET_BYTE
	call SPI_GET_BYTE

	call SPI_GET_BYTE
	cp 1		; Check voltage
	jp nz, .unusable

	call SPI_GET_BYTE
	cp 0aah		; Check pattern
	jp nz, .unusable

	; 4. Send ACMD41 to get into active state

	ld d, 0		; Retries for ACMD41
.acmd41_loop:
	ld a, 41
	ld hl, 4000h	; Does support HCS
	ld de, 0000h
	call SPI_SEND_ACMD
	ret c

	or a		; Check if in IDLE state
	jr z, .cmd58	; Not idle, move on
	dec d
	jr nz, .acmd41_loop	;Yes Idle, retry
	
	scf    		; Ran out of retries
	ret		; Return failure

.cmd58:
	; Send CMD58 to check card type
	ld a, 58
	ld hl, 0000h
	ld de, 0000h
	call SPI_SEND_CMD
	ret c

	call SPI_GET_BYTE
	and 0c0h	; Check if SDHC card
	cp 0c0h

	; TODO: Store this info somewhere

	; Discard rest of answer
	call SPI_GET_BYTE
	call SPI_GET_BYTE
	call SPI_GET_BYTE

	or a
	ret

.unusable:
	scf
	ret

; ***********************************************************
; Title:	Send Command to SD Card over SPI
; Name: 	SPI_SEND_CMD
; Purpose:	Sends the command specified in A
; 		to the SD Card over SPI
;		
;
; Entry:	Register A = Command id
; 		Register HL DE = Arguments
; 		
; Exit:		If successful:
; 		   Flag C reset
;		   Register A = Response Code
;		If something went wrong:
;		   Flag C set
;
; Registers used: A
; ***********************************************************
SPI_SEND_CMD:
	push bc
	ld c, a		; Save command id
	
	ld a, 0ffh	; Send one FF before command
	out (SPIDATA), a
	
	ld a, 01	; Set CS
	out (SPICTRL), a

	ld a, c
	or a, 40h	; Generate command
	out (SPIDATA), a
	
	ld a, 01	; Set CS
	out (SPICTRL), a

	ld a, h		; Send arg1
	out (SPIDATA), a

	ld a, 01	; Set CS
	out (SPICTRL), a
	
	ld a, l		; Send arg2
	out (SPIDATA), a

	ld a, 01	; Set CS
	out (SPICTRL), a
	
	ld a, d		; Send arg3
	out (SPIDATA), a

	ld a, 01	; Set CS
	out (SPICTRL), a
	
	ld a, e		; Send arg4
	out (SPIDATA), a

	ld a, 01	; Set CS
	out (SPICTRL), a
	
	; It's only CMD0 and CMD8 that needs
	; a valid CRC, so check for those
	ld a, c
	or a		; Check CMD0
	jr nz, .cmd8
	ld b, 95h
	jr .send_crc
.cmd8:
	cp 8		; Check CMD8
	jr nz, .cmdX
	ld b, 87h
	jr .send_crc
.cmdX:
	ld b, 0ffh
.send_crc:
	ld a, b		; Send CRC
	out (SPIDATA), a

	ld a, 01	; Set CS
	out (SPICTRL), a

.wait:
	ld b, 16	; Number of retries
	ld a, 0ffh	; Load MOSI
	out (SPIDATA), a
.loop:
	in a, (SPIDATA)
	ld c, a
	and 80h		; Check if we have a response
	jr z, .valid
	ld a, 1		; Get another response
	out (SPICTRL), a
	djnz .loop

	pop bc		; No response
	scf
	ret

.valid:
	ld a, c
	pop bc
	or a
	ret



; ***********************************************************
; Title:	Send App Command to SD Card over SPI
; Name: 	SPI_SEND_ACMD
; Purpose:	Sends the application command specified
; 		in A to the SD Card over SPI
;		
;
; Entry:	Register A = Command id
; 		Register HL DE = Arguments
; 		
; Exit:		If successful:
; 		   Flag C reset
;		   Register A = Response Code
;		If something went wrong:
;		   Flag C set
;
; Registers used: A
; ***********************************************************
SPI_SEND_ACMD:
	push hl
	push de
	push af
	ld a, 55
	ld hl, 0
	ld de, 0
	call SPI_SEND_CMD
	jr c, .error
	pop af
	pop de
	pop hl
	jp SPI_SEND_CMD
.error:
	pop de	; Keep AF
	pop de
	pop hl
	ret
	
; ***********************************************************
; Title:	Get a new byte from SPI.
; Name: 	SPI_GET_BYTE
; Purpose:	Gets a byte from SPI by transmitting
; 		a dummy FF value.
;		
;
; Entry:	None
; 		
; Exit:		Register A = SPI Value
;
; Registers used: A
; ***********************************************************
SPI_GET_BYTE:
	ld a, 1
	out (SPICTRL), a
	in a, (SPIDATA)
	ret


; ***********************************************************
; Title:	Wait for SD SPI Token
; Name: 	SPI_WAIT_TOKEN
; Purpose:	Reads updates from the SD Card
; 		and waits for a response token.
;		
;
; Entry:	None
; 		
; Exit:		If Data Token
; 		   Register A = Token
;		   Flag C = Reset
;		Else If Error Token
;		   Register A = Error Token
;		   Flag C = Set
;		Else: (time out)
;		   Register A = 0
;		   Flag C = Set
;
; Registers used: A, B
; ***********************************************************
SPI_WAIT_TOKEN:
	ld b, 0		; Time out after 256 tries
	ld a, 0ffh
	out (SPIDATA), a
.loop:
	call SPI_GET_BYTE
	cp 20h
	ret c
	cp 0ffh
	jr c, .data_token
	djnz .loop
	xor a		; Signal time out
	scf 		; Set C
	ret

.data_token:
	or a		; Clear C flag
	ret


; ***********************************************************
; Title:	Read Block of Data
; Name: 	SPI_READ_DATA_BLOCK
; Purpose:	Reads block of data from the SD Card
;
; Entry:	Register HL = Destination Address
; 		
; Exit:		Register HL = End of block
;
; Registers used: A, BC, HL
; ***********************************************************
SPI_READ_DATA_BLOCK:
	ld b, 0		; Loop counter, 256 loops
	      		; x2 = 512 loops in total
	ld c, SPIDATA	; Source Port
	ld a, 1		; Set CS
.loop:
	out (SPICTRL), a
	ini
	jp nz, .loop	; 256 loop
.loop2:
	out (SPICTRL), a
	ini
	jp nz, .loop2	; 256 loop

	; Discard CRC
	out (SPICTRL), a
	out (SPICTRL), a
	
	ret

; ***********************************************************
; Title:	Read Block 
; Name: 	SPI_READ_BLOCK
; Purpose:	Reads block of data from the SD Card
;
; Entry:	Register HL = Destination Address
; 		Register BC = Source Block msb
;		Register DE = Source Block lsb
; 		
; Exit:		If success:
; 		   Register HL = End of Data Block
;		   Flag C = Reset
;		Else:
;		   Flag C = Set
;
; Registers used: A, BC, D, HL
; ***********************************************************
SPI_READ_BLOCK:
	push hl
	ld a, 17
	ld h, b
	ld l, c
	call SPI_SEND_CMD
	jr c, .fail
	cp 5h
	jr z, .fail

	call SPI_WAIT_TOKEN
	jr c, .fail

	pop hl
	call SPI_READ_DATA_BLOCK
	or a
	ret
		
.fail:
	pop hl
	scf
	ret
