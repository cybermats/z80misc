salloc:	macro
	ld \1, -\2
	add \1, sp
	ld sp, \1
	endm

sfree:	macro
	ld \1, \2
	add \1, sp
	ld sp, \1
	endm
	

msg:	macro lbl, value, {GLOBALSYMBOLS}
lbl:
	db value, 0
lbl_LEN:equ $ - lbl
	endm
	