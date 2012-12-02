.section    .start
.global     _start

_start:
    li      $sp, 0x30008000
    jal     main



