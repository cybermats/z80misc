RUN_ARG:
	ex de, hl
	xor a
	cp (hl)
;	ret z
	jr nz, .readnum
	ld hl, 8000h
	jr .run

.readnum:
	call READNUM
	jr c, .error
	ex de, hl


.run:
	jp (hl)
.error:
	call SH_HOW
	ret
