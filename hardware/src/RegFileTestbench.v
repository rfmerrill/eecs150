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
  
  reg [31:0] testdata;
  reg [31:0] testdata2;

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
    ra1 = 5'b11;
    ra2 = 5'b10;
    
    wa = 5'b0;
    wd = 32'hFFFF;
    we = 1'b1;
    
    #(Cycle);
    
    ra1 = 5'b0;
    ra2 = 5'b0;
    
    #1;
    
    if (rd1 !== 32'b0) begin
      $display("FAIL: rd1 not zero!");
      $finish();
    end
    
    if (rd2 !== 32'b0) begin
      $display("FAIL: rd2 not zero!");
      $finish();
    end
    // Verify that data written to any other register is returned the same
    // cycle
    
    wa = {$random} & 5'b11111;
    ra1 = wa;
    ra2 = wa;
    
    testdata = {$random} & 32'hFFFF;
    
    wd = testdata;
    
    #(Cycle);
    
    if (rd1 !== testdata) begin
      $display("FAIL! rd1 incorrect output!");
      $finish();
    end
    
    if (rd2 !== testdata) begin
      $display("FAIL! rd2 incorrect output!");
      $finish();
    end
    
    // Verify that the we pin prevents data from being written

    testdata2 = {$random} & 32'hFFFF;
    
    we = 1'b0;
    wd = testdata2;
    
    #(Cycle);
    
    if (rd1 !== testdata) begin
      $display("FAIL! rd1 incorrect output! (we disabled)");
      $finish();
    end
    
    if (rd2 !== testdata) begin
      $display("FAIL! rd2 incorrect output! (we disabled)");
      $finish();
    end
    

    // Verify the reads are asynchronous
    
    ra1 = 5'b0;
    ra2 = 5'b0;
    
    #1;
    
    if (rd1 !== 32'b0) begin
      $display("FAIL: rd1 not zero! (asynch test)");
      $finish();
    end
    
    if (rd2 !== 32'b0) begin
      $display("FAIL: rd2 not zero! (asynch test)");
      $finish();
    end
    
    ra1 = wa;
    ra2 = wa;
    
    #1;
    
    if (rd1 !== testdata) begin
      $display("FAIL! rd1 incorrect output! (asynch test)");
      $finish();
    end
    
    if (rd2 !== testdata) begin
      $display("FAIL! rd2 incorrect output! (asynch test)");
      $finish();
    end
   
    $display("All tests passed!");
    $finish();
  end
endmodule
