#include "graphics.h"
#include "uart.h"
#include "ascii.h"
#include "types.h"


void fill(uint32_t color)
{
  //TODO: write this function and modify the interface to how your design handles this
}

void hwline(uint32_t color, uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1)
{
  //TODO: write this function and modify the interface to how your design handles this
}

void swfill(uint32_t color)
{
  //TODO: write this function and modify the interface to how your design handles this
}

//utility methods
void swap(int* a, int* b) 
{
  int tmp = *a;
  *a = *b;
  *b = tmp;
}

uint16_t abs(int a) 
{
   if (a < 0)
       return -a;
   return a;
}

void store_pixel(uint32_t color, int x, int y)
{
  //TODO: write thie function and modify the interface to how your design handles this
}

/* Based on wikipedia implementation 
 * TODO: modify this and its interface to be compatible with your design
*/
void swline(uint32_t color, int x0, int y0, int x1, int y1)
{
  char steep = (abs(y1-y0) > abs(x1-x0)) ? 1 : 0; 
  if(steep) {
    swap(&x0, &y0);
    swap(&x1, &y1);
  }
  if( x0 > x1 ) {
    swap(&x0, &x1);
    swap(&y0, &y1);
  }
  int deltax = x1 - x0;
  int deltay = abs(y1-y0);
  int error = deltax / 2;
  int ystep;
  int y = y0;
  int x;
  ystep = (y0 < y1) ? 1 : -1;
  for( x = x0; x <= x1; x++ ) {
    if(steep)
      store_pixel(color, y, x);
    else
      store_pixel(color, x, y);
    error = error - deltay;
    if( error < 0 ) {
      y += ystep;
      error += deltax;
    }
  }
}

