module replay_guard #(
  parameter int unsigned CACHE_DEPTH = 4
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        request_valid,
  input  logic [31:0] session_id,
  input  logic [31:0] challenge,
  input  logic        commit,
  output logic        replay_detected,
  output logic        accepted
);
  localparam int unsigned PTR_W = (CACHE_DEPTH < 2) ? 1 : $clog2(CACHE_DEPTH);

  logic [31:0] session_cache   [0:CACHE_DEPTH-1];
  logic [31:0] challenge_cache [0:CACHE_DEPTH-1];
  logic        valid_cache     [0:CACHE_DEPTH-1];
  logic [PTR_W-1:0] wr_ptr_q;
  integer i;

  always_comb begin
    replay_detected = 1'b0;
    if (request_valid) begin
      for (i = 0; i < CACHE_DEPTH; i = i + 1) begin
        if (valid_cache[i] &&
            session_cache[i] == session_id &&
            challenge_cache[i] == challenge)
          replay_detected = 1'b1;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr_q <= '0;
      accepted <= 1'b0;
      for (i = 0; i < CACHE_DEPTH; i = i + 1) begin
        session_cache[i]   <= 32'h0;
        challenge_cache[i] <= 32'h0;
        valid_cache[i]     <= 1'b0;
      end
    end else begin
      accepted <= 1'b0;
      if (request_valid && commit && !replay_detected) begin
        session_cache[wr_ptr_q]   <= session_id;
        challenge_cache[wr_ptr_q] <= challenge;
        valid_cache[wr_ptr_q]     <= 1'b1;
        accepted                  <= 1'b1;
        if (wr_ptr_q == CACHE_DEPTH-1)
          wr_ptr_q <= '0;
        else
          wr_ptr_q <= wr_ptr_q + 1'b1;
      end
    end
  end
endmodule
