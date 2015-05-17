#include "include/paint.h"


void StalkerMain()
{
	int x, y;
	//先铺上背景
	for(x=0; x<=319; x++)
	{
		for(y=0; y<=199; y++)
		{			
			setPixel(x, y, 2);
		}
	}
	
	
}



