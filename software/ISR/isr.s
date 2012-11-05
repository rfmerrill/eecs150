

.section    .start
.global     _start

_start:
#    li      $sp, 0x10001000
#    jal     main


#mfc0 $k0, $13
#li   $k1, 0x100ff018
#sw   $k0, 0($k1)

#mfc0 $k0, $12
#li   $k1, 0x100ff01c
#sw   $k0, 0($k1) 

mfc0 $k0, $13
mfc0 $k1, $12
andi $k1, $k1, 0xfc00
and  $k0, $k0, $k1
andi $k1, $k0, 0x8000
bne  $k1, $0, timer_ISR
andi $k1, $k0, 0x4000
bne  $k1, $0, RTC_ISR
andi $k1, $k0, 0x0800    #11 <<1 
bne  $k1, $0, UARTTX_ISR
andi $k1, $k0, 0x0400    # 10 << 1
bne  $k1, $0, UARTRX_ISR
j    done




timer_ISR:  # print mm:ss every second

mfc0 $k1, $11
li   $k0, 0x02faf080
addu $k0, $k0, $k1
mtc0 $k0, $11

li   $k1, 0x1000f104  # seconds
lbu   $k0, 0($k1)      # load it
addiu $k0, $k0, 1     # add one
addiu $k1, $k0, 0xFFF6 # subtract 10
beq   $k1, $0, inc_second_tens
# store seconds
li   $k1, 0x1000f104
sb   $k0, 0($k1)
j    time_done

inc_second_tens:
li   $k1, 0x1000f104  #seconds
sb    $0, 0($k1)  #zero it
addiu $k1, $k1, 1  #second (tens digit)
lbu   $k0, 0($k1)      # load it
addiu $k0, $k0, 1     # add one
addiu $k1, $k0, 0xFFFA # subtract 6
beq   $k1, $0, inc_minute
# store second (tens digit)
li    $k1, 0x1000f105
sb    $k0, 0($k1)
j     time_done

inc_minute:
li   $k1, 0x1000f105  #seconds (tens)
sb    $0, 0($k1)  #zero it
addiu $k1, $k1, 1  #minutes
lbu   $k0, 0($k1)      # load it
addiu $k0, $k0, 1     # add one
addiu $k1, $k0, 0xFFF6 # subtract 10
beq   $k1, $0, inc_minute_tens
# store minute
li    $k1, 0x1000f106
sb    $k0, 0($k1)
j     time_done


inc_minute_tens:
li  $k1, 0x1000f106 #minutes (ones digit)
sw  $0, 0($k1)      #set to zero
addiu $k1, $k1, 1   #tens digit
lbu  $k0, 0($k1)
addiu $k0, $k0, 1
sb  $k0, 0($k1)



time_done: 
li   $k0, 0x1000f300    #load enable address
#addi $k1, $0, 0x1    #load 1 into $k1
lw   $k0, 0($k0)
beq  $0, $k0, no_print  #check if enable is high


# print
# 0x30 -- '0', 0x0d = CR, 0x3A = :

#write the initial CR
li   $k0, 0x1000f004  #load in_index
lw   $k1, 0($k0)
li   $k0, 0x1000ff00  #buffer address
addu $k0, $k1, $k0    
li   $k1, 0x0d
sb   $k1, 0($k0)

li   $k0, 0x1000f004  #load in_index
lw   $k1, 0($k0)
addiu $k1, $k1, 1
andi $k1, $k1, 63
li   $k0, 0x1000ff00  #buffer address
addu $k0, $k1, $k0    #address to write to
li   $k1, 0x1000f107  #minutes (tens)
lbu  $k1, 0($k1)      
addiu $k1, $k1, 0x30
sb   $k1, 0($k0)

li   $k0, 0x1000f004  #load in_index
lw   $k1, 0($k0)
addiu $k1, $k1, 2
andi $k1, $k1, 63
li   $k0, 0x1000ff00  #buffer address
addu $k0, $k1, $k0    #address to write to
li   $k1, 0x1000f106  #minutes (ones)
lbu  $k1, 0($k1)      
addiu $k1, $k1, 0x30
sb   $k1, 0($k0)

li   $k0, 0x1000f004  #load in_index
lw   $k1, 0($k0)
addiu $k1, $k1, 3
andi $k1, $k1, 63
li   $k0, 0x1000ff00  #buffer address
addu $k0, $k1, $k0    #address to write to
addiu $k1, $0, 0x3A   #colon
sb   $k1, 0($k0)


li   $k0, 0x1000f004  #load in_index
lw   $k1, 0($k0)
addiu $k1, $k1, 4
andi $k1, $k1, 63
li   $k0, 0x1000ff00  #buffer address
addu $k0, $k1, $k0    #address to write to
li   $k1, 0x1000f105  #seconds (tens)
lbu  $k1, 0($k1)      
addiu $k1, $k1, 0x30
sb   $k1, 0($k0)

li   $k0, 0x1000f004  #load in_index
lw   $k1, 0($k0)
addiu $k1, $k1, 5
andi $k1, $k1, 63
li   $k0, 0x1000ff00  #buffer address
addu $k0, $k1, $k0    #address to write to
li   $k1, 0x1000f104  #seconds (ones)
lbu  $k1, 0($k1)      
addiu $k1, $k1, 0x30
sb   $k1, 0($k0)

li  $k0, 0x1000f004
lw  $k1, 0($k0)
addiu $k1, $k1, 6
andi $k1, $k1, 63
sw  $k1, 0($k0)

li  $k0, 0x80000000
lw  $k0, 0($k0)
bne $k0, $0, UARTTX_ISR

no_print:
#setting the compare register does this for us, not necessary.
#mfc0 $k1, $13
#li   $k0, 0xffff7fff
#and  $k1, $k1, $k0
#mtc0 $k1, $13
j    done



RTC_ISR:
mfc0  $k1, $13     
li    $k0, 0xffffbfff
and   $k1, $k1, $k0
mtc0  $k1, $13
li    $k1, 0x1000f10c  #adress of SW_RTC
lw    $k0, 0($k1)
addiu $k0, $k0, 0x1
sw    $k0, 0($k1)   #write back incremented SW_RTC 
#li    $k1, 0x100ff010  #let's write the value of count here.
#mfc0  $k0, $9
#sw    $k0, 0($k1)
mtc0  $0, $9
j done




UARTRX_ISR:   # state = input character
mfc0 $k1, $13
li   $k0, 0xfffffbff
and  $k1, $k1, $k0
mtc0 $k1, $13

li  $k0, 0x8000000c    #data from receiever address
lbu $k0, 0($k0)        #$k0 contains the value of data from receviver a word
li  $k1, 0x65   # 'e'
beq $k0, $k1, enable_time
li  $k1, 0x64   # 'd'
beq $k0, $k1, disable_time 

li  $k1, 0x1000f200    #load adress of State variable
sb  $k0, 0($k1)

j done

enable_time:
li  $k0, 0x1
li  $k1, 0x1000f300    #enable flag
sw  $k0, 0($k1)
j done

disable_time:
li  $k1, 0x1000f300
sw  $0,  0($k1)
j done


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
beq  $k1, $k0, tx_done    #nothing to write

li    $k0, 0x1000ff00 
addu  $k1, $k0, $k1  #address of byte to read
lbu   $k0, 0($k1)    #load byte from buffer(intex_out)
li    $k1, 0x80000008
sb    $k0, 0($k1)    #write to UART

li    $k0, 0x1000f00c   #adress of out_index  (the value of out-index is an integer)
lw    $k1, 0($k0)       #this gives u the index that out_index is pointing to (an intgeger like 2 or 19)
addiu $k1, $k1, 1
andi  $k1, $k1, 63    #wrap around
sw    $k1, 0($k0)

tx_done:
mfc0  $k1, $13
li    $k0, 0xfffff7ff
and   $k1, $k1, $k0
mtc0  $k1, $13

j     done 



done:     # eret would be shorter

mfc0 $k0, $14
mfc0 $k1, $12
ori  $k1, $k1, 1    #enable the interrupts
mtc0 $k1, $12
jr   $k0












