/* This module keeps a FIFO filled that then outputs to the DVI module. */

module PixelFeeder( //System:
                    input          cpu_clk_g,
                    input          clk50_g, // DVI Clock
                    input          rst,
                    //DDR2 FIFOS:
                    input          rdf_valid,
                    input          af_full,
                    input  [127:0] rdf_dout,
                    output   reg   rdf_rd_en,
                    output   reg   af_wr_en,
                    output [30:0]  af_addr_din,
                    // DVI module:
                    output [23:0]  video,
                    output         video_valid,
                    input          video_ready,
                    // CPU:
                    input  [31:0]  frame_addr,
                    input  frame_valid,
            		    output reg frame_interrupt);

/*
    assign rdf_rd_en = 1'b0;
    assign af_wr_en = 1'b0;
    assign af_addr_din = 31'b0;
    assign frame_interrupt = 1'b0;
*/

    // Hint: States
    localparam IDLE = 2'b00;
    localparam START = 2'b01;
    localparam SENDING = 2'b10;
    localparam WAIT = 2'b11;




    reg  [31:0] ignore_count;
    
    reg [1:0] state;
    reg [1:0] next_state;

    /**************************************************************************
    * YOUR CODE HERE: Write logic to keep the FIFO as full as possible.
    **************************************************************************/

    wire feeder_full;

    wire pre_feeder_empty;
    wire pre_feeder_full;


    reg [9:0] pre_feeder_lines;

    
    
    reg [9:0] requests;
    reg [9:0] requests_left;
    
    reg [9:0] x;
    reg [9:0] y;
    reg [5:0] addr_base;
    reg [5:0] next_addr_base; 
    
    wire request_sent;
    assign request_sent = af_wr_en & ~af_full;
    wire request_received;
    assign request_received = rdf_valid & rdf_rd_en;

    always @(*) begin
      if (state == IDLE) begin
        rdf_rd_en = 0;
        af_wr_en = 0;
        
        // pre_feeder_lines < 256.
        if (~(pre_feeder_lines[8] | pre_feeder_lines[9]))
          next_state = SENDING;
        else
          next_state = IDLE;

      end else if (state == SENDING) begin
        // requests_left gets set to 64 in IDLE state
        // while we have not yet sent 64 requests, send a request,
        // also, while outstanding requests have not yet been fulfilled,
        // wait for them.
      
        af_wr_en = (requests_left != 10'd0);
        rdf_rd_en = (requests != 10'd0);
        
        if ((requests_left == 10'd0) & (requests == 10'd0))
          next_state = IDLE;
        else
          next_state = SENDING;
      end
/*      
      end else if (state == SENDING) begin
        af_wr_en = 1;
        rdf_rd_en = 1;
        
        if (af_full || (requests_left == 10'd0))
          next_state = WAIT;
        else
          next_state = SENDING;
      
      end else if (state == WAIT) begin
        af_wr_en = 0;
        rdf_rd_en = 1;
        
        if (requests == 10'd0)
          next_state = IDLE;
        else
          next_state = WAIT;
      end */
    end

    always @(posedge cpu_clk_g) begin
      if(rst) begin
        x <= 10'd0;
        y <= 10'd0;
        requests <= 10'd0;
        requests_left <= 10'd64;

        addr_base <= 6'b111111;
        next_addr_base <= 6'b111111;
        frame_interrupt <= 1'b0;
        
        state <= IDLE;

      end else begin
        
        state <= next_state;
        
        if (frame_valid)
          next_addr_base <= frame_addr[27:22];
        
        if (request_sent) begin
          requests_left <= requests_left - 10'd1;
        
          if (request_received) requests <= requests + 10'd1;
          else requests <= requests + 10'd2;
        
          if ((x == 10'd792) && (y == 10'd599)) begin
            x <= 10'd0;
            y <= 10'd0;
            addr_base <= next_addr_base;
            frame_interrupt <= 1'b1;
          end else if (x == 10'd792) begin
            x <= 10'd0;
            y <= y + 10'd1;
            frame_interrupt <= 1'b0;          
          end else begin
            x <= x + 10'd8; 
            y <= y;
            frame_interrupt <= 1'b0;
          end 
      	end else begin
            if (state == IDLE)
              requests_left <= 10'd64;

      	    if (request_received) requests <= requests - 10'd1;
      	    else requests <= requests;
      	
            x <= x;
            y <= y;
            frame_interrupt <= 1'b0;
        end
      end
    end
    
    wire [9:0] real_x;
    
    assign real_x = 10'd792 - x;
    
    assign af_addr_din = {6'b0, addr_base, y, real_x[9:3], 2'b0};


    /* We drop the first frame to allow the buffer to fill with data from
    * DDR2. This gives alignment of the frame. */
    always @(posedge cpu_clk_g) begin
       if(rst)
            ignore_count <= 32'd480000; // 600*800 
       else if(ignore_count != 0 & video_ready)
            ignore_count <= ignore_count - 32'b1;
       else
            ignore_count <= ignore_count;
    end


    wire [31:0] feeder_dout;

    wire [127:0] pre_feeder_out;
    
    
    wire fifo_transfer;
    assign fifo_transfer = ~feeder_full & ~pre_feeder_empty;

    fifo_generator_v9_1 pre_feeder (
      .clk(cpu_clk_g),
      .rst(rst),
      .dout(pre_feeder_out),
      .full(pre_feeder_full),
      .empty(pre_feeder_empty),
      .wr_en(rdf_valid),
      .din(rdf_dout),
      .rd_en(fifo_transfer)      
    );

    // Count the number of lines in the pre-feeder
    // we can do this much easier than the second feeder because
    // we don't have to deal with different clock domains

    always @(posedge cpu_clk_g) begin
      if (rst) pre_feeder_lines <= 10'b0;
      else begin
        if (rdf_valid & ~fifo_transfer)
          pre_feeder_lines <= pre_feeder_lines + 10'd1;
        else if (~rdf_valid & fifo_transfer & (pre_feeder_lines != 10'd0)) // don't go negative
          pre_feeder_lines <= pre_feeder_lines - 10'd1;
        else if (pre_feeder_empty)
          pre_feeder_lines <= 10'd0;
        // pre_feeder_full should never happen
      end
    end


    pixel_fifo feeder_fifo(
    	.rst(rst),
    	.wr_clk(cpu_clk_g),
    	.rd_clk(clk50_g),
    	.din(pre_feeder_out),
    	.wr_en(fifo_transfer),
    	.rd_en(video_ready & ignore_count == 0),
    	.dout(feeder_dout),
    	.full(feeder_full),
    	.empty(feeder_empty));

    assign video = feeder_dout[23:0];
    assign video_valid = 1'b1;
    //assign rdf_rd_en = ~feeder_full;


/*
    wire [35 : 0] CSCTRL;

    chipscope_ila CILA (
      .CONTROL(CSCTRL),
      .CLK(cpu_clk_g),
      .DATA({ 8'b11010101, 24'hFFFFFF, //32
              words_in, words_out,
              af_addr_din, 1'b0,
              14'h0, rdf_valid, rdf_rd_en, af_full, af_wr_en, 14'hFFD,
              32'b0,
              32'b0,
              32'b0,
              17'b0, state, feeder_full, feeder_empty, frame_interrupt, video_valid, video_ready, 8'b11110000 }),
      .TRIG0(rdf_valid)
    );
    
    chipscope_icon CICON (
      .CONTROL0(CSCTRL)
    );
*/

endmodule

