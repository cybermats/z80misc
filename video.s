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


	; Load vram with 0-255 values
init_vram_loop:
	ld a, (de)
	or a
	jr nz, middle
	ld de, MESSAGE
	ld a, (de)
middle:
	ld (hl), a
	inc hl
	inc de
	dec bc 		; Decrement and test 16-bit counter
	ld a, b
	or c
	jr nz, init_vram_loop ; Continue until memory tested

	ld a, 3
	out (OUTPORT), a
	halt




	.org $0700
VIDEO_INIT_TBL:
	.db $64, $50 ; Horizontal Total, Horizontal Displayed
	.db $52, $0c ; Horizontal Sync Pos, Sync Width
	.db $1f, $0c ; Vertical Total, Vertical Total Adjust
	.db $1e, $1f ; Vertical Displayed, Vertical Sync Position
	.db $00, $0f ; Interlace Mode, Maximum Scan Line Address
	.db $20, $0f ; Cursor start + mode, Cursor end
	.db $00, $00 ; Memory Start offset high, low
	.db $00, $00 ; Cursor address high, low
MESSAGE:
	.data "0123456789abcdefghiJABCDEFGHIJ!", $22 ,"#¤%&/()=", 0

	.org $07fe
	.word $0000



; Pin out for Controller pins from Video Card, from left to right.
; 0 - reset
; 1 - WR
; 2 - RD
; 3 - IORQ
; 4 - MREQ