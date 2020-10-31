	org 0
	phase 8000h
MAIN:
	ld b, 0
.loop:
	ld a, b
	out (SPIDATA), a
	out (SPICTRL1), a
	in a, (SPIDATA)
	out (OUTPORT), a
	ld a, 250
	call DELAY
	djnz .loop
	ret






	include "utils/bios_constants.s"
	include "utils/util.s"
	include "utils/timing.s"

	end