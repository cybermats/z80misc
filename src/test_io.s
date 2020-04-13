	ld a, 55h
	out (00h), a
	ld a, 00aah
	out (00ffh), a
	halt
	org 07feh
	dw 0000h

	
