//----------------------------------------------------------------------------
// Module: Cache
// Inputs:
//    clk: clock signal, same as CPU
//    rst: system reset signal
//    address: 32-bit memory address
//    din: 32-bit block of data
//    we: 4-bit write mask
//    re: read enable (should be high only when we = 4'b0)
//    rdf_valid: control signal from DDR2 read data fifo
//    rdf_dout: 128 bits of data from DDR2 (2x per read command)
//    af_full: control signal for the address/cmd fifo
//    wdf_full: control signal for write data fifo
//
// Outputs:
//    stall: indicates the CPU should stall
//    dout: 32-bit result after a read
//    rdf_rd_en: read enable for the DDR2 read data fifo
//    af_cmd_din: 3-bit DDR2 command fifo input
//    af_addr_din: 31-bit DDR2 address input
//    af_wr_en: write enable for address, command fifos
//    wdf_din: 128-bit data input (should use 2x per write command)
//    wdf_mask_din: 16-bit write mask
//    wdf_wr_en: write enable signal for write data and mask fifo
//
//----------------------------------------------------------------------------
`include "cache.vh"

module Cache(
    input           clk,
    input           rst,
    input [31:0]    addr,
    input [31:0]    din,
    input [3:0]     we,
    input           re,
    input           rdf_valid,
    input [127:0]   rdf_dout,
    input           af_full,
    input           wdf_full,

    output          stall,
    output [31:0]   dout,
    output          rdf_rd_en,
    output [2:0]    af_cmd_din,
    output [30:0]   af_addr_din,
    output          af_wr_en,
    output [127:0]  wdf_din,
    output [15:0]   wdf_mask_din,
    output          wdf_wr_en,

    // Needed for set-associative cache
    output          tag_hit,
    output          tag_valid,
    output [2:0]    state
);

    // State declarations:
    localparam  IDLE     = 3'b000,
                WRITE1   = 3'b001,
                WRITE2   = 3'b010,
                FETCH    = 3'b011,
                READ1    = 3'b100,
                READ2    = 3'b101,
                CWRITEB  = 3'b110;

    //registers:
    // state for DDR2 FSM
    reg [2:0]     cs, ns;
    assign state = cs;
    // register to hold first 128-bits read back
    // from DDR2
    reg [127:0]   first_read;

    // register data in to write into the cache
    // either:
    // a) 1 cycle later - after a tag check
    // b) many cycles later - after doing a fetch from DDR2
    reg [31:0]    din_hold;

    // register address
    reg [31:0]    addr_hold;

    // register read and write enables
    reg           re_hold;
    reg [3:0]     we_hold;

    wire mem_en;
    wire [31:0] data_we;
    wire tag_we;
    wire [`SZ_CACHELINE-1:0] data;

    wire [`SZ_CACHELINE-1:0] data_line_out;
    wire [`SZ_TAGLINE-1:0] tag_line_out;
    wire [`SZ_CACHELINE-1:0] data_line_in;
    wire [`SZ_TAGLINE-1:0] tag_line_in;

    reg [`SZ_CACHELINE-1:0] active_data_line;

    wire [`SZ_OFFSET-1:0] offset  = addr[`IDX_ADDR_OFFSET];
    wire [`SZ_INDEX-1:0] index    = addr[`IDX_ADDR_INDEX];
    wire [`SZ_TAG-1:0] tag        = addr[`IDX_ADDR_TAG];

    wire [`SZ_OFFSET-1:0] offset_hold  = addr_hold[`IDX_ADDR_OFFSET];
    wire [`SZ_INDEX-1:0] index_hold    = addr_hold[`IDX_ADDR_INDEX];
    wire [`SZ_TAG-1:0] tag_hold        = addr_hold[`IDX_ADDR_TAG];

    wire [31:0] we_mask_hold;

    wire write_hit_hold;
    wire tag_equal;

    // block ram for the cache:
    // 8kb
    // 256 rows / 32 bytes per row
    cache_data_blk_ram cache_data(
        .clka(clk),
        .ena(mem_en),
        .wea(data_we),
        .addra(index_hold),
        .dina(data_line_in),
        .clkb(clk),
        .rstb(rst),
        .enb(mem_en),
        .addrb(index),
        .doutb(data_line_out));

    cache_tag_blk_ram cache_tag(
        .clka(clk),
        .ena(mem_en),
        .wea(tag_we),
        .addra(index_hold),
        .dina(tag_line_in),
        .clkb(clk),
        .rstb(rst),
        .enb(mem_en),
        .addrb(index),
        .doutb(tag_line_out));

    // Assignments for the cache block ram:
    assign mem_en  = (ns == IDLE) || (|data_we) || re;
    assign data_we = (ns == CWRITEB) ? 32'hFFFFFFFF :
                      {32{write_hit_hold}} & we_mask_hold;
    assign tag_we = (ns == CWRITEB) || (write_hit_hold);

    assign we_mask_hold = {28'b0, we_hold} << {offset_hold, 2'b0};


    // Some signals to make the FSM cleaner:
    assign tag_valid = tag_line_out[`IDX_TAG_VALID];
    assign tag_equal = tag_line_out[`IDX_TAG_TAG] == tag_hold;
    assign tag_hit = tag_valid && tag_equal;

    assign write_hit_hold = we_hold && tag_hit;

    assign read_miss = re_hold && !tag_hit;

    // synchronous logic:
    always @(posedge clk) begin
        if(rst)
            cs <= IDLE;
        else
            cs <= ns;

        if (ns == IDLE) begin
            addr_hold <= addr;
            re_hold <= re;
            we_hold <= we;
            din_hold <= din;
        end

        if(cs == READ1)
            first_read <= rdf_dout;

        if(cs == IDLE)
            active_data_line <= data_line_out;
        else if(ns == CWRITEB)
            active_data_line <= {first_read, rdf_dout};
    end

    // State transition logic:
    always @(*) begin
        ns = IDLE;
        case(cs)
            IDLE: begin
                if(we_hold)
                    ns = WRITE1;
                else if(read_miss)
                    ns = FETCH;
            end
            WRITE1: ns = (!wdf_full && !af_full) ? WRITE2 : WRITE1;
            WRITE2: ns = (!wdf_full) ? IDLE : WRITE2;
            FETCH: ns = (!af_full) ? READ1 : FETCH;
            READ1: ns = rdf_valid ? READ2 : READ1;
            READ2: ns = rdf_valid ? CWRITEB : READ2;
            CWRITEB: ns = IDLE;
            default: ns = IDLE;
        endcase
    end

    // FIFO output assignments:
    assign stall = (ns != IDLE);
    assign rdf_rd_en = (cs == READ1 || cs == READ2);
    assign af_wr_en = (cs == WRITE1 || cs == FETCH);
    assign af_cmd_din = (cs == WRITE1) ? 3'b000 : 3'b001;
    assign wdf_wr_en = cs == WRITE1 || cs == WRITE2;

    assign af_addr_din = {6'b0, addr_hold[`IDX_ADDR_DRAM], 2'b0};
    assign wdf_din = {4{din_hold}};
    // active low, so we have to flip the bits
    assign wdf_mask_din = (cs == WRITE1) ? ~we_mask_hold[31:16] : ~we_mask_hold[15:0];

    // CPU output assignments
    // the data out is either from cache line out or active cache line if there is a read
    assign data = (cs == IDLE) ? data_line_out[255:0] : active_data_line[255:0];
    assign dout = data >> {offset_hold, 5'b0};

    // If we're writing back data from DDR2, use the registered 128-bits
    // (first_read) and the current 128 bits from the read data FIFO
    assign data_line_in = (ns == CWRITEB) ? {first_read, rdf_dout} : {8{din_hold}};
    assign tag_line_in = {1'b0, 1'b1, tag_hold};

endmodule
