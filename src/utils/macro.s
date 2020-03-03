	macro salloc
	ld \1, -\2
	add \1, sp
	ld sp, \1
	endm

	macro sfree
	ld \1, \2
	add \1, sp
	ld sp, \1
	endm
	

	macro msg
\1:
	string \2
\1_LEN:	equ $ - \1
	endm
	