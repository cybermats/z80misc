	      
				    ; --------------------------------------------
				    ; Title: Memory Fill
				    ; Name: MFILL
				    ; --------------------------------------------
				    ; Arguments:
				    ;  HL - base address
				    ;  BC - size (A size of 0 is interpreted as 65536)
				    ;  A - Value to be placed in memory
				    ; Registers used:
				    ;  AF, BC, DE, HL
				    ; --------------------------------------------
MFILL:	      
	      LD    (hl), a	    ; Fill first byte with value
	      ld    d, h	    ; Destination Ptr = Source Ptr + 1
	      ld    e, l
	      inc   de
	      dec   bc		    ; Eliminate first byte from count
	      ld    a, b	    ; Are there more bytes to fill?
	      or    c
	      ret   z		    ; No, return - size was 1
	      ldir		    ; Yes, use block move to fill rest
				    ;  by moving value ahead 1 byte
	      ret
	      
	