#include <stdio.h>
#include <stdlib.h>
#include <math.h>

void swap(int*, int*);
void line(int, int, int, int);
void usage();

int main(int argc, char** argv) {
  if(argc < 5)
    usage();
  int x0 = atoi(argv[1]);
  int y0 = atoi(argv[2]);
  int x1 = atoi(argv[3]);
  int y1 = atoi(argv[4]);
  line(x0, y0, x1, y1);
  return 0;
}

void usage() {
  printf("./le x0 y0 x1 y1\n");
  exit(0);
}

void swap(int* a, int* b) {
  int tmp = *a;
  *a = *b;
  *b = tmp;
}

// Code from Wikipedia
void line(int x0, int y0, int x1, int y1) {
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
      printf("%4d %4d\n", y, x);
    else
      printf("%4d %4d\n", x, y);
    error = error - deltay;
    if( error < 0 ) {
      y += ystep;
      error += deltax;
    }
  }
}
