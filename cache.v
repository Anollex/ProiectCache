module controlUnitCache(
  input clk,
  input rst_b,
  input wire [1:0] cin,
  output reg cout
);

  localparam
    IDLE      = 4'd0,
    TAG_CHECK = 4'd1,
    RD_HIT    = 4'd2,
    WT_HIT    = 4'd3,
    RD_MISS   = 4'd4,
    WT_MISS   = 4'd5,
    EVICT     = 4'd6,
    UPDATE    = 4'd7,
    RESPONSE  = 4'd8;

  reg [3:0] state, next_state;

  reg [3:0] data [3:0];    // data[i]: [valid(3)][dirty(2)][timer(1:0)]
  reg [2:0] pos;
  reg [1:0] evicted_index;

  integer i;

  function [2:0] biasedRandom;
    input dummy;
    integer rand;
    begin
      rand = $urandom % 100;
      if (rand < 98)
        biasedRandom = $urandom % 4;
      else
        biasedRandom = 3'd4;
    end
  endfunction

  function [1:0] findEvict;
    input dummy;
    begin
      findEvict = 0;
      for (i = 1; i < 4; i = i + 1) begin
        // Evict line with largest timer (LRU)
        if (data[i][1:0] > data[findEvict][1:0])
          findEvict = i;
      end
    end
  endfunction

  task updateTimer;
    input [1:0] position;
    begin
      for (i = 0; i < 4; i = i + 1) begin
        if (i != position && data[i][1:0] < 2'd3)
          data[i][1:0] = data[i][1:0] + 1;
      end
      data[position][1:0] = 2'd0;
    end
  endtask

  task putFirst;
    input [1:0] position;
    begin
      for (i = 0; i < 4; i = i + 1) begin
        if (data[i][1:0] < data[position][1:0])
          data[i][1:0] = data[i][1:0] + 1;
      end
      data[position][1:0] = 2'd0;
    end
  endtask

  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (cin[0])
          next_state = TAG_CHECK;
      end

      TAG_CHECK: begin
        if (pos == 3'd4) begin
          next_state = EVICT;
          cout = 1;
        end else begin
          if (data[pos][3] == 1'b1) begin
            cout = 0;
            casez ({cin[1], cout[0]})
              1'b0: next_state = RD_HIT;
              1'b1: next_state = WT_HIT;
              default: next_state = IDLE;
            endcase
          end else begin
            next_state = (cin[1] == 1'b1) ? WT_MISS : RD_MISS;
            cout = 1;
          end
        end
      end

      RD_HIT:   next_state = RESPONSE;
      WT_HIT:   next_state = UPDATE;
      RD_MISS:  next_state = RESPONSE;
      WT_MISS:  next_state = UPDATE;
      UPDATE:   next_state = RESPONSE;
      RESPONSE: next_state = IDLE;

      EVICT: begin
        if (cout[0] == 1'b0)
          next_state = RD_MISS;
        else
          next_state = WT_MISS;
      end
    endcase
  end

  always @(posedge clk, negedge rst_b) begin
    if (!rst_b) begin
      state <= IDLE;
      for (i = 0; i < 4; i = i + 1)
        data[i] <= 4'b0000;  // valid=0, dirty=0, timer=0
    end else begin
      state <= next_state;

      case (state)
        TAG_CHECK: begin
          pos <= biasedRandom(1);
          if (pos == 3'd4) begin
            evicted_index <= findEvict(0);
          end else begin
            data[pos][3] <= 1'b1;      // valid
            data[pos][2] <= 1'b0;      // dirty cleared
            putFirst(pos[1:0]);
          end
        end

        EVICT: begin
          if (pos == 3'd4) begin
            updateTimer(evicted_index);
            data[evicted_index][3] <= 1'b0;
            data[evicted_index][2] <= 1'b0;
          end
        end

        WT_HIT, WT_MISS, UPDATE: begin
          data[pos][2] <= 1'b1;
        end
      endcase
    end
  end

endmodule

`timescale 1ns / 1ps

module controlUnitCache_tb;

  reg clk;
  reg rst_b;
  reg [3:0] cin;
  wire [7:0] cout;

  // Instantiate the cache controller
  controlUnitCache uut (
    .clk(clk),
    .rst_b(rst_b),
    .cin(cin),
    .cout(cout)
  );

  // Clock generation: 10ns period
  initial clk = 0;
  always #5 clk = ~clk;

  integer cycle_count;
  integer op_count;
  reg [7:0] rand_val;

  initial begin
    // Initialize inputs
    rst_b = 0;
    cin = 4'b0000;
    cycle_count = 0;
    op_count = 0;

    // Release reset after 20 ns
    #20 rst_b = 1;

    // Run 100 valid operations
    while (op_count < 100) begin
      @(posedge clk);

      // Randomly decide if we start a new operation
      rand_val = $urandom % 100;

      if (rand_val < 50) begin
        // 50% chance to start an operation
        // Random read/write with ~66% reads, 34% writes
        rand_val = $urandom % 100;
        if (rand_val < 66) begin
          // Read operation
          cin[1] = 1'b0;
        end else begin
          // Write operation
          cin[1] = 1'b1;
        end

        cin[0] = 1'b1;  // Trigger new operation

        op_count = op_count + 1;
      end else begin
        // No new operation this cycle
        cin[0] = 1'b0;
      end

      // Display current state info for debug
      $display("Cycle %0d: cin=%b, state=%0d, pos=%0d, valid/dirty/timer (line0)=%b", 
               op_count, cin, uut.state, uut.pos, uut.data[0]);

      @(negedge clk);
    end
  end

endmodule