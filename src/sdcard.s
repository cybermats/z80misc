	cpu Z80UNDOC
	org 0
	phase 8000h
MAIN:
	ld hl, MSG_INIT
	call PRINT
	
	call SPI_INIT_SD
	jp c, .fail


.run:
	; Start reading
	ld hl, DISK_BUFFER	; Destination address
	ld bc, 0000h
	ld de, 0000h	; Source Block
	call SPI_READ_BLOCK
	jp c, .fail

	call FAT_READ_MBR
	jp c, .fail

	ld hl, DISK_BUFFER	; Start of MBR
	call SPI_READ_BLOCK
	jp c, .fail

	call FAT_READ_VBR
	jp c, .fail

	; Load root sector
	ld hl, DISK_BUFFER
	ld de, (VBR_ROOT_SECT)
	ld bc, (VBR_ROOT_SECT + 2)
	call SPI_READ_BLOCK

	; Loop through root entry
	ld ix, DISK_BUFFER
.dir_loop:
	; Check if volume label
	ld a, (ix + FAT_FILE_ATT_OFFSET)
	cp FAT_FILE_ATTR_VOL
	jr z, .dir_cont
	; Check if long name
	cp FAT_FILE_ATTR_LNG
	jr z, .dir_cont
	; Check if deleted file
	ld a, (ix + FAT_FILE_NAME_OFFSET)
	cp FAT_FILE_NAME_DEL
	jr z, .dir_cont
	; Check if dot-entry
	cp FAT_FILE_NAME_DOT
	jr z, .dir_cont
	; Check if at end
	or a
	jr z, .dir_done
.dir_do:
	ld a, ixh
	ld h, a
	ld a, ixl
	ld l, a
	ld b, 8
	call PRINT_N
	push hl
	
	ld hl, .space_str
	call PRINT

	pop hl
	ld b, 3
	call PRINT_N

	ld a, (ix + FAT_FILE_ATT_OFFSET)
	and FAT_FILE_ATTR_DIR
	jr z, .dir_file

	ld hl, .dir_str
	call PRINT
.dir_file:
	ld hl, .nl_str
	call PRINT

.dir_cont:
	ld bc, 32
	add ix, bc
	jr .dir_loop
.dir_done:
	

	ld hl, MSG_DONE
	call PRINT
	ret

.space_str:
	db " ", 0
.dir_str:
	db "<DIR>", 0
.nl_str:
	db "\n", 0
.init_str:
	db "init ",0
.mbr_str:
	db "mbr ", 0
.vbr_str:
	db "vbr ", 0
.dte_str:
	db "dte ", 0

.fail:
	ld hl, MSG_FAIL
	add a, (hl)
	ld (hl), a
	call PRINT
	ld hl, MSG_FAIL
	ld (hl), '0'
	ret

PRINT:
	push hl
	push bc
	push de
	push af
.loop:
	ld a, (hl)
	or a
	jr z, .done

	ld e, a
	ld c, COUT
	push hl
	call BIOS
	pop hl
	inc hl
	jr .loop
.done:
	pop af
	pop de
	pop bc
	pop hl
	ret


PRINT_N:

.loop:
	ld e, (hl)
	ld c, COUT
	push hl
	push bc
	call BIOS
	pop bc
	pop hl
	inc hl
	dec b
	jr nz, .loop
.done:
	ret



MSG_DONE:
	db "Done\n", 0
MSG_INIT:
	db "Init\n", 0
MSG_SUCC:
	db "Succ\n", 0
MSG_FAIL:
	db "0 Fail\n", 0

HAS_INIT:
	db 0

	include "utils/bios_constants.s"
;	include "utils/util.s"
;	include "utils/timing.s"
	include "utils/spi_sdcard.s"
	include "utils/fat.s"


	align 10h
MBR_DATA:
MBR_PART_TYPE:
	ds 1
MBR_PART_SECT:
	ds 4
VBR_DATA:
VBR_SECT_CLST:
	ds 1
VBR_FAT1_SECT:
	ds 4
VBR_ROOT_SECT:
	ds 4
VBR_TOT_SECTR:
	ds 2
VBR_DATA_SECT:
	ds 4
VBR_VOL_LABEL:
	ds 11

	align 100h
DISK_BUFFER:








	end