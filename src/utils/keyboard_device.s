


; ***********************************************************
; Title:	Setup the keyboard input
; Name: 	KD_CONFIGURE
; Purpose:	Configure and setup all variables
; 		used by the keyboard serial port.
;
; Entry:	If setting up for interrupts:
; 		   Register A = INT vector
;		else
;		   Register A = 0
; Exit:		None
;
; Registers used:      A, HL
; ***********************************************************

KD_CONFIGURE:
	push de
	ld e, a		; Save for later
	; Channel reset
	ld a, KD_WR0_REG0 | KD_WR0_CMD_CHNL_RST
	out (SIOCMDB), a
	; Pointer 2 
	ld a, KD_WR0_REG2
	out (SIOCMDB), a
	; Interrupt vector
	ld a, e
	out (SIOCMDB), a
	; Ptr 4. Reset Ext/Status interrupts
	ld a, KD_WR0_REG4 | KD_WR0_CMD_RST_EXT_STS_INTS
	out (SIOCMDB), a
	; x1 Clock mode, Async,1 stop bit, odd partity
	ld a, KD_WR4_CLK_X1 | KD_WR4_STP_1 | KD_WR4_PRT_ODD | KD_WR4_PRT_EN
	out (SIOCMDB), a
	; Pointer 3
	ld a, KD_WR0_REG3
	out (SIOCMDB), a
	; Rx 8 bits, no auto enable, Rx enable
	ld a, KD_WR3_RX_8BITS | KD_WR3_RX_EN
	out (SIOCMDB), a
	; Pointer 5
	ld a, KD_WR0_REG5
	out (SIOCMDB), a
	; 8 bits, Tx not enabled
	ld a, KD_WR5_TX_8BITS
	out (SIOCMDB), a
	; Pointer 1, Reset Ext/Status ints
	ld a, KD_WR0_REG1 | KD_WR0_CMD_RST_EXT_STS_INTS
	out (SIOCMDB), a
	; Receive interrupts On First Char only
	ld a, e
	or a	; Check if interrupt vector has been given
	
	ld a, KD_WR1_RX_INT_DIS		; Default to disabled
	jr z, .no_ints ; Jump if no vector is specified
	ld a, KD_WR1_RX_INT_FIRST	; Turn on ints
.no_ints
	out (SIOCMDB), a

	; Initialize the keyboard input buffer
	ld hl, KB_BUFFER_BEG
	ld (KB_START_PTR), hl
	ld (KB_END_PTR), hl
	xor a
	ld (KB_PS2_STATE), a
	ld (KB_PS2_COUNT), a
	pop de
	ret


; ***********************************************************
; Title:	Callback for Keyboard interrupt
; Name: 	KD_CALLBACK
; Purpose:	Reads the value from the serial port
; 		and stores it in a circular buffer.
; Entry:	None
; Exit:		None
; Registers used:      A, HL
; ***********************************************************
KD_CALLBACK:
	in a, (SIODATAB)	; Fetch value from SIO
	call KD_CONVERT		; Convert A to ASCII
	jr c, .done		; This is not a key press we care about
	
	call KD_BUFFER_KEY	; Store ASCII in key buffer.

.done
	ld a, %00010000		; Pointer 0, Reset Ext/Status interrupts
	out (SIOCMDB), a	; Restore interrupts
	ret

; ***********************************************************
; Title:	Put char into key buffer
; Name: 	KD_BUFFER_KEY
; Purpose:	Puts a char into the char buffer.
; Entry:	Register A = ASCII Value of char
; Exit:		None
; Registers used:      A
; ***********************************************************
KD_BUFFER_KEY:
	push hl
	push de
	
	; KB_END_PTR points to the next available slot
	; so we store the key value there.
	ld de, (KB_END_PTR)	; Get end pointer addr
	ld (de), a		; Store value at KB_END_PTR

	; Now we need to update the end pointer and
	; make sure it overflows correctly
	inc de
	ld hl, KB_BUFFER_END	; Get end of buffer (exclusive)
	and a  			; Clear Carry for SBC
	sbc hl, de
	jr nz, .continue	; If the end ptr is the same as
	       			; end of buffer we should loop
				; around to the beginning
	ld de, KB_BUFFER_BEG

.continue
	ld (KB_END_PTR), de	; Store the new end pointer

	pop de
	pop hl
	ret

; ***********************************************************
; Title:	Get values from the keyboard
; Name: 	KD_NEXT_KVAL
; Purpose:	Returns the next value from the circular
; 		buffer used to store keys from the keyboard.
; Entry:	None
; Exit:		If there are keys waiting to be processed:
; 		   Register A = value
;		   Carry flag = 0
;		else
;		   Carry flag = 1
;
; Registers used:      A, HL
; ***********************************************************
KD_NEXT_KVAL:
	push bc
	push de
	ld de, (KB_START_PTR)	; Get end pointer addr
	ld hl, (KB_END_PTR)	; Get start pointer addr

	; Compare the two pointers.
	; If they are the same, we will set Carry flag
	; to signal that we don't have any new keys
	; available.

	and a			; Clear Carry for SBC
	sbc hl, de		; Compare the values
	jr nz, .input_available	; Jump if the values are different
	scf    			; Not different, so set error flag
	jr .done

.input_available:
	ld a, (de)		; We have values, so load the oldest value
	ld c, a			; Store it elsewhere
	
	inc de			; Update the start ptr
	ld hl, KB_BUFFER_END	; But check if we need to loop around

	and a  			; Clear Carry for SBC
	sbc hl, de
	jr nz, .update_ptr	; Jump if the start pointer isn't at the end
	ld de, KB_BUFFER_BEG	; It is at the end, so wrap around

.update_ptr:
	and a			; Clear carry
	ld (KB_START_PTR), de	; Update the start pointer
.done:
	ld a, c
	pop de
	pop bc
	ret

; ***********************************************************
; Title:	Poll the keyboard
; Name: 	KD_POLL
; Purpose:	Checks if there are any thing inbound from
; 		the keyboard, and if there is it returns it.
; Entry:	None
; Exit:		Key, if present, is buffered.
;
; Registers used:      A
; ***********************************************************
KD_POLL:
	ld a, KD_WR0_REG0	; Load status of keyboard
	out (SIOCMDB), a
	in a, (SIOCMDB)
	and KD_RD0_DATA_AV	; Check if data is available
	jr z, .done		; Jump if there is no data
	in a, (SIODATAB)	; Read data
	call KD_CONVERT		; Convert to ASCII
	jr c, .done		; Jump if irrelevant key
	call KD_BUFFER_KEY	; Store keys in buffer
.done:
	ret

; ***********************************************************
; Title:	Poll the keyboard ASCII char
; Name: 	KD_POLL_CHAR
; Purpose:	Checks if there are any thing inbound from
; 		the keyboard, and if there is it returns it.
; Entry:	None
; Exit:		If there are keys available:
; 		   Register A = value
;		   Carry flag = 0
;		else
;		   Carry flag = 1
;
; Registers used:      A
; ***********************************************************
KD_POLL_CHAR:
	ld a, KD_WR0_REG0	; Load status of keyboard
	out (SIOCMDB), a
	in a, (SIOCMDB)
	and KD_RD0_DATA_AV	; Check if data is available
	ret z
	in a, (SIODATAB)	; Read data
	call KD_CONVERT
	ret


; ***********************************************************
; Title:	Poll the keyboard scan code
; Name: 	KD_POLL_CODE
; Purpose:	Checks if there are any thing inbound from
; 		the keyboard, and if there is it returns it.
; Entry:	None
; Exit:		If there are keys available:
; 		   Register A = value
;		   Carry flag = 0
;		else
;		   Carry flag = 1
;
; Registers used:      A
; ***********************************************************
KD_POLL_CODE:
	ld a, KD_WR0_REG0	; Load status of keyboard
	out (SIOCMDB), a
	in a, (SIOCMDB)
	and KD_RD0_DATA_AV	; Check if data is available
	jr z, .done		; Jump if there is no data
	and a
	in a, (SIODATAB)	; Read data
	ret
.done:
	scf
	ret

; ***********************************************************
; Title:	Convert Scan Codes to ASCII
; Name: 	KD_CONVERT
; Purpose:	Converts PS/2 Scan Codes Set 2 to ASCII chars
;
; Entry:	Scan Code in Register A
; Exit:		If the code can be converted
; 		   Register A = ASCII
;		   Carry flag = 0
;		else
;		   Carry flag = 1
;
; Registers used:      A
; ***********************************************************
KD_CONVERT:
	push de
	push hl
	ld e, a			; Save A for later
	
	ld hl, KB_PS2_COUNT	; Increase counter
	inc (hl)

	and $e0			; Test for longer sequences (two top bits)
	cp $e0
	jr nz, .test_value	; Jump if this may be a character

	ld a, e
	cp $F0			; Test for Break
	jr nz, .test_extended	; Jump if this is not a Break

	ld a, (KB_PS2_STATE)
	or KD_STATE_BREAK	; Set Break flag
	ld (KB_PS2_STATE), a
	jr .done

.test_extended:
	cp $E0			; Test for Extended
	jr nz, .test_pause	; Jump if this is not a Extended

	ld a, (KB_PS2_STATE)
	or KD_STATE_EXTENDED	; Set Extended flag
	ld (KB_PS2_STATE), a
	jr .done

.test_pause:
	cp $E1			; Test for Extended
	jr nz, .reset_flags	; Jump if this is not a Extended

	ld a, (KB_PS2_STATE)
	or KD_STATE_PAUSE	; Set Pause flag
	ld (KB_PS2_STATE), a
	jr .done

.test_value:
	ld a, (KB_PS2_STATE)
	ld d, a			; Store STATE
	and KD_STATE_PAUSE	; Test Pause flag
	jr z, .test_break_set	; Jump if we're not in a Pause seq


	ld a, (KB_PS2_COUNT)
	and $8			; Check if we're at the end of the pause seq
	jr nz, .reset_flags	; Reset flags and count

	jr .done		; We're not in the end, just continue

.test_break_set:
	ld a, d
	and KD_STATE_BREAK
	jr z, .test_ext_set
	
	ld a, e
	cp $7c
	jr nz, .reset_flags

	jr .done

.test_ext_set:
	ld a, d
	and KD_STATE_EXTENDED
	jr z, .lookup

	ld a, e
	cp $12
	jr nz, .reset_flags
	
	jr .done

.lookup:
	ld a, e
	cp $5f
	jp p, .reset_flags

	ld d, 0
	ld hl, KD_SCANCODES
	add hl, de

	ld a, (hl)
	or a
	jr z, .reset_flags
	jr .all_done

.reset_flags:
	xor a
	ld (KB_PS2_STATE), a
	ld (KB_PS2_COUNT), a
.done:
	scf
.all_done:
	pop hl
	pop de
	ret
	
KD_SCANCODES:	; Scan Code set 2


	byte 0, 0, 0, 0, 0, 0, 0, 0
	byte 0, 0, 0, 0, 0, 0, '`', 0
	byte 0, 0, 0, 0, 0, 'Q', '1', 0
	byte 0, 0, 'Z', 'S', 'A', 'W', '2', 0
	byte 0, 'C', 'X', 'D', 'E', '4', '3', 0
	byte 0, ' ', 'V', 'F', 'T', 'R', '5', 0
	byte 0, 'N', 'B', 'H', 'G', 'Y', '6', 0
	byte 0, 0, 'M', 'J', 'U', '7', '8', 0
	byte 0, ',', 'K', 'I', 'O', '0', '9', 0
	byte 0, '.', '/', 'L', ';', 'P', '-', 0
	byte 0, 0, 0, 0, '[', '=', 0, 0
	byte 0, 0, '\n', ']', 0, '\\', 0, 0

KD_SCANCODES_LEN:    equ $ - KD_SCANCODES

KD_STATE_BREAK			= %10000000
KD_STATE_EXTENDED		= %01000000
KD_STATE_PAUSE			= %00100000
KD_STATE_CAPS			= %00010000
KD_STATE_NUM			= %00001000
KD_STATE_CTRL			= %00000100
KD_STATE_ALT			= %00000010
KD_STATE_SHIFT			= %00000001



KD_RD0_BREAK			= %10000000
KD_RD0_UNDERUN_EOM		= %01000000
KD_RD0_CTS			= %00100000
KD_RD0_SYNC_HUNT		= %00010000
KD_RD0_DCD			= %00001000
KD_RD0_TX_EMPTY			= %00000100
KD_RD0_INT_PEND			= %00000010
KD_RD0_DATA_AV			= %00000001

KD_WR0_REG0			= %00000000
KD_WR0_REG1 			= %00000001
KD_WR0_REG2 			= %00000010
KD_WR0_REG3 			= %00000011
KD_WR0_REG4 			= %00000100
KD_WR0_REG5 			= %00000101
KD_WR0_REG6 			= %00000110
KD_WR0_REG7 			= %00000111

KD_WR0_CMD_NULL			= %00000000
KD_WR0_CMD_ABORT 		= %00001000
KD_WR0_CMD_RST_EXT_STS_INTS	= %00010000
KD_WR0_CMD_CHNL_RST 		= %00011000
KD_WR0_CMD_EN_INT_NXT_RX_CHR 	= %00100000
KD_WR0_CMD_RST_TX_INT 		= %00101000
KD_WR0_CMD_ERR_RST 		= %00110000
KD_WR0_CMD_RTN_FRM_INT 		= %00111000

KD_WR0_CRC_NULL			= %00000000

KD_WR1_WR_EN			= %00000000
KD_WR1_WR_FUNC			= %01000000
KD_WR1_WR_ON_RT			= %00100000

KD_WR1_RX_INT_DIS		= %00000000
KD_WR1_RX_INT_FIRST		= %00001000
KD_WR1_RX_INT_ALL_PRT		= %00010000
KD_WR1_RX_INT_ALL		= %00011000

KD_WR1_ST_AFF_INT_VEC		= %00000100
KD_WR1_TX_INT			= %00000010
KD_WR1_EXT_INT			= %00000001


KD_WR3_RX_5BITS			= %00000000
KD_WR3_RX_7BITS			= %01000000
KD_WR3_RX_6BITS			= %10000000
KD_WR3_RX_8BITS			= %11000000

KD_WR3_AUTO_EN			= %00100000
KD_WR3_HUNT			= %00010000
KD_WR3_RX_CRC			= %00001000
KD_WR3_ADDR_SRC_SDLC		= %00000100
KD_WR3_SNC_CHAR_L		= %00000010
KD_WR3_RX_EN			= %00000001

KD_WR4_CLK_X1			= %00000000
KD_WR4_CLK_X16			= %01000000
KD_WR4_CLK_X32			= %10000000
KD_WR4_CLK_X64			= %11000000

KD_WR4_SNC_8B			= %00000000
KD_WR4_SNC_16B			= %00010000
KD_WR4_SNC_SDLC			= %00100000
KD_WR4_SNC_EXT			= %00110000

KD_WR4_SNC_EN			= %00000000
KD_WR4_STP_1			= %00000100
KD_WR4_STP_15			= %00001000
KD_WR4_STP_2			= %00001100

KD_WR4_PRT_ODD			= %00000000
KD_WR4_PRT_EVEN			= %00000010

KD_WR4_PRT_EN			= %00000001

KD_WR5_DTR			= %10000000

KD_WR5_TX_5BITS			= %00000000
KD_WR5_TX_7BITS			= %00100000
KD_WR5_TX_6BITS			= %01000000
KD_WR5_TX_8BITS			= %01100000

KD_WR5_SND_BRK			= %00010000
KD_WR5_TX_EN			= %00001000
KD_WR5_SDLC_CRC16		= %00000100
KD_WR5_RTS			= %00000010
KD_WR5_TX_CRC			= %00000001


