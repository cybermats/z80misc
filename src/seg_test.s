RAMBEG:	      equ  8000h	    ; Begin of RAM
RAMEND:	      equ  0ffffh	    ; End of RAM
DVTE:	      equ  8100h	    ; Device Table Entry memory pool
DVLST:	      equ  81ffh	    ; Device List Pointer
IOCB:	      equ  8200h	    ; IO Control Block
				    
				    
				    
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
				    
	      org  0100h
main:
	      ld    ix, IOCB
	      ld    (ix+IOCBOP), W1BYTE
	      ld    (ix+IOCBDN), 1
	      call  IOHDLR
loop:				    
	      in    a, (00ffh)
	      call  IOHDLR
	      jr    loop
	      
	      halt


	      include "utils/device_handler.s"
	      include "utils/segment.s"
	      include "utils/util.s"


				    ; --------------------------------------------
				    ; End of file
				    ; --------------------------------------------
	      org  07feh
	      dw 0000h
	      end
	      
	      
	      
