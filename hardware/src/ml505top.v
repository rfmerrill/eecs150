module ml505top
(
  input        FPGA_SERIAL_RX,
  output       FPGA_SERIAL_TX,
  input        GPIO_SW_C,
  output 	GPIO_COMPLED_S,
  input 	GPIO_DIP_0, 
  input        USER_CLK
);
  wire rst;
  
  reg [1:0]  reset_r;
  reg [15:0] count_r;
  
  wire [1:0]  next_reset_r;
  wire [15:0] next_count_r;
  
  wire user_clk_g;
  
  wire cpu_clk;
  wire cpu_clk_g;
  
  wire pll_lock;
  wire ctrl_lock;
  
  reg stall;
   							
  PLL_BASE
  #(
    .BANDWIDTH("OPTIMIZED"),
    .CLKFBOUT_MULT(30),
    .CLKFBOUT_PHASE(0.0),
    .CLKIN_PERIOD(10.0),
  
    .CLKOUT0_DIVIDE(12),
    .CLKOUT0_DUTY_CYCLE(0.5),
    .CLKOUT0_PHASE(0.0),
  
    .CLKOUT1_DIVIDE(6),
    .CLKOUT1_DUTY_CYCLE(0.5),
    .CLKOUT1_PHASE(0.0),
  
    .CLKOUT2_DIVIDE(6),
    .CLKOUT2_DUTY_CYCLE(0.5),
    .CLKOUT2_PHASE(0.0),
  
    .CLKOUT3_DIVIDE(6),
    .CLKOUT3_DUTY_CYCLE(0.5),
    .CLKOUT3_PHASE(0.0),
  
    .CLKOUT4_DIVIDE(6),
    .CLKOUT4_DUTY_CYCLE(0.5),
    .CLKOUT4_PHASE(0.0),
  
    .CLKOUT5_DIVIDE(6),
    .CLKOUT5_DUTY_CYCLE(0.5),
    .CLKOUT5_PHASE(0.0),
  
    .COMPENSATION("SYSTEM_SYNCHRONOUS"),
    .DIVCLK_DIVIDE(5),
    .REF_JITTER(0.100)
  )
  user_clk_pll
  (
    .CLKFBOUT(pll_fb),
    .CLKOUT0(cpu_clk),
    .CLKOUT1(),
    .CLKOUT2(),
    .CLKOUT3(),
    .CLKOUT4(),
    .CLKOUT5(),
    .LOCKED(pll_lock),
    .CLKFBIN(pll_fb),
    .CLKIN(user_clk_g),
    .RST(1'b0)
  );
  
  IBUFG user_clk_buf
  (
    .I(USER_CLK),
    .O(user_clk_g)
  );
  
  BUFG cpu_clk_buf
  (
    .I(cpu_clk),
    .O(cpu_clk_g)
  );
  
  IDELAYCTRL delay_ctrl
  (
    .RDY(ctrl_lock),
    .REFCLK(cpu_clk_g), 
    .RST(~pll_lock)
  );

  always @(posedge cpu_clk_g)
  begin
    reset_r <= next_reset_r;
    count_r <= next_count_r;
  end
  
  assign next_reset_r = {reset_r[0:0], GPIO_SW_C};
  
  assign rst = count_r == 16'h000F | ~pll_lock | ~ctrl_lock;
  
  assign next_count_r
  = (reset_r[1:1])     ? 16'h0001
  : (count_r == 15'b0) ? 16'h0000
  : count_r + 1;

  // Temporary code for testing checkpoint 2:
  assign GPIO_COMPLED_S = GPIO_DIP_0;
   
  always@(posedge cpu_clk_g) begin
      if(rst) begin
          stall <= 1'b0;
      end
      else begin
  	  if(GPIO_DIP_0)
            stall <= ~stall;
      	  else
      	    stall <= 1'b0;
  	  end
 end

  // MIPS 150 CPU
  MIPS150 CPU(
      .clk(cpu_clk_g),
      .rst(rst),
      .stall(stall),
      .FPGA_SERIAL_RX(FPGA_SERIAL_RX),
      .FPGA_SERIAL_TX(FPGA_SERIAL_TX)
  );
  
endmodule
