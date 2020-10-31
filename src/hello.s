
	org 0
	phase 8000h
MAIN:
	ld hl, MSG
.loop:
	ld a, (hl)
	or a
	jr z, .end

	ld e, a
	ld c, SH_OUT
	push hl
	call BIOS
	pop hl
	inc hl

	jr .loop

.end
	ret

MSG:
	db "Hello, world\n", 0
MSG_LEN:equ $ - MSG
	include "utils/bios_constants.s"


	end