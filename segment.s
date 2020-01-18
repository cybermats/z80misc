RAMBEG:	      .equ  $8000	    ; Begin of RAM
RAMEND:	      .equ  $ffff	    ; End of RAM
VIDRAM:	      .equ  $8000	    ; Video RAM


				    ; Data is on pin A15
				    ; Clock is on pin A14
I2C_D0_C0:    .equ  $00		    ; Data is 0, Clock is 0
I2C_D0_C1:    .equ  $80		    ; Data is 0, Clock is 1
I2C_D1_C0:    .equ  $40		    ; Data is 1, Clock is 0
I2C_D1_C1:    .equ  $c0		    ; Data is 1, Clock is 1

I2C_ADDR:     .equ  $70		    ; I2C Address
init:	      
	      ld    SP, RAMEND
	      ld    hl, screen_init
	      ld    de, VIDRAM
	      ld    b, 5
	      ldir
	      jp    main


	      .org  $0100
main:	      
	      ld    c, I2C_ADDR
	      ld    b, $01
	      call  segment_init
	      call  segment_show
	      ld    ix, VIDRAM
loop:	      
	      in    a, ($ff)

	      ld    b, 0
	      rra
	      jr    nc, fig1_done
	      ld    b, 1
fig1_done:    
	      ld    (ix), b

	      ld    b, 0
	      rra
	      jr    nc, fig2_done
	      ld    b, 1
fig2_done:    
	      ld    (ix+1), b

	      ld    b, 0
	      rra
	      jr    nc, fig3_done
	      ld    b, 1
fig3_done:    
	      ld    (ix+3), b

	      ld    b, 0
	      rra
	      jr    nc, fig4_done
	      ld    b, 1
fig4_done:	
	      ld    (ix+4), b

	      call  segment_show
	      jr    loop

	      halt

	


	

				    ; --------------------------------------------
				    ; segment_init - set up device
				    ; --------------------------------------------
				    ; Arguments:
				    ;  C - i2c address
				    ;  B - brightness
				    ; Registers used:
				    ;  A
				    ; --------------------------------------------
	
segment_init: 
	      ld    a, I2C_D1_C1    ; Initialize i2c
	      out   ($ff), a
	      ld    a, I2C_D0_C1    ; Send start frame
	      out   ($ff), a

	      ld    a, c	    ; Send address for system
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

	      ld    a, c	    ; Send address for system
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
	      
	      ld    a, c	    ; Send address for system
	      sla   a		    ; adjust address to be the top 7 bits, with a 0 at the end for "writing".
	      call  i2cchar
	      ld    a, $e0	    ; Brightness command
	      or    a, b	    ; Brightness
	      call  i2cchar

	      ld    a, I2C_D0_C1    ; Send end frame
	      out   ($ff), a
	      ld    a, I2C_D1_C1
	      out   ($ff), a

	      ret
	      

				    ; --------------------------------------------
				    ; segment_show - show message on display
				    ; --------------------------------------------
				    ; Arguments:
				    ;  C - i2c address
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

	      ld    a, c	    ; Send address for system
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
	      
				    ; --------------------------------------------
				    ; i2cchar - Send a char for i2c
				    ; --------------------------------------------
				    ; Character to send is in A
				    ; Registers used:
				    ;  A, B, C
				    ; --------------------------------------------
i2cchar:
	      push  bc
	      
	      ld    c, a
	      ld    b, $8	    ; Initialize loop counter

i2ccharloop:  
	      
	      ld    a, I2C_D0_C0    ; Set clock to zero
	      out   ($ff), a
	      
	      bit   7, c	    ; Test bit
	      
	      jr    nz, i2cset
	      
	      ld    a, I2C_D0_C1    ; Pulse clock
	      out   ($ff), a

	      jr    i2cdone
	      
i2cset:	      
	      ld    a, I2C_D1_C0    ; Prepare data
	      out   ($ff), a
	      ld    a, I2C_D1_C1    ; Pulse clock
	      out   ($ff), a
	      ld    a, I2C_D1_C0    ; Reset clock
	      out   ($ff), a
i2cdone:      
	      rlc   c		    ; Rotate data

	      djnz  i2ccharloop

	      ld    a, I2C_D0_C0    ; Set clock to zero
	      out   ($ff), a

	      ld    a, I2C_D0_C1    ; Wait for ACK/NACK
	      out   ($ff), a
	      ld    a, I2C_D0_C0    ; But ignore it for now
	      out   ($ff), a

	      pop   bc

	      ret

	      
screen_init:  
	      .defb $00, $00, $10, $00, $00
screen_init_len:
	      .defb $ - screen_init
	
	      .org  $400
font:	
	      .defb $3F,$06,$5B,$4F, $66,$6D,$7D,$07, $7F,$6F,$77,$7C, $39,$5E,$79,$71 ; All digits, 0-9a-f
	      .defb $00, $02
				    ; --------------------------------------------
				    ; End of file
				    ; --------------------------------------------
	      .org  $7fe
	      .word $0000
	      .end

	
