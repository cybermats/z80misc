I2C_ADDR:     .equ  $70		    ; I2C Address
SEG_BRGHT:    .equ  $01		    ; Screen brightness
VIDRAM:	      .equ  $8000     ; Video RAM


	      
segment_device:
				    ; Initialize screen buffer
	      ld    hl, screen_init
	      ld    de, VIDRAM
	      ld    bc, 5
	      ldir

	      
	      call  CREATEDTE	    ; Get empty Device Table Entry
	      push  hl		    ; Save DTE
	      ld    de, SEGDV	    ; Get Segment Device Table Entry from ROM
				    ; Prepare copying the DTE from ROM to RAM
	      ex    de, hl
	      ld    bc, 17
	      ldir
	      pop   hl		    ; Restore DTE
	      call  ADDDL	    ; Add device to Device List

				    ; Initialize segment
	      ld    ix, IOCB	    ; Point to IOCB
	      ld    (ix+IOCBOP), IOINIT	; Initialize operation
	      ld    (IX+IOCBDN), 1  ; Device number = 1
	      call IOHDLR








				    ; Console output status
segment_ostat:
	      ld    a, DEVRDY	    ; Status = Always ready to output
	      ret

				    ; Console output 1 byte
segment_out:
	      ld    e, a	    ; Save byte
	      or    $f		    ; Mask lower 16 bytes
	      ld    (VIDRAM + 4), a
	      ld    a, e
	      rra		    ; Mask next 16 bytes
	      rra
	      rra
	      rra
	      or    $f
	      ld    (VIDRAM + 3), a

	      call  segment_show
	      
	      sub   a		    ; Return, No Errors
	      ret
	      




	      
				    ; --------------------------------------------
				    ; segment_init - set up device
				    ; --------------------------------------------
				    ; Arguments:
				    ;  None
				    ; Registers used:
				    ;  A
				    ; --------------------------------------------
	      
segment_init:			    
	      ld    a, I2C_D1_C1    ; Initialize i2c
	      out   ($ff), a
	      ld    a, I2C_D0_C1    ; Send start frame
	      out   ($ff), a
	      
	      ld    a, I2C_ADDR	    ; Send address for system
	      sla   a		    ; adjust address to be the top 7 bits, with a 0 at the end for "writing".
	      call  i2cchar
	      ld    a, $21	    ; Set up system
	      call  i2cchar
	      
	      ld    a, I2C_D0_C1    ; Send end frame
	      out   ($ff), a
	      ld    a, I2C_D1_C1
	      out   ($ff), a
	      
	      ld    a, I2C_D0_C1    ; Send start frame
	      out   ($ff), a
	      
	      ld    a, I2C_ADDR	    ; Send address for system
	      sla   a		    ; adjust address to be the top 7 bits, with a 0 at the end for "writing".
	      call  i2cchar
	      ld    a, $80	    ; Display setup
	      or    a, $01	    ; Display on
	      call  i2cchar
				    
	      ld    a, I2C_D0_C1    ; Send end frame
	      out   ($ff), a
	      ld    a, I2C_D1_C1
	      out   ($ff), a
	      
	      ld    a, I2C_D0_C1    ; Send start frame
	      out   ($ff), a
				    
	      ld    a, I2C_ADDR	    ; Send address for system
	      sla   a		    ; adjust address to be the top 7 bits, with a 0 at the end for "writing".
	      call  i2cchar
	      ld    a, $e0	    ; Brightness command
	      or    a, SEG_BRGHT    ; Brightness
	      call  i2cchar
	      
	      ld    a, I2C_D0_C1    ; Send end frame
	      out   ($ff), a
	      ld    a, I2C_D1_C1
	      out   ($ff), a

	      sub   a		    ; Status = No Errors
	      
	      ret
				    
	      
	      
	      



	      
				    ; --------------------------------------------
				    ; segment_show - output frame buffer to display
				    ; --------------------------------------------
				    ; Arguments:
				    ;  None
				    ; Registers used:
				    ;  A
				    ; --------------------------------------------
segment_show:			    
	      push  hl
	      push  de
	      push  bc
				    
	      ld    a, I2C_D1_C1    ; Initialize i2c
	      out   ($ff), a
	      ld    a, I2C_D0_C1    ; Send start frame
	      out   ($ff), a
	      
	      ld    a, I2C_ADDR	    ; Send address for system
	      sla   a		    ; adjust address to be the top 7 bits, with a 0 at the end for "writing".
	      call  i2cchar
	      
	      ld    a, $00	    ; Set address to 00h
	      call  i2cchar
	      
	      ld    hl, VIDRAM
	      ld    b, $05
segment_loop:			    
	      ld    a, (hl)
	      ld    d, (font >> 8) & $ff
	      ld    e, a
	      ld    a, (de)
				    
	      call  i2cchar
	      ld    a, 0
	      call  i2cchar
	      inc   hl
	      djnz  segment_loop
	      
	      pop   bc
	      pop   de
	      pop   hl
	
	      ret


				    ; Default value for frame buffer
screen_init:			    
	      .defb $00, $00, $10, $00, $00
screen_init_len: 
	      .defb $ - screen_init

				    ; Device table entry
SEGDV:
	      dw    0		    ; Link Field
	      db    1		    ; Device 1
	      dw    segment_init    ; Segment Initialize
	      dw    0		    ; No Segment Input status
	      dw    0		    ; No Segment Input 1 byte
	      dw    0		    ; No Segment input N bytes
	      dw    segment_ostat   ; Segment output status
	      dw    segment_out	    ; Segment output 1 byte
	      dw    0		    ; No segment output n bytes
	      
	      
	      .org  $400
font:	      
	      .defb $3F,$06,$5B,$4F, $66,$6D,$7D,$07, $7F,$6F,$77,$7C, $39,$5E,$79,$71 ; All digits, 0-9a-f
       .defb $00, $02
	      


		.include "utils/i2c.s"
