	cpu Z80UNDOC

INIT:
	ld sp, 0
	ld hl, DATA
_loop:
	ld a, (hl)
	inc hl
	or a
	jr z, _end
	out (1), a
	jp _loop
_end:
	halt





	align 010h
SC_BUFFER:
	ds 32
DATA:
	db "hello", 0, 0, 0


;	include "utils/math.s"
;	include "utils/stdlib.s"

	end