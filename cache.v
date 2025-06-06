module cache_controller(
    input clk,
    input rst,
    input start,
    input read_write,
    input [7:0] tag_in,
    output reg [3:0] state_out,
    output reg hit_out
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

    reg [3:0] current_state, next_state;
    reg [7:0] tag_array [3:0];
    reg [1:0] age [3:0];
    reg valid [3:0];
    reg dirty [3:0];
    integer i;
    integer lru_index;
    reg hit;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            current_state <= IDLE;
            for (i = 0; i < 4; i = i + 1) begin
                tag_array[i] <= 8'd0;
                age[i] <= i;
                valid[i] <= 0;
                dirty[i] <= 0;
            end
        end else begin
            current_state <= next_state;
        end
    end

    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = TAG_CHECK;
            end
            TAG_CHECK: begin
                hit = 0;
                for (i = 0; i < 4; i = i + 1) begin
                    if (valid[i] && tag_array[i] == tag_in)
                        hit = 1;
                end
                if (hit && !read_write)
                    next_state = RD_HIT;
                else if (hit && read_write)
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
    
    function integer find_index;
        input [7:0] tag_val;
        begin
        find_index = -1;
        for (i = 0; i < 4; i = i + 1)
            if (valid[i] && tag_array[i] == tag_val)
                find_index = i;
        end
    endfunction


    always @(posedge clk) begin
      
      
        case (current_state)
            TAG_CHECK: begin
                hit = 0;
                for (i = 0; i < 4; i = i + 1) begin
                    if (valid[i] && tag_array[i] == tag_in) begin
                        hit = 1;
                        age[i] <= 0;
                    end else if (valid[i]) begin
                        age[i] <= age[i] + 1;
                    end
                end
                hit_out <= hit;
            end
            UPDATE: begin
                if (hit) begin
                    for (i = 0; i < 4; i = i + 1) begin
                        if (valid[i] && tag_array[i] == tag_in) begin
                            dirty[i] <= read_write;
                            age[i] <= 0;
                        end else if (valid[i] && age[i] < age[find_index(tag_in)]) begin
                            age[i] <= age[i] + 1;
                        end
                    end
            end else begin
                lru_index = 0;
                for (i = 1; i < 4; i = i + 1)
                    if (age[i] > age[lru_index])
                        lru_index = i;

                tag_array[lru_index] <= tag_in;
                valid[lru_index] <= 1;
                dirty[lru_index] <= read_write;
                age[lru_index] <= 0;

                for (i = 0; i < 4; i = i + 1)
                    if (i != lru_index && valid[i])
                        age[i] <= age[i] + 1;
            end
        end

        endcase
        state_out <= current_state;
    end
endmodule


module cache_controller_tb;

    reg clk;
    reg rst;
    reg start;
    reg read_write;
    reg [7:0] tag_in;
    wire [3:0] state_out;
    wire hit_out;

    cache_controller uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .read_write(read_write),
        .tag_in(tag_in),
        .state_out(state_out),
        .hit_out(hit_out)
    );

    // Clock generation
    always #5 clk = ~clk;

    integer i;
    reg [7:0] tag_seq [0:49];
    initial begin
        clk = 0;
        rst = 1;
        start = 0;
        read_write = 0;
        tag_in = 0;
        #20 rst = 0;

        // Generate test tag sequence within a realistic set-associative tag space (simulate 128 sets)
        for (i = 0; i < 50; i = i + 1) begin
            tag_seq[i] = { $urandom_range(0, 7), $urandom_range(0, 15) }; // 3 MSBs as index, 5 LSBs as tag
        end

        // Apply test sequence
        for (i = 0; i < 50; i = i + 1) begin
            @(posedge clk);
            start = 1;
            tag_in = tag_seq[i];
            read_write = $urandom % 2;
            $display("[%0t] Start access #%0d | RW=%0d | Tag=0x%h", $time, i, read_write, tag_in);
            @(posedge clk);
            start = 0;
            repeat (6) @(posedge clk);
            dump_cache();
        end

        #100 $finish;
    end

    // Monitor state transitions
    reg [3:0] prev_state;
    always @(posedge clk) begin
        if (state_out !== prev_state) begin
            $display("[%0t] State changed: %s", $time, state_name(state_out));
            prev_state <= state_out;
        end
    end

    // Translate state number to string
    function [8*12:1] state_name;
        input [3:0] state;
        case (state)
            4'd0: state_name = "IDLE";
            4'd1: state_name = "TAG_CHECK";
            4'd2: state_name = "RD_HIT";
            4'd3: state_name = "WR_HIT";
            4'd4: state_name = "EVICT";
            4'd5: state_name = "WR_MISS";
            4'd6: state_name = "RD_MISS";
            4'd7: state_name = "UPDATE";
            4'd8: state_name = "RESPONSE";
            default: state_name = "UNKNOWN";
        endcase
    endfunction

    // Cache state dump with visualization
    task dump_cache;
        integer j;
        begin
            $display("[%0t] Cache Dump:", $time);
            for (j = 0; j < 4; j = j + 1) begin
                $display("  Line %0d | Valid: %0d | Dirty: %0d | Age: %0d | Tag: 0x%h %s",
                    j,
                    uut.valid[j],
                    uut.dirty[j],
                    uut.age[j],
                    uut.tag_array[j],
                    (uut.age[j] == 2'b11) ? "<-- LRU" : "");
            end
        end
    endtask

endmodule


