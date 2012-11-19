//----------------------------------------------------------------------
// Module: Memory.v
// Authors: James Parker, Daiwei Li
// This module contains the instantiaton of the Xilinx DDR2 module, the 
// clock-crossing FIFOs for communication with the DDR2 controller, and
// the caches.
//
// *** NOTE ***
// You should not need to change the contents of this file. You will,
// however, need to have a general understanding of the FIFO <=> cache
// interface implemented in this module to design the FSM in your cache. 
//----------------------------------------------------------------------

module Memory150( 
               // Clocks:
               input         cpu_clk_g,
               input         clk0_g,
               input         clk200_g,
               input         clkdiv0_g,
               input         clk90_g,
               input         clk50_g,
               input         locked,
             
               // Reset logic:
               input         rst,
               output        init_done,

               // DDR2 Interface:
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
              
               // Cache <=> CPU interface
               input  [31:0] dcache_addr,
               input  [31:0] icache_addr,
               input  [3:0]  dcache_we,
               input  [3:0]  icache_we,
               input         dcache_re,
               input         icache_re,
               input  [31:0] dcache_din,
               input  [31:0] icache_din,
               output [31:0] dcache_dout,
               output [31:0] icache_dout,
               output        stall,

		  
               // DVI interface:
               output [23:0] video,
               output        video_valid,
               input         video_ready,

	       input [31:0] cpu_gp_code,
               input [31:0] cpu_gp_frame,
	       input cpu_gp_valid,
	       output frame_interrupt
             );

    parameter SIM_ONLY = 1'b0;

    // DDR2 & FIFO interface wires:
    wire         af_afull;
    wire         af_full;
    wire         af_valid;
    wire         ddr2_clock_tb;
    wire [33:0]  af_dout;
    wire         wdf_valid;
    wire [143:0] wdf_dout;

    wire [15:0]  wdf_mask_din;
    wire [127:0] wdf_din;
    wire         wdf_wr_en;
    wire         wdf_full;
    wire         wdf_afull;
    wire         wdf_rd_en;

    wire         rdf_dout_valid;
    wire         rdf_rd_en;
    wire         ddr_rd_valid;
    wire [127:0] rdf_dout;
    wire [127:0] ddr2_rd_dout;

    wire [2:0]   af_cmd_din;
    wire [30:0]  af_addr_din;
    wire         af_wr_en;
    wire         af_rd_en;
    
    // Cache <=> RequestController wires:
    wire         i_rdf_valid,    d_rdf_valid;
    wire         i_af_full,      d_af_full;
    wire         i_wdf_full,     d_wdf_full;
    wire         i_rdf_rd_en,    d_rdf_rd_en;
    wire [2:0]   i_af_cmd_din,   d_af_cmd_din;
    wire [30:0]  i_af_addr_din,  d_af_addr_din;
    wire         i_af_wr_en,     d_af_wr_en;
    wire [127:0] i_wdf_din,      d_wdf_din;
    wire [15:0]  i_wdf_mask_din, d_wdf_mask_din;
    wire         i_wdf_wr_en,    d_wdf_wr_en;
    wire         i_stall,        d_stall;

    // PixelFeeder <=> RequestController wires:
    wire         pixel_rdf_rd_en;
    wire         pixel_af_wr_en;
    wire [30:0]  pixel_af_addr_din;
    wire         pixel_af_full;
    wire         pixel_rdf_valid;

    // FrameFiller <=> RequestController wires:
    wire         filler_af_full;
    wire         filler_wdf_full;
    wire [127:0] filler_wdf_din;
    wire         filler_wdf_wr_en;
    wire [30:0]  filler_addr_din;
    wire         filler_af_wr_en;
    wire [15:0]  filler_wdf_mask_din;
   wire [31:0] 	 filler_frame;
 
    // Line Engine <=> RequestController wires:
    wire         line_af_full;
    wire         line_wdf_full;
    wire [127:0] line_wdf_din;
    wire         line_wdf_wr_en;
    wire [30:0]  line_addr_din;
    wire         line_af_wr_en;
    wire [15:0]  line_wdf_mask_din;
   wire [31:0] 	 line_frame;
   

    // Graphics Command Processor <=> RequestController wires:
    wire 		 cmd_rdf_rd_en;
    wire 		 cmd_af_wr_en;
    wire		 cmd_addr_din;
    wire		 cmd_rdf_valid;
    wire		 cmd_af_full;


   // DDR2 module:
    mig_v3_61   #(.SIM_ONLY(SIM_ONLY)) ddr2(
        .ddr2_dq(DDR2_D),
        .ddr2_a(DDR2_A),
        .ddr2_ba(DDR2_BA),
        .ddr2_ras_n(DDR2_RAS_B),
        .ddr2_cas_n(DDR2_CAS_B),
        .ddr2_we_n(DDR2_WE_B),
        .ddr2_cs_n(DDR2_CS_B),
        .ddr2_odt(DDR2_ODT),
        .ddr2_cke(DDR2_CKE),
        .ddr2_dm(DDR2_DM),
        .ddr2_dqs(DDR2_DQS_P),
        .ddr2_dqs_n(DDR2_DQS_N),
        .ddr2_ck(DDR2_CLK_P),
        .ddr2_ck_n(DDR2_CLK_N),
        .sys_rst_n(~rst),
        .phy_init_done(init_done),
        .locked(locked),
        .rst0_tb(rst_tb),
        .clk0(clk0_g),
        .clk0_tb(ddr2_clock_tb),
        .clk90(clk90_g),
        .clkdiv0(clkdiv0_g),
        .clk200(clk200_g),
        .app_wdf_afull(wdf_afull),
        .app_af_afull(af_afull), 
        .rd_data_valid(ddr_rd_valid),
        .app_wdf_wren(wdf_valid),
        .app_af_wren(af_valid),
        .app_af_addr(af_dout[30:0]),
        .app_af_cmd(af_dout[33:31]),
        .rd_data_fifo_out(ddr2_rd_dout),
        .app_wdf_data(wdf_dout[127:0]),
        .app_wdf_mask_data(wdf_dout[143:128]));


    // Clock-crossing FIFOs:
    assign af_rd_en = !af_afull;
    assign wdf_rd_en = !wdf_afull;

    //address and cmd fifo:      
    mig_af ddr2_addr_fifo(
        .valid(af_valid),
        .rd_en(af_rd_en),
        .empty(af_empty),
        .wr_en(af_wr_en),
        .full(af_full),
        .wr_clk(cpu_clk_g),
        .rst(rst || ~init_done),
        .rd_clk(ddr2_clock_tb),
        .dout(af_dout),
        .din({af_cmd_din, af_addr_din}));

    //write data and mask fifo:
    mig_wdf ddr2_write_fifo(
        .valid(wdf_valid),
        .rd_en(wdf_rd_en),
        .wr_en(wdf_wr_en),
        .full(wdf_full),
        .empty(),
        .wr_clk(cpu_clk_g),
        .rst(rst || ~init_done),
        .rd_clk(ddr2_clock_tb),
        .dout(wdf_dout),
        .din({wdf_mask_din, wdf_din}));

    // read data out fifo:
    mig_rdf  ddr2_read_fifo(
        .valid(rdf_dout_valid),
        .rd_en(rdf_rd_en),
        .wr_en(ddr_rd_valid),
        .full(),
        .empty(),
        .wr_clk(ddr2_clock_tb),
        .rst(rst || ~init_done),
        .rd_clk(cpu_clk_g),
        .dout(rdf_dout),
        .din(ddr2_rd_dout));

    // The RequestController gives each cache the illusion of having 
    // exclusive DDR2 Access:
    RequestController req_con(
        .clk(cpu_clk_g),
        .rst(rst || ~init_done),
        .af_full(af_full),
        .wdf_full(wdf_full),
        .rdf_valid(rdf_dout_valid),
        .i_rdf_rd_en(i_rdf_rd_en),
        .i_af_cmd_din(i_af_cmd_din),
        .i_addr_din(i_af_addr_din),
        .i_af_wr_en(i_af_wr_en),
        .i_wdf_din(i_wdf_din),
        .i_wdf_mask_din(i_wdf_mask_din),
        .i_wdf_wr_en(i_wdf_wr_en),
        .i_stall(i_stall),
        .d_rdf_rd_en(d_rdf_rd_en),
        .d_af_cmd_din(d_af_cmd_din),
        .d_addr_din(d_af_addr_din),
        .d_af_wr_en(d_af_wr_en),
        .d_wdf_din(d_wdf_din),
        .d_wdf_mask_din(d_wdf_mask_din),
        .d_wdf_wr_en(d_wdf_wr_en),
        .d_stall(d_stall),
        .rdf_rd_en(rdf_rd_en),
        .af_cmd_din(af_cmd_din),
        .addr_din(af_addr_din),
        .af_wr_en(af_wr_en),
        .wdf_din(wdf_din),
        .wdf_mask_din(wdf_mask_din),
        .wdf_wr_en(wdf_wr_en),
        .i_rdf_valid(i_rdf_valid),
        .i_af_full(i_af_full),
        .i_wdf_full(i_wdf_full),
        .d_rdf_valid(d_rdf_valid),
        .d_af_full(d_af_full),
        .d_wdf_full(d_wdf_full),
        
        // new inputs for cp4-5:
        .line_addr_din(line_addr_din), 
        .line_af_wr_en(line_af_wr_en),          
        .line_wdf_din(line_wdf_din),         
        .line_wdf_mask_din(line_wdf_mask_din),  
        .line_wdf_wr_en(line_wdf_wr_en),         
        .bypass_addr_din(128'b0), //not using this port
        .bypass_af_wr_en(1'b0),  //not using this port               
        .bypass_wdf_din(128'b0),  //not using this port
        .bypass_wdf_mask_din(),  //not using this port
        .bypass_wdf_wr_en(1'b0),  //not using this port               
        .filler_addr_din(filler_addr_din),
        .filler_af_wr_en(filler_af_wr_en),
        .filler_wdf_wr_en(filler_wdf_wr_en), 
        .filler_wdf_mask_din(filler_wdf_mask_din),
        .filler_wdf_din(filler_wdf_din),
        .pixel_rdf_rd_en(pixel_rdf_rd_en),
        .pixel_af_wr_en(pixel_af_wr_en), 
        .pixel_addr_din(pixel_af_addr_din), 
        // new outputs for cp4-5:
        .line_af_full(line_af_full),      
        .line_wdf_full(line_wdf_full),    
        .bypass_af_full(), //not using this port
        .bypass_wdf_full(), //not using this port
        .filler_af_full(filler_af_full),
        .filler_wdf_full(filler_wdf_full),
        .pixel_rdf_valid(pixel_rdf_valid),
        .pixel_af_full(pixel_af_full),  
        
        // new inputs for graphics command processor 
        .cmd_rdf_rd_en(cmd_rdf_rd_en),
        .cmd_af_wr_en(cmd_af_wr_en),
        .cmd_addr_din(cmd_addr_din),
        // new inputs for graphics command processor 
        .cmd_rdf_valid(cmd_rdf_valid),
        .cmd_af_full(cmd_af_full)
       );
   
    // The instruction cache:
    Cache icache(
        .clk(cpu_clk_g),
        .rst(rst || ~init_done),
        .addr(icache_addr),
        .din(icache_din),
        .we(icache_we),
        .re(icache_re),
        .rdf_valid(i_rdf_valid),
        .rdf_dout(rdf_dout),
        .af_full(i_af_full),
        .wdf_full(i_wdf_full),
        .stall(i_stall),
        .dout(icache_dout),
        .rdf_rd_en(i_rdf_rd_en),
        .af_cmd_din(i_af_cmd_din),
        .af_addr_din(i_af_addr_din),
        .af_wr_en(i_af_wr_en),
        .wdf_din(i_wdf_din),
        .wdf_mask_din(i_wdf_mask_din),
        .wdf_wr_en(i_wdf_wr_en)
    );
    
    // Data cache:
     Cache dcache(
        .clk(cpu_clk_g),
        .rst(rst || ~init_done),
        .addr(dcache_addr),
        .din(dcache_din),
        .we(dcache_we),
        .re(dcache_re),
        .rdf_valid(d_rdf_valid),
        .rdf_dout(rdf_dout),
        .af_full(d_af_full),
        .wdf_full(d_wdf_full),
        .stall(d_stall),
        .dout(dcache_dout),
        .rdf_rd_en(d_rdf_rd_en),
        .af_cmd_din(d_af_cmd_din),
        .af_addr_din(d_af_addr_din),
        .af_wr_en(d_af_wr_en),
        .wdf_din(d_wdf_din),
        .wdf_mask_din(d_wdf_mask_din),
        .wdf_wr_en(d_wdf_wr_en)
    );

     // assignments
    assign stall = d_stall || i_stall;

    // For feeding pixels to the DVI module:
   
    PixelFeeder pixelfeed(
        .cpu_clk_g(cpu_clk_g),
        .clk50_g(cpu_clk_g),
        .rst(rst || ~init_done),
        .rdf_valid(pixel_rdf_valid),
        .af_full(pixel_af_full),
        .rdf_dout(rdf_dout),
        .rdf_rd_en(pixel_rdf_rd_en),
        .af_wr_en(pixel_af_wr_en),
        .af_addr_din(pixel_af_addr_din),
        .video(video),
        .video_valid(video_valid),
        .video_ready(video_ready),
        .frame_interrupt(frame_interrupt));

    FrameFiller framefill(
        .clk(cpu_clk_g),
        .rst(rst || ~init_done),
        .valid(filler_valid), // for testing
        .color(filler_color),
        .af_full(filler_af_full),
        .wdf_full(filler_wdf_full),
        .wdf_din(filler_wdf_din),
        .wdf_wr_en(filler_wdf_wr_en),
        .af_addr_din(filler_addr_din),
        .af_wr_en(filler_af_wr_en),
        .wdf_mask_din(filler_wdf_mask_din),
        .ready(filler_ready),
        .FF_frame_base(filler_frame));


    // For CP5:
    LineEngine le(
      .clk(cpu_clk_g),
      .rst(rst || ~init_done),
      .LE_ready(line_ready),
      .LE_color(line_color),
      .LE_point(line_point),
      .LE_color_valid(line_color_valid),
      .LE_x0_valid(line_x0_valid),
      .LE_y0_valid(line_y0_valid),
      .LE_x1_valid(line_x1_valid),
      .LE_y1_valid(line_y1_valid),
      .LE_trigger(line_trigger),
      .af_full(line_af_full),
      .wdf_full(line_wdf_full),
      .af_addr_din(line_addr_din),
      .af_wr_en(line_af_wr_en),
      .wdf_din(line_wdf_din),
      .wdf_mask_din(line_wdf_mask_din),
      .wdf_wr_en(line_wdf_wr_en),
      .LE_frame_base(line_frame)
    );


   //For CP5:
   GraphicsProcessor graphicsprocessor(
      .clk(cpu_clk_g),
      .rst(rst || ~init_done), 
      //line engine IO
      .LE_ready(line_ready),
      .LE_color(line_color),
      .LE_point(line_point),
      .LE_color_valid(line_color_valid),
      .LE_x0_valid(line_x0_valid),
      .LE_y0_valid(line_y0_valid),
      .LE_x1_valid(line_x1_valid),
      .LE_y1_valid(line_y1_valid),
      .LE_trigger(line_trigger),
      .LE_frame(line_frame), 
      //frame filler IO
      .FF_ready(filler_ready),
      .FF_valid(filler_valid),
      .FF_color(filler_color),
      .FF_frame(filler_frame), 
      //DRAM request controller interface
      .rdf_valid(cmd_rdf_valid),
      .af_full(cmd_af_full),
      .rdf_dout(rdf_dout),
      .rdf_rd_en(cmd_rdf_rd_en),
      .af_wr_en(cmd_af_wr_en),
      .af_addr_din(cmd_addr_din),
      //CPU IO
      .GP_CODE(cpu_gp_code),
      .GP_FRAME(cpu_gp_frame),
      .GP_valid(cpu_gp_valid));
   
				       
endmodule
