RAMBEG:	      equ  008000h	    ; Begin of RAM
RAMEND:	      equ  00ffffh	    ; End of RAM
VRAMBEG:	  equ  7000h		; Begin VRAM
VRAMEND:	  equ  7fffh		; End VRAM
OUTPORT:	  equ  00h			; Parallel out port
VADDRPORT:	  equ  80h			; Video Address port
VDATAPORT:	  equ  81h			; Video Data port

init:				    
	ld    SP, RAMEND	    ; Set Stack to end of memory
	jp main
	
	org 0100h
	
main:
	ld a, 1h		; Indicate that the test starts
	out (OUTPORT), a


	; Test memory 
	ld hl, VRAMBEG	; hl = base address 
	ld de, VRAMEND - VRAMBEG	; de = size of area
	call RAMTST 

	jr c, RAMERR	; If carry is set, jump to RAMERR
	ld a, 2h		; No error, indicate success
	out (OUTPORT), a
	halt
RAMERR:
	; An error has happened. Loop through $ff, h, l, and a.
	ld e, a 		; Save a 
RAMERRLOOP:
	ld a, 00ffh 		; Show $ff
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


	include "utils/ramtest.s"
	include "utils/timing.s"

SLEEP:
	; Delay 1 second
	; Call DELAY 4 times at 250 ms each
	ld b, 4
delay_loop:
	ld a, 250
	call DELAY
	djnz delay_loop
	ret	

	org 0700h
VIDEO_INIT_TBL:
	db 100, 80, 82, 12
	db 31, 12, 30, 31
	db 0, 15


	org 07feh
	dw 0000h



; Pin out for Controller pins from Video Card, from left to right.
; 0 - reset
; 1 - WR
; 2 - RD
; 3 - IORQ
; 4 - MREQ
