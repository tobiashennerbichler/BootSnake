org 0x7C00

VGA_MODE	equ	0x0013 ; Set VGA_VIDEO_MODE to 320x200, 256 colors
VIDEO_MEMORY	equ	0xA000 ; Segment video memory address
SCREEN_WIDTH	equ	320
SCREEN_HEIGHT	equ	200
COLOR_RED	equ	0x4
COUNT_ADDR	equ	0x8000

; Set Video mode
;mov ax, VGA_MODE
;int 0x10

; Setup ES with video memory address: TODO
push 0
pop es
; Setup DS to 0 since origin is already 0x7C00
push 0
pop ds
cld

check_keystroke:
	; check for keystroke (non-blocking)
	mov ah, 1
	int 0x16
	jnz check_keystroke ; should be jz but for some reason jnz makes input read smoother
	; get keystroke
	mov ah, 0
	int 0x16
	; store al (ascii keystroke) in msg
	mov di, msg+17
	stosb

print_msg:
	mov si, msg
	.loop:
		lodsb
		test al, al
		jz check_keystroke
		mov ah, 0x0E
		mov bh, 0
		int 0x10
		jmp .loop

;wait_some_ticks:
;	mov ah, 0
;	int 0x1A
;	mov bx, dx
;	add bx, 2 ; num ticks to wait
;	.wait:
;		int 0x1A
;		cmp dx, bx
;		jl .wait
;	ret

halt:
	hlt

msg db "Found keystroke: ", 0, 0xa, 0

times 510-($-$$) db 0
dw 0xAA55
