.section    .start
.global     _start

_start:

addiu $s7, $0, 0x0
# Test 1

li $s0, 0x00000020
addiu $t0, $0, 0x20
addiu $s7, $s7, 1 # register to hold the test number (in case of failure)
bne $t0, $s0, Error
j Done

Error:
# Perhaps write the test number over serial

Done:
# Write success over serial
