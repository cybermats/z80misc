
	org 0
	phase 8000h
MAIN:
	; Turn off cursor
	ld e, 0
	ld c, CURSOR
	call BIOS

	; Clear the screen
	ld a, 0
	ld hl, VRAMBEG
	ld bc, VRAMEND - VRAMBEG
	call MFILL

	; Paint border
	
	; Fix corners
	ld a, 0c9h	; Upper left
	ld (VRAMBEG), a
	ld a, 0bbh	; Upper right
	ld (VRAMBEG + VIDEO_COLUMNS - 1), a
	ld a, 0c8h    	; Lower left
	ld (VRAMBEG + (VIDEO_COLUMNS * (VIDEO_ROWS - 1))), a
	ld a, 0bch    	; Lower right
	ld (VRAMBEG + (VIDEO_COLUMNS * VIDEO_ROWS) - 1), a

	; Top edge
	ld a, 0cdh    	; Horizontal border
	ld hl, VRAMBEG + 1
	ld b, VIDEO_COLUMNS - 2
.top_loop:
	ld (hl), a
	inc hl
	djnz .top_loop

	ld hl, VRAMBEG + (VIDEO_COLUMNS * (VIDEO_ROWS - 1)) + 1
	ld b, VIDEO_COLUMNS - 2
.bottom_loop:
	ld (hl), a
	inc hl
	djnz .bottom_loop


	ld a, 0bah    	; Vertical border
	ld hl, VRAMBEG + VIDEO_COLUMNS
	ld de, VIDEO_COLUMNS - 1
	ld b, VIDEO_ROWS - 2
.side_loop:
	ld (hl), a
	add hl, de
	ld (hl), a
	inc hl
	djnz .side_loop



	; Main loop
	; Direction in BC
	; Position in DE
	ld bc, 1
	ld de, (VIDEO_COLUMNS/2) + (VIDEO_ROWS/2)*VIDEO_COLUMNS
.loop:
	; Check and paint the snake
	ld hl, VRAMBEG
	add hl, de

	; Check snake
	ld a, (hl)
	or a
	jr nz, .end

	ld (hl), 0dbh
	
	; Move snake
	ex de, hl
	add hl, bc
	ex de, hl

	; Check input
	push bc
	push de
	ld c, CIN_NH
	call BIOS
	pop de
	pop bc
	jr c, .delay

	; Check ^C
	cp 03h
	jr z, .quit
	; Check ESC
	cp 1bh
	jr z, .quit


	cp 'a'
	jr c, .delay
	cp 'z'+1
	jr nc, .delay
	and 0dfh

	ld hl, -1
	cp 'A'
	jr z, .set_dir
	ld hl, 1
	cp 'D'
	jr z, .set_dir
	ld hl, -VIDEO_COLUMNS
	cp 'W'
	jr z, .set_dir
	ld hl, VIDEO_COLUMNS
	cp 'S'
	jr z, .set_dir

	jr .delay

.set_dir:
	ld b, h
	ld c, l


.delay:
	; Delay for a little while
	ld a, 100
	call DELAY

	jr .loop

	
.end:
	ld c, CIN
	call BIOS

	; Check ESC
	cp 1bh
	jr z, .quit

	; Upper case
	cp 'a'
	jr c, .end
	cp 'z'+1
	jr nc, .end
	and 0dfh
	
	cp 'Q'
	jr z, .quit
	jp MAIN


.quit:
	; Turn on cursor
	ld e, 1
	ld c, CURSOR
	call BIOS
	ret

GAMEOVER:
	db "Game Over", 0
	

	include "utils/bios_constants.s"
	include "utils/util.s"
	include "utils/timing.s"

	end