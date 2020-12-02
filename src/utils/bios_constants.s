; Addresses
BIOS:		equ	0003h
LOAD_ADDR: 	equ 	8000h

VRAMBEG:	equ	007000h
VRAMEND:  	equ	007fffh


; Constants
VIDEO_COLUMNS:	equ	80
VIDEO_ROWS:	equ	30

; BIOS functions
INIT:		equ	0
CIN: 		equ 	1
CIN_NH:		equ	2
COUT:		equ 	3
COUTN:		equ 	4
CURSOR:		equ 	5


; Ports
; General port
OUTPORT:	equ	0000h

; Video ports
VADDRPORT:	equ	0080h
VDATAPORT:	equ	0081h

; Serial ports
SIODATAA:	equ	00f0h
SIODATAB: 	equ	00f1h
SIOCMDA:  	equ	00f2h
SIOCMDB:  	equ	00f3h

; SPI Ports
SPIDATA:	equ	070h
SPICTRL:	equ	071h

