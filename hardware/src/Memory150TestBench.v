//----------------------------------------------------------------------
// Module: Memory150TestBench.v
// Authors: Dan Yeager, James Parker, Daiwei Li
// This module performs high level cache reads/writes
// which tests Memory150 and DDR2 as well as submodules
// such as the cache, clock crossing FIFOs and request handling.
//
// *** NOTES ***
// To turn off DDR2 info messages (greatly improves sim speed)
//  Set "DEBUG = 0" in src/mig_v3_61/ddr2_model_parameters.vh
//
// Also use sim_only to improve speed: Memory150 #(.SIM_ONLY(1'b1))
//----------------------------------------------------------------------

`timescale 1ns / 1ps

`define MODELSIM 1

module Memory150TestBench();
    // Test bench generates a reset
    reg Reset;

    parameter HalfCycle = 5;
    localparam Cycle = 2*HalfCycle;	
    reg	Clock; // feeds BUF -> usr_clk_g -> pll -> cpu_clk_g
    initial Clock	= 0;	
    always #(HalfCycle) Clock= ~Clock;

    // Test log variables
    localparam TB_DEBUG_OUT = 1;
    integer numFails,     ccDelayCnt;
    integer readNumD,     writeNumD;
    integer readNumI,     writeNumI;
    integer writeNumLine;
    integer writeNumPixel;
    reg [8*21:0] StrRW; // "read" or "write"

    localparam MAX_STALLS = 50; // simple time-out

    localparam HEARTBEAT = 1000; // 1 unit = 10ns (see $timeformat)
    integer ccCnt;

    // DDR 2 wires
    wire [12:0] DDR2_A;
    wire [1:0] DDR2_BA;
    wire DDR2_CAS_B;
    wire DDR2_CKE;
    wire [1:0] DDR2_CLK_N;
    wire [1:0] DDR2_CLK_P;
    wire DDR2_CS_B;
    wire [63:0]  DDR2_D;
    wire [7:0]   DDR2_DM;
    wire [7:0]   DDR2_DQS_N;
    wire [7:0]   DDR2_DQS_P;
    wire DDR2_ODT;
    wire DDR2_RAS_B;
    wire DDR2_WE_B;

    // PLL wires
    wire user_clk_g;
    wire cpu_clk;
    wire cpu_clk_g;
    wire clk0;
    wire clk0_g;
    wire clk50;
    wire clk50_g;
    wire clk90;
    wire clk90_g;
    wire clkdiv0;
    wire clkdiv0_g;
    wire clk200;
    wire clk200_g;
    wire pll_lock;

    // Memory150, CPU wires
    reg  [3:0]  dcache_we;
    reg  [3:0]  icache_we;
    reg         dcache_re;
    reg         icache_re;
    reg  [31:0] dcache_din;
    reg  [31:0] icache_din;
    reg  [31:0] d_addr;
    reg  [31:0] PC;
    wire [31:0] dcache_dout;
    wire [31:0] instruction;
    wire        stall;
    wire        init_done;


    // DVI interface:
    wire [23:0] video;
    wire        video_valid;
    reg         video_ready;

    // Modular cache testing procedures
    `include "CacheTestTasks.vh"

    PLL_BASE
    #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKFBOUT_MULT(32),
        .CLKFBOUT_PHASE(0.0),
        .CLKIN_PERIOD(10.0),

        .CLKOUT0_DIVIDE(16),
        .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT0_PHASE(0.0),

        .CLKOUT1_DIVIDE(4),
        .CLKOUT1_DUTY_CYCLE(0.5),
        .CLKOUT1_PHASE(0.0),

        .CLKOUT2_DIVIDE(4),
        .CLKOUT2_DUTY_CYCLE(0.5),
        .CLKOUT2_PHASE(0.0),

        .CLKOUT3_DIVIDE(4),
        .CLKOUT3_DUTY_CYCLE(0.5),
        .CLKOUT3_PHASE(90.0),

        .CLKOUT4_DIVIDE(8),
        .CLKOUT4_DUTY_CYCLE(0.5),
        .CLKOUT4_PHASE(0.0),

        .CLKOUT5_DIVIDE(16),
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

    IBUFG user_clk_buf ( .I(Clock),    .O(user_clk_g) );
    BUFG  cpu_clk_buf  ( .I(cpu_clk),  .O(cpu_clk_g)  );
    BUFG  clk200_buf   ( .I(clk200),   .O(clk200_g)   );
    BUFG  clk0_buf     ( .I(clk0),     .O(clk0_g)     );
    BUFG  clkdiv50_buf ( .I(clk50),    .O(clk50_g)    );
    BUFG  clk90_buf    ( .I(clk90),    .O(clk90_g)    );
    BUFG  clkdiv0_buf  ( .I(clkdiv0),  .O(clkdiv0_g)  );

    mt4htf3264hy ddr2(
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
        .DDR2_WE_B(DDR2_WE_B));

    Memory150 #(.SIM_ONLY(1'b1)) mem_arch(
        .cpu_clk_g(cpu_clk_g),
        .clk0_g(clk0_g),
        .clk200_g(clk200_g),
        .clkdiv0_g(clkdiv0_g),
        .clk90_g(clk90_g),
        .rst(Reset),
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
        .locked     (pll_lock),
        .dcache_addr(d_addr),
        .icache_addr(PC         ),
        .dcache_we  (dcache_we  ),
        .icache_we  (icache_we  ),
        .dcache_re  (dcache_re  ),
        .icache_re  (icache_re  ),
        .dcache_din (dcache_din ),
        .icache_din (icache_din ),
        .dcache_dout(dcache_dout),
        .instruction(instruction),
        .stall      (stall      )
    );

    initial begin
      $timeformat(-9, 1, " ns", 3);
      // $timeformat [ ( n, p, suffix , min_field_width ) ] ;
      //    units = 1 second ** (-n), n = 0->15, e.g. for n = 9, units = ns
      //    p = digits after decimal point for %t e.g. p = 5 gives 0.00000
      //    suffix for %t (despite timescale directive), ex " ns"
      //    min_field_width is number of character positions for %t */
      //#1;
      // Debugging status variables:
      numFails       = 0;
      readNumD       = 0;
      writeNumD      = 0;
      readNumI       = 0;
      writeNumI      = 0;
      writeNumLine   = 0;
      writeNumPixel  = 0;
      ccDelayCnt     = 0;
      // Inputs:
      Reset      = 1;
      icache_re  = 0;
      dcache_re  = 0;
      icache_we  = 4'b0;
      dcache_we  = 4'b0;
      dcache_din = 32'b0;
      icache_din = 32'b0;
      d_addr     = 32'h00000000;
      PC         = 32'b0;
      video_ready= 0;
      repeat (10) @( posedge cpu_clk_g ) ; // reset for 10 cc

      Reset = 0;
      @( posedge cpu_clk_g ) ;

      @( posedge init_done ) ; // wait for ddr init done
      @( posedge cpu_clk_g ) ;

      // 25 combinations of events - for each cache:
      //   1. No Read or Write
      //   2. Read Hit
      //   3. Write Hit
      //   4. Writeback
      //   5. Fetch

      PerformanceCacheExample();

      repeat (10) @( posedge cpu_clk_g ) ;

      ICacheIdleTest_WT();
      ICacheReadHitTest_WT();

      // A few of these are illegal:
      // ICache only written in bios mode,
      // I&D caches should write to same addr.

      if(numFails == 0) begin
        $display(" All tests PASSED ");
      end else begin
        $display(" ** FAIL ** ");
        $display("%d tests failed.", numFails);
      end

      repeat (10) @( posedge cpu_clk_g ) ;

      $finish();
   end

  always @ (posedge cpu_clk_g) begin
    if(ccCnt < HEARTBEAT) begin
      ccCnt = ccCnt + 1;
    end else begin
      ccCnt = 0;
      $display("TB: Time = %t", $time);
    end
  end

  task ExampleTest;
  begin
    $display("--- Start Simple Test ---");
    // Try storing a word, no eviction:
    SingleCacheWrite(`DCACHE, 32'h00000000, 32'h12345678, 4'b1111, 1'b0);

    // Try storing again, no hit on write-no-allocate:
    SingleCacheWrite(`DCACHE, 32'h00000000, 32'h12345678, 4'b1111, 1'b0);

    // Not a hit on write-no-allocate:
    SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b0);

    // Then cause the row to be evicted
    SingleCacheWrite(`DCACHE, 32'h00100000, 32'h12344321, 4'b1111, 1'b0);

    // and read it out
    SingleCacheRead(`DCACHE, 32'h00100000, 32'h12344321, 1'b0);

    // now try to read the original data:
    SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b0);
    $display("--- End Simple Test ---");
  end
  endtask

  task ICacheIdleTest_WT;
      begin
          $display("--------------------------");
          $display("--- Start I$ Idle Test ---");
          $display("--------------------------");
          // Try storing a word and reading it, no eviction:
          // Write (miss)
          SingleCacheWrite(`DCACHE, 32'h00000000, 32'h12345678, 4'b1111, 1'b0);
          // Read miss
          SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b0);
          // Read hit
          SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b1);

          // Write (hit)
          SingleCacheWrite(`DCACHE, 32'h00000000, 32'hdeadbeef, 4'b1111, 1'b0);
          // Read miss
          SingleCacheRead(`DCACHE, 32'h00000000, 32'hdeadbeef, 1'b1);
          // Write (hit)
          SingleCacheWrite(`DCACHE, 32'h00000000, 32'h12345678, 4'b1111, 1'b0);
          // Read miss
          SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b1);

          // Then cause the row to be evicted
          // Write (miss)
          SingleCacheWrite(`DCACHE, 32'h00100000, 32'h12344321, 4'b1111, 1'b0);

          // and read it out
          // Read miss
          SingleCacheRead(`DCACHE, 32'h00100000, 32'h12344321, 1'b0);
          // Read hit
          SingleCacheRead(`DCACHE, 32'h00100000, 32'h12344321, 1'b1);

          // now try to read the original data:
          // Read miss
          SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b0);
          // Read hit
          SingleCacheRead(`DCACHE, 32'h00000000, 32'h12345678, 1'b1);
          
          $display("--------------------------");
          $display("---- End I$ Idle Test ----");
          $display("--------------------------");
      end
  endtask

  task ICacheReadHitTest_WT;
      begin
          $display("------------------------------");
          $display("--- Start I$ Read Hit Test ---");
          $display("------------------------------");
         
          // Set up data for ICACHE
          SingleCacheWrite(`ICACHE, 32'h00000000, 32'h12345678, 4'b1111, 1'b0);
          SingleCacheRead(`ICACHE, 32'h00000000, 32'h12345678, 1'b0);
          SingleCacheRead(`ICACHE, 32'h00000000, 32'h12345678, 1'b1);

          // Try storing a word and reading it, no eviction:
          // Write (miss)
          DualCacheIreadDwrite(32'h00000000, 32'h12345678, 4'b1111, 1'b0, 32'h00000000, 32'h12345678, 1'b0);
          // Read miss
          DualCacheRead(32'h00000000, 32'h12345678, 32'h00000000, 32'h12345678);
          // Read hit
          DualCacheRead(32'h00000000, 32'h12345678, 32'h00000000, 32'h12345678);

          // Write (hit)
          DualCacheIreadDwrite(32'h00000000, 32'hdeadbeef, 4'b1111, 1'b0, 32'h00000000, 32'h12345678, 1'b0);
          // Read miss
          DualCacheRead(32'h00000000, 32'hdeadbeef, 32'h00000000, 32'h12345678);
          // Write (hit)
          DualCacheIreadDwrite(32'h00000000, 32'h12345678, 4'b1111, 1'b0, 32'h00000000, 32'h12345678, 1'b0);
          // Read miss
          DualCacheRead(32'h00000000, 32'h12345678, 32'h00000000, 32'h12345678);

          // Then cause the row to be evicted
          // Write (miss)
          DualCacheIreadDwrite(32'h00100000, 32'h12344321, 4'b1111, 1'b0, 32'h00000000, 32'h12345678, 1'b0);

          // and read it out
          // Read miss
          DualCacheRead(32'h00100000, 32'h12344321, 32'h00000000, 32'h12345678);
          // Read hit
          DualCacheRead(32'h00100000, 32'h12344321, 32'h00000000, 32'h12345678);

          // now try to read the original data:
          // Read miss
          DualCacheRead(32'h00000000, 32'h12345678, 32'h00000000, 32'h12345678);
          // Read hit
          DualCacheRead(32'h00000000, 32'h12345678, 32'h00000000, 32'h12345678);
 
          $display("------------------------------");
          $display("---- End I$ Read Hit Test ----");
          $display("------------------------------");
      end
  endtask

  /* Other examples:

      // instruction store (write same to both)
      DualCacheWrite(32'h00000100, 32'h11223344, 4'b1111, 1'b0,
                     32'h00000100, 32'h11223344, 4'b1111, 1'b0);

      // instruction store (read same from both)
      DualCacheRead(32'h00000100, 32'h11223344,
                    32'h00000100, 32'h11223344);

  */

  // Temp vars for performance cache testing
  localparam
    d1  = 32'hABCDDCBA,
    d2  = 32'h11112222,
    d1e  = 32'h33334444,
    d2e  = 32'h55556666;

  localparam // e for eviction address
    a1   = 32'h00000000,
    a1e  = 32'h00100000,
    a2   = 32'h00010000,
    a2e  = 32'h00110000;

  // Read cache at full speed
  // (requires interleaving of requests and verification)
  // ** hit/miss won't work here
  //    because when we interleave, we reset the cycle counter.
  task PerformanceCacheExample;
  begin
    $display("--- Start Performance Cache Test #1 ---");
    $display("ignore cycle counts here");

    // Request 1
    SetupWrite(`ICACHE, a1, d1, 4'b1111);
    SetupWrite(`DCACHE, a2, d2, 4'b1111);
    // (no prior requests to verify)
    ClockInRequest();

    // Request 2
    SetupWrite(`ICACHE, a1e, d1e, 4'b1111);
    SetupWrite(`DCACHE, a2e, d2e, 4'b1111);
    // Verify 1
    VerifyWrite(`ICACHE, 1'bx);
    VerifyWrite(`DCACHE, 1'bx);
    ClockInRequest();

    // Request 3
    SetupRead(`ICACHE, a1);
    SetupRead(`DCACHE, a2);
    VerifyWrite(`ICACHE, 1'bx);
    VerifyWrite(`DCACHE, 1'bx);
    // (could verify request 2 now)
    ClockInRequest();

    // Request 4
    SetupRead(`ICACHE, a1e);
    SetupRead(`DCACHE, a2e);
    // Verify 3
    // Read miss
    VerifyRead(`ICACHE, d1, 0'bx);
    VerifyRead(`DCACHE, d2, 0'bx);
    ClockInRequest();

    // Request 5
    SetupRead(`ICACHE, a1e);
    SetupRead(`DCACHE, a2e);
    // Verify 4
    // Read miss
    VerifyRead(`ICACHE, d1e, 0'bx);
    VerifyRead(`DCACHE, d2e, 0'bx);
    ClockInRequest();

    // Request 5
    // Verify 4
    // Read hit
    VerifyRead(`ICACHE, d1e, 1'bx);
    VerifyRead(`DCACHE, d2e, 1'bx);

    ClockInRequest();
    $display("--- End Performance Cache Test #1 ---");
  end
  endtask

endmodule
