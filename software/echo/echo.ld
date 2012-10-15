SECTIONS
{
    . = 0x10003000;
    .text : {
        * (.start);
        * (.text);
    }
}
