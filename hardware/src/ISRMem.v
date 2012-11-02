// I hate coregen, let's just infer this one.

module ISRMem (input  clk,
               input  stall,
               input  we,
               input  [11:0] wa,
               input  [31:0] wd,
               input  [11:0] ra,
               output reg [31:0] rd );

  reg [31:0] contents[0:4095];
    
  always @(posedge clk) begin
    if (~stall)
      rd <= contents[ra];
    if (we)
      contents[wa] <= wd;
  end

endmodule
