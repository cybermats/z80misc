	ld sp, 0
	ld de, DATA
	call PACK40
	halt





	align 010h
DATA:
	db "aa", 0, 0, 0


	include "lisp.s"

	end