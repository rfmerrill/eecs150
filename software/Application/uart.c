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
  if (UTRAN_CTRL && (UART_IN_INDEX == UART_OUT_INDEX)) {
      // Buffer is empty
      UTRAN_DATA = c;
  } else {
    if (UTRAN_CTRL) {
      // I'm not sure this is possible but just in case
      UTRAN_DATA = UART_BUFFER[UART_OUT_INDEX];
      UART_OUT_INDEX = (UART_OUT_INDEX + 1) & 63;
    }
    
    while (((UART_IN_INDEX + 1) & 63) == UART_OUT_INDEX) {
      /* do nothing */ 
    }
    
    UART_BUFFER[UART_IN_INDEX] = c;
    UART_IN_INDEX = (UART_IN_INDEX + 1) & 63;
  }
}

#endif


void uart_init() {
    UART_OUT_INDEX = 0;
    UART_IN_INDEX = 0;

}

void uwrite_int8s(const int8_t* s)
{
    for (int i = 0; s[i] != '\0'; i++) {
        uwrite_int8(s[i]);
    }
}

int8_t uread_int8(void)
{
    while (!URECV_CTRL) ;
    int8_t ch = URECV_DATA;
    if (ch == '\x0d') {
        uwrite_int8s("\r\n");
    } else {
        uwrite_int8(ch);
    }
    return ch;
}


