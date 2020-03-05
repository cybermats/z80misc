reset:
	ld a, $1
	out (OUTPORT), a
	ld sp, STACK_START
	jp INIT

	org $0100
INIT:
	ld a, $2
	out (OUTPORT), a

	ld a, 0 ; Set no int vector and disable ints
	call KD_CONFIGURE

	ld a, $3
	out (OUTPORT), a

MAIN:
	ld a, 10
	call DELAY
	call KD_POLL



	call KD_NEXT_KVAL
	jr c, MAIN
	out (OUTPORT), a
	jr MAIN
	
	include "constants.s"
	include "utils/keyboard_device.s"
	include "utils/video_driver.s"
	include "utils/timing.s"
	include "utils/strings.s"

	org $07fe
	word $0000
	end