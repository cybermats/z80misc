; Title		RAM test
; Name: 	RAMTST
;
; Purpose:	Test a RAM (read/write memory) area
;				1) Write all 0 and test
; 				2) Write all FF hex and test
; 				3) Write all AA hex and test
; 				4) Write all 55 hex and test
;				5) Shift a single 1 through each bit,
;				   while clearing all other bits
;
;				If the program finds an error, it exits
;				immediately with the Carry flag set and
;				indicates where the error occurred and
;				what value it used in the test.
;
; Entry:	Register pair HL = Base address of test area
;			Register pair DE = Size of area in bytes
;
; Exit:		If there are no errors then
;				Carry flag = 0
; 				test area contains 0 in all bytes
; 			else
;				Carry flag = 1
;				Register pair HL = Address of error
;				Register A = Expected value
;
; Registers used: AF, BC, DE, HL
;
; Time:		Approximately 633 cycles per byte plus
;			663 cycles overhead
;
; Size:		Program 82 bytes
;

RAMTST:
	; Exit with no errors if area size is 0
	ld a, d 	; Test area size
	or e
	ret z		; Exit with no errors if size is zero
	ld b, d 	; BC = area size
	ld c, e 

	; Fill memory with 0 and test
	sub a
	call FILCMP
	ret c 		; Exit if error found

	; Fill memory with FF HEX (all 1s) and test
	ld a, 00ffh
	call FILCMP
	ret c 		; Exit if error found

	; Fill memory with AA hex (alternating 1s and 0s) and test
	ld a, 00aah
	call FILCMP
	ret c 		; Exit if error found

	; Fill memory with 55 hex (alternating 1s and 0s) and test
	ld a, 0055h
	call FILCMP
	ret c 		; Exit if error found



	; Perform walking bit test. Place a 1 in bit 7 and
	; see if it can be read back. Then move the 1 to
	; bits 6, 5, 4, 3, 2, 1 and 0 and see if it can 
	; be read back.
WLKLP:
	ld a, 0080h	; Make bit 7 1, all other bits 0
WLKLP1:
	ld (hl), a 	; Store test pattern in memory
	cp (hl)		; Try to read it back
	scf			; Set carry in case of error 
	ret nz		; Return if error 
	rrca		; Rotate pattern to move 1 right
	cp 0080h		
	jr nz, WLKLP1 ; Continue until 1 is back in bit 7
	ld (hl), 0	; Clear byte just checked
	inc hl
	dec bc 		; Decrement and test 16-bit counter
	ld a, b
	or c
	jr nz, WLKLP ; Continue until memory tested
	ret 		; No errors (Note OR C clears carry)


; *******************************************
; Routine:	FILCMP
; Purpose:	Fill memory with a value and test
;			that it can be read back
; Entry:	A = Test value
;			HL = Base address
; 			BC = Size of area in bytes
; Exit:		If no errors then
;				Carry flag is 0 
; 			else
;	  			Carry flag is 1
;				HL = Address of error
;				DE = Base address
;				BC = Size of area in bytes
; 				A = Test value
; Registers used: AF, BC, DE, HL
; *******************************************

FILCMP:
	push hl 	; Save base address
	push bc 	; Save size of area
	ld e, a 	; Save test value
	ld (hl), a 	; Store test value in first byte
	dec bc 		; Remaining area = Size - 1
	ld a, b 	; Check if anything in remaining area
	or c 
	ld a, e 	; restore test value
	jr z, COMPARE ; Branch if area was only 1 byte

	; Fill rest of area using block move
	;  each iteration moves test value to next higher address
	ld d, h 	; Destination is always source + 1
	ld e, l 
	inc de 
	ldir		; Fill memory

	; Now that memory has been filled, test to see if
	; each byte can be read back correctly
COMPARE:
	pop bc 		; Restore size of area
	pop hl 		; Restore base address 
	push hl 	; save base address
	push bc 	; save size of value

	; Compare memory and test value
CMPLP:
	cpi 
	jr nz, CMPER ; Jump if not equal
	jp pe, CMPLP ; Continue through entire area
				; Note CPI clear P/V flag if it
				; decrements bc to 0

	; No errors found, so clear carry 
	pop bc 		; BC = size of area
	pop hl 		; HL = base address 
	or a 		; Clear carry, indicating no errors 
	ret 

	; Error exit, set carry 
	; HL = Address of error 
	; A = test value 
CMPER:
	pop bc 		; bc = Size of area
	pop de 		; de =  base address 
	scf 		; Set carry, indicating an error 
	ret 



