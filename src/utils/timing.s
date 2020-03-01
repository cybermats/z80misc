; Title  Delay milliseconds
; Name:  Delay
; 
; Purpose: Delay from 1 to 256 milliseconds
; 
; Entry: Register A = Nuimber of ms to delay
;        A 0 equals 256 milliseconds
; 
; Registers used: AF
; 
	      
CPMS:	equ	10000	    
		; 2000 = 2MHz Clock
		; 4000 = 4MHz Clock
		; 6000 = 6MHz Clock


; Method:
; The routine is divided int o 2 parts. The call to
; the "DLY" routine delays e xactly 1 less than the
; required number of millise conds. The last interation
; takes into account the ove rhead to call "DELAY" and
; "DLY". This overhead is:
;    17 Cycles ==> call DELAY
;    11 Cycles ==> push bc
;    17 Cycles ==> call DLY
;     4 Cycles ==> dec a
;    11 Cycles ==> ret z
;     7 Cycles ==> ld b, (CP MS/100)-1
;    10 Cycles ==> pop bc
;    13 Cycles ==> ld a, (DE LAY)
;    10 Cycles ==> ret
;    ------
;   100 Cycles overhead

DELAY:
				    ; Do all but the last millisecond
				    ; 17 cycles for the user's call
	      push  bc		    ; 11 Cycles
	      call  DLY		    ; 32 cycles to return from DLY
				    ; Do 2 less than 1 millisecond for overhead
	      ld    B, +(CPMS/50)-2 ; 7 Cycles
				    ; -------
				    ; 67 Cycles


LDLP:	      
	      jp    LDLY1	    ; 10 Cycles
LDLY1:	      jp    LDLY2	    ; 10 Cycles
LDLY2:	      jp    LDLY3	    ; 10 Cycles
LDLY3:	      add   a, 0	    ; 7 Cycles
	      djnz  LDLP	    ; 13 Cycles
				    ; ---
				    ; 50 Cycles

				    ; Exit in 33 Cycles
	      pop   bc		    ; 10 Cycles
	      ld    a, (DELAY)	    ; 13 Cycles
	      ret		    ; 10 Cycles
				    ; ---
				    ; 33 Cycles

				    ; ***********************
				    ; Routine: DLY
				    ; Purpose: Delay all but the last ms
				    ; Entry: Register a = total number of ms
				    ; Exit: Delay all but the la st ms
				    ; Registers used: AF, BC, HL
DLY:
	      dec   a		    ; 4 Cycles
	      ret   z		    ; 5 Cycles (return when done 11 cycles)
	      ld    B, +(CPMS/50)-1 ; 7 Cycles
				    ; ---
				    ; 16 Cycles
	      
DLP:	      
	      jp    DLY1	    ; 10 Cycles
DLY1:	      jp    DLY2	    ; 10 Cycles
DLY2:	      jp    DLY3	    ; 10 Cycles
DLY3:	      add   a, 0	    ; 7 Cycles
	      djnz  DLP		    ; 13 Cycles
				    ; ---
				    ; 50 Cycles

				    ; Exit in 34 Cycles
	      jp    DLY4	    ; 10 Cycles
DLY4:	      jp    DLY5	    ; 10 Cycles
DLY5:	      nop		    ; 4 Cycles
	      jp    DLY		    ; 10 Cycles
				    ; ---
				    ; 34 Cycles
				    
	      