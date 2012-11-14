module ml505top
(
  input        FPGA_SERIAL_RX,
  output       FPGA_SERIAL_TX,
  input        GPIO_SW_C,
  input        GPIO_SW_S,
  input        USER_CLK,

  output [7:0] GPIO_LED,

  output [12:0] DDR2_A,
  output [1:0]  DDR2_BA,
  output        DDR2_CAS_B,
  output        DDR2_CKE,
  output [1:0]  DDR2_CLK_N,
  output [1:0]  DDR2_CLK_P,
  output        DDR2_CS_B,
  inout  [63:0] DDR2_D,
  output [7:0]  DDR2_DM,
  inout  [7:0]  DDR2_DQS_N,
  inout  [7:0]  DDR2_DQS_P,
  output        DDR2_ODT,
  output        DDR2_RAS_B,
  output        DDR2_WE_B,
    
  output [11:0] DVI_D,
  output        DVI_DE,
  output        DVI_H,
  output        DVI_RESET_B,
  output        DVI_V,
  output        DVI_XCLK_N,
  output        DVI_XCLK_P,
  
  inout         IIC_SCL_VIDEO,
  inout         IIC_SDA_VIDEO
);

  reg [3:0]  reset_r = 4'b0;
  reg [25:0] count_r = 26'b0;

  wire [3:0]  next_reset_r;
  wire [25:0] next_count_r;

  wire user_clk_g;

  wire cpu_clk;
  wire cpu_clk_g;

  wire clk0;
  wire clk0_g;

  wire clk90;
  wire clk90_g;

  wire clkdiv0;
  wire clkdiv0_g;

  wire clk200;
  wire clk200_g;

  wire pll_lock;

  wire clk50;
  wire clk50_g;

  PLL_BASE
  #(
    .BANDWIDTH("OPTIMIZED"),
    .CLKFBOUT_MULT(24),
    .CLKFBOUT_PHASE(0.0),
    .CLKIN_PERIOD(10.0),

    .CLKOUT0_DIVIDE(12),
    .CLKOUT0_DUTY_CYCLE(0.5),
    .CLKOUT0_PHASE(0.0),

    .CLKOUT1_DIVIDE(3),
    .CLKOUT1_DUTY_CYCLE(0.5),
    .CLKOUT1_PHASE(0.0),

    .CLKOUT2_DIVIDE(3),
    .CLKOUT2_DUTY_CYCLE(0.5),
    .CLKOUT2_PHASE(0.0),

    .CLKOUT3_DIVIDE(3),
    .CLKOUT3_DUTY_CYCLE(0.5),
    .CLKOUT3_PHASE(90.0),

    .CLKOUT4_DIVIDE(6),
    .CLKOUT4_DUTY_CYCLE(0.5),
    .CLKOUT4_PHASE(0.0),

    .CLKOUT5_DIVIDE(12),
    .CLKOUT5_DUTY_CYCLE(0.5),
    .CLKOUT5_PHASE(0.0),

    .COMPENSATION("SYSTEM_SYNCHRONOUS"),
    .DIVCLK_DIVIDE(4),
    .REF_JITTER(0.100)
  )
  user_clk_pll
  (
    .CLKFBOUT(pll_fb),
    .CLKOUT0(cpu_clk),
    .CLKOUT1(clk200),
    .CLKOUT2(clk0),
    .CLKOUT3(clk90),
    .CLKOUT4(clkdiv0),
    .CLKOUT5(clk50),
    .LOCKED(pll_lock),
    .CLKFBIN(pll_fb),
    .CLKIN(user_clk_g),
    .RST(1'b0)
  );

  IBUFG user_clk_buf ( .I(USER_CLK), .O(user_clk_g) );
  BUFG  cpu_clk_buf  ( .I(cpu_clk),  .O(cpu_clk_g)  );
  BUFG  clk200_buf   ( .I(clk200),   .O(clk200_g)   );
  BUFG  clk0_buf     ( .I(clk0),     .O(clk0_g)     );
  BUFG  clkdiv50_buf ( .I(clk50),    .O(clk50_g)    );
  BUFG  clk90_buf    ( .I(clk90),    .O(clk90_g)    );
  BUFG  clkdiv0_buf  ( .I(clkdiv0),  .O(clkdiv0_g)  );

  always @(posedge cpu_clk_g)
  begin
    reset_r <= next_reset_r;
    count_r <= next_count_r;
  end

  assign next_reset_r = {reset_r[2:0], GPIO_SW_C};

  assign rst = (count_r == 26'b1) | ~pll_lock;

  assign next_count_r
    = (count_r == 26'b0) ? (reset_r[3] ? 26'b1 : 26'b0)
    :                      count_r + 1;

  // Reset shift register:
  reg [2:0] rst_sr;
  wire fifo_reset; // fifo_reset resets fifos... reset_fifo is a fifo for the reset signal.
  assign fifo_reset = rst | (|rst_sr);
  always @(posedge cpu_clk_g) begin
    rst_sr <= {rst_sr[1:0], rst};
  end


  wire  [31:0] dcache_addr;
  wire  [31:0] icache_addr;
  wire  [3:0]  dcache_we;
  wire  [3:0]  icache_we;
  wire         dcache_re;
  wire         icache_re;
  wire  [31:0] dcache_din;
  wire  [31:0] icache_din;
  wire [31:0]  dcache_dout;
  wire [31:0]  instruction;
  wire         stall;
  wire         video_ready;
  wire         dvi_video_ready;
  wire         video_valid;
  wire [23:0]  video;
  wire [23:0]  filler_color;
  wire         filler_ready;
  wire         filler_valid;
  wire         line_ready;
  wire  [31:0] line_color;
  wire  [9:0]  line_point;
  wire         line_color_valid;
  wire         line_x0_valid;
  wire         line_y0_valid;
  wire         line_x1_valid;
  wire         line_y1_valid;
  wire         line_trigger;
  
  wire fb0;
   wire frame_interrupt;
   wire [31:0] gp_code;
   wire [31:0] gp_frame;
   wire        gp_valid;
   
  
  Memory150 #(.SIM_ONLY(1'b0)) mem_arch(
      .cpu_clk_g(cpu_clk_g),
      .clk0_g(clk0_g),
      .clk200_g(clk200_g),
      .clkdiv0_g(clkdiv0_g),
      .clk90_g(clk90_g),
      .clk50_g(clk50_g),
      .rst(fifo_reset),
      .init_done(init_done),
      .DDR2_A(DDR2_A),
      .DDR2_BA(DDR2_BA),
      .DDR2_CAS_B(DDR2_CAS_B),
      .DDR2_CKE(DDR2_CKE),
      .DDR2_CLK_N(DDR2_CLK_N),
      .DDR2_CLK_P(DDR2_CLK_P),
      .DDR2_CS_B(DDR2_CS_B),
      .DDR2_D(DDR2_D),
      .DDR2_DM(DDR2_DM),
      .DDR2_DQS_N(DDR2_DQS_N),
      .DDR2_DQS_P(DDR2_DQS_P),
      .DDR2_ODT(DDR2_ODT),
      .DDR2_RAS_B(DDR2_RAS_B),
      .DDR2_WE_B(DDR2_WE_B),
      .locked(pll_lock),
      .dcache_addr(dcache_addr),     
      .icache_addr(icache_addr),         
      .dcache_we  (dcache_we  ),  
      .icache_we  (icache_we  ),  
      .dcache_re  (dcache_re  ),  
      .icache_re  (icache_re  ),  
      .dcache_din (dcache_din ), 
      .icache_din (icache_din ), 
      .dcache_dout(dcache_dout),
      .icache_dout(instruction),
      .stall      (stall      ),
      .video      (video      ),
      .video_ready(video_ready),
      .video_valid(video_valid),
      .cpu_gp_code(gp_code),
      .cpu_gp_frame(gp_frame),
      .cpu_gp_valid(gp_valid),
      .frame_interrupt(frame_interrupt)
    );
  
  // MIPS 150 CPU
  MIPS150 CPU(
    .clk(cpu_clk_g),
    .rst(rst || ~init_done),
    .stall(stall),
    .FPGA_SERIAL_RX(FPGA_SERIAL_RX),
    .FPGA_SERIAL_TX(FPGA_SERIAL_TX),
    .dcache_addr (dcache_addr ),
    .icache_addr (icache_addr ),
    .dcache_we   (dcache_we   ),
    .icache_we   (icache_we   ),
    .dcache_re   (dcache_re   ),
    .icache_re   (icache_re   ),
    .dcache_din  (dcache_din  ),
    .icache_din  (icache_din  ),
    .dcache_dout (dcache_dout ),
    .instruction (instruction ),
    .gp_code(cpu_gp_code),
    .gp_frame(cpu_gp_frame),
    .gp_valid(cpu_gp_valid),
    .frame_interrupt(frame_interrupt)
  ); //add GP_CODE, GP_FRAME, and GP_valid io here and pixel feeder interrupt

  DVI #(
    .ClockFreq(                 50000000),
    .Width(                     1040),   
    .FrontH(                    56),     
    .PulseH(                    120),    
    .BackH(                     64),    
    .Height(                    666),    
    .FrontV(                    37),      
    .PulseV(                    6),      
    .BackV(                     23)      
  ) dvi(         
    .Clock(                     cpu_clk_g),
    .Reset(                     rst || ~init_done),
    .DVI_D(                     DVI_D),
    .DVI_DE(                    DVI_DE),
    .DVI_H(                     DVI_H),
    .DVI_V(                     DVI_V),
    .DVI_RESET_B(               DVI_RESET_B),
    .DVI_XCLK_N(                DVI_XCLK_N),
    .DVI_XCLK_P(                DVI_XCLK_P),
    .I2C_SCL_DVI(               IIC_SCL_VIDEO),
    .I2C_SDA_DVI(               IIC_SDA_VIDEO),
    /* Ready/Valid interface for 24-bit pixel values */
    .Video(                     video),
    .VideoReady(                video_ready),
    .VideoValid(                video_valid)
  );

  assign GPIO_LED = {5'b0, stall, pll_lock, init_done};

endmodule
