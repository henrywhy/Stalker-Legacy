extern isrc_keyboard			;void isrc_keyboard(int scanCode)
extern isrc_mouse			;void isrc_mouse(int scanCode)
global _start


[section .text]
[bits 32]
_start:

	cli
	xor eax, eax
	in al, 0x60
	push eax
	call isrc_keyboard
	pop eax
	mov al, 0x20
	out 0xa0, al
	out 0x20, al		;告诉主8259A EOI，即当前中断处理结束，以便接受下一个中断信号
	sti
	iret
	
	cli
	xor eax, eax
	in al, 0x60
	push eax
	call isrc_mouse
	pop eax
	sti
	mov al, 0x20
	out 0xa0, al	
	out 0x20, al		;告诉主从8259A EOI，即当前中断处理结束，以便接受下一个中断信号
	iret
