#生成软盘镜像文件boot.img
boot.img: boot.asm kernel.bin loader.bin isr.bin
	nasm -o boot.img boot.asm
	sudo mkdir /mnt/floppyStalkerOS/
	sudo mount -o loop boot.img /mnt/floppyStalkerOS/
	sudo cp loader.bin kernel.bin isr.bin /mnt/floppyStalkerOS/
	sleep 1
	sudo umount /mnt/floppyStalkerOS/
	sudo rmdir /mnt/floppyStalkerOS/

#生成kernel.bin ELF可执行文件，通过链接两个目标文件
kernel.bin: kernel.o main.o setPixel.o paintChars.o
	ld -o  kernel.bin kernel.o  main.o setPixel.o paintChars.o

#loader.bin	
loader.bin:	loader.asm
	nasm -o loader.bin loader.asm
	
#isr.bin
isr.bin: isr.o isrc.o setPixel.o paintChars.o
	ld -Tdata 0x0 -o isr.bin isr.o isrc.o  setPixel.o paintChars.o
	
#isr.o
isr.o: isr.asm
	nasm -f elf -o isr.o isr.asm
	
#isrc.o
isrc.o: isrc.c
	gcc -c -o isrc.o isrc.c
	
#生成kernel.o ELF目标文件
kernel.o: kernel.asm
	nasm -f elf -o kernel.o kernel.asm

#生成main.o　ELF目标文件
main.o: main.c  
	gcc -c -o main.o main.c
	
#生成setPixel.o ELF目标文件
setPixel.o: paint/setPixel.asm
	nasm -f elf -o setPixel.o paint/setPixel.asm
	
#生成paintChars.o ELF目标文件
paintChars.o: paint/paintChars.c
	gcc -c -o paintChars.o paint/paintChars.c	
	
#工程构建完成后删除中间不需要的文件
clean:
	rm *.bin *.o