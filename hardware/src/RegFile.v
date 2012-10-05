//-----------------------------------------------------------------------------
//  Module: RegFile
//  Desc: An array of 32 32-bit registers
//  Inputs Interface:
//    clk: Clock signal
//    ra1: first read address (asynchronous)
//    ra2: second read address (asynchronous)
//    wa: write address (synchronous)
//    we: write enable (synchronous)
//    wd: data to write (synchronous)
//  Output Interface:
//    rd1: data stored at address ra1
//    rd2: data stored at address ra2
//  Author: <<YOUR NAME HERE>>
//-----------------------------------------------------------------------------

module RegFile(input clk,
               input we,
               input  [4:0] ra1, ra2, wa,
               input  [31:0] wd,
               output reg [31:0] rd1, rd2);

  reg [31:0] contents[0:31];

  always @(*) begin
    rd1 = (ra1 == 5'b0) ? 32'b0 : contents[ra1];
    rd2 = (ra2 == 5'b0) ? 32'b0 : contents[ra2];
  end
  
  always @(posedge clk) begin
    if (we && (wa != 5'b0))
      contents[wa] <= wd;
  end

endmodule
