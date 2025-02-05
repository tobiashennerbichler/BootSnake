.PHONY: all run

all:
	nasm -f bin snake.S -o snake.bin

run:
	qemu-system-i386 -drive file=snake.bin,format=raw
