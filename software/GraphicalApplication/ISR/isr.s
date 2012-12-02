

.section    .start
.global     _start

_start:
#    li      $sp, 0x10001000
#    jal     main

li $k0, 0x1000f050
sw $t0, 0($k0)
sw $t1, 4($k0)

mfc0 $t0, $13          #t0 <= cause

li $k0, 0xFFFFFFFF     #k0 <=  0xFFFFFFFF
mfc0 $k1, $12          #k1 <=  status
andi $t1, $k1, 0xfc00  #t1 <=  (status & 0xfc00)
xor  $k1, $t1, $k0     #k1 <=  (status & 0xfc00) ^ 0xffffffff


and  $k0, $t0, $k1     #k0 <=  cause & ~(status & 0xfc00)
mtc0 $k0, $13          #cause <= cause & ~(status & 0xfc00)

and  $t0, $t0, $t1     #t0 gets the bits which are enabled interrupts


andi $k1, $t0, 0x8000
bne  $k1, $0, timer_ISR

timer_done:

andi $k1, $t0, 0x4000
bne  $k1, $0, RTC_ISR

rtc_done:

andi $k1, $t0, 0x2000
bne  $k1, $0, GP_ISR

gp_done:

andi $k1, $t0, 0x1000
bne  $k1, $0, FRAME_ISR

frame_done:

andi $k1, $t0, 0x0800    #11 <<1 
bne  $k1, $0, UARTTX_ISR

uarttx_done:

andi $k1, $t0, 0x0400    # 10 << 1
bne  $k1, $0, UARTRX_ISR

uartrx_done:

j    done




timer_ISR: 

j timer_done

RTC_ISR:
#mfc0  $k1, $13     
#li    $k0, 0xffffbfff
#and   $k1, $k1, $k0
#mtc0  $k1, $13
li    $k1, 0x1000f10c  #adress of SW_RTC
lw    $k0, 0($k1)
addiu $k0, $k0, 0x1
sw    $k0, 0($k1)   #write back incremented SW_RTC 
#li    $k1, 0x100ff010  #let's write the value of count here.
#mfc0  $k0, $9
#sw    $k0, 0($k1)
mtc0  $0, $9
j rtc_done




UARTRX_ISR:   
#mfc0 $k1, $13
#li   $k0, 0xfffffbff
#and  $k1, $k1, $k0
#mtc0 $k1, $13


# Our buffer is 256 bytes long
# So it's unlikely that the user
# can overrun it

#load IN_INDEX
li  $k0, 0x1000f014    # UARTR_IN_INDEX
lw  $k0, 0($k0)

#add one to it, and with 255 and store it back
addiu $k1, $k0, 1
andi $k1, $k1, 0xff
sw  $k1, 0($k0)

#buffer address
li $k1, 0x1000fe00
#add the index
addu $k1, $k0, $k1

#read from the UART
li  $k0, 0x8000000c    # receive address
lbu $k0, 0($k0)        # received byte

#store the read byte
sb $k0, 0($k1)


j uartrx_done


UARTTX_ISR:
#mfc0  $k1, $13
#li    $k0, 0xfffff7ff
#and   $k1, $k1, $k0
#mtc0  $k1, $13
li   $k0, 0x1000f004   #adress of in_index
lw   $k0, 0($k0)
li   $k1, 0x1000f00c   #adress of out_index
lw   $k1, 0($k1)
nop
bne  $k1, $k0, not_empty

li    $k0, 0x1000f008  #empty flag
addiu $k1, $0, 1
sw    $k1, 0($k0)
j    uarttx_done

not_empty:

li    $k0, 0x1000ff00 
addu  $k1, $k0, $k1  #address of byte to read
lbu   $k0, 0($k1)    #load byte from buffer(intex_out)
li    $k1, 0x80000008
sb    $k0, 0($k1)    #write to UART

li    $k0, 0x1000f008 #empty flag
sw    $0, 0($k0)      #not empty

li    $k0, 0x1000f00c   #adress of out_index  (the value of out-index is an integer)
lw    $k1, 0($k0)       #this gives u the index that out_index is pointing to (an intgeger like 2 or 19)
addiu $k1, $k1, 1
andi  $k1, $k1, 255    #wrap around
sw    $k1, 0($k0)

j     uarttx_done


FRAME_ISR:
#mfc0  $k1, $13     
#li    $k0, 0xffffefff
#and   $k1, $k1, $k0
#mtc0  $k1, $13

li    $k0, 0x1000f020
lw    $k1, 0($k0)
addiu $k1, $k1, 1
sw    $k1, 0($k0)
j frame_done

GP_ISR:
#mfc0  $k0, $13     
#li    $k0, 0xffffdfff
#and   $k1, $k1, $k0
#mtc0  $k0, $13

li    $k0, 0x1000f030
li    $k1, 0x1
sw    $k1, 0($k0)
j gp_done



done:     # eret would be shorter


li $k0, 0x1000f050
lw $t0, 0($k0)
lw $t1, 4($k0)

mfc0 $k0, $14
mfc0 $k1, $12
ori  $k1, $k1, 1    #enable the interrupts
mtc0 $k1, $12
jr   $k0












