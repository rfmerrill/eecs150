`timescale 1ns/1ps

module GraphicsProcessorTestbench();

    reg Clock, Reset;

    parameter HalfCycle = 5;
    parameter Cycle = 2*HalfCycle;
    parameter ClockFreq = 50_000_000;

    initial Clock = 0;
    always #(HalfCycle) Clock <= ~Clock;
    
    reg trigger0;
    reg trigger1;
    reg count0;
    reg count1;
    reg rdf_valid;
    reg af_full;
    reg [127:0] rdf_dout;
    wire rdf_rd_en;
    wire af_wr_en;
    wire [30:0] af_addr_din;
    wire ready;
    wire fb0;
    
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
    						.bsel(bsel),
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
    	#(Cycle);
    	Reset = 1'b1;
    	gp_valid = 1'b0;
    	af_full = 1'b1;
    	#(Cycle);
    	Reset = 1'b0;
    	#(Cycle);
    	
    	gp_valid = 1'b1;
    	#(Cycle);
    	gp_valid = 1'b0;
    	af_full = 1'b0;
    	#(5*Cycle);
    	rdf_valid = 1'b1;
    	#(Cycle);
    	rdf_valid = 1'b0;
    	#(5*Cycle);
    	rdf_valid=1'b1;
    	rdf_dout[31:0]={8'h01,24'hffffff};
    	#(Cycle);
	  	FF_ready=1'b1;
    	#(5*Cycle);
		#(5*Cycle);
    	FF_ready=1'b1;
    	
    	
    	$finish();
    end

    
endmodule
