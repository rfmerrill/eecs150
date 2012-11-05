#ifndef UART_H_
#define UART_H_

#include "types.h"

#define URECV_CTRL (*((volatile uint32_t*)0x80000004) & 0x01)
#define URECV_DATA (*((volatile uint32_t*)0x8000000c) & 0xff)

#define UTRAN_CTRL (*((volatile uint32_t*)0x80000000) & 0x01)
#define UTRAN_DATA (*((volatile uint32_t*)0x80000008))

#define UART_IN_INDEX (*((volatile unsigned int*)0x1000f004))
#define UART_OUT_INDEX (*((volatile unsigned int*)0x1000f00c))
#define UART_BUFFER ((volatile unsigned char*)0x1000ff00)

#define UART_ASYNC_WRITE

void uwrite_int8(int8_t c);

void uwrite_int8s(const int8_t* s);

int8_t uread_int8(void);

void uart_init(void);

#endif
