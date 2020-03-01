; Constants for the cyber80 project


; Memory map
ROMBEG:		.equ	$0000
ROMEND:		.equ	$07ff
VRAMBEG:	.equ	$7000
VRAMEND:  	.equ	$7fff
RAMBEG:	  	.equ	$8000
RAMEND:	  	.equ	$ffff

; Ports
; General port
OUTPORT:	.equ	$00

; Video ports
VADDRPORT:	.equ	$80
VDATAPORT:	.equ	$81

; Serial ports
SIODATAA:	.equ	$f0
SIODATAB: 	.equ	$f1
SIOCMDA:  	.equ	$f2
SIOCMDB:  	.equ	$f3



; Memory Locations
VARBEG:		.equ	$fd00
STACK_START:	.equ	$fdff	; This gives $100 bytes for variables

DVLST:		.equ	$fe00	; Device list has $100 bytes, each taking 17 bytes, i.e. 10 devices
DVTE:		.equ	$fe02	; Device Table Entry memory pool

CURSOR_COL:	.equ	$ff00
CURSOR_ROW:	.equ	$ff01
VIDEO_STATUS:	.equ	$ff02


; Devices
VIDEO_DVC:	.equ	$01
KEYBOARD_DVC:	.equ	$02



; Misc consts