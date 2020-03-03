; ***********************************************************
;
; Title:	Video Driver
;
; Purpose:	Driver for the video card
;
; ***********************************************************



; Misc constants

VIDEO_COLUMNS:	equ	80
VIDEO_ROWS:	equ	30


; ***********************************************************
; Title:	Initialize and configure the video card
; Name: 	VD_CONFIGURE
; Purpose:	Configures the video card with the settings
; 		that will be used.
; Entry:	None
; 		
; Exit:		None
; Registers used:	 A
; ***********************************************************
VD_CONFIGURE:
	push hl
	push bc
	ld hl, VD_INIT_TBL
	ld b, 16
	ld c, 0

.loop:
	ld a, c
	out (VADDRPORT), a
	ld a, (hl)
	out (VDATAPORT), a
	inc hl
	inc c
	djnz .loop

	; 4. Set all video variables in memory
	ld hl, CURSOR_COL
	ld (hl), 0
	ld hl, CURSOR_ROW
	ld (hl), 0
	call VD_UPDATE_CURSOR
.done:
	pop bc
	pop hl
	ret



; ***********************************************************
; Title:	Outputs 1 byte to the video card
; Name: 	VD_OUT
; Purpose:	Prints one character to the video card
; 		at the location of the cursor. Also
;		changes the location of the cursor.
; Entry:	Register A = Char to output
; Exit:		None
; Registers used:	 A, HL
; ***********************************************************
VD_OUT:
;	out (OUTPORT), a
	push de
	push bc
	call VD_GET_CURSOR_ADDR	; Get the cursor address
	ld de, VRAMBEG		; Get the base memory for vram
	add hl, de		; Get the memory for the new char
	ld (hl), a		; Output char

	ld b, 0	 		; Move the cursor one step to the right
	ld c, 1
	call VD_MOVE_CURSOR_REL
	call VD_UPDATE_CURSOR
	pop bc
	pop de
	ret



; ***********************************************************
; Title:	Outputs N bytes to the video card
; Name: 	VD_OUTN
; Purpose:	Prints one character to the video card
; 		at the location of the cursor. Also
;		changes the location of the cursor.
;
;		Handles newlines (\n) and null terminated
;		strings.
;
; Entry:	Register HL = Pointer to string
; 		Register BC = Length of string
;
; Exit:		None
; Registers used:	 A, HL, BC
; ***********************************************************
VD_OUTN:
	push de
	push hl
	call VD_GET_CURSOR_ADDR
	ld de, VRAMBEG
	add hl, de
	ex de, hl
	pop hl
	
.loop:
	ld a, (hl)
	or a		; Check end of string
	jr z, .done
	cp $0a		; Check new-line
	jr z, .eol

	push bc
	ld b, 0
	ld c, 1
	call VD_MOVE_CURSOR_REL
	pop bc

	ldi		; Copy data
	jp pe, .loop
.done:
	call VD_UPDATE_CURSOR
	pop de
	ret
.eol:
	push hl
	call VD_NEW_LINE	; Get the new frame buffer pointer
	call VD_GET_CURSOR_ADDR
	ld de, VRAMBEG
	add hl, de
	ex de, hl
	pop hl
	inc hl
	dec bc
	ld a, b
	or c
	jr z, .done
	jr .loop
	

	
VD_NEW_LINE:
	xor a
	ld (CURSOR_COL), a
	ld a, (CURSOR_ROW)
	inc a
.check_row_overflow:
	cp VIDEO_ROWS
	jp m, .row_done
	sub VIDEO_ROWS
	jr .check_row_overflow
.row_done:
	ld (CURSOR_ROW), a		; Save CURSOR_ROW
	ret
	
	
	
	

; ***********************************************************
; Title:	Get Cursor Memory Address
; Name:		GET_CURSOR_ADDR
; Purpose:	Calculate the base address for the cursor
; 		given it's current row and column.
; Entry:	Nothing
; Exit:		Register HL = Base address for cursor
; Registers used:	 HL
; ***********************************************************

VD_GET_CURSOR_ADDR:
	push bc
	push de
	ld hl, CURSOR_ROW
	ld b, (hl)
	ld hl, CURSOR_COL
	ld c, (hl)
				; Calculate memory location of cursor
	ld hl, 0

	ld e, a			; Store a
	xor a
	or b
	ld a, e
	ld de, 80
	jr z, .loop_done

.loop:
	add hl, de
	djnz .loop
.loop_done:
	add hl, bc
	pop de
	pop bc
	ret


; ***********************************************************
; Title:	Move cursor relative
; Name: 	MOVE_CURSOR_REL
; Purpose:	Move the cursor relative to the
; 		current position.
;
;		!! Doesn't update the cursor in the video chip !!
;
; Entry:	Register b = row delta
; 		Register c = columns delta
; Exit:		Cursor has been moved, and variables updated.
; Registers used:      A, BC
; ***********************************************************
VD_MOVE_CURSOR_REL:
; Update and adjust the rows and columns
  	; Columns
	ld a, (CURSOR_COL)
	add c
	jp p, .check_col_overflow
				; We had a column move
	       			; ending in the previous line
	dec b
	add VIDEO_COLUMNS	; Adjust column

.check_col_overflow:
	cp VIDEO_COLUMNS
	jp m, .col_done
	inc b
	sub VIDEO_COLUMNS
	jr .check_col_overflow
.col_done:
	ld (CURSOR_COL), a		; Save CURSOR_COL

	; Rows
	ld a, (CURSOR_ROW)
	add b
	jp p, .check_row_overflow

	add VIDEO_ROWS

.check_row_overflow:
	cp VIDEO_ROWS
	jp m, .row_done
	sub VIDEO_ROWS
	jr .check_row_overflow
.row_done:
	ld (CURSOR_ROW), a		; Save CURSOR_ROW
	ret

; ***********************************************************
; Title:	Move cursor absolute
; Name: 	MOVE_CURSOR
; Purpose:	Move and update the cursor to a new
; 		position.
; Entry:	Register b = row
; 		Register c = columns
; Exit:		Cursor has been moved, and variables updated.
; Registers used:      A
; ***********************************************************
VD_MOVE_CURSOR:
	push hl		; Save status
	push de
	ld hl, CURSOR_ROW
	ld (hl), b
	ld hl, CURSOR_COL
	ld (hl), c

	ld hl, 0	; Initialize the counters
	ld de, VIDEO_COLUMNS

	ld a, 0		; Check if we're on the first row
	or b
	jr z, .loop_done

.loop:
	add hl, de
	djnz .loop
.loop_done:
	add hl, bc

	pop de
	pop hl
	ret

; ***********************************************************
; Title:	Update cursor position on screen
; Name: 	UPDATE_CURSOR
; Purpose:	Update the cursor from the two memory position
; 		describing it's position, CURSOR_COL, CURSOR_ROW.
; Entry:	None
; Exit:		None
; Registers used:      None
; ***********************************************************
VD_UPDATE_CURSOR:
	push hl
	push de
	push bc
	push af
; Set the actual cursor to the correct location

	ld hl, CURSOR_ROW
	ld b, (hl)
	ld hl, CURSOR_COL
	ld c, (hl)

      	ld hl, 0
	ld de, VIDEO_COLUMNS
	
	ld a, 0
	or b
	jr z, .loop_done
.loop:
	add hl, de
	djnz .loop
.loop_done:
	add hl, bc

; Output the cursor location to the video chip
  	ld a, 14   ; Register 14
	out (VADDRPORT), a
	ld a, h
	out (VDATAPORT), a

	ld a, 15   ; Register 15
	out (VADDRPORT), a
	ld a, l
	out (VDATAPORT), a
	 
	pop af
	pop bc
	pop de
	pop hl
	ret


VD_INIT_TBL:
	db $64, $50 ; Horizontal Total, Horizontal Displayed
	db $52, $0c ; Horizontal Sync Pos, Sync Width
	db $1f, $0c ; Vertical Total, Vertical Total Adjust
	db $1e, $1f ; Vertical Displayed, Vertical Sync Position
	db $00, $0f ; Interlace Mode, Maximum Scan Line Address
	db $47, $0f ; Cursor start + mode, Cursor end
	db $00, $00 ; Memory Start offset high, low
	db $00, $00 ; Cursor address high, low
