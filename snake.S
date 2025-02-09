org 0

; == CONSTANTS ===================================================================
VGA_MODE	equ	0x0013 ; Set VGA_VIDEO_MODE to 320x200, 256 colors
VIDEO_MEMORY	equ	0xA000 ; Segment video memory address
END_VIDEO_MEM	equ	0xAFA0 ; Segment end of video memory address
LFSR_BITMASK	equ	0x002D ; Bitmask defining the tapped bits for LFSR
SCREEN_WIDTH	equ	320
SCREEN_HEIGHT	equ	200
; RECT_WIDTH must be chosen to fit SCREEN_WIDTH/RECT_WIDTH into one byte
RECT_WIDTH	equ	8
RECT_HEIGHT	equ	8
WIDTH_END	equ	SCREEN_WIDTH / RECT_WIDTH
HEIGHT_END	equ	SCREEN_HEIGHT / RECT_HEIGHT

; Computing x % WIDTH_END/HEIGHT_END for the random apple location is not efficient (div) or costs
; too much space (see gcc optimizations). Since computing modulo for 2**i is easy (AND with (2**i) - 1), 
; we take the next highest power of 2 of WIDTH_END or HEIGHT_END, respectively, and subtract WIDTH_END or
; HEIGHT_END off of the end result. This does not result in exactly x % WIDTH_END/HEIGHT_END, but is still
; in its bounds in less operations. The bitmasks must be set manually when changing Width/Height.
WIDTH_BITMASK	equ	0x3F;0x7F
HEIGHT_BITMASK	equ	0x1F;0x3F

; Colors
BG_COLOR	equ	0
SNAKE_COLOR	equ	0x2F
APPLE_COLOR	equ	0x28

; Offsets into DS:
TIME		equ	0x0000 ; Stores time threshold for game ticks
LFSR		equ	0x0002 ; Stores the current lfsr state for random apple generation
DIR		equ	0x0004 ; Current snake direction (Direction: struct { u8 x_dir, u8 y_dir })
SNAKE_LEN	equ	0x0006 ; Length of snake position array
SNAKE		equ	0x0008 ; Start of snake position array (Position: struct { u8 x, u8 y })

; Offsets into ES:
TOGGLE		equ	0xF9FF
TOGGLE_RECT	equ 	0x1827
NUM_WAIT_TICKS	equ	2

; == CODE ========================================================================
jmp init
nop

init:
	; Init Stack Segment, Stack Pointer and Data Segment
	cli
	xor ax, ax
	mov ss, ax
	mov ax, 0x7C00
	mov sp, ax
	mov ds, ax
	sti

	; Set Video mode
	mov ax, VGA_MODE
	int 0x10

	; Setup ES with video memory address
	push VIDEO_MEMORY
	pop es

	; Setup DS to end of video memory
	push END_VIDEO_MEM
	pop ds

	; Initial len of snake array
	mov dx, 1
	mov [ds:SNAKE_LEN], dx
	; Initial Direction
	xor dx, dx
	mov [ds:DIR], dx
	; Initial Head Position (top left)
	mov [ds:SNAKE], dx

	cld

	; Do initial drawing of snake
	mov al, SNAKE_COLOR
	call draw_rect

	; Init LFSR state to current ticks (since midnight)
	; Cannot start at 0, otherwise only has a period of 1
	xor ah, ah
	int 0x1A
	test dx, dx
	jne .init_lfsr
	inc dx
	.init_lfsr:
	mov [ds:LFSR], dx
	call draw_new_apple

game_loop:
	mov bx, NUM_WAIT_TICKS
	call set_wait_time

	call draw_toggle		; Debug

	call get_keystroke		; in: - out: al = keystroke
	call update_direction		; in: al = keystroke, out: bx = direction
	call compute_new_head_pos	; in: bx = direction, out: dx = new head pos
	call get_color_from_pos		; in: dx = new head pos, out: bl = Color of pixel + in
	call check_game_over		; in: dx = new head pos + bl = Color of pixel, out: in

	push bx				
	call shift_parts_back		; in: -, out: ax = tail position + si = pointer to [ds:SNAKE_LEN*2]
	pop bx				
	push dx				; Preserve new head position
	push ax				; Preserve old tail position
	call wait_time			; wait before draw so drawing is always done at same speed

	; If snake eats apple, generate a new one and don't clear tail
	cmp bl, APPLE_COLOR
	jne .clear_old_tail
	pop ax
	mov [ds:si], ax
	mov cx, [ds:SNAKE_LEN]
	inc cx
	mov [ds:SNAKE_LEN], cx
	call draw_new_apple
	jmp .draw_new_head

	.clear_old_tail:
	pop dx
	xor al, al
	call draw_rect			; dx = Position, al = Color

	.draw_new_head:
	pop dx
	mov al, SNAKE_COLOR
	call draw_rect			; dx = Position, al = Color
	mov [ds:SNAKE], dx		; store new pos of head

	jmp game_loop

; TODO: print game over message
game_over:
	hlt

; Calling convention: Parameters: dx = new head Position, bl = Color of new head Position
;		      Return: -
;		      Destroys: cx, si, bp
check_game_over:
	cmp bl, SNAKE_COLOR
	jne .no_collision
	; Even if snake color, no collision if new head is old tail
	; TODO: could make exception for when len=2 (snake turns around and runs into old tail)
	; TODO: or simply disable snake from being able to turn around
	mov cx, [ds:SNAKE_LEN]
	mov si, SNAKE
	shl cx, 1
	add si, cx
	mov bp, -2[ds:si]
	cmp dx, bp
	jne game_over

	.no_collision:
	ret

; Calling convention: Parameters: 
;		      Return: si = pointer to after last snake part ([ds:SNAKE_LEN*2])
;			      ax = Position of old tail
;		      Destroys: ax, bx, cx, si
shift_parts_back:
	mov cx, [ds:SNAKE_LEN]
	mov si, SNAKE
	lodsw
	.loop:
		dec cx
		jz .loop_end
		mov bx, ax
		lodsw
		mov -2[ds:si], bx
		jmp .loop
	.loop_end:
	ret

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
		mov [ds:DIR], bx
		ret
	.read_old_dir:
		mov bx, [ds:DIR]	
		ret

; Calling convention: Parameters: bx = Direction (bl = x_dir, bh = y_dir)
;		      Return: dx = New Head Position
;		      Destroys: dx
compute_new_head_pos:
	; Compute new x pos + wrap around if necessary
	; Code duplication less space than generic method call i tested
	mov dx, [ds:SNAKE]

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
	ret

; Calling convention: Parameters: dx = Position (dl = x, dh = y)
;		      Return: bl = Color at the first index in video memory corresponding to the given position
;		      Destroys: ax, bl
get_color_from_pos:
	movzx ax, dl
	movzx bx, dh
	imul ax, RECT_WIDTH
	imul bx, RECT_HEIGHT*SCREEN_WIDTH
	add bx, ax
	mov bl, [es:bx]
	ret

; Calling convention: Parameters: bx = Ticks to wait
;		      Return: -
;		      Destroys: ah, dx, cx
set_wait_time:
	xor ah, ah
	int 0x1A
	add dx, bx
	mov [ds:TIME], dx
	ret

; Calling convention: Parameters: -
;		      Return: -
;		      Destroys: ah, cx, dx, bp
wait_time:
	xor ah, ah
	int 0x1A
	mov bp, [ds:TIME]
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
	xor al, 0xE
	mov dx, TOGGLE_RECT
	call draw_rect
	ret

; Calling convention: Parameters: -
;		      Returns: -
;		      Destroys: ax, bx, cx, dx, di
draw_new_apple:
	; bit = (lfsr ^ (lfsr >> 2) ^ (lfsr >> 3) ^ (lfsr >> 5)) << 15
	; lfsr = (lfsr >> 1) | bit
	; Implement it with popcount of tapped bits
	mov dx, [ds:LFSR]
	.advance:
		mov ax, dx
		and ax, LFSR_BITMASK
		popcnt ax, ax
		sal ax, 15
		shr dx, 1
		or dx, ax
	mov [ds:LFSR], dx

	; Restrict dh to 0..HEIGHT_END and dl to 0..WIDTH_END
	and dh, HEIGHT_BITMASK
	cmp dh, HEIGHT_END
	jl .height_ok
	sub dh, HEIGHT_END
	.height_ok:
	and dl, WIDTH_BITMASK
	cmp dl, WIDTH_END
	jl .width_ok
	sub dl, WIDTH_END
	.width_ok:

	call get_color_from_pos
	cmp bl, SNAKE_COLOR
	je draw_new_apple

	mov al, APPLE_COLOR
	call draw_rect
	ret

times 510-($-$$) db 0
dw 0xAA55
