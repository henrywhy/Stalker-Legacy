global setPixel

[section .text]
setPixel:
	push   ebp
	mov    ebp,esp
	sub    esp,0x10
	mov    edx, [ebp+0xc] 
	mov    eax,edx
	shl    eax,0x2
	add    eax,edx
	shl    eax,0x6
	add    eax, [ebp+0x8]
	mov    [ebp-0x8],eax
	mov    eax, [ebp-0x8]
	mov    [ebp-0x4],eax
	mov    eax, [ebp+0x10]
	mov    edx,eax
	mov    eax, [ebp-0x4]
	mov    [es:eax],dl
	leave  
	ret    

