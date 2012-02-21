start EchoTestbench
file copy -force ../../../software/echo/echo.mif imem_blk_mem.mif
file copy -force ../../../software/echo/echo.mif dmem_blk_mem.mif
add wave echotestbench/*
add wave echotestbench/CPU/*
run 10000us
