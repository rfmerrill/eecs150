SECTIONS
{
    . = 0x30004000;
    .text : {
        * (.start);
        * (.text);
    }
}
