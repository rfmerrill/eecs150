.section    .start
.global     _start

_start:
    li      $sp, 0x10004000
    jal     main
