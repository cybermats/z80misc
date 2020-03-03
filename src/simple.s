reset:
	ld a, $1
	out (OUTPORT), a
	ld sp, STACK_START
	ld a, 0
	ld i, a
	im 2
	ei
	jp INIT


	org $0038
KEYBOARD_INT:
	in a, (SIODATAB)	; Read input
	out (OUTPORT), a	; Print output to port

	; Read error things
;	ld a, KD_WR0_REG1
;	out (SIOCMDB), a
;	in a, (SIOCMDB)
;	out (OUTPORT), a	; Print errors to port

	; Set up the SIO for future success
	ld a, KD_WR0_CMD_RST_EXT_STS_INTS
	out (SIOCMDB), a
	ld a, KD_WR0_CMD_ERR_RST
	out (SIOCMDB), a

	; Return
	ei
	reti

	org $0100
INIT:
	ld a, $2
	out (OUTPORT), a

	call KD_CONFIGURE

	ld a, $3
	out (OUTPORT), a

MAIN:
	halt
	jr MAIN
	
	include "constants.s"
	include "utils/keyboard_device.s"

	org $07fe
	word $0000
	end