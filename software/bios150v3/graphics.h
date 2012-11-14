#ifndef GRAPHICS_H_
#define GRAPHICS_H_

#include "types.h"

//TODO: put your #defines for any addresses you may need here
//ex. #define LE_Y1 (*((volatile uint32_t*) 0x8000004c))

//TODO: modify these declarations as you need them
void fill(uint32_t color);
void hwline(uint32_t color, uint16_t x0, uint16_t y0, uint16_t x1, uint16_t y1);
void swline(uint32_t color, int x0, int y0, int x1, int y1);
void swfill(uint32_t color);

#endif
