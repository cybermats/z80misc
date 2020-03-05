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
.configure:

	ld a, $3		; Indicate that the system starts
	out (OUTPORT), a

	call VD_CONFIGURE

	ld a, $4		; Indicate that the video has been initialized
	out (OUTPORT), a

	ld hl, MSG1
	ld bc, MSG1_LEN
	call VD_OUTN
	ld hl, MSG2
	ld bc, MSG2_LEN
	call VD_OUTN
	ld hl, MSG3
	ld bc, MSG3_LEN
	call VD_OUTN
	ld hl, MSG4
	ld bc, MSG4_LEN
	call VD_OUTN
	ld e, 0
MAIN:
	push de
	ld a, 100
	call DELAY
	pop de
	inc e
	ld a, e
	call VD_OUT
	jr MAIN


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
MSG1:	string "ABCDEFGHIJKLMNOPQRSTUVWXYZ\n"
MSG1_LEN: equ $-MSG1
MSG2:	string "A B C D E F G H I J K L M N O P Q R S T U V W X Y Z\n"
MSG2_LEN: equ $-MSG2
MSG3:	string "0 1 2 3 4 5 6 7 8 9 \n"
MSG3_LEN: equ $-MSG3
MSG4:
	data $b1,$b1,$b1,$b1,$b1,$b1,$b1,$b1,$b1,$b1
	data $b1,$b1,$b1,$b1,$b1,$b1,$b1,$b1,$b1,$b1
	data $b1,$b1,$b1,$b1,$b1,$b1,$b1,$b1,$b1,$b1
	data $b1,$b1,$b1,$b1,$b1,$b1,$b1,$b1,$b1,$b1

	data $b1,$b1,$b1,$b1,$b1,$b1,$b1,$b1,$b1,$b1
	data $b1,$b1,$b1,$b1,$b1,$b1,$b1,$b1,$b1,$b1
	data $b1,$b1,$b1,$b1,$b1,$b1,$b1,$b1,$b1,$b1
	data $b1,$b1,$b1,$b1,$b1,$b1,$b1,$b1,$b1,$b1
	data 0

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
