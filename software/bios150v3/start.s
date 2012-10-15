.section    .start
.global     _start

_start:
    li      $sp, 0x10003000
    jal     main
