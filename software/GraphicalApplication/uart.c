#include "uart.h"

#ifndef UART_ASYNC_WRITE

void uwrite_int8(int8_t c)
{
    while (!UTRAN_CTRL) ;
    UTRAN_DATA = c;
}

#else 


void uwrite_int8(int8_t c)
{

  if (UART_EMPTY && UTRAN_CTRL) {
      // Buffer is empty

      UTRAN_DATA = c;
  } else {
   
    while (((UART_IN_INDEX + 1) & 255) == UART_OUT_INDEX) {
#if 0
      if (UTRAN_CTRL) {
        // I'm not sure this is possible but just in case
        asm ("mtc0    $0, $12");  // disable interrupts

        
        UTRAN_DATA = UART_BUFFER[UART_OUT_INDEX];
        UART_OUT_INDEX = (UART_OUT_INDEX + 1) & 63;
          
        asm ("ori     $k1, $0, 0x3801");
        asm ("mtc0    $k1, $12");
      }
#endif
    }
    
    asm ("mtc0    $0, $12");  // disable interrupts
    
    UART_BUFFER[UART_IN_INDEX] = c;
    UART_IN_INDEX = (UART_IN_INDEX + 1) & 255;
    
    asm ("ori     $k1, $0, 0xBC01");
    asm ("mtc0    $k1, $12");
  }
}

#endif


void uart_init() {
    UART_OUT_INDEX = 0;
    UART_IN_INDEX = 0;
    UARTR_IN_INDEX = 0;
    UARTR_OUT_INDEX = 0;
    UART_EMPTY = 1;
}

void uwrite_int8s(const int8_t* s)
{
    for (int i = 0; s[i] != '\0'; i++) {
        uwrite_int8(s[i]);
    }
}

#ifdef UART_ASYNC_READ

int8_t uread_int8(void) {
    int8_t ch;
    int idx;
  
    while (UARTR_IN_INDEX == UARTR_OUT_INDEX) {
     /* wait */
    }

    asm ("mtc0    $0, $12");  // disable interrupts
  
    idx = UARTR_OUT_INDEX;
    UARTR_OUT_INDEX = (UARTR_OUT_INDEX + 1) & 255;

    ch = UARTR_BUFFER[idx];

    asm ("ori     $k1, $0, 0xBC01");
    asm ("mtc0    $k1, $12");
 
#if 0
    if (ch == '\x0d') {
        uwrite_int8s("\r\n");
    } else {
        uwrite_int8(ch);
    }
#endif
    return ch;
}

#else

int8_t uread_int8(void)
{
    while (!URECV_CTRL) ;
    int8_t ch = URECV_DATA;

#if 0
    if (ch == '\x0d') {
        uwrite_int8s("\r\n");
    } else {
        uwrite_int8(ch);
    }
#endif

    return ch;
}

#endif


