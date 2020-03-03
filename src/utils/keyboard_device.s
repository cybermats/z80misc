


; ***********************************************************
; Title:	Setup the keyboard input
; Name: 	KD_CONFIGURE
; Purpose:	Configure and setup all variables
; 		used by the keyboard serial port.
; Entry:	None
; Exit:		None
; Registers used:      A, HL
; ***********************************************************

KD_CONFIGURE:
	; Channel reset
	ld a, KD_WR0_REG0 | KD_WR0_CMD_CHNL_RST
	out (SIOCMDB), a
	; Pointer 2 
	ld a, KD_WR0_REG2
	out (SIOCMDB), a
	; Interrupt vector
	ld a, $38;KEYBOARD_INT
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
	ld a, KD_WR1_RX_INT_FIRST
	out (SIOCMDB), a

;	ld hl, KB_BUFFER_BEG
;	ld (KB_START_PTR), hl
;	ld (KB_END_PTR), hl

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
;	push de
;	push bc
	in a, (SIODATAB)	; Fetch value from SIO
	out (OUTPORT), a
	jr .done


	ld hl, (KB_END_PTR)	; Get end pointer addr

	ld (hl), a		; Store value at KB_END_PTR

	; Now we need to update the
	; end pointer and make sure it overflows correctly.

	inc hl
	ld de, KB_BUFFER_END	; Get end of buffer

	and a  			; Clear Carry for SBC
	sbc hl, de
	jr nz, .continue	; If the end ptr is same as end of buffer
	ld hl, KB_BUFFER_BEG	; we should loop it around to the beginning

.continue:
	ld (KB_END_PTR), hl	; Store the end pointer back
.done:
	ld a, %00010000		; Pointer 0, Reset Ext/Status interrupts
	out (SIOCMDB), a
;	pop bc
;	pop de
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
	push de
	ld hl, (KB_END_PTR)	; Get end pointer addr
	ld e, l			; and store it in DE
	ld d, h

	ld hl, (KB_START_PTR)	; Get start pointer addr

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
	ld a, (hl)		; We have values, so load the oldest value

	inc hl			; Update the start ptr
	ld de, KB_BUFFER_END	; But check if we need to loop around

	and a  			; Clear Carry for SBC
	sbc hl, de
	jr nz, .update_ptr	; Jump if the start pointer isn't at the end
	ld hl, KB_BUFFER_BEG	; It is at the end, so wrap around

.update_ptr:
	ld (KB_START_PTR), hl	; Update the start pointer
.done:
	pop de
	ret


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

