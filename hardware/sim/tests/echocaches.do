start EchoTestbench
file copy -force ../../../software/echo/echo.mif bios_mem.mif
add wave EchoTestbenchCaches/*
add wave EchoTestbenchCaches/mem_arch/*
add wave EchoTestbenchCaches/mem_arch/dcache/*
add wave EchoTestbenchCaches/mem_arch/icache/*
add wave EchoTestbenchCaches/DUT/dpath/*
add wave EchoTestbenchCaches/DUT/ctrl/*
add wave EchoTestbenchCaches/DUT/dpath/ua/*
add wave EchoTestbenchCaches/DUT/dpath/regfile/*
run 10000us
