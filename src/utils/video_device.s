; ***********************************************************
;
; Title:	Video Device
;
; Purpose:	Full code for managing the video device
; 		through the Device Handler.
;
;		Status code	Description
;		       0		No Error
;		       3		Video Card ready
;		       250		Ram test failed
; ***********************************************************


; ***********************************************************
; Title:     Sets up and starts the video driver
; Name:	     SETUP_VIDEO_DRIVER
; Purpose:   Initializes the video card and driver by
;		 1. Create Device Table Entry
;		 2. Add device to Device List
;		 3. Initialize device
;
; Entry:     Nothing
;
; Exit:	     Nothing
; Registers used:	HL
; ***********************************************************

SETUP_VIDEO_DRIVER:
	ld hl, VIDEO_STATUS
	ld (hl), NOERR

	; 1. Create Device Table Entry
	call CREATEDTE	   ; Get empty Device Table Entry
	push hl		   ; Save DTE
	ld de, VIDEO_DEVICE ; Get Device Table Entry from ROM
	       		   ; and copy it to RAM
	ex de, hl
	ld bc, 17	   ; Size of DTE
	ldir   		   ; Copy the DTE from ROM to RAM

	pop hl		   ; Restore DTE
	
	; 2. Add device to Device List
	call ADDDL	   ; Add device to Device List


	; 3. Initialize operations
	ld ix, -IOCBSZ	   ; Make room on the stack for IOCB
	add ix, sp
	ld sp, ix

	ld (ix+IOCBOP), IOINIT	; Initialize operations
	ld (ix+IOCBDN), a  ; Device number in register a
	call IOHDLR	   ; Call IO Handler

	ld hl, IOCBSZ	   ; Clean up stack
	add hl, sp
	ld sp, hl


	; Set cursor to 0
	ld hl, VIDEO_STATUS
	ld (hl), DEVRDY

	ret	



; ***********************************************************
; Title:     Video Driver initialization
; Name:	     VD_INIT
; Purpose:   Initializes the video card and driver by
; 	         1. Testing the video ram
;		 2. Initializing the Video Ram to 0
;		 3. Initialize operations
;		 4. Set all video varibles in memory
;
; Entry:     Nothing
;
; Exit:	     Nothing
; ***********************************************************

VD_INIT:
	push hl
	push de
	push bc
	push af
	; 1. Test video ram
	; 2. Initialize video ram to 0 (it's done in the ram test)
	ld hl, VRAMBEG
	ld de, VRAMEND - VRAMBEG
	call RAMTST
	jr nc, .init_6845
	; Do error handling
	ld hl, VIDEO_STATUS
	ld (hl), RAMERR
	jr .done
	
	; 3. Initialize operations
.init_6845:
	call VD_CONFIGURE
	
	pop af
	pop bc
	pop de
	pop hl
	ret

; ***********************************************************
; Title:	Outputs 1 byte to the video card
; Name: 	VD_W1BYTE
; Purpose:	Prints one character to the video card
; 		at the location of the cursor. Also
;		changes the location of the cursor.
; Entry:	Register A = Char to output
; 		Register IX = Base address of IOCB
; Exit:		Register A = Copy of the IOCB status byte
; Registers used:	 A
; ***********************************************************

VD_W1BYTE:
	call VD_OUT
	ld a, NOERR
	ld (IX+IOCBST), a
	ret

; ***********************************************************
; Title:	Outputs N byte to the video card
; Name: 	VD_WNBYTE
; Purpose:	Prints N characters to the video card
; 		at the location of the cursor. Also
;		changes the location of the cursor.
; Entry:	Register IX = Base address of IOCB
; Exit:		Register A = Copy of the IOCB status byte
; Registers used:	 A, IX, HL, BC
; ***********************************************************
VD_WNBYTE:
	ld h, (ix + IOCBBA + 1)
	ld l, (ix + IOCBBA)
	ld b, (ix + IOCBBL + 1)
	ld c, (ix + IOCBBL)
	call VD_OUTN
	ret

; ***********************************************************
; Title:	Returns video driver status
; Name: 	VD_OSTAT
; Purpose:	Helper function for the Device Handler to
; 		return the Video Driver status
; Entry:	None
; Exit:		Register A = Status
; Registers used:	 A
; ***********************************************************

VD_OSTAT:
	ld a, (VIDEO_STATUS)
	ret



VIDEO_DEVICE:			; Device table entry for the Video Card
	.dw	0		; Link Field
	.db	VIDEO_DVC	; Device 1
	.dw	VD_INIT		; Video Driver Initialize
	.dw	0		; No Video Driver Input Status
	.dw	0		; No Video Driver Input 1 byte
	.dw	0		; No Video Driver Input N bytes
	.dw	VD_OSTAT	; Video Driver output status
	.dw	VD_W1BYTE	; Video Driver output 1 byte
	.dw	VD_WNBYTE	; Video Driver output N bytes

