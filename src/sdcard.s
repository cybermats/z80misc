	org 0
	phase 8000h
MAIN:
	; Initialize the sd card
	; 1. Let it cycle through at least 74 clks
	;    with MOSI and CS HIGH.

	ld a, '|'
	ld hl, (VIDEO_CNTR)
	ld (hl), a
	inc hl
	ld (VIDEO_CNTR), hl
	


	ld a, 0ffh		; MOSI High
	out (SPIDATA), a
	ld b, 0ah		; Loop 10 times
.init_loop:
	out (SPICTRL2), a	; CS HIGH because of port 2
	djnz .init_loop		; 10 x 8 is 80 cycles.



	ld hl, MSG_CMD0
	call PRINT
	
	; 2. Send CMD0
	ld hl, CMD0
	call SEND_CMD
	
	call WAIT_R1
	jr c, .fail
	
	ld hl, MSG_SUCC
	call PRINT

	ld hl, MSG_CMD8
	call PRINT

	; 3. Send CMD8
	ld hl, CMD8
	call SEND_CMD
	
	call WAIT_R7
	jr c, .fail
	
	push af
	push hl
	push de
	ld hl, MSG_SUCC
	call PRINT
	pop de
	pop hl
	pop af
	
	; Check illegal
	cp a, 00000101b

	ret
	
.fail:
	ld hl, MSG_FAIL
	call PRINT
	ret


PRINT:
	ld a, (hl)
	or a
	ret z

	ld e, a
	ld c, COUT
	push hl
	call BIOS
	pop hl
	inc hl
	jr PRINT


SEND_CMD:
	ld b, 6
	ld c, SPIDATA
.init_loop2:
	outi			; Send CMD
	inc b
	out (SPICTRL1), a
	djnz .init_loop2
	ret


; Carry = 0 if successful
WAIT_R1:
	ld b, 3
.loop:
	call READ_SPI
	out (OUTPORT), a
	or a
	bit 7, a
	ret nz
	ld a, 0ffh
	out (SPIDATA), a
	out (SPICTRL1), a
	djnz .loop
.failure:
	scf
	ret

; Carry = 0 if successful, Result in HL + DE, token in A
WAIT_R7:
	ld b, 4
.loop:
	call READ_SPI
	ld c, a
	cp 01h
	jp z, .payload
	ld a, 0ffh
	out (SPIDATA), a
	out (SPICTRL1), a
	djnz .loop
.failure:
	scf
	ret
.payload:
	ld a, 0ffh
	out (SPIDATA), a	; First 8 bits
	out (SPICTRL1), a
	call READ_SPI
	ld h, a

	ld a, 0ffh
	out (SPIDATA), a	; Second 8 bits
	out (SPICTRL1), a
	call READ_SPI
	ld l, a

	ld a, 0ffh
	out (SPIDATA), a	; Third 8 bits
	out (SPICTRL1), a
	call READ_SPI
	ld d, a

	ld a, 0ffh
	out (SPIDATA), a	; Fourth 8 bits
	out (SPICTRL1), a
	call READ_SPI
	ld e, a

	ld a, c
	or a
	ret


READ_SPI:
	in a, (SPIDATA)
	push af
	push hl
	ld hl, (VIDEO_CNTR)
.test_00:
	or a
	jr nz, .test_ff
	ld a, '0'
	jr .output
.test_ff:
	cp 0ffh
	jr nz, .output
	ld a, 'f'
.output:
	ld (hl), a
	inc hl
	ld (VIDEO_CNTR), hl
	ld a, '|'
	ld (hl), a

	pop hl
	pop af
	ret	

CMD0:
	db 01000000b ; 40h
	db 00000000b ; 00h
	db 00000000b ; 00h
	db 00000000b ; 00h
	db 00000000b ; 00h
	db 10010101b ; 95h

CMD8:
	db 01001000b ; 48h
	db 00000000b ; 00h
	db 00000000b ; 00h
	db 00000001b ; 00h
	db 10101010b ; aah
	db 00001111b ; 0fh

CMD58:
	db 01111010b ; 7ah
	db 00000000b ; 00h
	db 00000000b ; 00h
	db 00000000b ; 00h
	db 00000000b ; 00h
	db 01110101b ; 75h


MSG_DONE:
	db "Done\n", 0
MSG_SUCC:
	db "Succ\n", 0
MSG_FAIL:
	db "Fail\n", 0
MSG_CMD0:
	db "CMD0\n", 0
MSG_CMD8:
	db "CMD8\n", 0
MSG_CMD58:
	db "CMD58\n", 0
MSG_CMD55:
	db "CMD55\n", 0
MSG_ACMD41:
	db "ACMD41\n", 0

VIDEO_CNTR:
	dw VRAMBEG + (80 * 20) + 20


	include "utils/bios_constants.s"
	include "utils/util.s"
	include "utils/timing.s"

	end