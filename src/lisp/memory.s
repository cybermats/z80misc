
; ***********************************************************
; Title:	Init Workspace
; Name: 	INIT_WORKSPACE
; Purpose:	Initialize workspace and creates a memory
; 		pool for Cons'.
;		Head of the free cons is available at
;		FREELIST.
;		Count of free cons' is at FREESPACE
;
; Entry:	None
; 		
; Exit:		None
;
; Registers used:      All
; ***********************************************************
INIT_WORKSPACE:
	ld hl, WORKSPACE_END
	ld bc, (WORKSPACE_END - WORKSPACE_BEGIN) / 4
	ld (FREESPACE), bc
	ld de, 0
.loop:
	dec hl
	ld (hl), d
	dec hl
	ld (hl), e
	dec hl
	ld (hl), 0
	dec hl
	ld (hl), 0
	ld d, h
	ld e, l
	dec bc
	ld a, b
	or c
	jr nz, .loop
	ld (FREELIST), hl
	ret
	

; ***********************************************************
; Title:	Memory allocation
; Name: 	MALLOC
; Purpose:	Allocates one Cons from the free list.
;
; Entry:	None
; 		
; Exit:		If successful
; 		   Register IX = Cons
;		   Flag Z = 0
;		Else
;		   Flag Z = 1
;
; Registers used:      A, HL
; ***********************************************************
MALLOC:
	push hl
	ld hl, (FREESPACE)	; Check if we have space available
	ld a, h
	or l
	jr nz, .cont
	pop hl			; No, return with Z = 1
	ret

.cont:
	dec hl			; Decrease FREESPACE and save
	ld (FREESPACE), hl
	
	ld ix, (FREELIST)	; Load the head of the free list
	ld l, (ix + 2)		; Read the ->next
	ld h, (ix + 3)
	ld (FREELIST), hl	; Store it as the new head

	pop hl

	ret			; Z = 0 should be unaffected.
	


; ***********************************************************
; Title:	Free memory
; Name: 	FREE
; Purpose:	Frees the memory and returns it to the pool.
;
; Entry:	Register IX = Cons to be freed.
; 		
; Exit:		None
;
; Registers used:      IX
; ***********************************************************
FREE:
	; Null out the memory
	push hl

	ld (ix), 0
	ld (ix+1), 0
	ld hl, (FREELIST)
	ld (ix+2), l
	ld (ix+3), h
	ld (FREELIST), ix

	ld hl, (FREESPACE)
	inc hl
	ld (FREESPACE), hl

	pop hl
	ret
	
