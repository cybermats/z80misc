RAMBEG:	      .equ  $8000	    ; Begin of RAM
RAMEND:	      .equ  $ffff	    ; End of RAM
VRAMBEG:	  .equ  $7000		; Begin VRAM
VRAMEND:	  .equ  $7fff		; End VRAM
OUTPORT:	  .equ  $00			; Parallel out port
VADDRPORT:	  .equ  $80			; Video Address port
VDATAPORT:	  .equ  $81			; Video Data port

init:				    
	ld    SP, RAMEND	    ; Set Stack to end of memory
;	jp main





	
;	.org $0100
	
main:
	; Prepare system
	ld a, $1		; Indicate that the system starts
	out (OUTPORT), a

	; Do ram test
	ld hl, VRAMBEG
	ld de, VRAMEND - VRAMBEG
	call RAMTST
	jr nc, RAMTEST_SUCC

RAMTEST_ERR:
	ld a, $ff
	out (OUTPORT), a
	halt

RAMTEST_SUCC:


	ld a, $2		; Indicate that the system starts
	out (OUTPORT), a


	; Initialize the 6845
	ld hl, VIDEO_INIT_TBL
	ld b, 16
	ld c, 0

init_6845_loop:
	ld a, c
	out (OUTPORT), a
	out (VADDRPORT), a
	ld a, (hl)
	out (OUTPORT), a
	out (VDATAPORT), a
	inc hl
	inc c
	djnz init_6845_loop

	ld a, $4		; Indicate that the system starts
	out (OUTPORT), a

	ld hl, VRAMBEG	; hl = base address 
	ld bc, VRAMEND - VRAMBEG	; bc = size of area
	ld de, MESSAGE

	ld a, 3
	out (OUTPORT), a

	jr SLOWLY_UPDATE_SCREEN


; Paint border with cursor at 0,0
PAINT_BORDER:
	ld a, $db ; Full block
	; Top row
	ld hl, VRAMBEG
	ld de, VRAMBEG+1
	ld (hl), a
	ld bc, 79
	ldir

	; Bottom row
	ld hl, VRAMBEG + (80 * 29) ; Beginning of last row
	ld de, VRAMBEG + (80 * 29) + 1
	ld (hl), a
	ld bc, 79
	ldir


	ld hl, VRAMBEG
	ld de, 79
	ld b, 30

PAINT_BORDER_LOOP:
	ld (hl), a ; Left border
	add hl, de
	ld (hl), a ; Right border
	inc hl
	djnz PAINT_BORDER_LOOP


	halt


; Move the cursor
SLOWLY_UPDATE_SCREEN:
	ld e, $40
CHAR_LOOP$:
	ld b, $00
	ld hl, VRAMBEG
ROW_LOOP$:
	ld c, $00
COL_LOOP$:
	call SET_CURSOR
	ld (hl), e
	inc hl
;	ld a, 10
;	call DELAY
	call SLEEP

	inc c
	ld a, 80
	cp c
	jr nz, COL_LOOP$
	inc b
	ld a, 30
	cp b
	jr nz, ROW_LOOP$
	inc e
	jr CHAR_LOOP$

	halt


; Set Cursor position
; Arguments:	b = Row
;				c = Column
SET_CURSOR:
	push hl
	push de
	push bc
	ld hl, 0
	ld de, 80

	ld a, 0
	cp b
	jr z, SET_CURSOR_LOOP_DONE$

SET_CURSOR_LOOP$:
	add hl, de
	djnz SET_CURSOR_LOOP$
SET_CURSOR_LOOP_DONE$:
	add hl, bc

	ld a, 14
	out (VADDRPORT), a
	ld a, h
	out (VDATAPORT), a
	out (OUTPORT), a
	ld a, 15
	out (VADDRPORT), a
	ld a, l
	out (VDATAPORT), a
	pop bc
	pop de
	pop hl
	ret



SLEEP:
	push bc
	; Delay 1 second
	; Call DELAY 4 times at 250 ms each
	ld b, 4
delay_loop:
	ld a, 250
	call DELAY
	djnz delay_loop
	pop bc
	ret	

	.include "utils/timing.s"
	.include "utils/ramtest.s"


	.org $0700
VIDEO_INIT_TBL:
	.db $64, $50 ; Horizontal Total, Horizontal Displayed
	.db $52, $0c ; Horizontal Sync Pos, Sync Width
	.db $1f, $0c ; Vertical Total, Vertical Total Adjust
	.db $1e, $1f ; Vertical Displayed, Vertical Sync Position
	.db $00, $0f ; Interlace Mode, Maximum Scan Line Address
	.db $47, $0f ; Cursor start + mode, Cursor end
	.db $00, $00 ; Memory Start offset high, low
	.db $00, $00 ; Cursor address high, low
MESSAGE:
	.data "0123456789abcdefghijABCDEFGHIJ!", $22 ,"#¤%&/()=", 0

	.org $07fe
	.word $0000



; Pin out for Controller pins from Video Card, from left to right.
; 0 - reset
; 1 - WR
; 2 - RD
; 3 - IORQ
; 4 - MREQ
