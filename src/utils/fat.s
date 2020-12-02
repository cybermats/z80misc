; ***********************************************************
; Title:	FAT Directory Entry Offsets
; ***********************************************************
FAT_FILE_NAME_OFFSET:	equ	000h
FAT_FILE_EXT_OFFSET:	equ	008h
FAT_FILE_ATT_OFFSET:	equ	00bh
FAT_FILE_FST_C_OFFSET:	equ	01ah
FAT_FILE_SIZE_OFFSET:	equ	01ch

; ***********************************************************
; Title:	File Attributes
; ***********************************************************
FAT_FILE_NAME_DOT:	equ	02eh
FAT_FILE_NAME_DEL:	equ	0e5h
FAT_FILE_ATTR_VOL:	equ	008h
FAT_FILE_ATTR_LNG:	equ	00fh
FAT_FILE_ATTR_DIR:	equ	010h


; ***********************************************************
; Title:	Read MBR
; Name: 	FAT_READ_MBR
; Purpose:	Reads the MBR stored in the source.
; 		Parses the data and returns misc
;		data needed for further parsing.
;
; Entry:	DISK_BUFFER = Address for buffer
; 		
; Exit:		If MBR is valid:
; 		   Flag C reset
;		   Register BC = LBA for sector 1, msb
;		   Register DE = LBA for sector 1, lsb
;		If something went wrong:
;		   Flag C set
;		   Register A = Error Code
;
; Registers used: AF, BC, DE
; ***********************************************************
FAT_READ_MBR:
.PartTblOff:	equ 01beh
.PartStatus:	equ 0000h
.PartType:	equ 0004h
.BAFstSec:	equ 0008h

	; Check Partition Status, should be 00h or 80h
	ld a, (DISK_BUFFER + .PartTblOff + .PartStatus)
	and 7fh
	jr nz, .fail

	; Check partition type, only FAT12 (01h) is supported.
	ld a, (DISK_BUFFER + .PartTblOff + .PartType)
	ld (MBR_PART_TYPE), a
	dec a
	jr nz, .fail

	ld de, (DISK_BUFFER + .PartTblOff + .BAFstSec)
	ld bc, (DISK_BUFFER + .PartTblOff + .BAFstSec + 2)

	ld (MBR_PART_SECT), de
	ld (MBR_PART_SECT+2), bc
	
	or a
	ret

.fail:
	scf
	ret


; ***********************************************************
; Title:	Read Volume Boot Record
; Name: 	FAT_READ_VBR
; Purpose:	Reads the VBR stored in the source.
; 		Parses the data and returns misc
;		data needed for further parsing.
;
; Entry:	DISK_BUFFER = Start of VBR
; 		
; Exit:		If VBR is valid:
; 		   Flag C reset
;		If something went wrong:
;		   Flag C set
;
; Registers used: Plenty
; ***********************************************************
FAT_READ_VBR:
.BYTE_PER_SCTR: equ 0bh
.SECT_PER_CLST: equ 0dh
.RESV_SECT_CNT: equ 0eh
.NUM_FATS:      equ 10h
.MAX_ROOT_DIRS: equ 11h
.TOT_SECT_CNT:  equ 13h
.SECT_PER_FAT:  equ 16h
.VOL_LABEL:     equ 2bh

	; Check Bytes per Sector
	; Make sure it's 512.
	ld a, (DISK_BUFFER + .BYTE_PER_SCTR)
	or a
	jr z, .cont1
	ld a, 1
	jp .fail
.cont1:
	ld a, (DISK_BUFFER + .BYTE_PER_SCTR + 1)
	cp 2
	jr z, .cont2
	ld a, 2
	jp .fail
.cont2:
	ld b, 1		; Reset Sector counter

	; Get Sectors Per Cluster
	ld a, (DISK_BUFFER + .SECT_PER_CLST)
	ld (VBR_SECT_CLST), a

.get_fat_sector:
	
;	; Get Sector of first FAT
	ld hl, (DISK_BUFFER + .RESV_SECT_CNT)
	ld de, (MBR_PART_SECT)
	add hl, de
	ld (VBR_FAT1_SECT), hl
	ld hl, 0
	ld de, (MBR_PART_SECT + 2)
	adc hl, de
	ld (VBR_FAT1_SECT + 2), hl
	
	
	; Get Sector of the Root Directory
	ld a, (DISK_BUFFER + .NUM_FATS)	; Number of fats
	ld hl, (DISK_BUFFER + .SECT_PER_FAT) ; Sectors per FAT

	cp 2
	jr z, .cont3
	ld a, 3
	jr .fail	; Must have two FAT tables
.cont3:
	add hl, hl	; Multiply by two

	ld de, (VBR_FAT1_SECT)
	add hl, de
	ld (VBR_ROOT_SECT), hl
	ld hl, 0
	ld de, (VBR_FAT1_SECT + 2)
	adc hl, de
	ld (VBR_ROOT_SECT + 2), hl

	; Get total number of sectors
	ld hl, (DISK_BUFFER + .TOT_SECT_CNT)
	ld (VBR_TOT_SECTR), hl

	; Get Sector of Data Directory
	ld hl, (DISK_BUFFER + .MAX_ROOT_DIRS) ; Max number of root dir entries
	; Size of Directory Entries = Entries * 32
	; Sectors of Dir Ent = Size / 512
	; Sectors = Dir Ent / 16       (32 / 512) = 1/16
	sra h ; / 2
	rr l
	sra h ; / 4
	rr l
	sra h ; / 8
	rr l
	sra h ; / 16
	rr l

	ld de, (VBR_ROOT_SECT)
	add hl, de
	ld (VBR_DATA_SECT), hl
	ld hl, 0
	ld de, (VBR_ROOT_SECT + 2)
	adc hl, de
	ld (VBR_DATA_SECT + 2), hl


	; Get Volume Label
	ld hl, DISK_BUFFER + .VOL_LABEL
	ld de, VBR_VOL_LABEL
	ld bc, 11
	ldir

	or a
	ret
.fail:
	scf
	ret

