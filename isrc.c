#include "include/paint.h"


void delay()
{
	int i, j;
	for(i=0, j=0; i<100000; i++)
	{
		for(j=0; j<1000; j++)
		{
		
		}
	}
}



void isrc_keyboard(int scanCode)
{
	if(scanCode==0x1e || scanCode==0x9e)
	{
		paintNothing(50, 50);
		paintA(50, 50);
	} else if(scanCode==0x12 || scanCode==0x92)
	{
		paintNothing(50, 50);
		paintE(50, 50);
	} else 
	{
		paintNothing(50, 50);
	}
}


void isrc_mouse(int scanCode)
{
	static int x;			//局部静态变量不要初始化，在汇编级别上就可以正常使用数据区
	static int y;
	static int x_old;
	static int y_old;
	static int x_sign;		//记录位移量的符号
	static int y_sign;
	static int counter;
	static int first_fa_falg;
	if(scanCode == 0xfa)
	{
		x = x_old;
		y = y_old;
		counter = 0;
		paintMouse(x, y);
	} else if(counter == 0)
	{
		
		if((scanCode & 0x10) == 0)
		{
			x_sign = 0;		//位移为正
		} else {x_sign = 1;}
		
		if((scanCode & 0x20) == 0)
		{
			y_sign = 0;		//位移为正
		} else {y_sign = 1;}
		
		counter++;
	} else if(counter == 1)
	{
		x_old = x;
		if(x_sign == 0)
		{ x += (0x0 | scanCode); }
		else{ x += (0xffffff00 | scanCode);}
		
		counter++;
	} else if(counter == 2)
	{
		y_old = y;
		if(y_sign == 0)
		{ y -= (0x0 | scanCode); }
		else{ y -= (0xffffff00 | scanCode);}
		
		paintNothing(x_old, y_old);
		paintMouse(x, y);
		counter = 0;
	}
	
}



