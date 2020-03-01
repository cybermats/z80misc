; 
; Title:  I/O Device Table Handler
; Name: IOHDLR

; IOCB and Device Table Equates
				    
IOCBDN:		.equ  0		; IOCB Device Number
IOCBOP:		.equ  1		; IOCB Operation Number
IOCBST:		.equ  2		; IOCB Status
IOCBBA:		.equ  3		; IOCB Buffer Address
IOCBBL:		.equ  5		; IOCB Buffer Length
DTLNK:		.equ  0		; Device Table Link Field
DTDN:		.equ  2		; Device Table device number
DTSR:		.equ  3		; Beginning of Device Table Subroutines

				; Operation Numbers

NUMOP:		.equ  7		; Number of operations
IOINIT:		.equ  0		; Initialization
ISTAT:		.equ  1		; Input Status
R1BYTE:		.equ  2		; Read 1 Byte
RNBYTE:		.equ  3		; Read N Bytes
OSTAT:		.equ  4		; Output Status
W1BYTE:		.equ  5		; Write 1 Byte
WNBYTE:		.equ  6		; Write N Bytes

; Status Values

NOERR:		.equ  0		; No errors
DEVERR:		.equ  1		; Bad Device Number
OPERR:		.equ  2		; Bad Operation Number
DEVRDY:		.equ  3		; Input Data Available or Output Device Ready
RAMERR:		.equ  253	; RAM test failed on device.
BUFERR:		.equ  254	; Buffer too small for BDOS Read Console Buffer


; Title: 	I/O Device Table Handler
; Name:		IOHDLR
;
;
; Purpose:	Perform I/O in a device-independent manner.
; 		This can be done only by accessing all
;		devices in the same way using an I/O Control
;		Block (IOCB) and a device table. The routines
;		here allow the following operations:
;
;		Operation number	Description
;			0			Initialize Device
;			1			Determine input status
;			2			Read 1 byte
;			3			Read N bytes
; 			4			Determine output status
;			5			Write 1 byte
;			6			Write N bytes
;
;		Other operations that could be included are
;		Open, Close, Delete, Rename and Append, which
;		would support devices such as floppy disks.
;
;		A IOCB is an array of the following form:
;
;		IOCB + 0 = Device number
; 		IOCB + 1 = Operation number
; 		IOCB + 2 = Status
; 		IOCB + 3 = Low byte of Buffer Address
;		IOCB + 4 = High byte of Buffer Address
;		IOCB + 5 = Low byte of Buffer Length
;		IOCB + 6 = High byte of Buffer Length
;
;		The device table is implemented as a linked
;		list. Two routines maintain the list: INITDL,
;		which initializes the device list to empty, and
;		ADDDL, which adds a device to the list.
;		A device table entry has the following form:
;
;		DVTBL + 0 = Word of Link Field
;		DVTBL + 2 = Device Number
;		DVTBL + 3 = Word of Device Initialization
;		DVTBL + 5 = Word of Input Status Routine
;		DVTBL + 7 = Word of Input 1 Byte Routine
;		DVTBL + 9 = Word of Input N Bytes Routine
; 		DVTBL + 11 = Word Word of Output Status Routine
;		DVTBL + 13 = Word of Output 1 Byte Routine
;		DVTBL + 15 = Word of Output N Bytes Routine
;
; Entry:	Register IX = Base Address of IOCB
; 		Register A = For write 1 byte, contains the
;			     data (no buffer is used).
;
; Exit:		Register A = Copy of the IOCB status byte
; 			     Except contains the data for
;			     read 1 byte (no buffer is used).
;		Status byte of IOCB is 0 if the operation was
;		completed successfully; otherwise, it contains
;		the error number.
;
;		Status value	Description
;		       0		No errors
;		       1		Bad device number
;		       2		Bad operation number
;		       3		Input data available or output
;		       			device ready
;		       254		Buffer too small
;
; Registers used:	AF, BC, DE, HL, IX


IOHDLR:
	push af
	      
				; Initialize status byte to zero (No Errors)
	ld (ix+IOCBST), NOERR

				; Check that operation is valid
	ld a, (ix + IOCBOP)	; Get operation number from IOCB
	ld b, a	    		; Save operation number
	cp NUMOP	    	; Is operation number within limit?
	jr nc, BADOP	    	; Jump if operation number too large

	       			; Search device list for this device
				; C = IOCB Device number
				; DE = pointer to device list
	ld    c, (IX + IOCBDN) 	; C = IOCB Device Number
	ld    de, (DVLST)	; DE = First entry in device list
	      
				; DE = Pointer to device list
				; B = Operation Number
				; C = Requested Device Number

.SRCHLP:	      
	      
				; Check if at end of device list (Link Field = 0000)
	ld a, d			; Test link field
	or e
	jr z, BADDN		; Branch if no more device entries
	      
				; Check if current entry is device in IOCB
	ld hl, DTDN
	add hl, de
	ld a, (hl)
	cp c			; Compare to requested device
	jr z, FOUND		; Branch if device found

				; Device not found, so advance to next device
				;  table entry through link field
				;  make current device = lin k
	ex    de, hl		; Point to link field (First word)
	ld    e, (hl)		; Get low byte of link
	inc   hl
	ld    d, (hl)		; Get high byte of link
	jr    SRCHLP	    	; Check next entry in Device Table

				; Found Device, so vector to appropriate routine if any
				; DE = Address of Device Table Entry
				; B = Operation number
.FOUND:	      
				; Get routine address (Zero indicates invalid operation)
	ld    l, b	    	; HL = 16-bit operation number
	ld    h, 0	    	;
	add   hl, hl	    	; Multiply by 2 for address entries
	ld    bc, DTSR
	add   hl, bc		; HL = OFfset to subroutine in
				;   device table entry
	add   hl, de	    	; HL = Address of subroutine
	ld    a, (hl)	    	; Get subroutines's starting address
	inc   hl
	ld    h, (hl)
	ld    l, a		; is starting address zero?
	or    h
	jr    z, BADOP		; Yes, jump (operation invalid)
		  pop 	af
	jp    (hl)	    	; Goto subroutine
	      
.BADDN:	      
	ld    a, DEVERR		; Error code - no such device
	jr    EREXIT
.BADOP:	      
	ld    a, OPERR		; Error code - no such operation
.EREXIT:	      
	ld    (IX+IOCBST), a	; Set status byte in IOCB
	inc   sp		; Remove the AF that was push to the stack
	inc   sp
	ret
				    
	      





	      
	      
; ****************************************
; Routine:	INITDL
; Purpose: 	Initialize Device List to Empty
; Entry: 	None
; Exit: 	Device List Set to No Items
; Registers used: HL
; ****************************************
	      
INITDL:				    
				; Initialize device list header to 0 to indicate No Devices
	ld    hl, 0
	ld    (DVLST), hl
				; Initialize device table entry to start memory
	ld    hl, DVTE + 2
	ld (DVTE), hl
	ret
	      
; ****************************************
; Routine:	ADDDL
; Purpose: 	Add Device to Device List
; Entry: 	Register HL = Address of Device Table Entry
; Exit: 	Device Added to Device List
; Registers used: DE
; ****************************************
	      
ADDDL:
	push de
	ld    de, (DVLST)	; Get current head of Device List
	ld    (hl), e		; Store current head of Device List
	inc   hl		;  into link field of new device
	ld    (hl), d
	dec   hl
	ld    (DVLST), hl	; Make DVLST point at new device
	pop de
	ret

	      

; ****************************************
; Routine:	CREATEDTE
; Purpose: 	Create Device Table Entry
; Entry: 	None
; Exit: 	Register HL = Address of zeroed Device Table Entry
; Registers used: HL
; ****************************************
CREATEDTE:
	push de
	push bc
	ld    hl, (DVTE)	; Get next free Device Table Entry
	ld    b, h		; Save old DTE
	ld    c, l
	ld    de, 17		; Increase by the size of a DTE
	add   hl, de
	ld    (DVTE), hl	; Make DVTE point at the next area to use
	ld    hl, 0   		; Restore the old DVTE pointer
	add   hl, bc
	pop bc
	pop de
	ret


