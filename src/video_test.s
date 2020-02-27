RAMBEG:	      .equ  $8000	    ; Begin of RAM
RAMEND:	      .equ  $ffff	    ; End of RAM
VRAMBEG:	  .equ  $7000		; Begin VRAM
VRAMEND:	  .equ  $7fff		; End VRAM
OUTPORT:	  .equ  $00			; Parallel out port
VADDRPORT:	  .equ  $80			; Video Address port
VDATAPORT:	  .equ  $81			; Video Data port

init:				    
	ld    SP, RAMEND	    ; Set Stack to end of memory
	jp main
	
	.org $0100
	
main:
	ld a, $1		; Indicate that the test starts
	out (OUTPORT), a


	; Test memory 
	ld hl, VRAMBEG	; hl = base address 
	ld de, VRAMEND - VRAMBEG	; de = size of area
	call RAMTST 

	jr c, RAMERR	; If carry is set, jump to RAMERR
	ld a, $2		; No error, indicate success
	out (OUTPORT), a
	halt
RAMERR:
	; An error has happened. Loop through $ff, h, l, and a.
	ld e, a 		; Save a 
RAMERRLOOP:
	ld a, $ff 		; Show $ff
	out (OUTPORT), a 
	call SLEEP
	ld a, h 		; Show h
	out (OUTPORT), a 
	call SLEEP
	ld a, l 		; Show l
	out (OUTPORT), a 
	call SLEEP
	ld a, e 		; Show error value
	out (OUTPORT), a 
	call SLEEP
	jp RAMERRLOOP


	.include "utils/ramtest.s"
	.include "utils/timing.s"

SLEEP:
	; Delay 1 second
	; Call DELAY 4 times at 250 ms each
	ld b, 4
delay_loop:
	ld a, 250
	call DELAY
	djnz delay_loop
	ret	

	.org $0700
VIDEO_INIT_TBL:
	.db 100, 80, 82, 12
	.db 31, 12, 30, 31
	.db 0, 15


	.org $07fe
	.word $0000



; Pin out for Controller pins from Video Card, from left to right.
; 0 - reset
; 1 - WR
; 2 - RD
; 3 - IORQ
; 4 - MREQ
