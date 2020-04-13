RAMBEG:	      equ  8000h	    ; Begin of RAM
RAMEND:	      equ  0ffffh	    ; End of RAM
	
init:				    
	ld    SP, RAMEND	    ; Set Stack to end of memory
	jp main
	
	org 0100h
	
main:
	ld a, 1h		; Indicate that the test starts
	out (00h), a

	; Test memory 
	ld hl, RAMBEG	; hl = base address 
	ld de, 7000h	; de = size of area
	call RAMTST 

	jr c, RAMERR	; If carry is set, jump to RAMERR
	ld a, 2h		; No error, indicate success
	out (00h), a
	halt

RAMERR:
	

	; An error has happened. Loop through $ff, h, l, and a.
	ld e, a 		; Save a 
	ld a, 0ffh 		; Show $ff
	out (00h), a 
	call SLEEP
	ld a, h 		; Show h
	out (00h), a 
	call SLEEP
	ld a, l 		; Show l
	out (00h), a 
	call SLEEP
	ld a, e 		; Show error value
	out (00h), a 
	call SLEEP
	jp RAMERR



SLEEP:
	; Delay 1 second
	; Call DELAY 4 times at 250 ms each
	ld b, 4
delay_loop:
	ld a, 250
	call DELAY
	djnz delay_loop
	ret	


	include "utils/timing.s"
	include "utils/ramtest.s"
	
	org 07feh
	dw 0000h
