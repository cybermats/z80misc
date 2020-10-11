; US Keyboard Scan Codes Translation

KD_SCANCODES_OFFSET: equ 8
KD_SCANCODES:	; Scan Code set 2, no meta
	db 0, 0, 0, 0, 0, 0, 0, 0		; 00h Handled by OFFSET
	db 0, 0, 0, 0, 0, 0, '`', 0		; 08h
	db 0, 0, 0, 0, 0, 'q', '1', 0		; 10h
	db 0, 0, 'z', 's', 'a', 'w', '2', 0	; 18h
	db 0, 'c', 'x', 'd', 'e', '4', '3', 0	; 20h
	db 0, ' ', 'v', 'f', 't', 'r', '5', 0	; 28h
	db 0, 'n', 'b', 'h', 'g', 'y', '6', 0	; 30h
	db 0, 0, 'm', 'j', 'u', '7', '8', 0 	; 38h
	db 0, ',', 'k', 'i', 'o', '0', '9', 0	; 40h
	db 0, '.', '/', 'l', ';', 'p', '-', 0	; 48h
	db 0, 0, '\'', 0, '[', '=', 0, 0  	; 50h
	db 0, 0, '\n', ']', 0, '\\', 0, 0	; 58h
	db 0, 0, 0, 0, 0, 0, BACKSPC, 0		; 60h
KD_SCANCODES_LEN:      	  equ ($ - KD_SCANCODES) + KD_SCANCODES_OFFSET

KD_SCANCODES_SHIFT:	; Scan Code set 2, shift
	IF 0
	db 0, 0, 0, 0, 0, 0, 0, 0		; 00h Handled by OFFSET
	db 0, 0, 0, 0, 0, 0, '~', 0		; 08h
	db 0, 0, 0, 0, 0, 'Q', '!', 0		; 10h
	db 0, 0, 'Z', 'S', 'A', 'W', '@', 0	; 18h
	db 0, 'C', 'X', 'D', 'E', '$', '#', 0	; 20h
	db 0, ' ', 'V', 'F', 'T', 'R', '%', 0	; 28h
	db 0, 'N', 'B', 'H', 'G', 'Y', '^', 0	; 30h
	db 0, 0, 'M', 'J', 'U', '&', '*', 0 	; 38h
	db 0, '<', 'K', 'I', 'O', ')', '(', 0	; 40h
	db 0, '>', '?', 'L', ':', 'P', '_', 0	; 48h
	db 0, 0, '"', 0, '{', '+', 0, 0  	; 50h "
	db 0, 0, '\n', '}', 0, '|', 0, 0	; 58h
	db 0, 0, 0, 0, 0, 0, 08h, 0  		; 60h
	ENDIF
KD_SCANCODES_SHIFT_LEN:   equ ($ - KD_SCANCODES_SHIFT) + KD_SCANCODES_OFFSET

KD_SCANCODES_CTRL:	; Scan Code set 2, Ctrl
	if 0
	db 0, 0, 0, 0, 0, 0, 0, 0		; 00h Handled by OFFSET
	db 0, 0, 0, 0, 0, 0, 0, 0		; 08h
	db 0, 0, 0, 0, 0, 11h, 0, 0		; 10h
	db 0, 0, 1ah, 13h, 01h, 17h, 0, 0	; 18h
	db 0, 03h, 18h, 04h, 05h, 1ch, 1bh, 0	; 20h
	db 0, 0, 16h, 06h, 14h, 12h, 1dh, 0	; 28h
	db 0, 0eh, 02h, 08h, 07h, 19h, 1eh, 0	; 30h
	db 0, 0, 0dh, 0ah, 15h, 1fh, 7fh, 0 	; 38h
	db 0, 0, 0bh, 09h, 0fh, 0, 0, 0	; 40h
	db 0, 0, 0, 12h, 0, 10h, 0, 0	; 48h
	db 0, 0, 0, 0, 0, 0, 0, 0  	; 50h "
	db 0, 0, 0, 0, 0, 0, 0, 0	; 58h
	db 0, 0, 0, 0, 0, 0, 08h, 0  		; 60h
	endif
KD_SCANCODES_CTRL_LEN:    equ ($ - KD_SCANCODES_CTRL) + KD_SCANCODES_OFFSET

