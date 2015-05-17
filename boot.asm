org 0x7c00	
	BaseOfLoader EQU 0000H
	OffsetOfLoader EQU 8000H
	BaseOfStack	EQU	07c00h
	SectorNoOfRootDirectory	EQU 19		;19号扇区为root目录的起始扇区
	MaxSectorNoOfRootDir    EQU 32		;32号扇区为root目录的终止扇区
	SPT EQU 18		;每个磁道18个扇区
	HPC EQU 2		;每个柱面两个磁头

	FirstSectorOfFat1 EQU 1
	BaseOfFat1 EQU 1000H
	OffsetOfFat1 EQU 0
	FirstAddOfFat1 EQU OffsetOfFat1
	
	JMP Entry					;2个字节
	NOP							;1个字节
	BS_OEMName	DB 'Stalker '	; OEM String, 必须 8 个字节， 总共11个字节，属于开始的11个忽略字节
	
	;制作fat12格式软盘的BPB信息
	BPB_BytsPerSec	DW 512		; 每扇区字节数
	BPB_SecPerClus	DB 1		; 每簇多少扇区
	BPB_RsvdSecCnt	DW 1		; Boot 记录占用多少扇区
	BPB_NumFATs	DB 2			; 共有多少 FAT 表
	BPB_RootEntCnt	DW 0xE0		; 根目录文件数最大值
	BPB_TotSec16	DW 2880		; 逻辑扇区总数
	BPB_Media	DB 0xF0			; 媒体描述符
	BPB_FATSz16	DW 9			; 每FAT扇区数
	BPB_SecPerTrk	DW 18		; 每磁道扇区数
	BPB_NumHeads	DW 2		; 磁头数(面数)
	BPB_HiddSec	DD 0			; 隐藏扇区数
	BPB_TotSec32	DD 0		; wTotalSectorCount为0时这个值记录扇区数
	
	BS_DrvNum	DB 0			; 中断 13 的驱动器号
	BS_Reserved1	DB 0		; 未使用
	BS_BootSig	DB 29h			; 扩展引导标记 (29h)
	BS_VolID	DD 0			; 卷序列号
	BS_VolLab	DB 'Stalker OS!'; 卷标, 必须 11 个字节
	BS_FileSysType	DB 'FAT12   '	; 文件系统类型, 必须 8个字节 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
;;显示信息
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Entry:	
	MOV BP, BootMessage
	CALL DispStr
	CALL EnterLine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	

	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
;;加载loader,采用较为安全的复杂的扫描算法
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
;从这个扇区里寻找名字为xxx的文件
;-----------------------------------------------------
	
	MOV AX, BaseOfLoader
	MOV ES, AX
	MOV BX, OffsetOfLoader			;ES:BX存放着缓冲区的地址

Label_Read_NextSector:
	MOV AX, [RootDirSectorNo]		;AH保存当前要读取的根目录下的扇区号
	CALL ReadSector
	
	MOV DX, 0						;BX里面记录着文件号,总共有16个文件(0--15)

Label_String_Compare:	
	MOV SI, LoaderFileName 			;ds:si 指向源字符串，即要查找的文件名,作为即将比对的源数据
	MOV AX, DX
	MOV DI, 32
	PUSH DX
	MUL DI
	POP DX					;做乘法会影响dx的值，所以要保存一下dx的值
	ADD AX, OffsetOfLoader			
	MOV DI, AX						;ES:DI 指向目的字符串的首地址

	CLD								;清除标志位DF,使得si和di比较完之后自增
	MOV CX, 11						;重复操作的计数器
	
	REPZ CMPSB
	JNE	 NextFile
	ADD DI, 15
	MOV AX, [DI]
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
	MOV BP, NoLoader
	CALL DispStr
	JMP $
;--------------------------------------------------------	
	
	
	
;--------------------------------------------------------
;找到文件名之后跳到此处
;---------------------------------------------------------	
Label_FileName_Found:
	PUSH AX   			;保存ax里的开始簇号
	MOV BP, GetLoader
	CALL DispStr
	CALL EnterLine
	
	MOV AX, BaseOfLoader
	MOV ES, AX
	MOV BX, OffsetOfLoader			;ES:BX存放着缓冲区的地址
	POP AX
	CALL ReadSectorByFirstCluster	;加载loader
	
	JMP BaseOfLoader:OffsetOfLoader
;--------------------------------------------------------



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
	
	
	BootMessage DB "booting..."
	NoLoader DB "No Loader!"
	GetLoader DB "Loading..."
	RootDirSectorNo DW SectorNoOfRootDirectory			;记录根目录搜索扇区的变量，从19变化到32
	LoaderFileName DB "LOADER  BIN"
	TIMES 510-($-$$) DB 0
	DW 0xAA55
	TIMES 1440*1024-($-$$) DB 0
	
	
	
	
	