`timescale 1ns/1ps

module GraphicsProcessorTestbench();

    reg Clock, Reset;

    parameter HalfCycle = 5;
    parameter Cycle = 2*HalfCycle;
    parameter ClockFreq = 50_000_000;

    initial Clock = 0;
    always #(HalfCycle) Clock <= ~Clock;
    

    reg rdf_valid;
    reg af_full;
    reg [127:0] rdf_dout;
    wire rdf_rd_en;
    wire af_wr_en;
    wire [30:0] af_addr_din;
    wire ready;
    
    reg FF_ready;
    wire FF_valid;
    wire [23:0] FF_color;
    
    reg LE_ready;
    wire [31:0] LE_color;
    wire [9:0] LE_point;
    wire LE_color_valid;
    wire LE_x0_valid;
    wire LE_y0_valid;
    wire LE_x1_valid;
    wire LE_y1_valid;
    wire LE_trigger;
    
    wire [31:0] LE_frame;
    wire [31:0] FF_frame;
    wire bsel;
    
    reg [31:0] gp_code;
    reg [31:0] gp_frame;
    reg gp_valid;
    
    
    GraphicsProcessor DUT(	.clk(Clock),
    						.rst(Reset),
//    						.bsel(bsel),
    						.rdf_valid(rdf_valid),
    						.af_full(af_full),
    						.rdf_dout(rdf_dout),
    						.rdf_rd_en(rdf_rd_en),
    						.af_wr_en(af_wr_en),
    						.af_addr_din(af_addr_din),
    						//line engine control signals
    						.LE_ready(LE_ready),
    						.LE_color(LE_color),
    						.LE_point(LE_point),
    						.LE_color_valid(LE_color_valid),
    						.LE_x0_valid(LE_x0_valid),
    						.LE_y0_valid(LE_y0_valid),
    						.LE_x1_valid(LE_x1_valid),
    						.LE_y1_valid(LE_y1_valid),
    						.LE_trigger(LE_trigger),
    						.LE_frame(LE_frame),
    						//frame filler control signals
    						.FF_ready(FF_ready),
    						.FF_valid(FF_valid),
    						.FF_color(FF_color),
    						.FF_frame(FF_frame),
    						
    						.GP_CODE(gp_code),
    						.GP_FRAME(gp_frame),
    						.GP_valid(gp_valid)
    						
						);
    initial begin
      gp_frame = 32'h1FC00000;
      gp_code = 32'd12000008;
      gp_valid = 1'b0;
      FF_ready = 1'b1;
      LE_ready = 1'b1;
      af_full = 1'b1;
      rdf_valid = 1'b0;
      
      Reset = 1'b1;
      
      #(Cycle*10);
      
      Reset = 1'b0;
      #(Cycle)
      
      gp_valid = 1'b1;
    	
    	#(Cycle);
    	gp_valid = 1'b0;
    	
      #(Cycle);
    	
    	while (1) begin
       	while (~af_wr_en) #(Cycle);

      	af_full = 1'b0;
      	#(Cycle);
      	af_full = 1'b1;
      	
      	#(Cycle * 20);

        rdf_valid = 1;    	

      	rdf_dout = { 32'h01DDDDDD, 32'h01EEEEEE, 32'h01FFFFFF, 32'h01222222 };

      	#(Cycle);
      	rdf_dout = { 32'h01333333, 32'h01AAAAAA, 32'h01BBBBBB, 32'h01CCCCCC };

      	#(Cycle);
      	rdf_valid = 0;
      	
      	while (~af_wr_en) #(Cycle);

      	af_full = 1'b0;
      	#(Cycle);
      	af_full = 1'b1;
      	
      	#(Cycle * 10);
//      	gp_valid = 1'b1;
      	#(Cycle);
      	gp_valid = 1'b0;
      	#(Cycle * 10);
      	
        rdf_valid = 1;    	

      	rdf_dout = { 32'h00190022, 32'h001A004B, 32'h0, 32'h0 };

      	#(Cycle);
      	rdf_dout = { 32'h02FFFFFF, 32'h00100020, 32'h001A004B, 32'h02EEEEEE };

      	#(Cycle);
      	rdf_valid = 0;
    	end
    	
    	$finish();
    end

    
endmodule
