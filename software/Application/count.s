        .text
        .globl  count_100mil_register 
        .align  2
        .type   count_100mil_register,function
        .ent    count_100mil_register

count_100mil_register:
	li $t0, 0x0
	li $t1, 0x5F5E100
loopA:	addiu $t0, $t0, 1
        bne $t0, $t1, loopA
        jr $ra

        .globl  count_100mil_register_f
        .align  2
        .type   count_100mil_register_f,function
        .ent    count_100mil_register_f



count_100mil_register_f:
        li $t0, 0x0
        li $t1, 0x5F5E100
        or $t2, $ra, $0
loopB:   jal incr
        bne $t0, $t1, loopB

        jr $t2

incr:   addiu $t0, $t0, 1
        jr $ra 
