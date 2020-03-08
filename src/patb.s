; *********************************************************************
; *
; *		T B I
; *	TINY BASIC INTERPRETER
; *	     Version 3.0
; * 	   For 8080 System
; *	     Li-Chen Wang
; *	    26 April, 1977
; *
; *********************************************************************
; Taken from:
; https://www.autometer.de/unix4fun/z80pack/ftp/altair/Palo%20Alto%20Tiny%20BASIC%20Version%203.pdf


	macro TSTC
	db \1
	db \2-$-1
	CALL TSTCH
	endmacro

dwa:	macro 
	db (\1 >> 8) ; TODO + 128
	db \1 & $ff
	endmacro


; *********************************************************************
; *
; **** MEMORY USAGE***
; *
; * 0080-01FF Are for variables, input line, and stack
; * 2000-3FFF are for Tiny Basic Text & Array
; * F000-F7FF are for TBI code
; *

BOTSCR:	equ	$8000
TOPSCR: equ	$9fff
BOTRAM:	equ	$a000
DFTLMT:	equ	$f000
BOTROM:	equ	$0016
VRAMBEG:	equ	$7000
VRAMEND:  	equ	$7fff


; Misc constants

VIDEO_COLUMNS:	equ	80
VIDEO_ROWS:	equ	30


; *
; * Define variables, buffer, and stack in ram
; *

KEYWRD:	equ BOTSCR		; Was init done?
TXTLMT:	equ KEYWRD + 1		; ->Limit CF Text Area
VARBGN:	equ TXTLMT + 2		; TB Variables A-Z
CURRNT:	equ VARBGN + 2*26	; Points to current line
STKGOS:	equ CURRNT + 2		; Saves SP in 'GOSUB'
VARNXT:	equ STKGOS + 2		; Temp storage
STKINP:	equ VARNXT + 1		; Saves SP in 'INPUT'
LOPVAR:	equ STKINP + 2		; 'FOR' loop save area
LOPINC:	equ LOPVAR + 2		; Increment
LOPLMT:	equ LOPINC + 2		; Limit
LOPLN:	equ LOPLMT + 2		; Line number
LOPPT:	equ LOPLN  + 2		; Text Pointer
RANPNT:	equ LOPPT  + 2		; Random number pointer
CURSOR_COL:	equ	RANPNT +  2
CURSOR_ROW:	equ	CURSOR_COL + 1
KB_PS2_STATE:	equ	CURSOR_ROW + 1
KB_PS2_COUNT:	equ	KB_PS2_STATE + 1

		     		; Extra byte for buffer
BUFFER:	equ KB_PS2_COUNT + 2		; Input buffer
BUFEND:	equ BUFFER + 132	; Buffer ends
	    	     		; Extra bytes for stack
STKLMT:	equ BUFEND + 4		; Soft limit for stack



STACK:	equ TOPSCR		; Stack starts here

TXTUNF:	equ BOTRAM
TEXT:	equ TXTUNF + 2



; Video ports
VADDRPORT:	equ	$80
VDATAPORT:	equ	$81

; Serial ports
SIODATAA:	equ	$f0
SIODATAB: 	equ	$f1
SIOCMDA:  	equ	$f2
SIOCMDB:  	equ	$f3

; General port
OUTPORT:	equ	$00




; *
; *********************************************************************
; *
; * *** Local initialization ***
; *

	ld a, $1 : out (OUTPORT), a
	
	call VD_CONFIGURE
	
	ld a, $2 : out (OUTPORT), a
	
	ld a, 0
	call KD_CONFIGURE
	
	ld a, $3 : out (OUTPORT), a

	jr INIT
	



; *
; *********************************************************************
; *
; * *** Initialize ***
; *

	org BOTROM
INIT:	ld sp, STACK
	call CRLF
	ld hl, KEYWRD	; At power on KEYWRD is
	ld a, $c3	; probably not c3
	cp (hl)
	jp z, TELL	; It is C3, continue
	ld (hl), a	; No. Set it to C3
	ld hl, DFTLMT	; and set default value
	ld (TXTLMT), hl	; in 'TXTLMT'
	ld a, BOTROM>>8	; Initialize ranpnt
	ld (RANPNT+1), a
PURGE:	ld hl, TEXT+4	; Purge text area
	ld (TXTUNF), hl
	ld h, $ff
	ld (TEXT), hl
TELL:	ld de, MSG	; Tell user
	call PRTSTG	;  ***********************
	jp RSTART	; ***** JMP USER-INIT *****
MSG:	db "TINY "	;  ***********************
	db "BASIC"
	db " V3.0\n"
OK:	db "OK\n"
WHAT:	db "WHAT?\n"
HOW:	db "HOW?\n"
SORRY:	db "SORRY\n"


; *
; *********************************************************************
; *
; * *** Direct Command / Text Collecter ***
; *

RSTART:	ld sp, STACK	; Re-initialize Stack
	ld hl, ST1+1	; Literal 0
	ld (CURRNT), hl	; CURRNT->LINE # = 0
ST1:	ld hl, 0
	ld (LOPVAR), hl
	ld (STKGOS), hl
	ld de, OK	; de->STRING
	call PRTSTG	; Print String until CR
ST2:	ld a, '>'	; Prompt ">" and
	call GETLN	; read a line
	push de		; de->End of line
	ld de, BUFFER	; de->Beginning of line
	call TSTNUM	; Test if it is a number
	call IGNBLK
	ld a, h		; HL = Value of the # or
	or l  		; 0 if no # was found
	pop bc		; bc->end of line
	jp z, DIRECT
	dec de		; Backup DE and save
	ld a, h		; value of line # there
	ld (de), a
	dec de
	ld a, l
	ld (de), a
	push bc		; BC, DE->begin, end
	push de
	ld a, c
	sub e
	push af		; A=# of bytes in line
	call FNDLN	; Find this line in save
	push de		; area, de->save area
	jp nz, ST3	; NZ:Not found, insert
	push de		; Z:Found, delete it
	call FNDNXT	; Set de->next line
	pop bc		; BC->line to be deleted
	ld hl, (TXTUNF)	; hl->unfilled save area
	call MVUP	; Move up to delete
	ld h, b		; TXTUNF->unfilled area
	ld l, c
	ld (TXTUNF), hl	; update
ST3:	pop bc	     	; Get ready to insert
	ld hl, (TXTUNF)	; But first check if
	pop af 		; the length of new line
	push hl		; is 3 (Line # and CR)
	cp 3 		; then do not insert
	jp z, RSTART	; Must clear the stack
	add l 		; Compute new TXTUNF
	ld e, a
	ld a, 0
	adc h
	ld d, a		; de->new unfilled area
	ld hl, (TXTUNF)	; Check to see if there
	ex de, hl
	call COMP	; is enough space
	jp nc, QSORRY	; SORRY, no room for it
	ld (TXTUNF), hl	; OK, update TXTUNF
	pop de	     	; de->old unfilled area
	call MVDOWN
	pop de		; de->begin, hl->end
	pop hl
	call MVUP	; Move new line to save
	jp ST2		; area
	
; *
; *********************************************************************
; *
; * *** DIRECT *** & EXEC ***
; *
; * This section of the code tests a string against a table. When a
; * match is found, control is trasfered to the section of code
; * according ot the table.
; *
; * At 'EXEC', DE should point to the string and HL should point to the
; * TABLE-1. At 'DIRECT', DE should point to the string, HL will be set
; * up to point to TAB1-1, which is the table of all direct and
; * statement commands.
; *
; * A '.' in the string will terminate the test and the partial match
; * will be considered as a match. E.g., 'P.', 'PR.', 'PRI.', 'PRIN.',
; * or 'PRINT' will all match 'PRINT'.
; *
; * The table consists of any number of items. Each item is a string of
; * characters with bit 7 set to 0 and a jump address stored hi-low with
; * bit 8 of the high byte set to 1.
; *
; * End of table is an item with a jump address only. If the string
; * does not match any of the other items, it will match this null item
; * as default.

DIRECT:	ld hl, TAB1-1	; *** Direct ***
EXEC:	call IGNBLK	; *** Exec ***
	push de		; Save pointer
EX1:	ld a, (de)	; If found '.' in String
	inc de		; before any mismatch
	cp '.'		; we declare a match
	jr z, EX3
	inc hl		; hl->table
	cp (hl)		; If match, test next
	jr z, EX1
	ld a, $7f	; else, see if bit 7
	dec de		; of table is set, which
	cp (hl)		; is the jump addr. (HI)
	jr c, EX5	; C: Yes, Matched
EX2:	inc hl		; NC: No, find jump addr
	cp (hl)
	jr nc, EX2
	inc hl		; Bump to next tab. item
	pop de		; Restore String pointer
	jr EXEC		; test against next item
EX3:	ld a, $7f	; Partial match, find
EX4:	inc hl		; jump addr., which is
	cp (hl)		; flagged by bit 7
	jr c, EX4
EX5:	ld a, (hl)	; Load hl with the jump
	inc hl		; address from the table
	ld l, (hl)	;  ****************
	and $ff		; ***** AND 7f *****
	ld h, a		;  ****************
	pop AF		; Clean up the garbage
	jp (hl)		; and we go do it

; *
; *********************************************************************
; *
; * What follows is the code to execute direct and statement commands.
; * Control is transfered to these points via the command table lookup
; * code of "DIRECT" and "EXEC" in last section. After the command is
; * executed, control is transfered to other sections as follows:
; *
; * For "LIST", "NEW", and "STOP": Go back to "RSTART"
; * For "RUN": Go execute the first stored line if any; Else go back to
; * 	"RSTART".
; * For "GOTO" and "GOSUB": Go execute the target line.
; * For "RETURN" and "NEXT": Go back to saved return line.
; * For all others: If "CURRNT" -> 0, go to "RSTART", else go execute
; * 	next command. (This is done in "FINISH".)
; *
; *********************************************************************
; *
; * *** NEW *** STOP *** RUN (& FRIENDS) *** & GOTO ***
; *
; * "NEW(CR)" resets "TXTUNF"
; *
; * "STOP(CR)" goes back to "RSTART"
; *
; * "RUN(CR)" finds the first stored line, store its address (in
; * "CURRNT"), and start execute it. Note that only those
; * commands in TAB2 are legal for stored program.
; *
; * There are 3 more entries in "RUN":
; * "RUNNXL" finds next line, stores its addr, and executes it.
; * "RUNTSL" stores the address of this line and executes it.
; * "RUNSML" continues the execution on same line.
; *
; * "GOTO EXPR(CR)" evaluates the expression, find the target
; * line, and jump to "RUNTSL" to do it.
; *

NEW:	call ENDCHK	; *** NEW(CR) ***
	jp PURGE

STOP:	call ENDCHK	; *** STOP(CR) ***
	jp RSTART

RUN:	call ENDCHK	; *** RUN(CR) ***
	ld de, TEXT	; First saved line

RUNNXL:	ld hl, 0	; *** RUNNXL ***
	call FNDLP	; Find whatever line #
	jp c, RSTART	; C:Passed TXTUNF, Quit

RUNTSL:	ex de, hl	; *** RUNTSL ***
	ld (CURRNT), hl	; Set "CURRENT"->Line #
	ex de, hl
	inc de		; Bump pass line #
	inc de

RUNSML:	call CHKIO	; *** RUNSML ***
	ld hl, TAB2-1	; Find command in TAB2
	jp EXEC		; and execute it

GOTO:	call EXPR	; *** GOTO EXPR ***
	push de		; Save for error routine
	call ENDCHK	; Must find a CR
	call FNDLN	; Find the target line
	jp nz, AHOW	; No such line #
	pop af 		; Clear the push DE
	jp RUNTSL	; Go do it
	

; *
; *********************************************************************
; *
; * *** LIST *** & PRINT ***
; *
; * LIST has three forms:
; * "LIST(CR)" lists all saved lines
; * "LIST N(CR)" start list at line n
; * "LIST N1, N2(CR)" start list at line N1 for N2 lines. You can stop
; * the listing by control c key
; *
; * Print command is "PRINT ....;" or "PRINT ....(CR)"
; * Where "...." is a list of expressions, formats, and/or strings.
; * These items are separated by commas.
; *
; * A format is a pound sign followed by a number. It controls the
; * number of spaces the value of an expression is going to be printed.
; * It stays effective for the rest of the print command unless changed
; * by another format. If no format is specified, 8 positions will be 
; * used.
; *
; * A string is quoted in a pair of single quotes or a pair of double
; * qoutes.
; *
; * Control Characters and lower case letters can be included inside the
; * quotes. Another (better) way of generating control characters on 
; * the output is use the up-arrow character followed by a letter. ^L
; * means FF, ^I means HT, ^G means bell etc.
; *
; * A (CRLF) is generated after the entire list has been printed or if
; * the list is a null list. However if the list ended with a comma, no
; * (CRLF) is generated.
; *

LIST:	call TSTNUM	; Test if there is a #
	push hl
	ld hl, $ffff
	TSTC ',', LS1
	call TSTNUM
LS1:	ex (sp), hl
	call ENDCHK	; If no # we get a 0
	call FNDLN	; Find this or next line
LS2:	jp c, RSTART	; C:Passed TXTUNF
	ex (sp), hl
	ld a, h
	or l
	jp z, RSTART
	dec hl
	ex (sp), hl
	call PRTLN	; Print the line
	call PRTSTG
	call CHKIO
	call FNDLP	; Find next line
	jr LS2

PRINT:	ld c, 8		; C= # GF Spaces
	TSTC ';', PR1	; If null list & ";"
	call CRLF 	; Give CR-LF and
	jp RUNSML	; continue same line
PR1:	TSTC '\n', PR6	; If null list (CR)
	call CRLF  	; Also give CR-LF and
	jp RUNNXL	; go to next line
PR2:	TSTC '#', PR4	; else is it format?
PR3:	call EXPR 	; Yes, evaluate EXPR
	ld a, $c0
	and l
	or h
	jp nz, QHOW
	ld c, l		; And save it in C
	jr PR5		; Look for more to print
PR4:	call QTSTG	; or is it a string?
	jr PR9		; if not, must be EXPR
PR5:	TSTC ',',PR8	; If ",", go find next
PR6:	TSTC ',', PR7
	ld a, ' '
	call OUTCH
	jr PR6
PR7:	call FIN	; in the list
	jr PR2		; List continues
PR8:	call CRLF	; List ends
	jp FINISH
PR9:	call EXPR	; Evaluate the EXPR
	push bc
	call PRTNUM	; Print the value
	pop bc
	jr PR5		; More to print?

; *
; *********************************************************************
; *
; * *** GOSUB *** & RETURN ***
; *
; * "GOSUB EXPR:" or "GOSUB EXPR (CR)" is like the "GOTO" command,
; * except that the current text pointer, stack pointer etc. are saved so
; * that execution can be continued after the subroutine "RETURN". In
; * order that "GOSUB" can be nested (and even recursive), the save area
; * must be stacked. The stack pointer is saved in "STKGOS". The old
; * "STKGOS" is saved in the stack. If we are in the main routine,
; * "STKGOS" is zero (this was done by the "MAIN" section of the code),
; * but we still save it as a flag for no further "RETURN"s.
; *
; * "RETURN(CR)" undos everythign that "GOSUB" did, and this return the 
; * execution to the command after the most recent "GOSUB". If "STKGOS"
; * is zero, it indicates th we never had a "GOSUB" and is this an 
; * error.
; *
	if 0
	
GOSUB:	call PUSHA	; Save the current "FOR"
	call EXPR	; parameters
	push de		; and text pointer
	call FNDLN	; Find the target line
	jp nz, AHOW	; Not there. Say "HOW?"
	ld hl, (CURRNT)	; Save old
	push hl		; "CURRNT" old "STKGOS"
	ld hl, (STKGOS)
	push hl
	ld hl, 0	; and load new ones
	ld (LOPVAR), hl
	add hl, sp
	ld (STKGOS), hl
	jp RUNTSL	; Then run that line
RETURN:	call ENDCHK	; There must be a CR
	ld hl, (STKGOS)	; Old stack pointer
	ld a, h		; 0 means not exist
	or l
	jp z, QWHAT	; So, we say: "WHAT?"
	ld sp, hl	; else, restore it
RESTOR:	pop hl
	ld (STKGOS), hl	; and the old "STKGOS"
	pop hl
	ld (CURRNT), hl	; and the old "CURRNT"
	pop de	     	; old text pointer
	call POPA	; old "FOR" parameters
	jp FINISH

; *
; *********************************************************************
; *
; * *** FOR *** & NEXT ***
; *
; * "FOR" has two forms: "FOR VAR=EXP1 TO EXP2 STEP EXP3" and "FOR
; * VAR=EXP1 TO EXP2". The second form means the same thing as the first
; * form with EXP3=1. (I.e. with a step of +1.) TBI will find the 
; * variable VAR. and set its value to the current value of EXP1. It
; * also evaluates EXP2 and EXP3 and save all these together with the
; * text pointer etc. in the "FOR" save area, which consists of
; * "LOPVAR", "LOPINC", "LOPLMT", "LOPLN" and "LOPPT". If there is
; * already something in the save area (this is indicated by a
; * non-zero "LOPVAR"), then the old save area is saved in the stack
; * before the new one overwrites it. TBI will then dig in the stack
; * and find out if this same variable was used in another currently
; * active "FOR" loop. If that is the case, then the old "FOR" loop is
; * deactivated. (Purged from the stack..)
; *
; * "NEXT VAR" serves as the logical (not necessarilly physical) end of
; * the "FOR" loop. The control variable VAR. is checked with the 
; * "LOPVAR". If they are not the same, TBI digs in the stack to find
; * the right one and purges all those that did not match. Either way,
; * TBI then adds the "STEP" to that variable and check the result with
; * the limit. If it is within the limit, control loops back to the
; * command following the "FOR". If outside the limit, the save area is
; * purged and execution continues.
; *

FOR:	call PUSHA	; Save the old save area
	call SETVAL	; Set the control var
	dec hl		; HL is its address
	ld (LOPVAR), hl	; Save that
	ld hl, TAB4-1	; Use "EXEC" to look
	jp EXEC		; for the word "TO"
FR1:	call EXPR	; Evaluate the limit
	ld (LOPLMT), hl	; Save that
	ld hl, TAB5-1	; Use "EXEC" to look
	jp EXEC		; for the work "STEP"
FR2:	call EXPR	; Found it, get step
	jr FR4
FR3:	ld hl, 1	; Not found, set to 1
FR4:	ld (LOPINC), hl	; Save that to
	ld hl, (CURRNT)	; Save current line #
	ld (LOPLN), hl	;
	ex de, hl   	; And text pointer
	ld (LOPPT), hl	;
	ld bc, 10   	; dig into stack to
	ld hl, (LOPVAR)	; find "LOPVAR"
	ex de, hl
	ld h, b
	ld l, b		; HL=0 now
	add hl, sp	; Here is the stack
	jr FR6
FR5:	add hl, bc	; Each level is 10 deep
FR6:	ld a, (hl)	; Get that old "LOPVAR"
	inc hl
	or a, (hl)
	jr z, FR7	; 0 says no more in it
	ld a, (hl)
	dec hl
	cp d		; same as this one?
	jr nz, FR5
	ld a, (hl)	; The other half?
	cp e
	jr nz, FR5
	ex de, hl	; Yes, found one
	ld hl, 0
	add hl, sp	; Try to move SP
	ld b, h
	ld c, l
	ld hl, 10
	add hl, de
	call MVDOWN	; and purge 10 words
	ld sp, hl	; in the stack
FR7:	ld hl, (LOPPT)	; Job done, restore DE
	ex de, hl
	jp FINISH	; and continue

NEXT:	call TSTV	; Get address of var.
	jp c, QWHAT	; No variable, "WHAT?"
	ld (VARNXT), hl	; Yes, save it
NX1:	push de	     	; Save text pointer
	ex de, hl
	ld hl, (LOPVAR)	; Get var in "FOR"
	ld a, h
	or l		; 0 says never had one
	jp AWHAT	; so we ask: "WHAT?"
	call COMP	; else we check them
	jr z, NX2	; OK, they agree
	pop de		; No, let's see
	call POPA	; purge current loop
	ld hl, (VARNXT)	; and pop one level
	jr NX1 		; go check again
NX2:	ld e, (hl)	; Come here when agreed
	inc hl
	ld d, (hl)	; DE= value of VAR.
	ld hl, (LOPINC)
	push hl
	ld a, h
	xor d		; S=Sign differ
	ld a, d		; A=Sign of DE
	add hl, de	; Add one step
	jp m, NX3	; cannot overflow
	xor h 		; May overflow
	jp m, NX5	; And it did
NX3:	ex de, hl
	ld hl, (LOPVAR)	; Put it back
	ld (hl), e
	inc hl
	ld (hl), d
	ld hl, (LOPLMT)	; HL=limit
	pop af 		; old hl
	or a
	jp p, NX4	; step > 0
	ex de, hl	; step < 0
NX4:	call CKHLDE	; Compare with limit
	pop de		; restore text pointer
	jr c, NX6	; outside limit
	ld hl, (LOPLN)	; within limit, go
	ld (CURRNT), hl	; back to the saved
	ld hl, (LOPPT)	; "CURRNT" and text
	ex de, hl	; pointer
	jp FINISH
NX5:	pop hl		; overflow, purge
	pop de		; garbage in stack
NX6:	call POPA	; Purge this loop
	jp FINISH
	
	endif
; *
; *********************************************************************
; *
; * *** REM *** IF *** INPUT *** & LET (& DEFLT) ***
; *
; * "REM" can be followed by anything and is ignored by TBI. TBI treats
; * it like an "IF" with a false condition.
; *
; * "IF" is followed by an EXPR, as a condition and one or more commands
; * (including other "IF"s) separated by semi-colons. Note that the
; * word "THEN" is not used. TBI evaluates the EXPR. If it is non-zero,
; * execution continues. If the expr is zero, the commands that
; * follows are ignored and execution continues at the next line.
; *
; * "INPUT" command is like the "PRINT" command, and is followed by a
; * list of items. If the item is a string in single or double quotes,
; * or is an up-arrow, it has the same effect as a "PRINT". If an item
; * is a vairaible, this variable name is printed out followed by a 
; * colon. Then TBI waits for an EXPR to be typed in. The variable is
; * then set to the value of this EXPR. If the variable is proceded by 
; * a string (again in single or double quotes), the string will be
; * printed followed by a colon. TBI then waits for input EXPR and
; * set the variable to the value of the EXPR.
; *
; * If the input EXPR is invalid, TBI will print "WHAT?", "HOW?" or
; * "SORRY" and reprint the prompt and redo the input. The execution
; * will not terminate unless you type CONTROL-C. This is handled in
; * "INPERR".
; *
; * "LET" is followed by a list of items separated by command. Each item
; * consists of a variable, an equal sign, and an EXPR. TBI evaluates
; * the EXPR and set the variable to that value. TBI will also handle
; * "LET" command without the word "LET". This is done by "DEFLT".
; *

REM:	ld hl, 0	; *** REM ***
	jr IF1 		; This is like "IF 0"
IFF:	call EXPR	; *** IF ***
IF1:	ld a, h		; Is the EXPR=0?
	or l
	jp nz, RUNSML	; No, continue
	call FNDSKP	; Yes, skip rest of line
	jp nc, RUNTSL	; and run the next line
	jp RSTART	; if NC next, re-start

INPERR:	ld hl, (STKINP)	; *** INPERR ***
	ld sp, hl	; Restore old SP
	pop hl 		; and old "CURRNT"
	ld (CURRNT), hl
	pop de		; and old text pointer
	pop de		; redo input

INPUT:	ds 0
IP1:	push de		; Save in case of error
	call QTSTG	; Is next item a string?
	jr IP8		; No
IP2:	call TSTV	; Yes, but followed by a
	jr c, IP5	; variable? No.
IP3:	call IP12
	ld de, BUFFER	; Pointes to buffer
	call EXPR	; Evaluate input
	call ENDCHK
	pop de		; OK, Get old HL
	ex de, hl
	ld (hl), e	; Save value in Var.
	inc hl
	ld (HL), d
IP4:	pop hl		; Get old "CURRNT"
	ld (CURRNT), hl
	pop de		; And old Text Pointer
IP5:	pop af		; Purge junk in stack
IP6:	TSTC ',', IP7	; Is next character ","?
	jr INPUT  	; Yes, more items
IP7:	jp FINISH
IP8:	push de		; Save for PRTSTG
	call TSTV	; Must be variable now
	jr nc, IP11
IP10:	jp QWHAT	; "WHAT?" it is not?
IP11:	ld b, e
	pop de
	call PRTCHS	; Print those as prompt
	jr IP3		; Yes, input variable
IP12:	pop bc		; Return address
	push de		; Save text pointer
	ex de, hl
	ld hl, (CURRNT)	; Also save "CURRNT"
	push hl
	ld hl, IP1	; A negative number
	ld (CURRNT), hl	; as a flag
	ld hl, 0     	; Save SP too
	add hl, sp
	ld (STKINP), hl	;
	push de	     	; Old HL
	ld a, ' '	; Print a space
	push bc
	jp GETLN	; And get a line
DEFLT:	ld a, (de)	; *** DEFLT ***
	cp '\n'		; Empty line is ok
	jr z, LT4	; Else it is "LET"
LET:	ds 0  		; *** LET ***
LT2:	call SETVAL
LT3:	TSTC ',',LT4	; Set value to var.
	jr LET		; Item by item
LT4:	jp FINISH	; Until finish

; *
; *********************************************************************
; *
; * *** EXPR ***
; *
; * "EXPR" evaluates arithmetical or logical expressions.
; * <EXPR>::=<EXPR1>
; *	     <EXPR1><REL.OP.><EXPR1>
; * Where <REL.OP.> is one of the operators in TAB6 and the result of
; * these operations is 1 if True and 0 if False.
; * <EXPR1>::=(+ or -)<EXPR2>(+ or -<EXPR2>)(....)
; * where () are optional and (....) are optional repeats.
; * <EXPR2>::=<EXPR3>(<* or /><EXPR3>)(....)
; * <EXPR3>::=<VARIABLE>
; *	      <FUNCTION>
; *	      <EXPR>
; * <EXPR> is recursive so that variable '@' can have an <EXPR> as
; * index, functions can have an <EXPR> as arguments, and
; * <EXPR3> can be an <EXPR> in paranthese.
; *

EXPR:	call EXPR1	; *** EXPR ***
	push hl		; Save <EXPR1> value
	ld hl, TAB6-1	; Lookup REL.OP.
	jp EXEC		; Go do it
XPR1:	call XPR8	; REL.OP.">="
	ret c		; No, return HL=0
	ld l, a		; Yes, return HL=1
	ret
XPR2:	call XPR8	; REL.OP."#"
	ret z		; False, return hl=0
	ld l, a		; True, return HL=1
	ret
XPR3:	call XPR8	; REL.OP.">"
	ret z		; False
	ret c		; Also false, HL=0
	ld l, a		; True, HL=1
	ret
XPR4:	call XPR8	; REL.OP."<="
	ld l, a		; set HL=1
	ret z 		; Rel True, return
	ret c
	ld l, h		; else set HL=0
	ret
XPR5:	call XPR8	; REL.OP."="
	ret nz		; False, return HL=0
	ld l, a		; Else set HL=1
	ret

XPR6:	call XPR8	; REL.OP."<"
	ret nc		; False, return HL=0
	ld l, a		; else set HL=1
	ret
XPR7:	pop hl		; not REL.OP.
	ret
XPR8:	ld a, c		; Subroutine for all
	pop hl		; REL.OP.'s
	pop bc
	push hl		; Reverse top of stack
	push bc
	ld c, a
	call EXPR1	; Get 2nd <EXPR1>
	ex de, hl	; Value in DE now
	ex (sp), hl	; 1st <EXPR1> in HL
	call CKHLDE	; Compare 1st with 3nd
	pop de		; restore text pointer
	ld hl, 0	; set HL=0, A=1
	ld a, 1
	ret

EXPR1:	TSTC '-', XP11	; Negative sign?
	ld hl, 0  	; Yes, fake "0-"
	jr XP16		; Treat like subtract
XP11:	TSTC '+', XP12	; Positive sign? Ignore
XP12:	call EXPR2	; 1st <EXPR2>
XP13:	TSTC '+', XP15	; Add?
	push hl	  	; Yes, save value
	call EXPR2	; Get 2nd <EXPR2>
XP14:	ex de, hl	; 2nd in DE
	ex (sp), hl	; 1st in HL
	ld a, h	 	; Compare sign
	xor d
	ld a, d
	add hl, de
	pop de		; Restore text pointer
	jp m, XP13	; 1st 2nd sign differ
	xor h 		; 1st 2nd sign equal
	jp p, XP13	; So is result
	jp QHOW		; else we have overflow
XP15:	TSTC '-', XPR9	; Subtract?
XP16:	push hl	  	; Yes, save 1st <EXPR2>
	call EXPR2	; Get 2nd <EXPR2>
	call CHGSGN	; Negate
	jr XP14		; And add them

EXPR2:	call EXPR3	; Get 1st <EXPR3>
XP21:	TSTC '*', XP24	; Multiply?
	push hl	  	; Yes, save 1st
	call EXPR3	; and get 2nd <EXPR3>
	ld b, 0		; Clear b for sign
	call CHKSGN	; Check sign
	ex (sp), hl	; 1st in HL
	call CHKSGN	; Check sign of 1st
	ex de, hl
	ex (sp), hl
	ld a, h		; is HL > 255 ?
	or a
	jr z, XP22	; No
	ld a, d		; Yes, how about DE
	or d
	ex de, hl	; Put smaller in HL
	jp nz, AHOW	; Also >, will overflow
XP22:	ld a, l		; This is dumb
	ld hl, 0	; Clear result
	or a   		; add and count
	jr z, XP25
XP23:	add hl, de
	jp z, AHOW	; Overflow
	dec a
	jr nz, XP23
	jr XP25		; Finished
XP24:	TSTC '/', XPR9	; Divide?
	push hl	  	; Yes, save 1st <EXPR3>
	call EXPR3	; and get 2nd one
	ld b, 0		; Clear B for sign
	call CHKSGN	; Check sign of 2nd
	ex (sp), hl	; Get 1st in HL
	call CHKSGN	; Check sign of 1st
	ex de, hl
	ex (sp), hl
	ex de, hl
	ld a, d		; Divide by 0?
	or e
	jp z, AHOW	; Say "HOW?"
	push bc		; Else save sign
	call DIVIDE	; Use subroutine
	ld h, b		; Result in HL now
	ld l, c		;
	pop bc		; Get sign back
XP25:	pop de		; and text pointer
	ld a, h		; HL must BE +
	or a
	jp m, QHOW	; Else it is overflow
	ld a, b
	or a
	call m, CHGSGN	; Change sign if needed
	jr XP21		; Look for more terms
EXPR3:	ld hl, TAB3-1	; Find function in TAB3
	jp EXEC		; and go do it
NOTF:	call TSTV	; No, not a function
	jr c, XP32	; Nor a variable
	ld a, (hl)	; Variable
	inc hl
	ld h, (hl)	; Value in hl
	ld l, a
	ret
XP32:	call TSTNUM	; Or is it a number
	ld a, b		; # of digit
	or a
	ret nz		; ok
PARN:	TSTC '(', XPR0	; No digit, ust be
PARNP:	call EXPR 	; "(EXPR)"
	TSTC ')', XPR0
XPR9:	ret
XPR0:	jp QWHAT	; Else say: "WHAT?"

RND:	call PARN	; *** RND(EXPR) ***
	ld a, h		; EXPR must be +
	or a
	jp m, QHOW
	or l		; and non-zero
	jp z, QHOW
	push de		; Save both
	push hl
	ld hl, (RANPNT)	; Get memory as random
	ld de, (RANEND)
	call COMP
	jr c, RA1	; Wrap around if last
	ld hl, (BOTROM)
RA1:	ld e, (hl)
	inc hl
	ld d, (hl)
	ld (RANPNT), hl
	pop hl
	ex de, hl
	push bc
	call DIVIDE	; RND(N)=MOD(M, N)+1
	pop bc
	pop de
	inc hl
	ret

ABS:	call PARN	; *** ABS(EXPR) ***
	dec de
	call CHKSGN	; Check sign
	inc de
	ret

SIZE:	ld hl, (TXTUNF)	; *** SIZE ***
	push de		; Get the number of free
	ex de, hl	; bytes between 'TXTUNF'
	ld hl, (TXTLMT)	; and "TXTLMT"
	call SUBDE
	pop de
	ret

; *
; *********************************************************************
; *
; * *** DIVIDE *** SUBDE *** CHKSGN *** CHGSGN *** & CKHLDE ***
; *
; * "DIVIDE" divides HL by DE, results in BC, remainder in HL
; *
; * "SUBDE" subtracts DE from HL
; *
; * "CHKSGN" checks sign of HL. If +, no change. If -, change sign and
; * flip sign of B.
; *
; * "CHGSGN" changes sign of HL and B unconditionally.
; *
; * "CKHLDE" checks sign of HL and DE. If different, HL and DE are
; * interchanged. If same sign, not interchanged. Either case, HL DE
; * are then compared to set the flags.

DIVIDE:	push hl		; *** DIVIDE ***
	ld l, h		; Divide H by DE
	ld h, 0
	call DV1
	ld b, c		; Save result in B
	ld a, l		; (Remainder+L)/DE
	pop hl
	ld h, a
DV1:	ld c, -1	; Result in C
DV2:	inc c 		; Dumb routine
	call SUBDE	; Divide by subtract
	jr nc, DV2	; and count
	add hl, de
	ret

SUBDE:	ld a, l		; *** SUBDE ***
	sub e 		; Subtract DE from
	ld l, a		; HL
	ld a, h
	sbc d
	ld h, a
	ret

CHKSGN:	ld a, h		; *** CHKSGN ***
	or a  		; Check sign of HL
	ret p		; If -, change sign

CHGSGN:	ld a, h		; *** CHGSGN ***
	or l
	ret z
	ld a, h
	push af
	cpl		; Change sign of HL
	ld h, a
	ld a, l
	cpl
	ld l, a
	inc hl
	pop af
	xor h
	jp QHOW
	ld a, b		; And also flip B
	xor $80
	ld b, a
	ret

CKHLDE:	ld a, h
	xor d		; Same sign?
	jr CK1		; Yes, compare
	ex de, hl	; No, exchange and COMP
CK1:	call COMP
	ret

COMP:	ld a, h		; *** COMP ***
	cp d  		; Compare HL with DE
	ret nz		; Return correct C and
	ld a, l		; Z flags
	cp e  		; But old A is lost
	ret



; *
; *********************************************************************
; *
; * *** SETVAL *** FIN *** ENDCHK *** & ERROR (& FRIENDS) ***
; *
; * "SETVAL" expects a variable, followed by an equal sign and then an
; * EXPR. It evaluates the EXPR. and set the variable to that value.
; *
; * "FIN" checks the end of a command. If it ended with ";", execution
; * continues. IF it ended with a CR, it finds the next line and
; * continue from there.
; *
; * "ENDCHK" Checks if a command is ended with CR. This is required in
; * certain commands. (GOTO, RETURN, and STOP etc.)
  ; *
; * "ERROR" prints the stirng pointed by DE (and ends with CR). It then
; * prints the line pointed by "CURRNT" with a "?" inserted at where th
; * old text pointer (shuold be on top of the stack) points to.
; * Execution of TB is stopped and TBI is restarted. However, if
; * "CURRNT" -> ZERO (indicating a direct command), the direct command
; * is not printed. And if "CURRNT" -> Negative # (Indicating 'INPUT'
; * command, the input line is not printed and execution is not
; * terminated but continued at "INPERR".
; *
; * Related to "ERROR" are the following: "QWHAT" saves text pointer in
; * stack and get message "WHAT?". "AWHAT" just get message "WHAT?" and
; * jump to "ERROR". "QSORRY" and "ASORRY" do same kind of thing.
; * "QHOW" and "AHOW" in the zero page section also do this
; *

SETVAL:	call TSTV	; *** SETVAL ***
	jr c, QWHAT	; "WHAT?" no variable
	push hl		; Save address of var.
	TSTC '=', SV1	; Pass "=" sign
	call EXPR 	; Evaluate expr
	ld b, h		; value in BC now
	ld c, l
	pop hl		; get address
	ld (hl), c	; save value
	inc hl
	ld (hl), b
	ret
FINISH:	call FIN	; Check end of command
SV1:	jr QWHAT	; Print "WHAT?" if wrong
FIN:	TSTC ';', FI1	; *** FIN ***
	pop af	  	; ";", purge ret addr.
	jp RUNSML	; Continue same line
FI1:	TSTC '\n', FI2	; Not ";", is it CR?
	pop af		; Yes, purge ret addr.
	jp RUNNXL	; run next line
FI2:	ret		; else return to caller

IGNBLK:	ld a, (de)	; *** IGNBLK ***
	cp ' '		; Ignore blanks
	ret nz		; in text (Where DE->)
	inc de		; and return the first
	jr IGNBLK	; non-blank char. in A

ENDCHK:	call IGNBLK	; *** ENDCHK ***
	cp '\n'		; end with CR?
	ret z		; OK, else say: "WHAT?"
QWHAT:	push de		; *** QWHAT ***
AWHAT:	ld de, WHAT	; *** AWHAT ***
ERROR:	call CRLF
	call PRTSTG	; Print error message
	ld hl, (CURRNT)	; Get current line #
	push hl
	ld a, (hl)	; Check the value
	inc h
	or (hl)
	pop de
	jp z, TELL	; If zero, just restart
	ld a, (hl)	; If negative
	or a
	jp m, INPERR	; redo input
	call PRTLN	; else print the line
	pop bc
	ld b, c
	call PRTCHS
	ld a, '?'	; Print a "?"
	call OUTCH
	call PRTSTG	; Line
	jp TELL		; then restart
QSORRY:	push de		; *** QSORRY ***
ASORRY:	ld de, SORRY	; *** ASORRY ***
	jp ERROR
	

; *
; *********************************************************************
; *
; * *** FNDLN (& FRIENDS) ***
; *
; * "INFDLN" find a line with a given line # (in HL) in the text save
; * area. DE is used as the text pointer. If the line is found, DE
; * will point to the beginning of that line (i.e., the low byte of the
; * line #), and flags are NC & Z. If that line is not there and a line
; * with a higher line # is found, DE points to there and flags are NC &
; * NZ. If we reached the end of text save area and cannot find the
; * line, flags are C & NZ. "FINDLN" will initialize DE to the beginning
; * of the text save area to start the search. Some other entries of
; * this routine will not initialize DE and do the search. "FNDLP"
; * will start with the DE and search for the line #. "FNDNXT" will bump DE
; * by 2, find a CR and then start search. "FNDSKP" use DE to find a
; * CR, and the start search.
FNDLN:	ld a, h	      ; *** FNDLN ***
	or a  	      ; Check sign of HL
	jp m, QHOW    ; it cannot be -
	ld de, TEXT   ; init text pointer

FNDLP:	inc de 	      ; Is it EOT mark?
	ld a, (de)
	dec de
	add a
	ret c		; C, NZ passed end
	ld a, (de)	; We did not. Get byte 1
	sub l 		; is this the line?
	ld b, a		; compare low byte
	inc de
	ld a, (de)	; Get byte 2
	sbc h 		; compare high order
	jr c, FL1	; no, not there yet
	dec de		; else we either found
	or b		; it, or it is not there
	ret		; NC, Z: Found; NC, NZ: No

FNDNXT:	inc de		; Find next line
FL1:	inc de		; Just passed byte 1 & 2

FNDSKP:	ld a, (de)	; *** FNDSKP ***
	cp '\n'		; Try to find CR
	jr nz, FL1	; keep looking
	inc de 		; Found CR, skip over
	jr FNDLP	; Check if end of text

TSTV:	call IGNBLK	; *** TSTV ***
	sub '@'		; Test variables
	ret c		; C:Not a variable
	jr nz, TV1	; Not "@" array
	inc de 		; It is the "@" array
	call PARN	; @ should be followed
	add hl, hl	; by (EXPR) as its index
	jp c, QHOW	; is index too big?
	push de		; will it fit?
	ex de, hl
	call SIZE	; Find size of free
	call COMP	; and check that
	jr c, ASORRY	; if not, say "Sorry"
	call LOCR	; If fits, get address
	add hl, de	; of @(EXPR) and put it
	pop de		; in HL
	ret 		; C flag is cleared
TV1	cp 27		; not @, is it A to Z?
	ccf		; If not return C flag
	ret c
	inc de		; If A through Z
	ld hl, VARBGN-2
	rla		; HL->Variable
	add l		; Return
	ld l, a		; With c flag cleared
	ld a, 0
	adc h
	ld h, a
	ret
	
	
; *
; *********************************************************************
; *
; * *** TSTCH *** TSTNUM ***
; *
; * TSTCH is used to test the next non-blank character in the text
; * (pointed by DE) against the character that follows the call. If
; * they do not match, N bytes of code will be skipped over, where N is
; * between 0 and 255 and is stored in the second byte following the
; * call.
; *
; * TSTNUM is used to check whether the text (pointed by DE) is a
; * number. If a numnber is found, B will be non-zero and HL will
; * contain the value (in binary) of the number, else B and HL are 0.
; *

TSTCH:	ex (sp), hl	; *** TSTCH ***
	call IGNBLK	; Ignore leading blanks
	cp (hl)		; and test the character
	inc hl		; Compare the byte that
	jr z, TC1	; follows the call inst.
	push bc		; with the text (DE->)
	ld c, (hl)	; If not =, add the 2nd
	ld b, 0		; byte that follows the
	add hl, bc	; call to the old PC
	pop bc		; i.e., do a relative
	dec de		; jump if not =
TC1:	inc de		; If =, skip those bytes
	inc hl		; and continue
	ex (sp), hl
	ret

TSTNUM:	ld hl, 0	; *** TSTNUM ***
	ld b, h		; Test if the text is
	call IGNBLK	; a number
TN1:	cp '0'		; If not, return 0 in
	ret c		; B and HL
	cp $3a		; IF numbers, convert
	ret nc		; to binary in HL and
	ld a, $f0	; set B to # of digits
	and h 		; if h>255, there is no
	jr nz, QHOW	; room for next digit
	inc b  		; B counts # of digits
	push bc
	ld b, h		; HL=10*HL+(New digit)
	ld c, l
	add hl, hl	; Where 10*is done by
	add hl, hl	; shift and add
	add hl, bc
	add hl, hl
	ld a, (de)	; and (digit) is from
	inc de		; stripping the ASCII
	and $0f		; code
	add l
	ld l, a
	ld a, 0
	adc h
	ld h, a
	pop bc
	ld a, (de)	; Do this digit after
	jr TN1		; digit. S says overflow
QHOW:	push de		; *** ERROR: "HOW?" ***
AHOW:	ld de, HOW
	jp ERROR




; *
; *********************************************************************
; *
; * *** MVUP *** MVDOWN *** POPA *** & PUSHA ***
; *
; * 'MVUP' moves a block up from where de-> to where bc-> until de=hl
; *
; * 'MVDOWN' moves a block down from where de-> to where hl-> until de =
; * bc
; *
; * 'POPA' restores the 'FOR' loop variable save area from the stack
; *
; * 'PUSHA' stacks the 'FOR' loop variable save area into the stack
; *

MVUP:	call COMP	; *** MVUP ***
	ret z		; DE = HL, return
	ld a, (de)	; Get one byte
	ld (bc), a	; move it
	inc de	 	; Increase both pointers
	inc bc
	jr MVUP		; Until done

MVDOWN:	ld a, b		; *** MVDOWN ***
	sub d 		; Test if CE = BC
	jr MD1		; No, go move
	ld a, c		; Maybe, other byte?
	sub e
	ret z		; Yes, return
MD1:	dec de		; else move a byte
	dec hl		; but first decrease
	ld a, (de)	; both pointers and
	ld (hl), a	; then do it
	jr MVDOWN	; loop back

	if 0

POPA:	pop bc		; BC = Return addr.
	pop hl		; restore LOPVAR, but
	ld (LOPVAR), hl	; =0 means no more
	ld a, h
	or l
	jr z, PP1	; Yep, go return
	pop hl		; Nop, restore others
	ld (LOPINC), hl
	pop hl
	ld (LOPLMT), hl
	pop hl
	ld (LOPLN), hl
	pop hl
	ld (LOPPT), hl
PP1:	push bc		; BC = Return addr.
	ret

PUSHA:	ld hl, STKLMT	; *** PUSHA ***
	call CHGSGN
	pop bc		; BC=Return address
	add hl, sp	; Is stack near the top?
	jp nc, QSORRY	; Yes, sorry for that.
	ld hl, (LOPVAR)	; else save loop vars.
	ld a, h		; But if lopvar is 0
	or l  		; that will be all
	jr z, PU1
	ld hl, (LOPPT)	; Else, more to save
	push hl
	ld hl, (LOPLN)
	push hl
	ld hl, (LOPLMT)
	push hl
	ld hl, (LOPINC)
	push hl
	ld hl, (LOPVAR)
PU1:	push hl
	push bc		; BC = return addr
	ret

	endif

LOCR:	ld hl, (TXTUNF)
	dec hl
	dec hl
	ret

; *
; *********************************************************************
; *
; * *** PRTSTG *** QTSTG *** PRTNUM *** & PRTLN ***
; *
; * "PRTSTG" prints a string pointed by DE. It stops printing and
; * returns to caller when either a CR is printed or when the next byte
; * is zero. Reg A and B are changed. Reg DE points to what follows
; * the CR or to the zero.
; *
; * "QTSTG" looks for up-arrow, single quote, or double quote. If none
; * of these, return to caller. If up-arrow, output a control
; * character. If single or double quote, print the string in hte quote
; * and demands a matching unquote. After the printing the next 3 bytes
; * of the caller is skipped over (Ususally a jump instruction).
; *
; * "PRTNUM" prints the number in HL. Leading blanks are added if
; * needed to pad the number of spaces to the number in C. However, if
; * the number of digits is larger than the # in C, all digits are
; * printed anyway. Negative sign is also printed and counted in,
; * positive sign is not.
; *
; * "PRTLN" finds a saved line, prints the line # and a space.
; *

PRTSTG:	sub a		; *** PRTSTG ***
PS1:	ld b, a		
PS2:	ld a, (de)	; get a character
	inc de		; bump pointer
	cp b		; same as old A?
	ret z		; Yes, return
	call OUTCH	; else print it
	cp '\n'		; Was it a CR?
	jr nz, PS2	; No, next
	ret    		; Yes, return

QTSTG:	TSTC '"', QT3	; *** QTSTG ***
	ld a, '"' 	; It is a "
QT1:	call PS1	; Print until another
QT2:	cp '\n'		; Was last one a CR?
	pop hl		; Return address
	jp z, RUNNXL	; Was CR, run next line
	inc hl		; Skip 3 bytes on return
	inc hl
	inc hl
	jp (hl)		; return
QT3:	TSTC $27, QT4	; Is it a '?
	ld a, $27 	; Yes, do same
	jr QT1		; as in "
QT4:	TSTC $5e, QT5	; Is it an up-arrow?
	ld a, (de)	; Yes, convert character
	xor $40		; To control-Ch
	call OUTCH
	ld a, (de)	; Just in case it is a CR
	inc de
	jr QT2
QT5:	ret		; None of above

PRTCHS:	ld a, e
	cp b
	ret z
	ld a, (de)
	call OUTCH
	inc de
	jr PRTCHS

PRTNUM:	ds 0		; *** PRTNUM ***
PN3:	ld b, 0		; B=Sign
	call CHKSGN	; Check Sign
	jp p, PN4	; No sign
	ld b, '-'	; B=Sign
	dec c 		; '-' takes space
PN4:	push de
	ld de, 10	; Decimal
	push de		; Save as a flag
	dec c		; C=Spaces
	push bc		; Save sign & space
PN5:	call DIVIDE	; Divide HL by 10
	ld a, b		; result 0?
	or c
	jr z, PN6	; Yes, we got all
	ex (sp), hl	; No, save reminder
	dec l	 	; and count space
	push hl		; HL is old BC
	ld h, b		; move result to BC
	ld l, c		;
	jr PN5		; and dividy by 10
PN6:	pop bc		; We got all digits in
PN7:	dec c		; the stack
	ld a, c		; Look at space count
	or a
	jp m, PN8	; No leading blanks
	ld a, ' '	; Leading blanks
	call OUTCH
	jr PN7		; More?
PN8:	ld a, b		; Print sign
	or a  		;
	call nz, OUTCH	; Maybe - or null
	ld e, l	 	; Last remainder in E
PN9:	ld a, e		; Check digit in E
	cp 10 		; 10 is flag for no more
	pop de
	ret z		; If so, return
	add '0'		; Else convert to ASCII
	call OUTCH	; and print the digit
	jr PN9		; Go back for more

PRTLN:	ld a, (de)	; *** PRTLN ***
	ld l, a		; Low order line #
	inc de
	ld a, (de)	; High order
	ld h, a
	inc de
	ld c, 4		; Print 4 digit line #
	call PRTNUM
	ld a, ' '	; Followed by a blank
	call OUTCH
	ret

TAB1:	db "LIST" : dwa LIST	; Direct Commands
	db "NEW" : dwa NEW
	db "RUN" : dwa RUN

TAB2:
;	db "NEXT" : dwa NEXT	; Direct/Statement
	db "LET" : dwa LET
	db "IF" : dwa IFF
	db "GOTO" : dwa GOTO
;	db "GOSUB" : dwa GOSUB
;	db "RETURN" : dwa RETURN
	db "REM" : dwa REM
;	db "FOR" : dwa FOR
	db "INPUT" : dwa INPUT
	db "PRINT" : dwa PRINT
	db "STOP" : dwa STOP
	db 0 : dwa MOREC

MOREC:	jp DEFLT		; *** JMP USER-COMMAND ***

TAB3:	db "RND" : dwa RND		; Functions
	db "ABS" : dwa ABS
	db "SIZE" : dwa SIZE
	db 0 : dwa MOREF
MOREF:	jp NOTF			; *** JMP USER-FUNCTION ***

TAB4:
;	db "TO" : dwa FR1		; "FOR" command
;	db 0 : dwa QWHAT
TAB5:
;	db "STEP" : dwa FR2	; "FOR" command
;	db 0 : dwa FR3

TAB6:	db ">=" : dwa XPR1		; Relation operators
	db "#" : dwa XPR2
	db ">" : dwa XPR3
	db "=" : dwa XPR5
	db "<=" : dwa XPR4
	db "<" : dwa XPR6
	db 0 : dwa XPR7
RANEND:	EQU $


; *
; *********************************************************************
; *
; * *** Input Output Routines ***
; *
; * User must varify and/or modify these routines
; *********************************************************************
; *
; * *** CRLF *** OUTCH ***
; *
; * "CRLF" will output a CR. Only A & flags may change at return
; *
; * "OUTCH" will output the character in A. If the character is CR, it
; * will also output a LF and three nulls. Flags may change at return,
; * other registers do not.
; *
; * *** CHKIO *** GETLN ***
; *
; * "CHECKIO" checks to see if there is any input. If no input, it
; * returns with Z flag. If there is input, it further checks whether
; * input is CONTROL-C. If not CONTROL-C, it returns the character in A
; * with Z flag cleared. If input is CONTROL.C, CHKIO jumps to "INIT"
; * and will not return. Only A & flags may change at return.
; *
; * "GETLN" reads a input line into "BUFFER". It first prompt the 
; * character in A (given by the caller), then it fills the buffer
; * and echos. Back-space is used to delete the last character (if there
; * is one). CR signals the end of the line, and cause "GETLN" to
; * return. When buffer is full, "GETLN" will accept back-space or CR
; * only and will ignore (and will not echo) other characters. After
; * the input line is stored in the buffer, two more bytes of FF are
; * also stored and DE points to the last FF. A & flags are also 
; * changed at return.
; *
; *

CRLF:	ld a, '\n'	; CR in A
OUTCH:	push hl
	push af
	call VD_OUT
	pop af
	pop hl
	ret
	
CHKIO:	call KD_POLL_CHAR
	ret nc		; Return if nothing came out
	xor a  		; No, nothing exists, set Zero flag
	ret

GETLN:	ret


; ***********************************************************
; Title:	Setup the keyboard input
; Name: 	KD_CONFIGURE
; Purpose:	Configure and setup all variables
; 		used by the keyboard serial port.
;
; Entry:	If setting up for interrupts:
; 		   Register A = INT vector
;		else
;		   Register A = 0
; Exit:		None
;
; Registers used:      A
; ***********************************************************

KD_CONFIGURE:
	; Channel reset
	ld a, KD_WR0_REG0 | KD_WR0_CMD_CHNL_RST
	out (SIOCMDB), a
	; Ptr 4. Reset Ext/Status interrupts
	ld a, KD_WR0_REG4 | KD_WR0_CMD_RST_EXT_STS_INTS
	out (SIOCMDB), a
	; x1 Clock mode, Async,1 stop bit, odd partity
	ld a, KD_WR4_CLK_X1 | KD_WR4_STP_1 | KD_WR4_PRT_ODD | KD_WR4_PRT_EN
	out (SIOCMDB), a
	; Pointer 3
	ld a, KD_WR0_REG3
	out (SIOCMDB), a
	; Rx 8 bits, no auto enable, Rx enable
	ld a, KD_WR3_RX_8BITS | KD_WR3_RX_EN
	out (SIOCMDB), a
	; Pointer 5
	ld a, KD_WR0_REG5
	out (SIOCMDB), a
	; 8 bits, Tx not enabled
	ld a, KD_WR5_TX_8BITS
	out (SIOCMDB), a
	; Pointer 1, Reset Ext/Status ints
	ld a, KD_WR0_REG1 | KD_WR0_CMD_RST_EXT_STS_INTS
	out (SIOCMDB), a
	; Receive interrupts On First Char only
	ld a, KD_WR1_RX_INT_DIS		; Default to disabled
	out (SIOCMDB), a

	; Initialize the keyboard input buffer
	xor a
	ld (KB_PS2_STATE), a
	ld (KB_PS2_COUNT), a
	ret


; ***********************************************************
; Title:	Poll the keyboard ASCII char
; Name: 	KD_POLL_CHAR
; Purpose:	Checks if there are any thing inbound from
; 		the keyboard, and if there is it returns it.
; Entry:	None
; Exit:		If there are keys available:
; 		   Register A = value
;		   Carry flag = 0
;		else
;		   Carry flag = 1
;
; Registers used:      A
; ***********************************************************
KD_POLL_CHAR:
	in a, (SIOCMDB)
	and KD_RD0_DATA_AV	; Check if data is available
	ret z
	in a, (SIODATAB)	; Read data
	call KD_CONVERT
	ret

; ***********************************************************
; Title:	Convert Scan Codes to ASCII
; Name: 	KD_CONVERT
; Purpose:	Converts PS/2 Scan Codes Set 2 to ASCII chars
;
; Entry:	Scan Code in Register A
; Exit:		If the code can be converted
; 		   Register A = ASCII
;		   Carry flag = 0
;		else
;		   Carry flag = 1
;
; Registers used:      A
; ***********************************************************
KD_CONVERT:
	push de
	push hl
	ld e, a			; Save A for later
	ld a, (KB_PS2_STATE)
	ld d, a
	ld a, e
	
	ld hl, KB_PS2_COUNT	; Increase counter
	inc (hl)

	and $e0			; Test for longer sequences (two top bits)
	cp $e0
	jr nz, .test_value	; Jump if this may be a character

	ld a, e
	cp $F0			; Test for Break
	jr nz, .test_extended	; Jump if this is not a Break

	ld a, KD_STATE_BREAK
	or d
	ld d, a
	jr .done

.test_extended:
	cp $E0			; Test for Extended
	jr nz, .test_pause	; Jump if this is not a Extended

	ld a, KD_STATE_EXTENDED
	or d
	ld d, a
	jr .done

.test_pause:
	cp $E1			; Test for Extended
	jr nz, .reset_flags	; Jump if this is not a Extended

	ld a, KD_STATE_PAUSE
	or d
	ld d, a
	jr .done

.test_value:
	ld a, d			; Fetch STATE
	and KD_STATE_PAUSE	; Test Pause flag
	jr z, .test_break_set	; Jump if we're not in a Pause seq


	ld a, (KB_PS2_COUNT)
	and $8			; Check if we're at the end of the pause seq
	jr nz, .reset_flags	; Reset flags and count

	jr .done		; We're not in the end, just continue

.test_break_set:
	ld a, d
	and KD_STATE_BREAK
	jr z, .test_ext_set
	
	ld a, e
	cp $7c
	jr nz, .reset_flags

	jr .done

.test_ext_set:
	ld a, d
	and KD_STATE_EXTENDED
	jr z, .lookup

	ld a, e
	cp $12
	jr nz, .reset_flags
	
	jr .done

.lookup:
	ld a, e
	cp $5f
	jp p, .reset_flags

	ld d, 0
	ld hl, KD_SCANCODES
	add hl, de

	ld a, (hl)
	or a
	jr z, .reset_flags
	jr .all_done

.reset_flags:
	xor a
	ld d, a
	ld (KB_PS2_COUNT), a
.done:
	ld a, d
	ld (KB_PS2_STATE), a
	scf
.all_done:
	pop hl
	pop de
	ret

KD_SCANCODES:	; Scan Code set 2


	byte 0, 0, 0, 0, 0, 0, 0, 0
	byte 0, 0, 0, 0, 0, 0, '`', 0
	byte 0, 0, 0, 0, 0, 'Q', '1', 0
	byte 0, 0, 'Z', 'S', 'A', 'W', '2', 0
	byte 0, 'C', 'X', 'D', 'E', '4', '3', 0
	byte 0, ' ', 'V', 'F', 'T', 'R', '5', 0
	byte 0, 'N', 'B', 'H', 'G', 'Y', '6', 0
	byte 0, 0, 'M', 'J', 'U', '7', '8', 0
	byte 0, ',', 'K', 'I', 'O', '0', '9', 0
	byte 0, '.', '/', 'L', ';', 'P', '-', 0
	byte 0, 0, 0, 0, '[', '=', 0, 0
	byte 0, 0, '\n', ']', 0, '\\', 0, 0

KD_SCANCODES_LEN:    equ $ - KD_SCANCODES

KD_STATE_BREAK			= %10000000
KD_STATE_EXTENDED		= %01000000
KD_STATE_PAUSE			= %00100000
KD_STATE_CAPS			= %00010000
KD_STATE_NUM			= %00001000
KD_STATE_CTRL			= %00000100
KD_STATE_ALT			= %00000010
KD_STATE_SHIFT			= %00000001



KD_RD0_BREAK			= %10000000
KD_RD0_UNDERUN_EOM		= %01000000
KD_RD0_CTS			= %00100000
KD_RD0_SYNC_HUNT		= %00010000
KD_RD0_DCD			= %00001000
KD_RD0_TX_EMPTY			= %00000100
KD_RD0_INT_PEND			= %00000010
KD_RD0_DATA_AV			= %00000001

KD_WR0_REG0			= %00000000
KD_WR0_REG1 			= %00000001
KD_WR0_REG2 			= %00000010
KD_WR0_REG3 			= %00000011
KD_WR0_REG4 			= %00000100
KD_WR0_REG5 			= %00000101
KD_WR0_REG6 			= %00000110
KD_WR0_REG7 			= %00000111

KD_WR0_CMD_NULL			= %00000000
KD_WR0_CMD_ABORT 		= %00001000
KD_WR0_CMD_RST_EXT_STS_INTS	= %00010000
KD_WR0_CMD_CHNL_RST 		= %00011000
KD_WR0_CMD_EN_INT_NXT_RX_CHR 	= %00100000
KD_WR0_CMD_RST_TX_INT 		= %00101000
KD_WR0_CMD_ERR_RST 		= %00110000
KD_WR0_CMD_RTN_FRM_INT 		= %00111000

KD_WR0_CRC_NULL			= %00000000

KD_WR1_WR_EN			= %00000000
KD_WR1_WR_FUNC			= %01000000
KD_WR1_WR_ON_RT			= %00100000

KD_WR1_RX_INT_DIS		= %00000000
KD_WR1_RX_INT_FIRST		= %00001000
KD_WR1_RX_INT_ALL_PRT		= %00010000
KD_WR1_RX_INT_ALL		= %00011000

KD_WR1_ST_AFF_INT_VEC		= %00000100
KD_WR1_TX_INT			= %00000010
KD_WR1_EXT_INT			= %00000001


KD_WR3_RX_5BITS			= %00000000
KD_WR3_RX_7BITS			= %01000000
KD_WR3_RX_6BITS			= %10000000
KD_WR3_RX_8BITS			= %11000000

KD_WR3_AUTO_EN			= %00100000
KD_WR3_HUNT			= %00010000
KD_WR3_RX_CRC			= %00001000
KD_WR3_ADDR_SRC_SDLC		= %00000100
KD_WR3_SNC_CHAR_L		= %00000010
KD_WR3_RX_EN			= %00000001

KD_WR4_CLK_X1			= %00000000
KD_WR4_CLK_X16			= %01000000
KD_WR4_CLK_X32			= %10000000
KD_WR4_CLK_X64			= %11000000

KD_WR4_SNC_8B			= %00000000
KD_WR4_SNC_16B			= %00010000
KD_WR4_SNC_SDLC			= %00100000
KD_WR4_SNC_EXT			= %00110000

KD_WR4_SNC_EN			= %00000000
KD_WR4_STP_1			= %00000100
KD_WR4_STP_15			= %00001000
KD_WR4_STP_2			= %00001100

KD_WR4_PRT_ODD			= %00000000
KD_WR4_PRT_EVEN			= %00000010

KD_WR4_PRT_EN			= %00000001

KD_WR5_DTR			= %10000000

KD_WR5_TX_5BITS			= %00000000
KD_WR5_TX_7BITS			= %00100000
KD_WR5_TX_6BITS			= %01000000
KD_WR5_TX_8BITS			= %01100000

KD_WR5_SND_BRK			= %00010000
KD_WR5_TX_EN			= %00001000
KD_WR5_SDLC_CRC16		= %00000100
KD_WR5_RTS			= %00000010
KD_WR5_TX_CRC			= %00000001


; ***********************************************************
; Title:	Initialize and configure the video card
; Name: 	VD_CONFIGURE
; Purpose:	Configures the video card with the settings
; 		that will be used.
; Entry:	None
; 		
; Exit:		None
; Registers used:	 A, BC, HL
; ***********************************************************
VD_CONFIGURE:
	ld hl, VD_INIT_TBL
	ld b, 16
	ld c, 0

.loop:
	ld a, c
	out (VADDRPORT), a
	ld a, (hl)
	out (VDATAPORT), a
	inc hl
	inc c
	djnz .loop

	; 4. Set all video variables in memory
	xor a
	ld (CURSOR_COL), a
	ld (CURSOR_ROW), a
	call VD_UPDATE_CURSOR
.done:
	ret

; ***********************************************************
; Title:	Outputs 1 byte to the video card
; Name: 	VD_OUT
; Purpose:	Prints one character to the video card
; 		at the location of the cursor. Also
;		changes the location of the cursor.
; Entry:	Register A = Char to output
; Exit:		None
; Registers used:	 A, HL
; ***********************************************************
VD_OUT:
	cp '\n'			; Check for newline
	jr z, .eol
	
	push de
	push bc
	call VD_GET_CURSOR_ADDR	; Get the cursor address
	ld de, VRAMBEG		; Get the base memory for vram
	add hl, de		; Get the memory for the new char
	ld (hl), a		; Output char

	ld b, 0	 		; Move the cursor one step to the right
	ld c, 1
	call VD_MOVE_CURSOR_REL
	call VD_UPDATE_CURSOR
	pop bc
	pop de
	ret

.eol
	xor a
	ld (CURSOR_COL), a
	ld a, (CURSOR_ROW)
	inc a
.check_row_overflow:
	cp VIDEO_ROWS
	jp m, .row_done
	sub VIDEO_ROWS
;	jr .check_row_overflow
.row_done:
	ld (CURSOR_ROW), a		; Save CURSOR_ROW
	ret

; ***********************************************************
; Title:	Move cursor relative
; Name: 	MOVE_CURSOR_REL
; Purpose:	Move the cursor relative to the
; 		current position.
;
;		!! Doesn't update the cursor in the video chip !!
;
; Entry:	Register b = row delta
; 		Register c = columns delta
; Exit:		Cursor has been moved, and variables updated.
; Registers used:      A, BC
; ***********************************************************
VD_MOVE_CURSOR_REL:
; Update and adjust the rows and columns
  	; Columns
	ld a, (CURSOR_COL)
	add c
	jp p, .check_col_overflow
				; We had a column move
	       			; ending in the previous line
	dec b
	add VIDEO_COLUMNS	; Adjust column

.check_col_overflow:
	cp VIDEO_COLUMNS
	jp m, .col_done
	inc b
	sub VIDEO_COLUMNS
	jr .check_col_overflow
.col_done:
	ld (CURSOR_COL), a		; Save CURSOR_COL

	; Rows
	ld a, (CURSOR_ROW)
	add b
	jp p, .check_row_overflow

	add VIDEO_ROWS

.check_row_overflow:
	cp VIDEO_ROWS
	jp m, .row_done
	sub VIDEO_ROWS
	jr .check_row_overflow
.row_done:
	ld (CURSOR_ROW), a		; Save CURSOR_ROW
	ret

; ***********************************************************
; Title:	Update cursor position on screen
; Name: 	UPDATE_CURSOR
; Purpose:	Update the cursor from the two memory position
; 		describing it's position, CURSOR_COL, CURSOR_ROW.
; Entry:	None
; Exit:		None
; Registers used:      None
; ***********************************************************
VD_UPDATE_CURSOR:
	push hl
	push de
	push bc
	push af
; Set the actual cursor to the correct location

	ld hl, CURSOR_ROW
	ld b, (hl)
	ld hl, CURSOR_COL
	ld c, (hl)

      	ld hl, 0
	ld de, VIDEO_COLUMNS
	
	ld a, 0
	or b
	jr z, .loop_done
.loop:
	add hl, de
	djnz .loop
.loop_done:
	add hl, bc

; Output the cursor location to the video chip
  	ld a, 14   ; Register 14
	out (VADDRPORT), a
	ld a, h
	out (VDATAPORT), a

	ld a, 15   ; Register 15
	out (VADDRPORT), a
	ld a, l
	out (VDATAPORT), a
	 
	pop af
	pop bc
	pop de
	pop hl
	ret

; ***********************************************************
; Title:	Get Cursor Memory Address
; Name:		GET_CURSOR_ADDR
; Purpose:	Calculate the base address for the cursor
; 		given it's current row and column.
; Entry:	Nothing
; Exit:		Register HL = Base address for cursor
; Registers used:	 HL
; ***********************************************************

VD_GET_CURSOR_ADDR:
	push bc
	push de
	ld hl, CURSOR_ROW
	ld b, (hl)
	ld hl, CURSOR_COL
	ld c, (hl)
				; Calculate memory location of cursor
	ld hl, 0

	ld e, a			; Store a
	xor a
	or b
	ld a, e
	ld de, 80
	jr z, .loop_done

.loop:
	add hl, de
	djnz .loop
.loop_done:
	add hl, bc
	pop de
	pop bc
	ret


VD_INIT_TBL:
	db $64, $50 ; Horizontal Total, Horizontal Displayed
	db $52, $0c ; Horizontal Sync Pos, Sync Width
	db $1f, $0c ; Vertical Total, Vertical Total Adjust
	db $1e, $1f ; Vertical Displayed, Vertical Sync Position
	db $00, $0f ; Interlace Mode, Maximum Scan Line Address
	db $47, $0f ; Cursor start + mode, Cursor end
	db $00, $00 ; Memory Start offset high, low
	db $00, $00 ; Cursor address high, low

	org $07fe
	word $0000
	end