RAMBEG:	      .equ  $8000	    ; Begin of RAM
RAMEND:	      .equ  $ffff	    ; End of RAM
DVTE:	      .equ  $8100	    ; Device Table Entry memory pool
DVLST:	      .equ  $81ff	    ; Device List Pointer
IOCB:	      .equ  $8200	    ; IO Control Block
				    
				    
				    
init:				    
	      ld    SP, RAMEND	    ; Set Stack to end of memory
	      
				    ; Prepare IOCB
	      ld    hl, IOCB	    ; Zero out IOCB
	      ld    bc, 7	    ; Length is 7 bytes
	      xor   a		    ; fill with zero
	      call  MFILL
	      
	      call  INITDL	    ; Initialize Device List
	      call  segment_device  ; Add and Initialize the Segment Display
	      jp    main	    ; Jump to start
				    
	      .org  $0100
main:
	      ld    ix, IOCB
	      ld    (ix+IOCBOP), W1BYTE
	      ld    (ix+IOCBDN), 1
	      call  IOHDLR
loop:				    
	      in    a, ($ff)
	      call  IOHDLR
	      jr    loop
	      
	      halt


	      .include "device_handler.s"
	      .include "segment.s"
	      .include "util.s"


				    ; --------------------------------------------
				    ; End of file
				    ; --------------------------------------------
	      .org  $7fe
	      .word $0000
	      .end
	      
	      
	      