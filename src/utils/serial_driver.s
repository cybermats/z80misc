

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
	ld e, a		; Save for later

	; Initialize the input buffer
	push hl
	ld hl, SR_BUFFER_BEG
	ld (SR_START_PTR), hl
	ld (SR_END_PTR), hl
	pop hl

	; Channel reset
	ld a, SIO_WR0_REG0 | SIO_WR0_CMD_CHNL_RST
	out (SIOCMDB), a

	ld a, e
	or a
	jr z, .no_vector
	; Pointer 2 
	ld a, SIO_WR0_REG2
	out (SIOCMDB), a
	; Interrupt vector
	ld a, e
	out (SIOCMDB), a
.no_vector
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
	ld a, SIO_WR1_RX_INT_FIRST | SIO_WR1_ST_AFF_INT_VEC	; Turn on ints
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
;		   C flag = 0
;		else
;		   C flag = 1
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
	if 0
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
	ld a, 0fh
	and e
	ld (SR_START_PTR), a
	ld a, d
	pop hl
	pop de
	ret
	endif
	
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
	push af
	in a, (SIODATAB)
	call SER_BUFFER_KEY
	ld a, SIO_WR0_CMD_EN_INT_NXT_RX_CHR
	out (SIOCMDB), a
	ld a, SIO_WR0_CMD_RTN_FRM_INT
	out (SIOCMDB), a

	pop af
	ret



	if 0
	ld d, 0
	ld a, (SR_END_PTR)
	ld e, a
	ld hl, SR_BUFFER_BEG
	add hl, de
	in a, (SIODATAB)	; Read data
	ld (hl), a
	inc e
	ld a, 0fh
	and e
	ld (SR_END_PTR), a
	
	ld a, SIO_WR0_REG0 | SIO_WR0_CMD_RST_EXT_STS_INTS
	out (SIOCMDB), a
	ret

	endif


; ***********************************************************
; Title:	Put char into key buffer
; Name: 	SER_BUFFER_KEY
; Purpose:	Puts a char into the char buffer.
; Entry:	Register A = ASCII Value of char
; Exit:		None
; Registers used:      A
; ***********************************************************
SER_BUFFER_KEY:
	push hl
	push de

	ld de, (SR_END_PTR)
	ld (de), a

	inc de
	ld hl, SR_BUFFER_END
	and a
	sbc hl, de
	jr nz, .continue

	ld de, SR_BUFFER_BEG

.continue
	ld (SR_END_PTR), de
	pop de
	pop hl
	ret


; ***********************************************************
; Title:	Get values from the serial
; Name: 	SR_NEXT_VAL
; Purpose:	Returns the next value from the circular
; 		buffer used to store keys from the serial port.
;
; Entry:	None
; Exit:		If keys are available:
; 		   Register A = value
;		   Carry flag = 0
;		else
;		   Carry flag = 1
;
; Registers used:      A
; ***********************************************************
SR_NEXT_VAL:
	push bc
	push de
	push hl
.loop
	ld de, (SR_START_PTR)	; Get end pointer addr
	ld hl, (SR_END_PTR)	; Get start pointer addr

	; Compare the two pointers.
	; If they are the same, we will set Carry flag
	; to signal that we don't have any new keys
	; available.

	and a			; Clear Carry for SBC
	sbc hl, de		; Compare the values
	jr nz, .input_available	; Jump if the values are different

	scf
	jr .done

.input_available:
	ld a, (de)		; We have values, so load the oldest value
	ld c, a			; Store it elsewhere
	
	inc de			; Update the start ptr
	ld hl, SR_BUFFER_END	; But check if we need to loop around

	and a  			; Clear Carry for SBC
	sbc hl, de
	jr nz, .update_ptr	; Jump if the start pointer isn't at the end
	ld de, SR_BUFFER_BEG	; It is at the end, so wrap around

.update_ptr:
	ld (SR_START_PTR), de	; Update the start pointer
	or a
.done:
	ld a, c
	pop hl
	pop de
	pop bc
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

