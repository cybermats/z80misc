				    ; Data is on pin A15
				    ; Clock is on pin A14
I2C_D0_C0:    .equ  $00		    ; Data is 0, Clock is 0
I2C_D0_C1:    .equ  $80		    ; Data is 0, Clock is 1
I2C_D1_C0:    .equ  $40		    ; Data is 1, Clock is 0
I2C_D1_C1:    .equ  $c0		    ; Data is 1, Clock is 1




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
