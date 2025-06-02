module cache_controller (
    input clk,
    input rst,
    input start,
    input read_write,
    input hit_miss,
    output [3:0] state_out
);

    localparam
        IDLE      = 4'd0,
        TAG_CHECK = 4'd1,
        RD_HIT    = 4'd2,
        WR_HIT    = 4'd3,
        EVICT     = 4'd4,
        WR_MISS   = 4'd5,
        RD_MISS   = 4'd6,
        UPDATE    = 4'd7,
        RESPONSE  = 4'd8;

    reg[3:0] current_state, next_state;

    always @(posedge clk or posedge rst) begin
        if (rst)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    always @(*)begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = TAG_CHECK;
            end
            TAG_CHECK: begin
                if (!hit_miss && !read_write)
                    next_state = RD_HIT;
                else if (!hit_miss && read_write)
                    next_state = WR_HIT;
                else
                    next_state = EVICT;
            end
            RD_HIT:    next_state = RESPONSE;
            WR_HIT:    next_state = UPDATE;
            EVICT:     next_state = (read_write ? WR_MISS : RD_MISS);
            WR_MISS:   next_state = UPDATE;
            RD_MISS:   next_state = UPDATE;
            UPDATE:    next_state = RESPONSE;
            RESPONSE:  next_state = IDLE;
            default:   next_state = IDLE;
        endcase
    end

    assign state_out = current_state;

endmodule  
  
  module cache_controller_tb;

    reg clk;
    reg rst;
    reg start;
    reg read_write;
    reg hit_miss;
    wire [3:0] state_out;

    // Instantiate the DUT (Device Under Test)
    cache_controller uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .read_write(read_write),
        .hit_miss(hit_miss),
        .state_out(state_out)
    );

    always #5 clk = ~clk;
    
    function automatic get_hit_miss;
      input dump;
    begin
        // Use a random number from 0 to 99
        // Return 1 (miss) only if the number is 98 or 99
        get_hit_miss = ($urandom_range(0, 99) < 98) ? 0 : 1;
    end
endfunction

    integer i;
initial begin

    clk = 0;
    rst = 1;
    start = 0;
    read_write = 0;
    hit_miss = 0;
    #10 rst = 0;

    for (i = 0; i < 50; i = i + 1) begin
        #10;
        start = 1;
        read_write = $urandom % 2;
        hit_miss = get_hit_miss(1);
        #10;
        start = 0;
        #60;
    end
end
    
    // Monitor FSM state and inputs on state change
  reg prev_start, prev_rw, prev_hitmiss;
  reg [3:0] prev_state;

always @(posedge clk) begin
    if (read_write !== prev_rw || hit_miss !== prev_hitmiss) begin
        $display("Time: %0t | Input change -> read_write=%b, hit_miss=%b",
                 $time, read_write, hit_miss);
        prev_start   <= start;
        prev_rw      <= read_write;
        prev_hitmiss <= hit_miss;
    end
end

always @(posedge clk) begin
    if (state_out !== prev_state) begin
        $display("Time: %0t | State: %s",
                 $time, state_name(state_out));
        prev_state <= state_out;
    end
end

// Function to convert state number to name
function [8*10:1] state_name;
    input [3:0] state;
    case (state)
        4'd0:  state_name = "IDLE";
        4'd1:  state_name = "TAG_CHECK";
        4'd2:  state_name = "RD_HIT";
        4'd3:  state_name = "WR_HIT";
        4'd4:  state_name = "EVICT";
        4'd5:  state_name = "WR_MISS";
        4'd6:  state_name = "RD_MISS";
        4'd7:  state_name = "UPDATE";
        4'd8:  state_name = "RESPONSE";
        default: state_name = "UNKNOWN";
    endcase
endfunction


endmodule