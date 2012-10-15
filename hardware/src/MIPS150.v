module MIPS150(
    input clk,
    input rst,

    // Serial
    input FPGA_SERIAL_RX,
    output FPGA_SERIAL_TX,

    // Memory system connections
    output [31:0] dcache_addr,
    output [31:0] icache_addr,
    output [3:0] dcache_we,
    output [3:0] icache_we,
    output dcache_re,
    output icache_re,
    output [31:0] dcache_din,
    output [31:0] icache_din,
    input [31:0] dcache_dout,
    input [31:0] instruction,
    input stall
);

// Use this as the top-level module for your CPU. You
// will likely want to break control and datapath out
// into separate modules that you instantiate here.

endmodule
