ORG 8000H
	BaseOfKernel EQU 4000H
	OffsetOfKernel EQU 0000H
	BaseOfISR EQU 8000H
	OffsetOfISR EQU 0000H
	
	BaseOfStack	EQU	07c00h
	SectorNoOfRootDirectory	EQU 19		;19号扇区为root目录的起始扇区
	MaxSectorNoOfRootDir    EQU 32		;32号扇区为root目录的终止扇区
	SPT EQU 18		;每个磁道18个扇区
	HPC EQU 2		;每个柱面两个磁头

	FirstSectorOfFat1 EQU 1
	BaseOfFat1 EQU 1000H
	OffsetOfFat1 EQU 0
	FirstAddOfFat1 EQU OffsetOfFat1
	
	BaseOfGDT EQU 2000H				;GDT的基地址和偏移地址
	OffsetOfGDT EQU 0000H
	
	BaseOfIDT EQU 3000H				;IDT的基地址和偏移地址
	OffsetOfIDT EQU 0000H
	
	SelectorCode equ	0x0008		;代码段选择子
	
	MOV BP, LoadKernel
	CALL DispStr
	CALL EnterLine

	
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
;;加载kernel,采用较为安全的复杂的扫描算法
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;------------------------------------
;先初始化栈，设置栈在7c00H地址之上
;-------------------------------------
	MOV AX, CS	
	MOV SS, AX
	MOV DS, AX,
	MOV ES, AX
	MOV SP, BaseOfStack				;栈指针
	MOV BP, BaseOfStack				;帧指针
;-------------------------------------	
	
	XOR AH, AH
	XOR DL, DL
	INT 13H			;软驱复位
	
	
;-----------------------------------------------------
;算法核心：从根目录开始扫描，先装载一个扇区到内存中
;从这个扇区里寻找名字为kernel的文件
;-----------------------------------------------------
	
	MOV AX, BaseOfKernel
	MOV ES, AX
	MOV BX, OffsetOfKernel			;ES:BX存放着缓冲区的地址

Label_Read_NextSector:
	MOV AX, [RootDirSectorNo]		;AH保存当前要读取的根目录下的扇区号
	CALL ReadSector
	
	MOV DX, 0						;BX里面记录着文件号,总共有16个文件(0--15)

Label_String_Compare:	
	MOV SI, KernelFileName 			;ds:si 指向源字符串，即要查找的文件名,作为即将比对的源数据
	MOV AX, DX
	MOV DI, 32
	PUSH DX
	MUL DI
	POP DX					;做乘法会影响dx的值，所以要保存一下dx的值
	ADD AX, OffsetOfKernel			
	MOV DI, AX						;ES:DI 指向目的字符串的首地址

	CLD								;清除标志位DF,使得si和di比较完之后自增
	MOV CX, 11						;重复操作的计数器
	
	REPZ CMPSB
	JNE	 NextFile
	ADD DI, 15
	PUSH DS
	MOV AX, ES
	MOV DS, AX
	MOV AX, [DI]
	POP DS
	JMP  Label_FileName_Found		;找到指定的文件名！！
NextFile:	
	INC DX
	CMP DX, 16
	JNE	Label_String_Compare			;继续对下一个文件进行匹配
	MOV AX, [RootDirSectorNo]		;读取下一个扇区，因为等于16，说明该扇区所有的文件都不是要找的文件，
	INC AX
	MOV [RootDirSectorNo], AX
	CMP  AX, MaxSectorNoOfRootDir+1
	JNE Label_Read_NextSector
	JMP Label_FileName_NotFound			;读完了所有的扇区，也没能找到
;------------------------------------------------------------------------------

	

	
;--------------------------------------------------------
;没有找到要找的文件跳到此处
;---------------------------------------------------------		
Label_FileName_NotFound:
	MOV BP, NoKernel
	CALL DispStr
	JMP $
;--------------------------------------------------------	
	
	
	
;--------------------------------------------------------
;找到文件名之后跳到此处
;---------------------------------------------------------	
Label_FileName_Found:
	PUSH AX   			;保存ax里的开始簇号
	MOV BP, GetKernel
	CALL DispStr
	CALL EnterLine
	
	MOV AX, BaseOfKernel
	MOV ES, AX
	MOV BX, OffsetOfKernel			;ES:BX存放着缓冲区的地址
	POP AX
	CALL ReadSectorByFirstCluster	;加载Kernel

	
		
	jmp Find_ISR_File			;加载内核之后再加载ISR	
;--------------------------------------------------------






Find_ISR_File:
;------------------------------------
;先初始化栈，设置栈在7c00H地址之上
;-------------------------------------
	MOV AX, CS	
	MOV SS, AX
	MOV DS, AX,
	MOV ES, AX
	MOV SP, BaseOfStack				;栈指针
	MOV BP, BaseOfStack				;帧指针
;-------------------------------------	
	
	XOR AH, AH
	XOR DL, DL
	INT 13H			;软驱复位
	
;-----------------------------------------------------
;算法核心：从根目录开始扫描，先装载一个扇区到内存中
;从这个扇区里寻找名字为ISR的文件
;-----------------------------------------------------
	
	MOV AX, BaseOfISR
	MOV ES, AX
	MOV BX, OffsetOfISR			;ES:BX存放着缓冲区的地址

Label_Read_NextSector_ISR:
	MOV AX, [RootDirSectorNo]		;AH保存当前要读取的根目录下的扇区号
	CALL ReadSector
	
	MOV DX, 0						;BX里面记录着文件号,总共有16个文件(0--15)

Label_String_Compare_ISR:	
	MOV SI, ISRFileName 			;ds:si 指向源字符串，即要查找的文件名,作为即将比对的源数据
	MOV AX, DX
	MOV DI, 32
	PUSH DX
	MUL DI
	POP DX					;做乘法会影响dx的值，所以要保存一下dx的值
	ADD AX, OffsetOfISR			
	MOV DI, AX						;ES:DI 指向目的字符串的首地址

	CLD								;清除标志位DF,使得si和di比较完之后自增
	MOV CX, 11						;重复操作的计数器
	
	REPZ CMPSB
	JNE	 NextFile_ISR
	ADD DI, 15
	PUSH DS
	MOV AX, ES
	MOV DS, AX
	MOV AX, [DI]
	POP DS
	JMP  Label_ISRFileName_Found		;找到指定的文件名！！
NextFile_ISR:	
	INC DX
	CMP DX, 16
	JNE	Label_String_Compare_ISR			;继续对下一个文件进行匹配
	MOV AX, [RootDirSectorNo]		;读取下一个扇区，因为等于16，说明该扇区所有的文件都不是要找的文件，
	INC AX
	MOV [RootDirSectorNo], AX
	CMP  AX, MaxSectorNoOfRootDir+1
	JNE Label_Read_NextSector_ISR
	JMP Label_ISRFileName_NotFound			;读完了所有的扇区，也没能找到
;------------------------------------------------------------------------------

	

	
;--------------------------------------------------------
;没有找到要找的ISR文件跳到此处
;---------------------------------------------------------		
Label_ISRFileName_NotFound:
	MOV BP, NoISR
	CALL DispStr
	JMP $
;--------------------------------------------------------	
	
	
	
;--------------------------------------------------------
;找到ISR文件名之后跳到此处
;---------------------------------------------------------	
Label_ISRFileName_Found:
	PUSH AX   			;保存ax里的开始簇号
	MOV BP, GetISR
	CALL DispStr
	CALL EnterLine
	
	MOV AX, BaseOfISR
	MOV ES, AX
	MOV BX, OffsetOfISR			;ES:BX存放着缓冲区的地址
	POP AX
	CALL ReadSectorByFirstCluster	;加载ISR
	
	
	;切换VGA图形显示模式
	mov ax, 0x0013
	int 0x10
	
	jmp Label_Goto_Protect			;ISR加载完成后跳入保护模式
;--------------------------------------------------------





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;带领处理器进入保护模式
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Label_Goto_Protect:	

	;初始化GDT表，在BaseOfGDT:OffsetOfGDT地址空间内
	mov ax, BaseOfGDT
	mov ds, ax
	mov bx, OffsetOfGDT
	mov si, 0
	
	;0#描述符，null，符合处理器的规定
	mov dword [bx+si], 0
	add si, 4
	mov dword [bx+si], 0
	add si, 4

	;1#描述符,代码段描述符，线性基地址0x00040000,长度为256k，末尾地址为0x0007ffff，只能执行，特权等级为0
	mov dword [bx+si], 0x0000ffff
	add si, 4
	mov dword [bx+si], 0x00439804 
	add si, 4

	;2#描述符,特殊数据段描述符，线性基地址0x000b8000,长度为32k，末尾地址为0x000bffff，可读可写，特权等级为0
	;文本模式下彩色视频缓冲区
	mov dword [bx+si], 0x80007fff
	add si, 4
	mov dword [bx+si], 0x0040920b
	add si, 4

	;3#描述符，堆栈段描述符，线性基地址0x00100000，ESP的值最小不能小于1ff+1
	mov dword [bx+si], 0x000001ff
	add si, 4
	mov dword [bx+si], 0x00409610
	add si, 4

	;4#描述符,特殊数据段描述符，线性基地址0x000a0000,长度为64k，末尾地址为0x000affff，可读可写，特权等级为0
	;图形模式下视频缓冲区
	mov dword [bx+si], 0x0000ffff
	add si, 4
	mov dword [bx+si], 0x0040920a
	add si, 4
	
	;5#描述符,中断代码段描述符，线性基地址0x00080000,长度为64k，末尾地址为0x0008ffff，只能执行，特权等级为0
	mov dword [bx+si], 0x0000ffff
	add si, 4
	mov dword [bx+si], 0x00409808
	add si, 4
	
	;6#描述符,全局数据段描述符，线性基地址0x00200000,长度为1M，末尾地址为0x002fffff，可读可写，特权等级为0
	mov dword [bx+si], 0x0000ffff
	add si, 4
	mov dword [bx+si], 0x004f9220
	add si, 4
	
	
	;重新添加描述符的时候，要注意修改gdtr中的段限
	;加载GDTR
	mov ax, bx
	add ax, si
	mov word [bx+si], 55		;gdtr中低16位的表的界限
	add si, 2
	mov dword [bx+si], BaseOfGDT*16+OffsetOfGDT	;gdtr中高32位的gdtr线性地址的基地址
	mov bx, ax
	lgdt [bx]			;将48位数据拷贝到gdtr中
	
	
	;;初始化IDT表，在BaseOfIDT:OffsetOfIDT地址空间内
	mov ax, BaseOfIDT
	mov ds, ax
	mov bx, OffsetOfIDT
	mov si, 0
	
	;中断门描述符表， 暂时将描述符初始化为同一值
Label_Load_GateDescriptor:	
	mov dword [bx+si], 0x002800a0			;选择子为0x0028指向中断服务子程序
	add si, 4
	mov dword [bx+si], 0x00008e00
	add si, 4
	cmp si, 256*8
	jne Label_Load_GateDescriptor
	
	;单独修改鼠标中断描述符的中断例程的地址
	mov ax, si
	mov si, 44*8			;鼠标中断是40号
	mov dword [bx+si], 0x002800b4
	add si, 4
	mov dword [bx+si], 0x00008e00
	mov si, ax
	
	;加载IDTR
	mov ax, bx
	add ax, si
	mov word [bx+si], 256*8-1		;Idtr中低16位的表的界限
	add si, 2
	mov dword [bx+si], BaseOfIDT*16+OffsetOfIDT	;gdtr中高32位的gdtr线性地址的基地址
	mov bx, ax
	lidt [bx]			;将48位数据拷贝到idtr中
	
	
	
	;关中断
	cli
	
	;打开地址线A20
	in al,0x92                         ;南桥芯片内的端口 
    or al,0000_0010B
	out 0x92,al                        ;打开A20
	
	;开启cr0控制位PE
	mov eax, cr0
	or eax, 1							;或运算使得最低位为1
	mov cr0, eax

	;16位的保护模式下获取并执行这条跳转指令，该指令会刷新ecs：eip
	jmp dword 	SelectorCode:0x80			;选择子:32位偏移地址


;----------------------------------------------------------------------
;函数名:DispStr, 入口参数为BP，字符串的起始位置； 字符串长度统一设为10
;----------------------------------------------------------------------
DispStr:
	MOV AH, 03H			;03号功能
	MOV BH, 00H			;显示页码
	INT 10H				;获取光标位置，DX中存储着光标的行列值
	
	;显示字符串
	MOV AX, CS
	MOV	ES, AX
	;MOV BP, CHARS ;BP里面的值有调用者设置
	
	MOV AX, 1301H
	MOV BX, 0007H	   
	MOV CX, 000AH		;字符串长度统一设为10
	INT 10H
	RET
;--------------------------------------------------------


;--------------------------------------------------------
;函数名：EnterLine，文本模式下设置光标位置换行
;--------------------------------------------------------
EnterLine:
	MOV AH, 03H			;03号功能
	MOV BH, 00H			;显示页码
	INT 10H				;DX中存储着光标的行列值
	
	MOV	 AX, 0200H		;02号功能00页码
	INC  DH
	MOV  DL, 00H		
	INT 10H
	RET 
;--------------------------------------------------------


;-------------------------------------------------------------------------------
;函数名：ReadSector
;参数:es:bx为缓冲区的地址,ax里面存储的是要读取的扇区号
;-------------------------------------------------------------------------------
ReadSector:
	;先将ax里面的扇区号进行转换，求得CHS地址
	INC AX
	MOV CH, HPC * SPT
	DIV CH
	CMP AH, 0
	JNE Label_GetCylinder
	DEC AL
	MOV CH, AL
	MOV DH, 1
	MOV CL, 18
	JMP Label_GetDriver
Label_GetCylinder:
	MOV CH, AL			;柱面
	
	MOV CL, 8			;应该移动一个字节ah-->al	
	SHR AX, CL			;余数移到al中
	
	MOV DH, SPT
	DIV DH
	CMP AH, 0
	JNE Label_GetHeader
	MOV DH, 0
	MOV CL, 18
	JMP Label_GetDriver
Label_GetHeader:	
	MOV DH, AL			;磁头
	
	MOV CL, AH			;扇区
			
	
Label_GetDriver:	
	MOV DL, 00H					;0驱动器
	MOV	AX, 0201H				;读一个扇区
	INT 13h
	JC ReadSector
	RET
;--------------------------------------------------------
	
	

;-------------------------------------------------------------------------------
;函数名：ReadSectorByFistCluster
;参数:es:bx为缓冲区的地址,ax里面存储的是该文件的起始簇号，函数将该文件所有扇区内容
;都复制到es:bx开头的连续内存空间中
;-------------------------------------------------------------------------------	
ReadSectorByFirstCluster:
	PUSH AX
	
	ADD AX, 31		;把AX变成扇区号
	CALL ReadSector
	ADD BX, 0x200
	POP AX

	;必须首先加载fat1表进内存
	PUSH ES
	PUSH BX
	PUSH AX
	MOV AX, BaseOfFat1 
	MOV ES, AX
	MOV BX, OffsetOfFat1
	MOV AX, FirstSectorOfFat1
	CALL ReadSector
	POP AX
	POP BX
	POP ES
	
	;;读取fat项的算法
	MOV DX, 0
	MOV CX, 2
	PUSH AX
	DIV CX
	POP AX
	CMP DX, 0
	JNE	Label_Odd_Number		;fat项为奇数则跳转处理
	MOV CX, 3
	MUL CX
	MOV CX, 2
	DIV CX			;此时ax为fat项的起始字节号
	ADD AX, FirstAddOfFat1
	MOV SI, AX
	PUSH DS
	MOV AX, BaseOfFat1
	MOV DS, AX
	MOV DL, [SI]
	INC SI
	MOV DH, [SI]
	POP DS
	AND DH, 0x0f
	MOV AX, DX			;AX得到fat项，也许为下一个簇号,需要判断	
	JMP Judge_Read_NextSector

Label_Odd_Number:
	MOV DX, 0
	DEC AX
	MOV CX, 3
	MUL CX
	MOV CX, 2
	DIV CX			;此时ax为fat项的起始字	
	ADD AX, FirstAddOfFat1+1
	MOV SI, AX
	PUSH DS
	MOV AX, BaseOfFat1
	MOV DS, AX
	MOV DL, [SI]
	INC SI
	MOV DH, [SI]
	POP DS
	MOV CL, 4
	SHR DX, CL
	MOV AX, DX		
	
Judge_Read_NextSector:
	CMP AX, 0xFF8
	JB ReadSectorByFirstCluster	
	RET	
;-------------------------------------------------------------------------------




	NoKernel DB "No Kernel!"
	GetKernel DB "Get Kernel"
	RootDirSectorNo DW SectorNoOfRootDirectory			;记录根目录搜索扇区的变量，从19变化到32
	KernelFileName DB "KERNEL  BIN"
	LoadKernel DB "Kernel...."
	
	NoISR DB "No ISRfile"
	GetISR DB "Get ISR!!!"
	ISRFileName DB "ISR     BIN"
	LoadISR DB "ISRfile...."
	
	
	
	