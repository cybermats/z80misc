	cpu Z80UNDOC

	ld sp, 0
INIT:
	in a, (01)
	ld h, a
	in a, (01)
	ld l, a

	ld bc, 10
	ld de, SC_BUFFER
	

	call ITOA
	ld de, SC_BUFFER	
.loop:
	ld a, (de)
	inc de
	or a
	jr z, .end

	out (00), a
	jr .loop
.end:
	halt





	align 010h
SC_BUFFER:
	ds 32
DATA:
	db "aa", 0, 0, 0


	include "utils/math.s"
	include "utils/stdlib.s"

	end