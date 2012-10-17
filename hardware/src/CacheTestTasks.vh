//----------------------------------------------------------------------
// Module: CacheTestTasks.vh
// Authors: Dan Yeager, James Parker, Daiwei Li
// Modular cache testing procedures. 
// See Memory150TestBench.v for usage.

// Note that these run at half speed. There is one cycle of NOP between
//   cache events.  Running at full speed requires interleaving
//   of your requests and verification. Ex, see PerformanceCacheExample.

//----------------------------------------------------------------------

`ifndef CACHE_CONSTANTS
  `define CACHE_CONSTANTS
  `define ICACHE    2'h0
  `define DCACHE    2'h1
  `define LINEENG   2'h2
  `define DIRDRAW   2'h3
`endif

task DualCacheIreadDwrite;
  input [31:0] task_addrD;
  input [31:0] task_cache_dinD;
  input [3:0]  task_cache_weD;
  input        task_expect_hitD;
  input [31:0] task_addrI;
  input [31:0] task_expected_cache_doutI;
  input        task_expect_hitI;
begin
  SetupRead(`ICACHE, task_addrI);
  SetupWrite(`DCACHE, task_addrD, task_cache_dinD, task_cache_weD);
  ClockInRequest();
  // no read/write in pipeline:
  ClockInRequest();
  VerifyRead (`ICACHE, task_expected_cache_doutI, task_expect_hitI);
  VerifyWrite(`DCACHE, task_expect_hitD);
end
endtask

task DualCacheWrite;
  input [31:0] task_addrD;
  input [31:0] task_cache_dinD;
  input [3:0]  task_cache_weD;
  input        task_expect_hitD;
  input [31:0] task_addrI;
  input [31:0] task_cache_dinI;
  input [3:0]  task_cache_weI;
  input        task_expect_hitI;
begin
  SetupWrite(`ICACHE, task_addrI, task_cache_dinI, task_cache_weI);
  SetupWrite(`DCACHE, task_addrD, task_cache_dinD, task_cache_weD);
  ClockInRequest();
  // no read/write in pipeline:
  ClockInRequest();
  VerifyWrite(`ICACHE, 1'bx);
  VerifyWrite(`DCACHE, 1'bx);
end
endtask

task DualCacheRead;
  input [31:0] task_addrD;
  input [31:0] task_expected_cache_doutD;
  input [31:0] task_addrI;
  input [31:0] task_expected_cache_doutI;
begin
  SetupRead(`ICACHE, task_addrI);
  SetupRead(`DCACHE, task_addrD);
  ClockInRequest();
  // no read/write in pipeline:
  ClockInRequest();
  VerifyRead(`ICACHE, task_expected_cache_doutI, 1'bx);
  VerifyRead(`DCACHE, task_expected_cache_doutD, 1'bx);
end
endtask

task SingleCacheWrite;
  input [1:0]  cache_select;
  input [31:0] task_addr;
  input [31:0] task_cache_din;
  input [3:0]  task_cache_we;
  input        task_expect_hit;
begin
  SetupWrite(cache_select, task_addr, task_cache_din, task_cache_we);
  ClockInRequest();
  // no read/write in pipeline:
  ClockInRequest();
  VerifyWrite(cache_select, task_expect_hit);
end
endtask

task SingleCacheRead;
  input [1:0]  cache_select;
  input [31:0] task_addr;
  input [31:0] task_expected_cache_dout;
  input        task_expect_hit;
begin
  SetupRead(cache_select, task_addr);
  ClockInRequest();
  // no read/write in pipeline:
  ClockInRequest();
  //WaitForStall();
  VerifyRead(cache_select, task_expected_cache_dout, task_expect_hit);
end
endtask

// Due to synchronous memory,
// inputs must be setup before clock
task SetupWrite;
  input [1:0]  cache_select;
  input [31:0] task_addr;
  input [31:0] task_cache_din;
  input [3:0]  task_cache_we;
begin
  ccDelayCnt = 1;
  if (cache_select === `DCACHE) begin
    writeNumD = writeNumD + 1; // debugging info
    $display("TB: d-Write #%0d start at %t", writeNumD, $time);
    d_addr = task_addr;
    dcache_din = task_cache_din;
    dcache_we = task_cache_we;
  end else if (cache_select === `ICACHE) begin
    writeNumI = writeNumI + 1; // debugging info
    $display("TB: i-Write #%0d start at %t", writeNumI, $time);
    PC = task_addr;
    icache_din = task_cache_din;
    icache_we = task_cache_we;
  end else if (cache_select === `LINEENG) begin
    writeNumLine = writeNumLine + 1; // debugging info
    $display("TB: line-Write #%0d start at %t", writeNumLine, $time);
    $display("TB: ERROR !!!! not yet implemented");
    /*_addr = task_addr;
    _din = task_cache_din;
    _we = task_cache_we; */
  end else if (cache_select === `DIRDRAW) begin
    writeNumPixel = writeNumPixel + 1; // debugging info
    $display("TB: pixel-Write #%0d start at %t", writeNumPixel, $time);
    $display("TB: ERROR !!!! not yet implemented");
    /*_addr = task_addr;
    _din = task_cache_din;
    _we = task_cache_we; */
  end
end
endtask

integer TempReadWriteNum;

// Due to synchronous memory,
// inputs must be setup before clock
task SetupRead;
  input [1:0]  cache_select;
  input [31:0] task_addr;
begin
  ccDelayCnt = 1;
  if (cache_select === `DCACHE) begin
    StrRW = "d";
    readNumD = readNumD + 1; // debugging info
    TempReadWriteNum = readNumD;
    d_addr = task_addr;
    dcache_re = 1'b1;
  end else if (cache_select === `ICACHE) begin
    StrRW = "i";
    readNumI = readNumI + 1; // debugging info
    TempReadWriteNum = readNumI;
    PC = task_addr;
    icache_re = 1'b1;
  end else begin
    StrRW = "";
    $display("TB: ERROR !!!! you can only read from I/D cache");
  end
  if(TB_DEBUG_OUT)
    $display("TB: %0s-Read #%0d, Addr=%8h start at %t", 
            StrRW, TempReadWriteNum, task_addr, $time);
end
endtask

task ClockInRequest;
begin
  @( posedge cpu_clk_g ) ;
  // start fresh after clocking in re/we requests:
  icache_re = 1'b0;
  dcache_re = 1'b0;
  icache_we = 4'b0;
  dcache_we = 4'b0;
  @( negedge cpu_clk_g ) ; // wait for stall
// TODO ** disable we for pixel and line
  //_we = 4'b0;
  //_we = 4'b0;
  // Wait for a stall after we clock in requests
  WaitForStall();
end
endtask

task WaitForStall;
begin
  while(stall && (ccDelayCnt < MAX_STALLS))
    @( negedge cpu_clk_g ) ccDelayCnt = ccDelayCnt + 1;
end
endtask

// You can pass "x" for expected hit to ignore
reg [31:0] data_to_verify;
task VerifyRead;
  input [1:0]  cache_select;
  input [31:0] task_expected_cache_dout;
  input        task_expect_hit;
begin
  // grab data:
  case(cache_select)
    `ICACHE: begin
      StrRW          = "i";
      data_to_verify = instruction;
      TempReadWriteNum    = readNumI;
    end
    `DCACHE: begin
      StrRW          = "d";
      data_to_verify = dcache_dout;
      TempReadWriteNum    = readNumD;
    end
    default: begin
      StrRW          = "*ERROR*";
      data_to_verify = 0;
      TempReadWriteNum    = -1;
      $display("TB: You can only read from I/D cache!");
    end
  endcase
  // Check output:
  if(stall) begin
      $display("TB: *FAIL* on Read #%0d - stall high after %0d cycles", 
                TempReadWriteNum, MAX_STALLS);
      numFails = numFails + 1;
  end else begin
    // verify:
    if(data_to_verify !== task_expected_cache_dout) begin
        $display("TB: *FAIL* on %0s-Read #%0d - Expected %h, Got %h", 
              StrRW, TempReadWriteNum, task_expected_cache_dout, data_to_verify);
        numFails = numFails + 1;
    end else if ((task_expect_hit === 1) && ccDelayCnt !== 1) begin
        $display("TB: *FAIL* on %0s-Read #%0d - expected HIT, Got %h", 
              StrRW, TempReadWriteNum, task_expected_cache_dout, data_to_verify);
        numFails = numFails + 1;
    end else if ((task_expect_hit === 0) && ccDelayCnt === 1) begin
        $display("TB: *FAIL* on %0s-Read #%0d - expected NOT HIT, Got %h", 
              StrRW, TempReadWriteNum, task_expected_cache_dout, data_to_verify);
        numFails = numFails + 1;
    end else begin
      $display("TB: %0s-Read  #%0d pass at %t (%0d cycles)", 
              StrRW, TempReadWriteNum, $time, ccDelayCnt);
    end
  end
end
endtask

task VerifyWrite;
  input [2:0] cache_select;
  input task_expect_hit;
begin
  case(cache_select)
    `ICACHE:  StrRW = "i";
    `DCACHE:  StrRW = "d";
    `LINEENG: StrRW = "line";
    `DIRDRAW: StrRW = "pixel";
  endcase
  case(cache_select)
    `ICACHE:  TempReadWriteNum = writeNumI;
    `DCACHE:  TempReadWriteNum = writeNumD;
    `LINEENG: TempReadWriteNum = writeNumLine;
    `DIRDRAW: TempReadWriteNum = writeNumPixel;
  endcase
  if(stall) begin
    $display("TB: *FAIL* on %0s-Write #%0d - stall high after %0d cycles", 
              StrRW, TempReadWriteNum, MAX_STALLS);
    numFails = numFails + 1;
    // ** Add HIT test here **
  end else begin
    $display("TB: Write #%0d done at %t (%0d cycles)", 
              TempReadWriteNum, $time, ccDelayCnt);
  end
end
endtask

