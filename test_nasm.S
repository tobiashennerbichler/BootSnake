mov al, dl
mov cl, 5
call wrap_around_if
mov dl, al

mov al, dh
mov bl, bh
mov cl, 5
call wrap_around_if
mov dh, al

wrap_around_if:
	add al, bl
	jns .not_neg
	add al, cl
	.not_neg:
	cmp al, cl
	jne .not_eq
	xor al, al
	.not_eq:
	ret

msg db "-----"

add al, bl
jns .not_neg
add dl, 5
.not_neg:
cmp dl, 5
jne .not_eq
xor al, al
.not_eq:

add dh, bh
jns .not_neg2
add dh, 5
.not_neg2:
cmp dh, 5
jne .not_eq2
xor dh, dh
.not_eq2:

