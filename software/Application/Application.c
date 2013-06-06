// This is demonstration code to show that our timer and UART interrupts work properly.
// There was conflicting information given to us from the TAs and Professor,
// so we weren't quite sure how we were supposed to do it.

//not sure if what I do here is what they exactly want


#include "uart.h"
#include "ascii.h"


#define STATE_CHARACTER (*((volatile unsigned char *)0x1000f200))

#define PRINT_ENABLE (*((volatile unsigned int*)0x1000f300))


#define CYCLE_COUNT (*((volatile unsigned int*)0x80000010))
#define INSTR_COUNT (*((volatile unsigned int*)0x80000014))

#define TIME_SECONDS_ONES (*(volatile unsigned char *)0x1000f104)
#define TIME_SECONDS_TENS (*(volatile unsigned char *)0x1000f105)
#define TIME_MINUTES_ONES (*(volatile unsigned char *)0x1000f106)
#define TIME_MINUTES_TENS (*(volatile unsigned char *)0x1000f107)


static volatile int n;

void increment_n() {
  n++;
}

void count_100mil_register();
void count_100mil_register_f();


int main(){

  register int a;
  int cstart, cend, istart, iend;
  //static volatile int state ='r';

  int b = 0;
  char s[32];
  char oldstate;

  STATE_CHARACTER = 'r';  //just initialization

  oldstate = 'r';

  uart_init();
  
  TIME_SECONDS_ONES = 0;
  TIME_SECONDS_TENS = 0;
  TIME_MINUTES_ONES = 0;
  TIME_MINUTES_TENS = 0;

  asm ("mtc0    $0, $9");
  asm ("ori     $k1, $0, 0xCC01");
  asm ("mtc0    $k1, $12");

  uwrite_int8s("Endian test\r\n");

  PRINT_ENABLE = 1;

  while(1){

		cstart = CYCLE_COUNT;
 		istart = INSTR_COUNT;

    if (STATE_CHARACTER == 'r') {		     
  	/*	
    	register int i;
     	for(i =0; i <100000000; i++){
      
      }
    */
	  	
	  	
	  	oldstate = 'r';

	  	count_100mil_register();

      cend = CYCLE_COUNT;
  		iend = INSTR_COUNT;
		
      uwrite_int8s(" r: ");
  		uint32_to_ascii_hex(cend - cstart, s, 32);
  		uwrite_int8s(s);
  		uwrite_int8(' ');
  		uint32_to_ascii_hex(iend - istart, s, 32); 
  		uwrite_int8s(s);
  		uwrite_int8s("\r\n");

  	} else if (STATE_CHARACTER == 'R'){
	 
  		oldstate = 'R';
 		
  		count_100mil_register_f();
  		
      cend = CYCLE_COUNT;
  		iend = INSTR_COUNT;
		
      uwrite_int8(' ');
      uwrite_int8('R');
      uwrite_int8(':');
      uwrite_int8(' ');
      uint32_to_ascii_hex(cend - cstart, s, 32);
  		uwrite_int8s(s);
  		uwrite_int8(' ');
  		uint32_to_ascii_hex(iend - istart, s, 32); 
  		uwrite_int8s(s);
  		uwrite_int8('\r');
  		uwrite_int8('\n');
	
	  } else if (STATE_CHARACTER == 'v'){

		  oldstate = 'v';

      for (n = 0; n < 100000000; n++) {
      
      }

      cend = CYCLE_COUNT;
  		iend = INSTR_COUNT;
		
      uwrite_int8(' ');
      uwrite_int8('v');
      uwrite_int8(':');
      uwrite_int8(' ');
      uint32_to_ascii_hex(cend - cstart, s, 32);
  		uwrite_int8s(s);
  		uwrite_int8(' ');
  		uint32_to_ascii_hex(iend - istart, s, 32); 
  		uwrite_int8s(s);
  		uwrite_int8('\r');
  		uwrite_int8('\n');

  	} else if (STATE_CHARACTER == 'V'){
  		
  		oldstate = 'V';
  		
      for (n = 0; n < 100000000; increment_n()) {
      
      }

      cend = CYCLE_COUNT;
  		iend = INSTR_COUNT;
		
      uwrite_int8(' ');
      uwrite_int8('V');
      uwrite_int8(':');
      uwrite_int8(' ');
      uint32_to_ascii_hex(cend - cstart, s, 32);
  		uwrite_int8s(s);
  		uwrite_int8(' ');
  		uint32_to_ascii_hex(iend - istart, s, 32); 
  		uwrite_int8s(s);
  		uwrite_int8('\r');
  		uwrite_int8('\n');

  	} else {
  	  STATE_CHARACTER = oldstate; 
    }
    

  }
}
