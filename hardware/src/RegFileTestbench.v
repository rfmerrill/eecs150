// If #1 is in the initial block of your testbench, time advances by
// 1ns rather than 1ps
`timescale 1ns / 1ps

module RegFileTestbench();

  parameter Halfcycle = 5; //half period is 5ns

  localparam Cycle = 2*Halfcycle;

  reg Clock;

  // Clock Sinal generation:
  initial Clock = 0; 
  always #(Halfcycle) Clock = ~Clock;

  // Register and wires to test the RegFile
  reg [4:0] ra1;
  reg [4:0] ra2;
  reg [4:0] wa;
  reg we;
  reg [31:0] wd;
  wire [31:0] rd1;
  wire [31:0] rd2;

  RegFile DUT(.clk(Clock),
              .we(we),
              .ra1(ra1),
              .ra2(ra2),
              .wa(wa),
              .wd(wd),
              .rd1(rd1),
              .rd2(rd2));
  

  // Testing logic:
  initial begin
    #1;
    // Verify that writing to reg 0 is a nop
    
    // Verify that data written to any other register is returned the same
    // cycle
    
    // Verify that the we pin prevents data from being written

    // Verify the reads are asynchronous
   
    $display("All tests passed!");
    $finish();
  end
endmodule
