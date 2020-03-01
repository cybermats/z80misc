salloc	.macro
	ld \1, -\2
	add \1, sp
	ld sp, \1
	.end

sfree	.macro
	ld \1, \2
	add \1, sp
	ld sp, \1
	.endmacro
	

	
	