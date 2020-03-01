RAMBEG:	      equ  $8000	    ; Begin of RAM
RAMEND:	      equ  $ffff	    ; End of RAM
	
init:				    
	ld    SP, RAMEND	    ; Set Stack to end of memory
	jp main
	
	org $0100
	
main:
	ld a, $1		; Indicate that the test starts
	out ($00), a

	; Test memory 
	ld hl, RAMBEG	; hl = base address 
	ld de, $7000	; de = size of area
	call RAMTST 

	jr c, RAMERR	; If carry is set, jump to RAMERR
	ld a, $2		; No error, indicate success
	out ($00), a
	halt

RAMERR:
	

	; An error has happened. Loop through $ff, h, l, and a.
	ld e, a 		; Save a 
	ld a, $ff 		; Show $ff
	out ($00), a 
	call SLEEP
	ld a, h 		; Show h
	out ($00), a 
	call SLEEP
	ld a, l 		; Show l
	out ($00), a 
	call SLEEP
	ld a, e 		; Show error value
	out ($00), a 
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
	
	org $7fe
	word $0000
