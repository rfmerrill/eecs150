SECTIONS
{
    . = 0x30000000;
    .text : {
        * (.start);
        * (.text);
    }
}
