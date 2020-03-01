	include "utils/macro.s"

RESET:
	di
	ld a, $1
	out (OUTPORT), a
	ld    SP, STACK_START	    ; Set Stack to end of memory
	jp INIT

	org $0100
	
INIT:
	; Prepare system
	ld a, $2		; Indicate that the system starts
	out (OUTPORT), a

	; Do ram test
	ld hl, VRAMBEG
	ld de, VRAMEND - VRAMBEG
	call RAMTST
	jr nc, .ramtest_succ

.ramtest_err:
	ld a, $aa
	out (OUTPORT), a
	halt
	jr .ramtest_err

.ramtest_succ:

	ld a, $3		; Indicate that the system starts
	out (OUTPORT), a

	call VD_CONFIGURE

	ld a, $4		; Indicate that the video has been initialized
	out (OUTPORT), a
MAIN:

.loop:
	call SLEEP

	salloc hl, 12

	ld a, $ff
	ld ($8200), a
	ld d, h
	ld e, l
	ld a, 0
	ld (de), a
	inc de
	ld (de), a
	inc de
	ld (de), a
	inc de
	ld (de), a
	dec de
	
.inner_loop:
	push hl
	push de
	push bc
	ld a, ($8200)
	inc a
	ld ($8200), a
	
	ld bc, 12
	call ITOA
	
	ld a, $20
	ld (de), a
	
	call VD_OUTN
	ld a, 250
	call DELAY
	pop bc
	pop de
	pop hl
	jr .inner_loop

	

	sfree hl, 12


	halt
	jr .loop


SLEEP:
	push bc
	; Delay 2 second
	; Call DELAY 4 times at 250 ms each
	ld b, 8
delay_loop:
	ld a, 250
	call DELAY
	djnz delay_loop
	pop bc
	ret	

	include "constants.s"
	include "utils/timing.s"
	include "utils/ramtest.s"
	include "utils/video_driver.s"
	include "utils/strings.s"

MESSAGES:
	dw MSG1
	dw MSG2
	dw MSG3
	dw MSG4
MSG1:	string "Hello, world!"
MSG1_LEN: equ $-MSG1
MSG2:	string "My name is Mats Fredriksson!"
MSG2_LEN: equ $-MSG2
MSG3:	string "This\nis\na\nmultiline\nstring."
MSG3_LEN: equ $-MSG3
MSG4:	string "Foo bar1234567689"
MSG4_LEN: equ $-MSG4

	org $07fe
	word $0000
	end



; Pin out for Controller pins from Video Card, from left to right.
; 0 - reset
; 1 - WR
; 2 - RD
; 3 - IORQ
; 4 - MREQ
