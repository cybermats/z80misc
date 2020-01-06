	.org $0000
	jp blink

	.org $0100

blink:
	ld a, $55
	out ($ff), a
loop:
	rla
	out ($ff), a
	jp loop
	
	
	.org $7fe
	.word $0000
