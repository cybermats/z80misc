

; ***********************************************************
; Title:	Setup the SERIAL I/O
; Name: 	SER_CONFIGURE
; Purpose:	Configure and setup all variables
; 		used by the serial port.
;
; Entry:	If setting up for interrupts:
; 		   Register A = INT vector
;		else
;		   Register A = 0
; Exit:		None
;
; Registers used:      A, HL
; ***********************************************************

SER_CONFIGURE:
	push de

	ld de, 0
	ld (SR_START_PTR), de	; Nil out the ptrs


	ld e, a		; Save for later
	; Channel reset
	ld a, SIO_WR0_REG0 | SIO_WR0_CMD_CHNL_RST
	out (SIOCMDB), a
	; Pointer 2 
	ld a, SIO_WR0_REG2
	out (SIOCMDB), a
	; Interrupt vector
	ld a, e
	out (SIOCMDB), a
	; Ptr 4. Reset Ext/Status interrupts
	ld a, SIO_WR0_REG4 | SIO_WR0_CMD_RST_EXT_STS_INTS
	out (SIOCMDB), a
	; x1 Clock mode, Async,1 stop bit, no parity
	ld a, SIO_WR4_CLK_X64 | SIO_WR4_STP_1
	out (SIOCMDB), a
	; Pointer 3
	ld a, SIO_WR0_REG3
	out (SIOCMDB), a
	; Rx 8 bits, no auto enable, Rx enable
	ld a, SIO_WR3_RX_8BITS | SIO_WR3_RX_EN
	out (SIOCMDB), a
	; Pointer 5
	ld a, SIO_WR0_REG5
	out (SIOCMDB), a
	; 8 bits, Tx enabled
	ld a, SIO_WR5_TX_8BITS | SIO_WR5_TX_EN
	out (SIOCMDB), a
	; Pointer 1, Reset Ext/Status ints
	ld a, SIO_WR0_REG1 | SIO_WR0_CMD_RST_EXT_STS_INTS
	out (SIOCMDB), a
	; Receive interrupts On First Char only
	ld a, e
	or a	; Check if interrupt vector has been given
	
	ld a, SIO_WR1_RX_INT_DIS	; Default to disabled
	jr z, .no_ints ; Jump if no vector is specified
	ld a, SIO_WR1_RX_INT_FIRST	; Turn on ints
.no_ints
	out (SIOCMDB), a

	pop de
	ret


; ***********************************************************
; Title:	Poll the serial port
; Name: 	SER_POLL
; Purpose:	Checks if there are any thing inbound from
; 		the serial port, and if there is it returns it.
; Entry:	None
; Exit:		If there are keys available:
; 		   Register A = value
;		   Zero flag = 0
;		else
;		   Zero flag = 1
;
; Registers used:      A
; ***********************************************************
SER_POLL:
	ld a, SIO_WR0_REG0	; Load status of keyboard	; 7
	out (SIOCMDB), a	       	      	 		; 11
	in a, (SIOCMDB)						; 11
	and SIO_RD0_DATA_AV	; Check if data is available	; 7
	scf 			  	   	   		; 4
	ret z							; 11/5
	in a, (SIODATAB)	; Read data			; 11
	ccf   			       				; 4
	ret							; 10
								; ---
								; 51/70


; ***********************************************************
; Title:	Read the serial buffer
; Name: 	SER_GET
; Purpose:	Checks if there is anythign in the serial
; 		buffer. Blocks if nothing is available.
; Entry:	None
; Exit:		Register A = value
;
; Registers used:      A
; ***********************************************************
SER_GET:
	push de
	push hl
SG_LOOP:
	ld de, (SR_START_PTR)	; Fetches START -> E, END -> D
	ld a, d
	cp e
	jr nz, SG_FOUND
	halt			; Nothing in buffer, halt
	jr SG_LOOP		; Check if stuff is available
SG_FOUND:  			; Stuff is available
	ld d, 0
	ld hl, SR_BUFFER_BEG
	add hl, de
	ld a, (hl)
	ld d, a			; Store result temp
	inc e
	ld a, $0f
	and e
	ld (SR_START_PTR), a
	ld a, d
	pop hl
	pop de
	ret
	
	

; ***********************************************************
; Title:	Serial Callback
; Name: 	SER_CALLBACK
; Purpose:	Loads the data stored in the serial port
; 		and put's it into the buffer.
; Entry:	None
; Exit:		None, buffer is updated through SR_END_PTR
;
; Registers used:      A, DE, HL
; ***********************************************************
SER_CALLBACK:
	ld d, 0
	ld a, (SR_END_PTR)
	ld e, a
	ld hl, SR_BUFFER_BEG
	add hl, de
	in a, (SIODATAB)	; Read data
	ld (hl), a
	inc e
	ld a, $0f
	and e
	ld (SR_END_PTR), a
	
	ld a, SIO_WR0_REG0 | SIO_WR0_CMD_RST_EXT_STS_INTS
	out (SIOCMDB), a
	ret
	

; ***********************************************************
; Title:	Send data to the serial port
; Name: 	SER_SEND
; Purpose:	Loads the transmission port with data to send
; 		
; Entry:	Char to send in Register A
; Exit:		None
; Registers used:      A
; ***********************************************************
SER_SEND:
	out (SIODATAB), a
	ret

