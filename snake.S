org 0x7C00

VGA_MODE	equ	0x0013 ; Set VGA_VIDEO_MODE to 320x200, 256 colors
VIDEO_MEMORY	equ	0xA000 ; Segment video memory address
SCREEN_WIDTH	equ	320
SCREEN_HEIGHT	equ	200
SNAKE_COLOR	equ	0x30
POSITION_INDEX	equ	0xFA00 ; Index into ES (0xAFA00 - after video memory), Position: struct { uint8_t x, uint8_t y }
RECT_WIDTH	equ	4
RECT_HEIGHT	equ	4

; Set Video mode
mov ax, VGA_MODE
int 0x10
; Setup ES with video memory address
push VIDEO_MEMORY
pop es
; Setup DS to 0 since origin is already 0x7C00
push 0
pop ds
; Setup Position struct
mov ax, 0x1414
mov [es:POSITION_INDEX], ax
cld

game_loop:
	.check_keystroke:
		; check for keystroke (non-blocking)
		mov ah, 1
		int 0x16
		jnz .check_keystroke ; should be jz but for some reason jnz makes input read smoother
		; get ascii keystroke into al
		mov ah, 0
		int 0x16
	.read_pos:
		mov dx, [es:POSITION_INDEX]	; read Position
		mov al, SNAKE_COLOR			
		call draw_rect
		jmp .check_keystroke

; Calling convention: dx = Position (dl=x, dh=y)
;		      al = Color
draw_rect:
	movzx di, dl		    		; x
	movzx bx, dh		    		; y
	imul di, RECT_WIDTH			; x = x * RECT_WIDTH
	imul bx, RECT_HEIGHT*SCREEN_WIDTH 	; y = y * RECT_HEIGHT * SCREEN_WIDTH
	add di, bx				; di = di + y
	xor bx, bx				; i = 0
	.loop:
		mov cx, RECT_WIDTH
		rep stosb			; for cx in 0..RECT_WIDTH: [es:di+cx] = 0x4
		inc bx
		add di, SCREEN_WIDTH-RECT_WIDTH ; go to next line
		cmp bx, RECT_HEIGHT		; Assumes that RECT_HEIGHT is at least 1
		jl .loop
	ret


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

times 510-($-$$) db 0
dw 0xAA55
