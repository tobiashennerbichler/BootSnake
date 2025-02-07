.PHONY: all run

all:
	nasm -f bin snake.S -o snake.bin

run:
	qemu-system-i386 -drive file=snake.bin,format=raw

floppy:
	head -c 1474560 /dev/zero > boot.vfd
	dd status=noxfer conv=notrunc if=snake.bin of=boot.vfd

test: test_nasm.S
	nasm -f bin test_nasm.S -o nasm.bin
	xxd nasm.bin
