


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

	; Initialize the keyboard input buffer
	push hl
	ld hl, KB_BUFFER_BEG
	ld (KB_START_PTR), hl
	ld (KB_END_PTR), hl
	xor a
	ld (KB_PS2_STATE), a
	ld (KB_PS2_COUNT), a
	pop hl

	; Channel reset
	ld a, SIO_WR0_REG0 | SIO_WR0_CMD_CHNL_RST
	out (SIOCMDA), a
	nop
	nop
	; Pointer 2 
	ld a, SIO_WR0_REG2
	out (SIOCMDB), a
	; Interrupt vector
	ld a, e
	out (SIOCMDB), a
	; Ptr 4. Reset Ext/Status interrupts
	ld a, SIO_WR0_REG4 | SIO_WR0_CMD_RST_EXT_STS_INTS
	out (SIOCMDA), a
	; x1 Clock mode, Async,1 stop bit, odd partity
	ld a, SIO_WR4_CLK_X1 | SIO_WR4_STP_1 | SIO_WR4_PRT_ODD | SIO_WR4_PRT_EN
	out (SIOCMDA), a
	; Pointer 3
	ld a, SIO_WR0_REG3
	out (SIOCMDA), a
	; Rx 8 bits, no auto enable, Rx enable
	ld a, SIO_WR3_RX_8BITS | SIO_WR3_RX_EN
	out (SIOCMDA), a
	; Pointer 5
	ld a, SIO_WR0_REG5
	out (SIOCMDA), a
	; 8 bits, Tx not enabled
	ld a, SIO_WR5_TX_8BITS
	out (SIOCMDA), a
	; Pointer 1, Reset Ext/Status ints
	ld a, SIO_WR0_REG1 | SIO_WR0_CMD_RST_EXT_STS_INTS
	out (SIOCMDA), a
	; Receive interrupts On First Char only
	ld a, e
	or a	; Check if interrupt vector has been given
	
	ld a, SIO_WR1_RX_INT_DIS	; Default to disabled
	jr z, .no_ints ; Jump if no vector is specified
	ld a, SIO_WR1_RX_INT_FIRST | SIO_WR1_ST_AFF_INT_VEC	; Turn on ints
.no_ints
	out (SIOCMDA), a

	pop de
	ret


; ***********************************************************
; Title:	Callback for Keyboard interrupt
; Name: 	KD_CALLBACK
; Purpose:	Reads the value from the serial port
; 		and stores it in a circular buffer.
; Entry:	None
; Exit:		None
; Registers used:	None
; ***********************************************************
KD_CALLBACK:
	push af
	in a, (SIODATAA)	; Fetch value from SIO
	call KD_CONVERT		; Convert A to ASCII
	jr c, .done		; This is not a key press we care about
	
	call KD_BUFFER_KEY	; Store ASCII in key buffer.
.done
	ld a, SIO_WR0_CMD_EN_INT_NXT_RX_CHR
	out (SIOCMDA), a
	ld a, SIO_WR0_CMD_RTN_FRM_INT
	out (SIOCMDA), a

	pop af
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
; Name: 	KD_NEXT_VAL
; Purpose:	Returns the next value from the circular
; 		buffer used to store keys from the keyboard.
;
;		Blocks if no values are present.
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
KD_NEXT_VAL:
	push bc
	push de
	push hl
.loop
	ld de, (KB_START_PTR)	; Get end pointer addr
	ld hl, (KB_END_PTR)	; Get start pointer addr

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
	ld hl, KB_BUFFER_END	; But check if we need to loop around

	and a  			; Clear Carry for SBC
	sbc hl, de
	jr nz, .update_ptr	; Jump if the start pointer isn't at the end
	ld de, KB_BUFFER_BEG	; It is at the end, so wrap around

.update_ptr:
	ld (KB_START_PTR), de	; Update the start pointer
	or a
.done:
	ld a, c
	pop hl
	pop de
	pop bc
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

	and 00e0h		; Test for longer sequences (two top bits)
	cp 00e0h
	jr nz, .test_pause_set	; Jump if this may be a character

	ld a, e
	cp 00f0h		; Test for Break
	jr nz, .test_extended	; Jump if this is not a Break

	ld a, (KB_PS2_STATE)
	or KD_STATE_BREAK	; Set Break flag
	ld (KB_PS2_STATE), a
	jp .done

.test_extended:
	cp 00e0h		; Test for Extended
	jr nz, .test_pause	; Jump if this is not a Extended

	ld a, (KB_PS2_STATE)
	or KD_STATE_EXTENDED	; Set Extended flag
	ld (KB_PS2_STATE), a
	jp .done

.test_pause:
	cp 00e1h			; Test for Extended
	jp nz, .reset_flags	; Jump if this is not a Extended

	ld a, (KB_PS2_STATE)
	or KD_STATE_PAUSE	; Set Pause flag
	ld (KB_PS2_STATE), a
	jp .done

.test_pause_set:
	ld a, (KB_PS2_STATE)
	ld d, a			; Store STATE
	and KD_STATE_PAUSE	; Test Pause flag
	jr z, .test_break_set	; Jump if we're not in a Pause seq


	ld a, (KB_PS2_COUNT)
	and 8h			; Check if we're at the end 3of the pause seq
	jp nz, .reset_flags	; Reset flags and count

	jp .done		; We're not in the end, just continue

.test_break_set:
	ld a, d
	and KD_STATE_BREAK
	jr z, .test_ext_set
	
	ld a, e
	cp 7ch			; Test for Prt Scr
	jp z, .done		; Is Prt Scr, we're done

	      			; Check if it's a meta key that
				; has been broken
				; which can be Left (not extended) or
				; Right (extended) Alt/Shift/Ctrl

	ld a, d			; Check for Right (extended)
	and KD_STATE_EXTENDED
	jr nz, .test_meta_ext	; It's extended
	
	ld a, e			; It's not extended
	cp 11h			; Alt
	jr z, .clear_alt
	cp 12h			; Shift (Left)
	jr z, .clear_shift
	cp 14h			; Ctrl
	jr z, .clear_ctrl
	cp 59h
	jr z, .clear_shift	; Shift (Right)

	jp .reset_flags		; It's not a meta key, ignore this break


.test_meta_ext:
	ld a, e			; It's extended
	cp 11h			; Alt
	jr z, .clear_alt
	cp 14h			; Ctrl
	jr z, .clear_ctrl

	jp .reset_flags		; It's not a meta key, ignore this break

.clear_alt:
	ld a, d
	and (~KD_STATE_ALT) & KD_STATE_CLEAR_FLAGS
	ld (KB_PS2_STATE), a
	ld d, a
	jp .reset_flags
.clear_shift:
	ld a, d
	and (~KD_STATE_SHIFT) & KD_STATE_CLEAR_FLAGS
	ld (KB_PS2_STATE), a
	ld d, a
	jp .reset_flags
.clear_ctrl:
	ld a, d
	and (~KD_STATE_CTRL) & KD_STATE_CLEAR_FLAGS
	ld (KB_PS2_STATE), a
	ld d, a
	jr .reset_flags



.test_ext_set:
	ld a, d			; Check if this char is extended.
	and KD_STATE_EXTENDED
	jr z, .lookup		; It's not, go to lookup.

	ld a, e
	cp 12h
	jr z, .done		; It's Ptr Scr. We're done.

	      			; Check if the extended char
				; is a meta char. If that's the case
				; we need to set the right meta key.

	cp 11h			; Alt
	jr z, .set_alt
	cp 12h
	jr z, .set_shift
	cp 14h			; Ctrl
	jr z, .set_ctrl

	jr .reset_flags		; It's not a meta char. Ignore

	
.lookup:
	ld a, e
	cp KD_SCANCODES_LEN	; Check if the value is too high
	   			; to be an actual char.
	jp p, .reset_flags	; It is, abort.

	ld a, d
	and KD_STATE_SHIFT
	jr nz, .lookup_shift
	ld a, d
	and KD_STATE_CTRL
	jr nz, .lookup_ctrl
	
	ld hl, KD_SCANCODES
	jr .lookup_default

.lookup_shift:
	ld hl, KD_SCANCODES_SHIFT
	jr .lookup_default	

.lookup_ctrl:
	ld hl, KD_SCANCODES_CTRL
	jr .lookup_default	

.lookup_default:
	ld d, 0			; Check in lookup table.
	add hl, de
	
	ld a, (KB_PS2_STATE)
	ld d, a			; Store STATE again

	ld a, (hl)
	or a
	jr nz, .all_done	; Jump if it's a char

	
	ld a, e			; It's not a char, check for meta
	cp 11h			; Alt
	jr z, .set_alt
	cp 12h			; Shift (Left)
	jr z, .set_shift
	cp 14h			; Ctrl
	jr z, .set_ctrl
	cp 59h
	jr z, .set_shift	; Shift (Right)

	jr .reset_flags		; It's not a char and not meta.

	
.set_alt:
	ld a, d
	or KD_STATE_ALT & KD_STATE_CLEAR_FLAGS
	ld (KB_PS2_STATE), a
	ld d, a
	jr .reset_flags
.set_shift:
	ld a, d
	or KD_STATE_SHIFT & KD_STATE_CLEAR_FLAGS
	ld (KB_PS2_STATE), a
	ld d, a
	jr .reset_flags
.set_ctrl:
	ld a, d
	or KD_STATE_CTRL & KD_STATE_CLEAR_FLAGS
	ld (KB_PS2_STATE), a
	ld d, a
	jr .reset_flags

.reset_flags:
	xor a
	ld (KB_PS2_COUNT), a
	ld a, d
	and KD_STATE_CLEAR_FLAGS
	ld (KB_PS2_STATE), a
.done:
	scf
.all_done:
	pop hl
	pop de
	ret


	include "sc-us.s"	; Include scan codes table

KD_STATE_BREAK			= 10000000b
KD_STATE_EXTENDED		= 01000000b
KD_STATE_PAUSE			= 00100000b
KD_STATE_CAPS			= 00010000b
KD_STATE_NUM			= 00001000b
KD_STATE_CTRL			= 00000100b
KD_STATE_ALT			= 00000010b
KD_STATE_SHIFT			= 00000001b

KD_STATE_CLEAR_FLAGS		= 00000111b