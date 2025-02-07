org 0x7C00

; == CONSTANTS ===================================================================
VGA_MODE	equ	0x0013 ; Set VGA_VIDEO_MODE to 320x200, 256 colors
VIDEO_MEMORY	equ	0xA000 ; Segment video memory address
END_VIDEO_MEM	equ	0xAFA0 ; Segment end of video memory address (allows us to store more than 0xFFFF - 0xFA00 = 0x5FF snake parts)
SCREEN_WIDTH	equ	320
SCREEN_HEIGHT	equ	200
RECT_WIDTH	equ	4
RECT_HEIGHT	equ	4
WIDTH_END	equ	SCREEN_WIDTH / RECT_WIDTH
HEIGHT_END	equ	SCREEN_HEIGHT / RECT_HEIGHT
BG_COLOR	equ	0
SNAKE_COLOR	equ	0x30
TIME_OFF	equ	0x0000
DIR_OFF		equ	0x0002 ; Offset into DS for current snake direction (struct { u8 x_dir, u8 y_dir })
SNAKE_LEN_OFF	equ	0x0004 ; Offset into DS for length of snake position array
SNAKE_OFF	equ	0x0006 ; Offset into DS for start of snake position array (struct { u8 x, u8 y })
TOGGLE		equ	0xF9FF
TOGGLE_RECT	equ 	0x314F
NUM_WAIT_TICKS	equ	2

; == CODE ========================================================================
; Set Video mode
mov ax, VGA_MODE
int 0x10

; Setup ES with video memory address
push VIDEO_MEMORY
pop es

; Setup DS to end of video memory
push END_VIDEO_MEM
pop ds

; Initial Direction
xor dx, dx
mov [ds:DIR_OFF], dx
; Initial Head Position (top left)
mov [ds:SNAKE_OFF], dx
; Initial len of snake array (starts as 0)
mov [ds:SNAKE_LEN_OFF], dx
; Point stack segment to 0
mov ss, dx

cld

; Do initial drawing of snake
mov al, SNAKE_COLOR
call draw_rect
; TODO: init first apple. everytime its eaten generate new one

; TODO: apple generation
; TODO: apple eat + resize
; TODO: when moving always compute new head and store in some reg (e.g. bx), then loop through all parts - 1, everytime read next part, exchange it with prev and repeat, once we get to last part we read its value, clear it and set it to prev value (unless we ate apple, then keep last element)

game_loop:
	mov bx, NUM_WAIT_TICKS
	call set_wait_time

	call draw_toggle			; Debug

	call get_keystroke			; al = keystroke
	call update_direction			; bx = direction
	.compute_newpos:
		mov dx, [ds:SNAKE_OFF]

		; Compute new x pos + wrap around if necessary
		; Code duplication less space than generic method call i tested
		add dl, bl
		jns .not_neg
		add dl, WIDTH_END
		.not_neg:
		cmp dl, WIDTH_END
		jne .not_eq
		xor dl, dl
		.not_eq:

		; Compute new y pos + wrap around if necessary
		add dh, bh
		jns .not_neg2
		add dh, HEIGHT_END
		.not_neg2:
		cmp dh, HEIGHT_END
		jne .not_eq2
		xor dh, dh
		.not_eq2:

		push dx
		call wait_time
		pop dx

		; draw new head
		mov al, SNAKE_COLOR
		call draw_rect			; dx = Position, al = Color
		mov [ds:SNAKE_OFF], dx		; store new pos of head
		jmp game_loop

; Calling convention: Parameters: dx = Position (dl=x, dh=y)
;		      		  al = Color
;		      Return: -
;		      Destroys: di, bx, cx
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

; Calling convention: Parameters: -
;		      Return: al = ASCII keystroke
;		      Destroys: ax
get_keystroke:
	; check for keystroke (non-blocking)
	mov ah, 1
	int 0x16
	jz .no_keystroke
	.keystroke:
		; get ascii keystroke into al
		xor ah, ah
		int 0x16
		ret
	.no_keystroke:
		; reset al
		xor al, al
		ret

; Calling convention: Parameters: al = ASCII keystroke
;		      Return: bx = direction
;		      Destroys: bx
update_direction:
	xor bx, bx			; bh = y_dir, bl = x_dir
	cmp al, 'w'
	je .w
	cmp al, 's'
	je .s
	cmp al, 'a'
	je .a
	cmp al, 'd'
	je .d
	jmp .read_old_dir		; not one of 'wasd'
	.w:
		mov bh, -1
		jmp .update_dir
	.s:
		mov bh, 1
		jmp .update_dir
	.a:
		mov bl, -1
		jmp .update_dir
	.d:
		mov bl, 1
	.update_dir:
		mov [ds:DIR_OFF], bx
		ret
	.read_old_dir:
		mov bx, [ds:DIR_OFF]
		ret

; Calling convention: Parameters: bx = Ticks to wait
;		      Return: -
;		      Destroys: ah, dx, cx
set_wait_time:
	xor ah, ah
	int 0x1A
	add dx, bx
	mov [ds:TIME_OFF], dx
	ret

; Calling convention: Parameters: -
;		      Return: -
;		      Destroys: ah, cx, dx, bp
wait_time:
	xor ah, ah
	int 0x1A
	mov bp, [ds:TIME_OFF]
	.wait:
		int 0x1A
		cmp dx, bp
		jl .wait
	ret

; Calling convention: Parameters: -
;		      Returns: -
;		      Destroys: al, dx, di, bx, cx
draw_toggle:
	mov al, [es:TOGGLE]
	xor al, 1
	mov dx, TOGGLE_RECT
	call draw_rect
	ret

times 510-($-$$) db 0
dw 0xAA55
