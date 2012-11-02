SECTIONS
{
    . = 0xC0000000;
    .text : {
        * (.start);
        * (.text);
    }
}
