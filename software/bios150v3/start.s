.section    .start
.global     _start

_start:
    li      $sp, 0x10010000
    jal     main
