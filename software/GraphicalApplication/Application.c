
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
#define GP_WAIT  (*((volatile uint32_t*)0x1000f034))
#define GP_SWAP  (*((volatile uint32_t*)0x1000f038))

#define GP_CYCLES  (*((volatile uint32_t*)0x1000f040))

#define FRAME_COUNT (*((volatile uint32_t*)0x1000f020))

#define COUNTER_RST (*((volatile uint32_t*) 0x80000018))
#define CYCLE_COUNTER (*((volatile uint32_t*)0x80000010))
#define INSTRUCTION_COUNTER (*((volatile uint32_t*)0x80000014))


#define TIME_SECONDS_ONES (*(volatile unsigned char *)0x1000f104)
#define TIME_SECONDS_TENS (*(volatile unsigned char *)0x1000f105)
#define TIME_MINUTES_ONES (*(volatile unsigned char *)0x1000f106)
#define TIME_MINUTES_TENS (*(volatile unsigned char *)0x1000f107)

volatile uint32_t *gpcode[2] = { (volatile uint32_t *)0x10200000, (volatile uint32_t *)0x10400000 };

int codeswap;
int gpindex;

void gp_launch() {
  *gp_code = gpcode[codeswap];
  GP_READY = 0;

}

void gp_begin() {
  codeswap = (1 - codeswap);
  gpindex = 0;
}

void gp_end() {
  gpcode[codeswap][gpindex] = 0;
}

void frame_fill(uint32_t color) {
  gpcode[codeswap][gpindex] = 0x01000000 + color;
  gpindex += 1;
} 

void draw_line(uint32_t color, int x0, int y0, int x1, int y1) {
  gpcode[codeswap][gpindex] = 0x02000000 + color;
  gpcode[codeswap][gpindex+1] = (x0 << 16) + y0;
  gpcode[codeswap][gpindex+2] = (x1 << 16) + y1;
  gpindex += 3;
}

void draw_rect(uint32_t color, int x0, int y0, int x1, int y1) {
  gpcode[codeswap][gpindex] = 0x03000000 + color;
  gpcode[codeswap][gpindex+1] = (x0 << 16) + y0;
  gpcode[codeswap][gpindex+2] = (x1 << 16) + y1;
  gpindex += 3;
}

void draw_rect_outline (uint32_t color, int x0, int y0, int x1, int y1) {
  draw_line(color, x0, y0, x0, y1);
  draw_line(color, x0, y0, x1, y0);
  draw_line(color, x1, y0, x1, y1);
  draw_line(color, x0, y1, x1, y1);
}

void draw_tile(uint32_t color1, uint32_t color2, int x, int y) { 
  int xp = x+32;
  int yp = y+32;
  
  draw_rect_outline(color2, x, y, xp, yp);
  draw_rect(color1, x+1, y+1, xp-1, yp-1);
  draw_rect_outline(color2, x+2, y+2, xp-2, yp-2);
  draw_rect_outline(color2, x+4, y+4, xp-4, yp-4);

/*  
  draw_rect(color2, x+2, y+2, xp-2, yp-2);
  draw_rect(color1, x+4, y+4, xp-4, yp-4);
*/
} 

#define SEG_TOP  (1<<1)
#define SEG_TR   (1<<2)
#define SEG_TL   (1<<3)
#define SEG_MID  (1<<4)
#define SEG_BL   (1<<5)
#define SEG_BR   (1<<6)
#define SEG_BOT  (1<<0)


uint8_t digit_decode[] = { 
  ~(SEG_MID),
  (SEG_TR | SEG_BR),
  ~(SEG_TL | SEG_BR),
  ~(SEG_TL | SEG_BL),
  (SEG_MID | SEG_TL | SEG_TR | SEG_BR),
  ~(SEG_TR | SEG_BL),
  ~(SEG_TR),
  (SEG_TOP | SEG_TR | SEG_BR),
  ~0,
  ~(SEG_BL | SEG_BOT)
};


static void draw_numeral(uint32_t color, uint32_t n, uint32_t x, uint32_t y) {
  uint8_t bf = digit_decode[n];
  
  if (bf & SEG_TOP)
    draw_rect(color, x, y, x+15, y+2);
  if (bf & SEG_TR)
    draw_rect(color, x+13, y, x+15, y+11);
  if (bf & SEG_TL)
    draw_rect(color, x, y, x+2, y+11);
  if (bf & SEG_MID)
    draw_rect(color, x, y+11, x+15, y+13);
  if (bf & SEG_BR)
    draw_rect(color, x+13, y+12, x+15, y+23);
  if (bf & SEG_BL)
    draw_rect(color, x, y+12, x+2, y+23);
  if (bf & SEG_BOT)
    draw_rect(color, x, y+21, x+15, y+23);

}


void draw_triangle (uint32_t color, uint32_t x, uint32_t y, uint32_t base, int32_t height) {

  draw_line(color, x+base, y, x-base, y);
  draw_line(color, x+base, y, x, y+height);
  draw_line(color, x-base, y, x, y+height);

}

void draw_sierpinski (uint32_t color, uint32_t x, uint32_t y, uint32_t base, uint32_t height, int n) {
  uint32_t halfbase = base>>1;
  uint32_t halfheight = height>>1;

  draw_triangle (color, x, y-halfheight, halfbase, halfheight);
  
  if (n > 1) {
    draw_sierpinski (color, x+halfbase, y, halfbase, halfheight, n-1);
    draw_sierpinski (color, x-halfbase, y, halfbase, halfheight, n-1);
    draw_sierpinski (color, x, y-halfheight, halfbase, halfheight, n-1); 
  }
}


void draw_square_fractal (uint32_t color1, uint32_t color2, uint32_t x, uint32_t y, uint32_t side, int n) {
  int halfside = (side>>1);

  draw_rect(color1, x, y, x+side+1, y+side+1);

  if (n > 1) {
//    if (n & 1) {
      draw_square_fractal (color1, color2, x+halfside, y, halfside, n-1);
      draw_square_fractal (color1, color2, x, y+halfside, halfside, n-1);
//    } else {
      draw_square_fractal (color2, color1, x, y, halfside, n-1);
      draw_square_fractal (color2, color1, x+halfside, y+halfside, halfside, n-1);    
//    }
     
  }

}


uint8_t blocks_present[288];

#define BLOCK_PRESENT(x, y) blocks_present[((y)<<4) + (x)]

int main() {

  int count = 0;
  int mcount = 0;
  unsigned char pixel = 0, pixel2 = 0;
  uint32_t fpixel = 0;
  uint32_t fpixel2 = 0;
  static char buffer[32];
  int kx=0, ky=0;
  int flashing_row = 0;
  int x, y;
  int paused = 0;
  
  uint32_t gpcycles=0, cpucycles=0;
  
  int trianglemode = 0;
  int fill_only = 0;
  int line_mode = 0;
  int block_speed = 0;
  
  int print_enabled = 0;
  
  uint8_t **ptr;

  uart_init();

  gpcode[0] = (volatile uint32_t *)0x10040000;
  gpcode[1] = (volatile uint32_t *)0x10030000;

  GP_SWAP = 0;
  GP_READY = 1;
  GP_WAIT = 0;
  
  codeswap = 0;

  *gp_frame = framebuf1;
  *framebuf_set = framebuf2;
  
  
  for (int i = 0; i < 288; i++) {
    blocks_present[i] = 0;
  } 
  
  
  TIME_SECONDS_ONES = 0;
  TIME_SECONDS_TENS = 0;
  TIME_MINUTES_ONES = 0;
  TIME_MINUTES_TENS = 0;
  
  GP_CYCLES = 0;

  COUNTER_RST = 1;
  FRAME_COUNT = 0;
  
// enable interrupts
  asm ("mtc0    $0, $9");
  asm ("ori     $k1, $0, 0xBC01");
  asm ("mtc0    $k1, $12");


  
  gpcode[0][0] = 0;
  gpcode[1][0] = 0;

  uwrite_int8s("go!\r\n");

  while(1) {
    
    if (GP_READY && !GP_WAIT) {
     gpcycles = GP_CYCLES;
     COUNTER_RST = 1;
    
     gp_launch();
     if (!paused) {

      count++;
      mcount = mcount + (1 << block_speed);

      pixel = (count & 0x100) ? (count & 0xFF) : (0xFF - (count & 0xFF));
      fpixel = (pixel << 8) + (pixel << 16) + pixel;
  
      gp_begin();
      
      
      


#if 0      
      uwrite_int8s("#");
      uwrite_int8s(uint32_to_ascii_hex(count, buffer, 32));
      uwrite_int8s("\r\n");
#endif
      
      y = 0;

      if (fill_only || line_mode) {
        frame_fill(fpixel);
        
        if (line_mode == 1) {
          for (int i = 0; i < 500; i++)
            draw_line(0xffffff, 790, 0, 0, 599);
        } else if (line_mode == 2) {
          for (int i = 0; i < 500; i++)
            draw_line(0xffffff, 300, 300, 301, 301);
        } else if (line_mode == 3) {
          for (int i = 0; i < 500; i++)
            draw_line(0xffffff, 300, 300, 332, 332);        
        }

        if (line_mode == 4) {
          for (int i = 0; i < 500; i++)
            draw_rect(0xffffff, 790, 0, 0, 599);
        } else if (line_mode == 5) {
          for (int i = 0; i < 500; i++)
            draw_rect(0xffffff, 300, 300, 301, 301);
        } else if (line_mode == 6) {
          for (int i = 0; i < 500; i++)
            draw_rect(0xffffff, 300, 300, 332, 332);        
        }
      
      } else if (!trianglemode) {
        frame_fill(fpixel);
      
        //playing field
        draw_rect(0x0, 240, 0, 560, 576);
        
        draw_rect((0xFF-pixel) << 8, 230, 0, 239, 585);
        draw_rect((0xFF-pixel) << 8, 561, 0, 570, 585);
        draw_rect((0xFF-pixel) << 8, 230, 577, 570, 585);
        
        for (int i = 0, y = 0; i < 18; i++) {
          x = 240;
          for (int j = 0, x= 240; j < 10 ; j++) { 
                    
            if (BLOCK_PRESENT(j, 17-i)) {
                draw_tile((((i+j) & 1) ? 0xFF00 : 0xFF) + ((0xFF-pixel) << 16) , 0, x, y);
            }        
            x += 32;          
          }
          y += 32;
        }
      
        if (count & 8)
          draw_tile(0xFFFFFF, 0x000000, 240 + (kx << 5), ((17-ky) << 5));
        else
         draw_tile(0x000000, 0xFFFFFF, 240 + (kx << 5), ((17-ky) << 5));
    
    
        draw_tile(0xFF00 + (pixel << 16),0, 700, 44+ ( ((mcount & 256) ? (mcount & 255) : (255-(mcount & 255))) << 1 ));

      } else {
        frame_fill(0x0);
      
        if (trianglemode > 0)
          draw_sierpinski(0xFF00, 400, 575, 350, 200+pixel, trianglemode);
        else
          draw_square_fractal(0xFF00, 0xFF0000, 200, 50, 512, -trianglemode);
      }
      
      if (!fill_only && !line_mode) {
        draw_numeral(0xFF0000, TIME_MINUTES_TENS, 8, 8);
        draw_numeral(0xFF0000, TIME_MINUTES_ONES, 26, 8);
      
        draw_numeral(0xFF0000, TIME_SECONDS_TENS, 48, 8);
        draw_numeral(0xFF0000, TIME_SECONDS_ONES, 66, 8);
      
        draw_rect(0xFF0000, 8, 64, 8+(cpucycles>>12), 88); 
        draw_rect_outline(0xFF, 8, 64, 9+(666666>>12), 88); 
        draw_rect(0xFF00, 8, 96, 8+(gpcycles>>12), 120 ); 
        draw_rect_outline(0xFF, 8, 96, 9+(666666>>12), 120 ); 
      }

      gp_end();
      

     }
     
     cpucycles = CYCLE_COUNTER;

     if (print_enabled) {     
       uwrite_int8s("#");
       uwrite_int8s(uint32_to_ascii_hex(FRAME_COUNT, buffer, 32));
     
       uwrite_int8(codeswap ? 'A' : 'B');

       uwrite_int8s(" CPU_cycles: ");
       uwrite_int8s(uint32_to_ascii_hex(cpucycles, buffer, 32));
       uwrite_int8s(" GP_cycles: ");
       uwrite_int8s(uint32_to_ascii_hex(gpcycles, buffer, 32));
       uwrite_int8s(" GPcmds: ");
       uwrite_int8s(uint32_to_ascii_hex(gpindex, buffer, 32));
       uwrite_int8s("\r\n");     
     }

    }
    
    if (UART_DATA_WAITING) {
      int8_t ch;
      
      ch = uread_int8();
      
      if (!paused) {
        if (ch == 'w' && (ky != 17))
          ky++;
        if (ch == 's' && (ky != 0))
          ky--;
        if (ch == 'd' && (kx != 9))
          kx++;
        if (ch == 'a' && (kx != 0))
          kx--;
      }
        
      if (ch == 'f') {
        
        BLOCK_PRESENT(kx, ky) = !BLOCK_PRESENT(kx, ky);
      }
      
      if (ch == 'g') {
          for (int i = 0; i < 288; i++) {
             blocks_present[i] = 0;
          } 
      }

      if (ch == 'h') {
          for (int i = 0; i < 288; i++) {
             blocks_present[i] = 1;
          } 
      }
      
      if (ch == ' ') {
        paused = !paused;
      }
  
      if (ch == 't') {
        uwrite_int8(TIME_MINUTES_TENS + '0');
        uwrite_int8(TIME_MINUTES_ONES + '0');
        uwrite_int8(':');
        uwrite_int8(TIME_SECONDS_TENS + '0');
        uwrite_int8(TIME_SECONDS_ONES + '0');
        uwrite_int8s("\r\n");
      }
      
      if (ch == 'q') {
        trianglemode++;
      }
      
      if (ch == 'e') {
        trianglemode--;
      }
      
      if (ch == 'm') {
        fill_only = !fill_only;
      }
      
      if (ch == 'l') {
        line_mode++;
        if (line_mode > 6)
          line_mode = 0;
      }
      
      if (ch == 'o') {
        if (block_speed > 0)
          block_speed--;
      }
      
      if (ch == 'p') {
        if (block_speed < 8)
          block_speed++;
      }

      if (ch == 'u') {
        print_enabled = !print_enabled;
      }
  
    }


  }
}
