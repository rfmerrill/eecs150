
//not sure if what I do here is what they exactly want


#include "uart.h"
#include "ascii.h"


volatile uint32_t * framebuf1 = (volatile uint32_t*)0x1FC00000;
volatile uint32_t * framebuf2 = (volatile uint32_t*)0x1F800000;
volatile uint32_t * framebuf3 = (volatile uint32_t*)0x1F400000;

volatile uint32_t * volatile * const gp_frame = (volatile uint32_t * volatile *)0x80000030;
volatile uint32_t * volatile * const gp_code = (volatile uint32_t * volatile *)0x80000034;

volatile uint32_t * volatile * const framebuf_set = (volatile uint32_t * volatile *)0x80000020;


#define PIXEL(X, Y) framebuf1[((Y) << 10) | (X)]
#define PIXEL2(X, Y) framebuf2[((Y) << 10) | (X)]
#define PIXEL3(X, Y) framebuf3[((Y) << 10) | (X)]

#define GP_READY (*((volatile uint32_t*)0x1000f030))
#define FRAMEBUF_READY (*((volatile uint32_t*)0x1000f020))

#define COUNTER_RST (*((volatile uint32_t*) 0x80000018))
#define CYCLE_COUNTER (*((volatile uint32_t*)0x80000010))
#define INSTRUCTION_COUNTER (*((volatile uint32_t*)0x80000014))

volatile uint32_t gpcode[] = { 
  0x0100FF00,
  0x00000000       
};

int main(){

  int count = 0;
  uint32_t gpstart, gpend, frameend, framestart;
  uint32_t highest_frames = 0, fbr;
  int x, y;
  unsigned char pixel = 0;
  uint32_t fpixel = 0;
  static char buffer[32];
  

  uart_init();

  asm ("mtc0    $0, $9");
  asm ("ori     $k1, $0, 0x3801");
  asm ("mtc0    $k1, $12");
 
#if 0 
  while (1) {
    uwrite_int8s("0123456789");
  }
#endif

  *framebuf_set = framebuf1;

  GP_READY = 0;
  FRAMEBUF_READY = 0;
  
  COUNTER_RST = 1;

  framestart = CYCLE_COUNTER;

  while(1) {

  
    if (!(count & 0xFF)) {
      highest_frames = 0;
    }
    
    count++;
            
    
    pixel = (count & 0x100) ? (count & 0xFF) : (0xFF - (count & 0xFF));
    fpixel = (pixel << 8) + (pixel << 16) + pixel;

    gpcode[0] = 0x01000000 + fpixel;
    
    
    *gp_frame = ((count & 1) ? framebuf1 : framebuf2); 

    gpstart = CYCLE_COUNTER;

    *gp_code = gpcode;

        
    while (!GP_READY) {
    }
    
    gpend = CYCLE_COUNTER;
    GP_READY = 0;
    
    

    *framebuf_set = ((count & 1) ? framebuf1 : framebuf2);

    while (!FRAMEBUF_READY) {
    }

    fbr = FRAMEBUF_READY;
    FRAMEBUF_READY = 0;
   
    if (fbr > highest_frames)
      highest_frames = fbr;
      

    framestart = frameend; 
    frameend = CYCLE_COUNTER;

    uwrite_int8s("#");
    uwrite_int8s(uint32_to_ascii_hex(count, buffer, 32));
    uwrite_int8s(" GPstart: ");
    uwrite_int8s(uint32_to_ascii_hex(gpstart, buffer, 32));
    uwrite_int8s(" GPend: ");
    uwrite_int8s(uint32_to_ascii_hex(gpend, buffer, 32));    
    uwrite_int8s(" fe: ");
    uwrite_int8s(uint32_to_ascii_hex(frameend, buffer, 32));
    uwrite_int8s(" GPstart-fs: ");
    uwrite_int8s(uint32_to_ascii_hex(gpstart-framestart, buffer, 32));
    uwrite_int8s(" GPend-fs: ");
    uwrite_int8s(uint32_to_ascii_hex(gpend-framestart, buffer, 32));    
    uwrite_int8s(" fe-fs: ");
    uwrite_int8s(uint32_to_ascii_hex(frameend-framestart, buffer, 32));
    uwrite_int8s(" highest: ");
    uwrite_int8s(uint32_to_ascii_hex(highest_frames, buffer, 32));
    uwrite_int8('\r');
    uwrite_int8('\n');
  }
}
