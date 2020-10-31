	ld sp, 0
	ld hl, DATA
	call BUILTIN
	halt





	align 010h
DATA:
	db "lambda", 0


	include "lisp.s"

	end