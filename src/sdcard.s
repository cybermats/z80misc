	org 0
	phase 8000h
MAIN:
	; Initialize the sd card
	; 1. Let it cycle through at least 74 clks
	;    with MOSI and CS HIGH.

	ld a, 0ffh		; MOSI High
	out (SPIDATA), a
	ld b, 0ah		; Loop 10 times
	xor a			; No CS
.init_loop:
	out (SPICTRL1), a	; 
	djnz .init_loop		; 10 x 8 is 80 cycles.


	; 2. Send CMD0
	ld hl, CMD0
	call SEND_CMD
	
	call WAIT_R1
;	jp c, .fail
	
	; 3. Send CMD8
	ld hl, CMD8
	call SEND_CMD
	
	call WAIT_R7
	jp c, .fail

	; Check illegal
	cp a, 00000101b
	jp z, .ver_1x

	and 0feh
	jp nz, .fail

.ver_2:
	; Check voltage
	ld a, 1
	cp d
	jp nz, .unusable

	; Check Pattern
	ld a, 0aah
	cp e
	jp nz, .unusable

.cmd41:
	; Send ACMD41
	ld d, 0
.cmd41_loop:
	ld hl, CMD55
	call SEND_CMD

	call WAIT_R1
	jp c, .fail

	ld hl, ACMD41
	call SEND_CMD

	call WAIT_R1
	jp c, .fail

	cp 5h		; Check if command understood
	jr z, .cmd58	; If not, try with CMD1

	or a   		; Check if in idle state
	jr z, .cmd58	; No, move on.
	dec d
	jr nz, .cmd41_loop
	jp .fail

.cmd1:
	; CMD1
	ld d, 0
.cmd1_loop:
	ld hl, CMD1
	call SEND_CMD
	
	call WAIT_R1
	jp c, .fail

	cp 1		; Check if in idle state
	jr nz, .cmd58
;	dec d
;	jr nz, .cmd1_loop	; Yes, then try again
	jr .cmd1_loop
	jp .fail

.cmd58:
	; Send CMD58, to check CCS
	ld hl, CMD58
	call SEND_CMD

	call WAIT_R3
	jr c, .fail

	; Check voltage
	inc l		; l should be ff
	jp nz, .fail

	; Start reading
	ld hl, CMD17
	call SEND_CMD

	call WAIT_R1
	jr c, .fail
	cp 5h		; Check if command understood
	jr z, .fail	

	ld hl, MSG_READ
	call PRINT

	; Read transfer token
	call WAIT_TOKEN
	jp c, .fail
	
	; Prepare for block reading
	ld hl, 9000h
	ld b, 0
	ld d, 2
	ld c, SPIDATA

.read:	
	ld a, 1
	out (SPICTRL1), a
	ini
	jp nz, .read
	dec d
	jr nz, .read

	; Read CRC
	out (SPICTRL1), a
	ini
	out (SPICTRL1), a
	ini
	

	

	push af
	push hl
	push de
	ld hl, MSG_SUCC
	call PRINT
	pop de
	pop hl
	pop af





	ret

.unusable:
	ld hl, MSG_UNUSE
	call PRINT
	ret

.ver_1x:
.fail:
	ld hl, MSG_FAIL
	add a, (hl)
	ld (hl), a
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
	ld b, 12 ; Double since both outi and djnz decs.
	ld c, SPIDATA
	ld a, 0ffh		; Send one FF before command
	out (SPIDATA), a
	ld a, 01		; Set CS
	out (SPICTRL1), a
.init_loop2:
	outi			; Send CMD
	out (SPICTRL1), a
	djnz .init_loop2
	ret


WAIT_TOKEN:
	ld b, 16
	ld a, 0ffh
	out (SPIDATA), a
.loop:
	ld a, 1
	out (SPICTRL1), a
	
	call READ_SPI
	cp 20h
	jr c, .error_token
	cp 0ffh
	jr c, .data_token
	djnz .loop

.data_token:
	or a
	ret

.error_token:
	scf
	ret


; Carry = 0 if successful
WAIT_R1:
	ld b, 16	; Number of tries
	ld a, 0ffh	; Load FF into SPI
	out (SPIDATA), a
.loop:
	call READ_SPI
	or a		; Reset Carry
	bit 7, a	; Check if successful
	ret z  		; Return if success

	ld a, 1		; Set Card Select
	out (SPICTRL1), a
	djnz .loop

.failure:
	scf		; Set Carry
	ret


; Carry = 0 if successful, Result in HL + DE, token in A
WAIT_R3:
WAIT_R7:
	ld b, 16
	ld a, 0ffh
	out (SPIDATA), a
.loop:
	call READ_SPI
	ld c, a
	bit 7, a
	jr z, .payload
	ld a, 1
	out (SPICTRL1), a
	djnz .loop
.failure:
	scf
	ret
.payload:
	ld a, 1
	out (SPICTRL1), a
	call READ_SPI
	ld h, a

	ld a, 1
	out (SPICTRL1), a
	call READ_SPI
	ld l, a

	ld a, 1
	out (SPICTRL1), a
	call READ_SPI
	ld d, a

	ld a, 1
	out (SPICTRL1), a
	call READ_SPI
	ld e, a

	ld a, c
	or a
	ret


READ_SPI:
	in a, (SPIDATA)
	ret	

CMD0:
	db 01000000b ; 40h
	db 00000000b ; 00h
	db 00000000b ; 00h
	db 00000000b ; 00h
	db 00000000b ; 00h
	db 10010101b ; 95h

CMD1:
	db 01000001b ; 69h
	db 01000000b ; 40h	; Does support HCS
	db 00000000b ; 00h
	db 00000000b ; 00h
	db 00000000b ; 00h
	db 11111111b ; ffh

CMD8:
	db 01001000b ; 48h
	db 00000000b ; 00h
	db 00000000b ; 00h
	db 00000001b ; 01h
	db 10101010b ; aah
	db 10000111b ; 87h

CMD17:
	db 01010001b ; 51h
	db 00000000b ; 00h
	db 00000000b ; 00h
	db 00000000b ; 00h
	db 00000000b ; 00h
	db 11111111b ; ffh

CMD55:
	db 01110111b ; 77h
	db 00000000b ; 00h
	db 00000000b ; 00h
	db 00000000b ; 00h
	db 00000000b ; 00h
	db 11111111b ; ffh

CMD58:
	db 01111010b ; 7ah
	db 00000000b ; 00h
	db 00000000b ; 00h
	db 00000000b ; 00h
	db 00000000b ; 00h
	db 11111101b ; 75h

ACMD41:
	db 01101001b ; 69h
	db 01000000b ; 40h	; Does support HCS
	db 00000000b ; 00h
	db 00000000b ; 00h
	db 00000000b ; 00h
	db 11111111b ; ffh
	


MSG_DONE:
	db "Done\n", 0
MSG_SUCC:
	db "Succ\n", 0
MSG_FAIL:
	db "0 Fail\n", 0
MSG_UNUSE:
	db "Unusable\n", 0
MSG_READ:
	db "Reading\n", 0

	include "utils/bios_constants.s"
	include "utils/util.s"
	include "utils/timing.s"

	end