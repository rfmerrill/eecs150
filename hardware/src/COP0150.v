module COP0150(
    Clock,
    Enable,
    Reset,

    DataAddress,
    DataOut,
    DataInEnable,
    DataIn,

    InterruptedPC,
    InterruptHandled,
    InterruptRequest,

    UART0Request,
    UART1Request
);

input                           Clock;
input                           Enable;
input                           Reset;

input       [4:0]               DataAddress;
output      [31:0]              DataOut;
input                           DataInEnable;
input       [31:0]              DataIn;

input       [31:0]              InterruptedPC;
input                           InterruptHandled;
output                          InterruptRequest;

input                           UART0Request;
input                           UART1Request;


wire                            firetimer;
wire        [5:0]               interrupts;


reg         [31:0]              dataout;

reg         [31:0]              epc;
reg         [31:0]              count;
reg         [31:0]              compare;
reg         [31:0]              status;
reg         [31:0]              cause;

wire        [5:0]               ip;
wire        [5:0]               im;
wire                            ie;

wire        [5:0]               next_ip;


assign DataOut          = dataout;
assign InterruptRequest = ie & |(im & ip);

assign firetimer        = (count == compare);
assign firertc          = (count == 32'hFFFF_FFFF);
assign interrupts       = {firetimer, firertc, 2'b00, UART1Request, UART0Request};

assign ip               = cause[15:10];
assign im               = status[15:10];
assign ie               = status[0];

assign next_ip          = ip | interrupts;

always@(*) begin
    case(DataAddress)
        5'hE:       dataout <= epc;
        5'h9:       dataout <= count;
        5'hB:       dataout <= compare;
        5'hC:       dataout <= status;
        5'hD:       dataout <= cause;
        default:    dataout <= 32'bx;
    endcase
end

always@(posedge Clock) begin
    if(Enable) begin
        if(Reset) begin
            epc     <= 32'b0;
            count   <= 32'b0;
            compare <= 32'hFFFF;
            status  <= 32'b0;
            cause   <= 32'b0;
        end else begin
            if(DataInEnable) begin
                epc     <= epc;
                count   <= DataAddress == 5'h9 ? DataIn : count + 1;
                compare <= DataAddress == 5'hB ? DataIn : compare;
                status  <= DataAddress == 5'hC ? DataIn : status;
                cause   <= DataAddress == 5'hD ? {DataIn[31:16], next_ip & DataIn[15:10], DataIn[9:0]}
                         : DataAddress == 5'hB ? {cause[31:16], 1'b0, next_ip[4:0], cause[9:0]}
                         :                       {cause[31:16], next_ip, cause[9:0]};
            end else if(InterruptHandled) begin
                epc     <= InterruptedPC;
                count   <= count + 1;
                compare <= compare;
                status  <= {status[31:1], 1'b0};
                cause   <= {cause[31:16], next_ip, cause[9:0]};
            end else begin
                epc     <= epc;
                count   <= count + 1;
                compare <= compare;
                status  <= status;
                cause   <= {cause[31:16], next_ip, cause[9:0]};
            end
        end
    end
end

endmodule
