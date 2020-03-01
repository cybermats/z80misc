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
	

	
	