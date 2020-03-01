; ***********************************************************
;
; Title:	Video Driver
;
; Purpose:	Full code for managing the video driver
; 		through the Device Handler.
;
;		Status code	Description
;		       0		No Error
;		       3		Video Card ready
;		       250		Ram test failed
; ***********************************************************



; Misc constants

VIDEO_COLUMNS:	.equ	80
VIDEO_ROWS:	.equ	30







; ***********************************************************
; Title:     Sets up and starts the video driver
; Name:	     SETUP_VIDEO_DRIVER
; Purpose:   Initializes the video card and driver by
;		 1. Create Device Table Entry
;		 2. Add device to Device List
;		 3. Initialize device
;
; Entry:     Register A = Device ID
;
; Exit:	     Nothing
; ***********************************************************

SETUP_VIDEO_DRIVER:
	ld (VIDEO_STATUS), NOERR

	; 1. Create Device Table Entry
	call CREATEDTE	   ; Get empty Device Table Entry
	push hl		   ; Save DTE
	ld de, VIDEODEVICE ; Get Device Table Entry from ROM
	       		   ; and copy it to RAM
	ex de, hl
	ld bc, 17	   ; Size of DTE
	ldir   		   ; Copy the DTE from ROM to RAM

	pop hl		   ; Restore DTE
	
	; 2. Add device to Device List
	call ADDDL	   ; Add device to Device List


	; 3. Initialize operations
	ld ix, -8	   ; Make room on the stack for IOCB
	add ix, sp
	ld sp, ix

	ld (ix+IOCBOP), IOINIT	; Initialize operations
	ld (ix+IOCBDN), a  ; Device number in register a
	call IOHDLR	   ; Call IO Handler

	ld hl, 8	   ; Clean up stack
	add hl, sp
	ld sp, hl


	; Set cursor to 0
	ld bc, 0
	call MOVE_CURSOR

	ret	


; ***********************************************************
; Title:     Video Driver initialization
; Name:	     VD_INIT
; Purpose:   Initializes the video card and driver by
; 	         1. Testing the video ram
;		 2. Initializing the Video Ram to 0
;		 3. Initialize operations
;		 4. Set all video varibles in memory
;
; Entry:     Nothing
;
; Exit:	     Nothing
; ***********************************************************

VD_INIT:
	push hl
	push de
	push bc
	push af
	; 1. Test video ram
	; 2. Initialize video ram to 0 (it's done in the ram test)
	ld hl, VRAMBEG
	ld de, VRAMEND - VRAMBEG
	call RAMTST
	jr nc, .init_6845
	; Do error handling
	ld (VIDEO_STATUS), RAMERR
	jr .done
	
	; 3. Initialize operations
.init_6845:
	ld hl, VIDEO_INIT_TBL
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
	ld (CURSOR_COL), 0
	ld (CURSOR_ROW), 0
	ld (VIDEO_STATUS), DEVRDY
.done:
	pop af
	pop bc
	pop de
	pop hl
	ret


; ***********************************************************
; Title:	Returns video driver status
; Name: 	VD_OSTAT
; Purpose:	Helper function for the Device Handler to
; 		return the Video Driver status
; Entry:	None
; Exit:		Register A = Status
; Registers used:	 A
; ***********************************************************

VD_OSTAT:
	ld a, (VIDEO_STATUS)
	ret


; ***********************************************************
; Title:	Outputs 1 byte to the video card
; Name: 	VD_OUT
; Purpose:	Prints one character to the video card
; 		at the location of the cursor. Also
;		changes the location of the cursor.
; Entry:	Register A = Char to output
; 		Register IX = Base address of IOCB
; Exit:		Register A = Copy of the IOCB status byte
; Registers used:	 A
; ***********************************************************
VD_OUT:
	push hl
	push de
	call GET_CURSOR_ADDR	; Get the cursor address
	ld de, VRAMBEG		; Get the base memory for vram
	add hl, de		; Get the memory for the new char
	ld (hl), a		; Output char

	ld b, 0	 		; Move the cursor one step to the right
	ld c, 1
	call MOVE_CURSOR_REL
	ld a, NOERR
	pop de
	pop hl
	ret



VD_OUTN:

; ***********************************************************
; Title:	Get Cursor Memory Address
; Name:		GET_CURSOR_ADDR
; Purpose:	Calculate the base address for the cursor
; 		given it's current row and column.
; Entry:	Nothing
; Exit:		Register HL = Base address for cursor
; Registers used:	 HL
; ***********************************************************

GET_CURSOR_ADDR:
	push bc
	push de
	ld b, (CURSOR_ROW)
	ld c, (CURSOR_COL)
	ld hl, 0
	ld de, 80
				; Calculate memory location of cursor
	ld hl, 0
	ld de, 80

	ld a, 0
	or b
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
; Purpose:	Move and update the cursor relative to the
; 		current position.
; Entry:	Register b = row delta
; 		Register c = columns delta
; Exit:		Cursor has been moved, and variables updated.
; Registers used:      A
; ***********************************************************
MOVE_CURSOR_REL:
; Update and adjust the rows and columns
  	; Columns
	ld a, (CURSOR_COL)
	add c
	jr nc, .check_col_overflow
				; We had a column move
	       			; ending in the previous line
	dec b
	add VIDEO_COLUMNS	; Adjust column

.check_col_overflow:
	cp VIDEO_COLUMNS
	jp p, .col_done
	inc b
	sub VIDEO_COLUMNS
.col_done:
	ld (CURSOR_COL), a

	; Rows

	ld a, (CURSOR_ROW)
	add b
	jr nc, .check_row_overflow

	add VIDEO_ROWS

.check_row_overflow:
	cp VIDEO_ROWS
	jp p, .row_done
	sub VIDEO_ROWS

.row_done:
	ld (CURSOR_ROW), a
	call UPDATE_CURSOR
	ret

; ***********************************************************
; Title:	Move cursor absolute
; Name: 	MOVE_CURSOR_REL
; Purpose:	Move and update the cursor to a new
; 		position.
; Entry:	Register b = row
; 		Register c = columns
; Exit:		Cursor has been moved, and variables updated.
; Registers used:      A
; ***********************************************************
MOVE_CURSOR:
	push hl		; Save status
	push de

	ld (CURSOR_ROW), b
	ld (CURSOR_COL), c

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

	call UPDATE_CURSOR

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
UPDATE_CURSOR:
	push hl
	push de
	push af
; Set the actual cursor to the correct location
      	ld hl, 0
	ld de, VIDEO_COLUMNS

	ld b, (CURSOR_ROW)
	ld c, (CURSOR_COL)

	ld a, 0
	or b
	jr z, .loop_done
.loop:
	add hl, de
	djnz, .loop
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
	pop de
	pop hl
	ret


VIDEO_DEVICE:  ; Device table entry for the Video Card
	.dw	0	; Link Field
	.db	1	; Device 1
	.dw	VD_INIT ; Video Driver Initialize
	.dw	0	; No Video Driver Input Status
	.dw	0	; No Video Driver Input 1 byte
	.dw	0	; No Video Driver Input N bytes
	.dw	VD_OSTAT; Video Driver output status
	.dw	VD_OUT  ; Video Driver output 1 byte
	.dw	VD_OUTN ; Video Driver output N bytes

VD_INIT_TBL:
	.db $64, $50 ; Horizontal Total, Horizontal Displayed
	.db $52, $0c ; Horizontal Sync Pos, Sync Width
	.db $1f, $0c ; Vertical Total, Vertical Total Adjust
	.db $1e, $1f ; Vertical Displayed, Vertical Sync Position
	.db $00, $0f ; Interlace Mode, Maximum Scan Line Address
	.db $47, $0f ; Cursor start + mode, Cursor end
	.db $00, $00 ; Memory Start offset high, low
	.db $00, $00 ; Cursor address high, low
