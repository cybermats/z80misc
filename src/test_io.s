	ld a, $55
	out ($00), a
	ld a, $aa
	out ($ff), a
	halt
	.org $7fe
	.word $0000

	
