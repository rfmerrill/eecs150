//----------------------------------------------------------------------------
// Module: RequestControler.v
// Author: James Parker
//
// This module is designed to give the caches the illusion of having exclusive 
// access to the DDR2 FIFOs. Additionally, it interleaves requests when both 
// caches attempt to access DDR2 simultaneously. The instruction cache is 
// given priority (i.e. it's requests are serviced first). 
//
// When there are access collisions, this module tells the data cache that the
// FIFOs are full, essentially stalling the cache until the icache finishes.
//
// There are some optimizations this module does not attempt that you may
// experiment with for the performance contest:
//   - Recognizing duplicate read requests and performing only one DDR2 access
//   - Giving reads priority (because we don't block on completing writes)
//
// v2 Changes:
// To support the framebuffer, there are three new access paths:
//   - Write-only path from the line engine to DDR2
//   - Write-only path from the color filler to the DDR2
//   - Read-only path from DDR2 to a module that feeds DVI with pixels.
//
// v3 changes: (Ian Juch)
// To support graphics command processor:
// 	 - Read only path to access the instructions from DDR2
//-----------------------------------------------------------------------------

module RequestController( 
                        input           clk,
                        input           rst,
                        // inputs from the DDR2 FIFOs:
                        input           af_full,
                        input           wdf_full,
                        input           rdf_valid,
                        
                       // inputs from the instruction cache:
                       input            i_rdf_rd_en,
                       input [2:0]      i_af_cmd_din,
                       input [30:0]     i_addr_din,
                       input            i_af_wr_en,
                       input [127:0]    i_wdf_din,
                       input [15:0]     i_wdf_mask_din,
                       input            i_wdf_wr_en,
                       input            i_stall,

                       // inputs from the data cache:
                       input            d_rdf_rd_en,
                       input [2:0]      d_af_cmd_din,
                       input [30:0]     d_addr_din,
                       input            d_af_wr_en,
                       input [127:0]    d_wdf_din,
                       input [15:0]     d_wdf_mask_din,
                       input            d_wdf_wr_en,
                       input            d_stall,

                       // inputs from the line drawing engine
                       // Note: the line drawing engine only needs to write,
                       //   thus, it accesses on a subset of the fifo signals
                       input [30:0]     line_addr_din,
                       input            line_af_wr_en,
                       input [127:0]    line_wdf_din,
                       input [15:0]     line_wdf_mask_din,
                       input            line_wdf_wr_en,

                       // inputs from the cache bypass module
                       //   write-only path
                       input [30:0]     bypass_addr_din,
                       input            bypass_af_wr_en,
                       input [127:0]    bypass_wdf_din,
                       input [15:0]     bypass_wdf_mask_din,
                       input            bypass_wdf_wr_en,
                       
                       // inputs from the color filler
                       // similarly only needs to write
                       input [30:0]     filler_addr_din,
                       input            filler_af_wr_en,
                       input [127:0]    filler_wdf_din,
                       input [15:0]     filler_wdf_mask_din,
                       input            filler_wdf_wr_en,
                       
                       // inputs from the graphics command processor
                       // read only
                       input            cmd_rdf_rd_en,
                       input            cmd_af_wr_en,
                       input [30:0]     cmd_addr_din,

                       // inputs from the module responsibile for keeping the 
                       // pixel fifo full, designated with 'pixel'. This only allows
                       // read access.
                       input            pixel_rdf_rd_en,
                       input            pixel_af_wr_en,
                       input [30:0]     pixel_addr_din,
                       
                       // output to the DDR2 FIFOs:
                       output             rdf_rd_en,
                       output reg [2:0]   af_cmd_din,
                       output reg [30:0]  addr_din,
                       output reg         af_wr_en,
                       output reg [127:0] wdf_din,
                       output reg [15:0]  wdf_mask_din,
                       output reg         wdf_wr_en,

                       // output to the instruction cache:
                       output             i_rdf_valid,
                       output             i_af_full,
                       output             i_wdf_full,

                       // output to the data cache:
                       output             d_rdf_valid,
                       output             d_af_full,
                       output             d_wdf_full,
   
                       // outputs to the line drawing engine:
                       output             line_af_full,
                       output             line_wdf_full,
                       
                       // outputs to the cache bypass module
                       output             bypass_af_full,
                       output             bypass_wdf_full,

                       // outputs to the color filler:
                       output             filler_af_full,
                       output             filler_wdf_full,

                       // outputs to the fifo-filling module:
                       output             pixel_rdf_valid,
                       output             pixel_af_full,
                       
                       // outputs to graphics command processor
                       output 			cmd_rdf_valid,
                       output 			cmd_af_full
                       );
   


    localparam NO_ACCESS     = 3'b000;
    localparam D_ACCESS      = 3'b001;
    localparam I_ACCESS      = 3'b010;
    localparam FILLER_ACCESS = 3'b011;
    localparam LINE_ACCESS   = 3'b100;
    localparam PIXEL_ACCESS  = 3'b101;
    localparam BYPASS_ACCESS = 3'b110;
    localparam CMD_ACCESS 	 = 3'b111;

    // New approach: icache and dcache don't stream reads. Keep
    // a count of each read and then remember the number for
    // the caches. Should be okay if they wrap around; 11 bits
    // so that they are larger than max fifo size.
    
    reg  [2:0]  fifo_access;
    reg [10:0]  icache_req_num;
    reg [1:0]   icache_req_valid;
    reg [10:0]  dcache_req_num;
    reg [1:0]   dcache_req_valid;
    reg [10:0]  cmd_req_num;
    reg [1:0]   cmd_req_valid;
    reg [10:0]  issued_reads;
    reg [11:0]  serviced_reads; // extra bit b/c 2 chunks - use [11:1] to cmpare.
    wire fetch_issued;

    assign fetch_issued = af_wr_en && af_cmd_din == 3'b001 && !af_full && !wdf_full;

    always @(posedge clk) begin
        if(rst)
            issued_reads <= 11'b0;
        else if(fetch_issued)
            issued_reads <= issued_reads + 11'b1;
        else
            issued_reads <= issued_reads;

        if(rst)
            serviced_reads <= 12'b0;
        else if(rdf_valid)
            serviced_reads <= serviced_reads + 1;
        else
            serviced_reads <= serviced_reads;

        if(rst) begin
            icache_req_num <= 10'b0;
            icache_req_valid <= 2'b0;
        end else if(fifo_access == I_ACCESS && fetch_issued) begin
            icache_req_num <= issued_reads;
            icache_req_valid <= 2'b10;
        end else if(icache_req_num == serviced_reads[11:1] && icache_req_valid != 2'b00 && rdf_valid) begin
            icache_req_num <= icache_req_num;
            icache_req_valid <= icache_req_valid - 1;
        end else begin
            icache_req_num <= icache_req_num;
            icache_req_valid <= icache_req_valid;
        end

        if(rst) begin
            dcache_req_num <= 10'b0;
            dcache_req_valid <= 2'b0;
        end else if(fifo_access == D_ACCESS && fetch_issued) begin
            dcache_req_num <= issued_reads;
            dcache_req_valid <= 2'b10;
        end else if(dcache_req_num == serviced_reads[11:1] && dcache_req_valid != 2'b0 && rdf_valid) begin
            dcache_req_num <= dcache_req_num;
            dcache_req_valid <= dcache_req_valid - 1;
        end else begin
            dcache_req_num <= dcache_req_num;
            dcache_req_valid <= dcache_req_valid;
        end
        
        if(rst) begin
            cmd_req_num <= 10'b0;
            cmd_req_valid <= 2'b0;
        end else if(fifo_access == CMD_ACCESS && fetch_issued) begin
            cmd_req_num <= issued_reads;
            cmd_req_valid <= 2'b10;
        end else if(cmd_req_num == serviced_reads[11:1] && cmd_req_valid != 2'b0 && rdf_valid) begin
            cmd_req_num <= cmd_req_num;
            cmd_req_valid <= cmd_req_valid - 1;
        end else begin
            cmd_req_num <= cmd_req_num;
            cmd_req_valid <= cmd_req_valid;
        end
    end


 
    // this can go straight through, only logic req'd is for directing the data
    wire i_read, d_read, pixel_read;
    assign i_read = icache_req_valid != 2'b00 && icache_req_num == serviced_reads[11:1];
    assign d_read = dcache_req_valid != 2'b00 && dcache_req_num == serviced_reads[11:1];
    assign cmd_read = cmd_req_valid != 2'b00 && cmd_req_num == serviced_reads[11:1];

    assign rdf_rd_en = i_read ? i_rdf_rd_en :
                       d_read ? d_rdf_rd_en :
                       cmd_read ? cmd_rdf_rd_en:
                       pixel_rdf_rd_en;

    // directing the data is now straightforward: we give it to current_reader
    assign i_rdf_valid =  i_read ? rdf_valid : 1'b0;
    assign d_rdf_valid =  d_read ? rdf_valid : 1'b0;
    assign cmd_rdf_valid = cmd_read ? rdf_valid : 1'b0;
    assign pixel_rdf_valid = (i_read || d_read || cmd_read) ? 1'b0 : rdf_valid;

    //**************************************************************************
    // This section is for determining the signals to the DDR2 fifos and the 
    // full signals to send to the various access paths.
    //************************************************************************

    
    // The "reserved" signals are used to prevent the higher-priority paths 
    // from interrupting the filler or line engine (which run async) during
    // writes.
    
    reg line_reserved;
    reg filler_reserved;
    reg bypass_reserved;
    reg cmd_reserved;
    wire reserved;
    assign reserved = filler_reserved || line_reserved || bypass_reserved || cmd_reserved;

    always @(posedge clk) begin
        if(rst) 
            line_reserved <= 1'b0;
        else if (fifo_access == LINE_ACCESS && !wdf_full && !af_full) 
            line_reserved <= line_reserved + 1'b1;

        if(rst)
            bypass_reserved <= 1'b0;
        else if(fifo_access == BYPASS_ACCESS && !wdf_full && !af_full)
          bypass_reserved <= 1'b0;

        if(rst)
            filler_reserved <= 1'b0;
        else if(fifo_access == FILLER_ACCESS && !wdf_full && !af_full)
            filler_reserved <= filler_reserved + 1'b1;
            
        if(rst)
            cmd_reserved <= 1'b0;
        else if(fifo_access == CMD_ACCESS && !wdf_full && !af_full)
            cmd_reserved <= cmd_reserved + 1'b1;
    end

    always @(*) begin
       // Access is given in the order of icache, dcache, pixel feeder, color filler
       // line engine.
        if((i_af_wr_en || i_wdf_wr_en) && !reserved) begin
            fifo_access  = I_ACCESS;
            //icache -> fifo signals:
            af_cmd_din   = i_af_cmd_din;
            addr_din     = i_addr_din;
            af_wr_en     = i_af_wr_en && (!wdf_full &&  !af_full);
            wdf_din      = i_wdf_din;
            wdf_mask_din = i_wdf_mask_din;
            wdf_wr_en    = i_wdf_wr_en && (!wdf_full && !af_full);
        end
        else if((d_af_wr_en || d_wdf_wr_en) && !reserved) begin
            fifo_access  = D_ACCESS;
            af_cmd_din   = d_af_cmd_din;
            addr_din     = d_addr_din;
            af_wr_en     = d_af_wr_en && (!wdf_full && !af_full);
            wdf_din      = d_wdf_din;
            wdf_mask_din = d_wdf_mask_din;
            wdf_wr_en    = d_wdf_wr_en && (!wdf_full && !af_full);
        end
        
        else if((cmd_af_wr_en) && !reserved) begin
            fifo_access  = CMD_ACCESS;
            // read-only path
            af_cmd_din   = 3'b001;
            addr_din     = cmd_addr_din;
            af_wr_en     = cmd_af_wr_en && !af_full && !wdf_full;
            wdf_din      = 128'bx; // doesn't matter
            wdf_mask_din = 16'hFFFF; // not writing
            wdf_wr_en    = 1'b0; //not writing
        end
        else if(pixel_af_wr_en && !filler_reserved && !line_reserved && !bypass_reserved) begin
            fifo_access  = PIXEL_ACCESS;
            // read-only path:
            af_cmd_din   = 3'b001;
            addr_din     = pixel_addr_din;
            af_wr_en     = pixel_af_wr_en && !af_full && !wdf_full;
            wdf_din      = 128'bx; // doesn't matter
            wdf_mask_din = 16'hFFFF; // not writing
            wdf_wr_en    = 1'b0; //not writing
        end
        else if((filler_af_wr_en || filler_wdf_wr_en) && !line_reserved && !bypass_reserved) begin
            fifo_access  = FILLER_ACCESS;
            // write-only path
            af_cmd_din   = 3'b000;
            addr_din     = filler_addr_din;
            af_wr_en     = filler_af_wr_en && !wdf_full && !af_full;
            wdf_din      = filler_wdf_din;
            wdf_mask_din = filler_wdf_mask_din;
            wdf_wr_en    = filler_wdf_wr_en && !wdf_full && !af_full;
        end
        else if((line_af_wr_en || line_wdf_wr_en) && !filler_reserved && !bypass_reserved) begin
            fifo_access  = LINE_ACCESS;
            // write-only path
            af_cmd_din   = 3'b000;
            addr_din     = line_addr_din;
            af_wr_en     = line_af_wr_en && !wdf_full && !af_full;
            wdf_din      = line_wdf_din;
            wdf_mask_din = line_wdf_mask_din;
            wdf_wr_en    = line_wdf_wr_en && !wdf_full && !af_full;
        end
        /*
	else if((bypass_af_wr_en || bypass_wdf_wr_en) && !filler_reserved && !line_reserved) begin
            fifo_access  = BYPASS_ACCESS;
            // write-only path
            af_cmd_din   = 3'b000;
            addr_din     = bypass_addr_din;
            af_wr_en     = bypass_af_wr_en && !wdf_full && !af_full;
            wdf_din      = bypass_wdf_din;
            wdf_mask_din = bypass_wdf_mask_din;
            wdf_wr_en    = bypass_wdf_wr_en && !wdf_full && !af_full;
        end*/
        else begin 
            fifo_access  = NO_ACCESS;
            // in the default case, both need to see the actual fifo full
            // signals, otherwise the cache will never attempt to write.
            // for the other signals, we don't care, so just choose icache          
            af_cmd_din   = i_af_cmd_din;
            addr_din     = i_addr_din;
            af_wr_en     = 1'b0;
            wdf_din      = i_wdf_din;
            wdf_mask_din = i_wdf_mask_din;
            wdf_wr_en    = 1'b0;
        end
    end

    // To facilitate the switch to asserting wr_en's even when fifos are full,
    // we have to and the full signals so data and cmds are written together.

    // finally, based on the cache accessing, the fifo signals need to be set:
    assign i_af_full = fifo_access == I_ACCESS ?  af_full || wdf_full : 1'b1; 
    assign i_wdf_full = fifo_access == I_ACCESS ? wdf_full || af_full : 1'b1;


    // checking against fifo_access implicitly checks reserved
    assign d_af_full  = fifo_access == D_ACCESS ?  af_full || wdf_full : 1'b1;
    assign d_wdf_full = fifo_access == D_ACCESS ? wdf_full || af_full : 1'b1;
     
    assign filler_af_full  = fifo_access == FILLER_ACCESS  ? wdf_full || af_full : 1'b1;
    assign filler_wdf_full = fifo_access == FILLER_ACCESS  ? wdf_full || af_full : 1'b1;
    
    assign line_af_full  = fifo_access == LINE_ACCESS  ? af_full || wdf_full : 1'b1;
    assign line_wdf_full = fifo_access == LINE_ACCESS  ? wdf_full || af_full : 1'b1;

    assign bypass_af_full  = fifo_access == BYPASS_ACCESS  ? af_full || wdf_full : 1'b1;
    assign bypass_wdf_full = fifo_access == BYPASS_ACCESS  ? wdf_full || af_full : 1'b1;

    assign pixel_af_full  = fifo_access == PIXEL_ACCESS  ? af_full || wdf_full : 1'b1;
    
    assign cmd_af_full  = fifo_access == CMD_ACCESS  ? af_full || wdf_full : 1'b1;

endmodule

