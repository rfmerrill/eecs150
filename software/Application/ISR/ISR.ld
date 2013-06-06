SECTIONS
{
    . = 0xc0000180;
    .text : {
        * (.start);
        * (.text);
    }
}
