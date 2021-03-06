; Reading a ps/2 keyboard through the Z80 SIO

  	include "utils/constants.s"
	
reset:
	ld a, 1	; Indicate that the system starts
	out (OUTPORT), a
	ld sp, STACK_START	; Setup stack
	ld a, 0	; Setup interrupt page
	ld i, a
	im 2		; Set interrupt mode 2
	ei
	jp init

; General interrupt received
	org 0038h
keyboard_int:
	call HANDLE_KEYBOARD
	ei
	reti

; Non-maskable interrupt received
  	org 0066h
nmi:
	ld a, 0fh	; Indicate that a NMI has been received.
	out (OUTPORT), a
	ld a, 250
	call DELAY
	retn
	

	org 0100h
init:
; Prepare system
	ld a, 2	; Indicate that the system initializes
	out (OUTPORT), a

; Set up the SIO
      	ld a, 00011000b		; Channel reset
	out (SIOCMDB), a
	ld a, 2		; Pointer 2 
	out (SIOCMDB), a
	ld a, keyboard_int      ; Interrupt vector
	out (SIOCMDB), a
	ld a, 00010100b		; Pointer 4. Reset Ext/Status interrupts
	out (SIOCMDB), a
	ld a, 00000101b		; x1 Clock mode, Async, 1 stop bit, odd partity
	out (SIOCMDB), a
	ld a, 3		; Pointer 3
	out (SIOCMDB), a
	ld a, 11000001b		; Rx 8 bits, no auto enable, Rx enable
	out (SIOCMDB), a
	ld a, 5		; Pointer 5
	out (SIOCMDB), a
	ld a, 01100000b		; 8 bits, Tx not enabled
	out (SIOCMDB), a
	ld a, 00010001b		; Pointer 1, Reset Ext/Status ints
	out (SIOCMDB), a
	ld a, 00001000b		; Receive interrupts On First Char only
	out (SIOCMDB), a

	ld a, 3	; Indicate that the system is running
	out (OUTPORT), a

HALT_LOOP:
	halt
	jr HALT_LOOP

HANDLE_KEYBOARD:
	in a, (SIODATAB)
	out (OUTPORT), a
	ld a, 00010000b		; Pointer 0. Reset Ext/Status interrupts
	out (SIOCMDB), a
	ret

	include "utils/timing.s"


; End of program
	org 07feh
	dw 0000h
	end
