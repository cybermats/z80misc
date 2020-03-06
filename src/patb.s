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


; *********************************************************************
; *
; **** MEMORY USAGE***
; *
; * 0080-01FF Are for variables, input line, and stack
; * 2000-3FFF are for Tiny Basic Text & Array
; * F000-F7FF are for TBI code
; *

BOTSCR:	equ	$0080
TOPSCR: equ	$0200
BOTRAM:	equ	$2000
DFTLMT:	equ	$4000
BOTROM:	equ	$f000

; *
; * Define variables, buffer, and stack in ram
; *

	org BOTSCR
KEYWRD:	ds 1	; Was init done?
TXTLMT:	ds 2	; ->Limit CF Text Area
VARBGN:	ds 2*26	; TB Variables A-Z
CURRNT:	ds 2	; Points to current line
STKGOS:	ds 2	; Saves SP in 'GOSUB'
VARNXT:	ds 0	; Temp storage
SKTINP:	ds 2	; Saves SP in 'INPUT'
LOPVAR:	ds 2	; 'FOR' loop save area
LOPINC:	ds 2	; Increment
LOPLMT:	ds 2	; Limit
LOPLN:	ds 2	; Line number
LOPPT:	ds 2	; Text Pointer
RANPNT:	ds 2	; Random number pointer
	ds 1	; Extra byte for buffer
BUFFER:	ds 132	; Input buffer
BUFEND:	ds 0	; Buffer ends
	ds 4	; Extra bytes for stack
STKLMT:	ds 0	; Soft limit for stack

	org TOPSCR
STACK:	ds 0	; Stack starts here

	org BOTRAM
TXTUNF:	ds 2
TEXT:	ds 2

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
	jr FINISH
PR9:	call EXPR	; Evaluate the EXPR
	push bc
	call PRTNUM	; Print the value
	pop bc
	jr PR5		; More to print?



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

