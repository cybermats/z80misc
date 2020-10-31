STRUC_COUNT	set 0
STRUC_5 	set 0
STRUC_4 	set 0
STRUC_3 	set 0
STRUC_2 	set 0
STRUC_TOP 	set 0

STRUC_PUSH	macro arg
STRUC_COUNT set STRUC_COUNT + 1

STRUC_5 set STRUC_4	
STRUC_4 set STRUC_3
STRUC_3 set STRUC_2
STRUC_2 set STRUC_TOP
STRUC_TOP set arg
	endm

STRUC_POP:	macro
STRUC_COUNT set STRUC_COUNT - 1

STRUC_TOP set STRUC_2
STRUC_2 set STRUC_3
STRUC_3 set STRUC_4
STRUC_4 set STRUC_5
STRUC_5 set 0
	endm

JUMP_FWD:	macro
CUR_ADR set $
	org STRUC_TOP - 2
	dw CUR_ADR
	org CUR_ADR
	endm

_if:	macro flag
	jr flag, if_label
	jp $	 ; placeholder jump to _else or _endif
	STRUC_PUSH $
if_label:
	endm

_else:	macro
	jp $	; Placeholder jump to _endif
	JUMP_FWD
	STRUC_TOP set $	; Reuse top of stack
	endm

_endif:	macro
	JUMP_FWD
	STRUC_POP
	endm


_switch:	macro
	jr switch_label
	jp $	; Placeholder jump to endswitch
	STRUC_PUSH $
switch_label:
	endm

_case:	macro flag
	jr flag, case_label
	jp $
	STRUC_PUSH $
case_label:
	endm

_endcase:	macro
	jp STRUC_2 - 3 ; jump to placeholder jump to endswitch
	JUMP_FWD
	STRUC_POP
	endm

_endswitch:	macro
	JUMP_FWD
	STRUC_POP
	endm
