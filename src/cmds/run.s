RUN_ARG:
	ex de, hl
	xor a
	cp (hl)
	ret z
	
	call READNUM
	jr c, .error
	jp (hl)
.error:
	call SH_HOW
	ret
