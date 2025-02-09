mov bh, -1
mov bh, 1
mov bl, -1
mov bl, 1

msg db "-----"

push 0xFF00
pop bx
push 0x0100
pop bx
push 0x00FF
pop bx
push 0x0001
pop bx
