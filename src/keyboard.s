; Reading a ps/2 keyboard through the Z80 SIO

  	.include "constants.s"
	
reset:
	ld a, $1	; Indicate that the system starts
	out (OUTPORT), a
	ld sp, STACK_START	; Setup stack
	ld a, $00	; Setup interrupt page
	ld i, a
	im 2		; Set interrupt mode 2
	ei
	jp init

; General interrupt received
	.org $0038
keyboard_int:
	call HANDLE_KEYBOARD
	ei
	reti

; Non-maskable interrupt received
  	.org $0066
nmi:
	ld a, $0f	; Indicate that a NMI has been received.
	out (OUTPORT), a
	ld a, 250
	call DELAY
	retn
	

	.org $0100
init:
; Prepare system
	ld a, $2	; Indicate that the system initializes
	out (OUTPORT), a

; Set up the SIO
      	ld a, %00011000		; Channel reset
	out (SIOCMDB), a
	ld a, $02		; Pointer 2 
	out (SIOCMDB), a
	ld a, keyboard_int      ; Interrupt vector
	out (SIOCMDB), a
	ld a, %00010100		; Pointer 4. Reset Ext/Status interrupts
	out (SIOCMDB), a
	ld a, %00000101		; x1 Clock mode, Async, 1 stop bit, odd partity
	out (SIOCMDB), a
	ld a, $03		; Pointer 3
	out (SIOCMDB), a
	ld a, %11000001		; Rx 8 bits, no auto enable, Rx enable
	out (SIOCMDB), a
	ld a, $05		; Pointer 5
	out (SIOCMDB), a
	ld a, %01100000		; 8 bits, Tx not enabled
	out (SIOCMDB), a
	ld a, %00010001		; Pointer 1, Reset Ext/Status ints
	out (SIOCMDB), a
	ld a, %00001000		; Receive interrupts On First Char only
	out (SIOCMDB), a

	ld a, $3	; Indicate that the system is running
	out (OUTPORT), a

HALT_LOOP:
	halt
	jr HALT_LOOP

HANDLE_KEYBOARD:
	in a, (SIODATAB)
	out (OUTPORT), a
	ld a, %00010000		; Pointer 0. Reset Ext/Status interrupts
	out (SIOCMDB), a
	ret

	.include "utils/timing.s"


; End of program
	.org $07fe
	.word $0000
	.end
