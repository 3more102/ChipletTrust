module chiplet_manager #(
  parameter int unsigned NUM_CHIPLETS = 4,
  parameter int unsigned HEARTBEAT_LIMIT = 8
) (
  input  logic                       clk,
  input  logic                       rst_n,
  input  logic [NUM_CHIPLETS-1:0]    attest_done,
  input  logic [NUM_CHIPLETS-1:0]    attest_match,
  input  logic [NUM_CHIPLETS-1:0]    tamper,
  input  logic [NUM_CHIPLETS-1:0]    heartbeat,
  input  logic [NUM_CHIPLETS-1:0]    clear_trust,
  output logic [NUM_CHIPLETS-1:0]    trusted,
  output logic [NUM_CHIPLETS-1:0]    isolated,
  output logic [NUM_CHIPLETS-1:0]    heartbeat_fault
);
  localparam int unsigned HB_W = (HEARTBEAT_LIMIT < 2) ? 1 : $clog2(HEARTBEAT_LIMIT + 1);
  logic [HB_W-1:0] hb_count [0:NUM_CHIPLETS-1];
  integer i;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      trusted         <= '0;
      isolated        <= '0;
      heartbeat_fault <= '0;
      for (i = 0; i < NUM_CHIPLETS; i = i + 1)
        hb_count[i] <= '0;
    end else begin
      for (i = 0; i < NUM_CHIPLETS; i = i + 1) begin
        if (heartbeat[i]) begin
          hb_count[i] <= '0;
        end else if (!isolated[i]) begin
          if (hb_count[i] < HEARTBEAT_LIMIT)
            hb_count[i] <= hb_count[i] + 1'b1;
          if (hb_count[i] >= HEARTBEAT_LIMIT-1) begin
            heartbeat_fault[i] <= 1'b1;
            isolated[i]        <= 1'b1;
            trusted[i]         <= 1'b0;
          end
        end

        if (clear_trust[i])
          trusted[i] <= 1'b0;

        if (attest_done[i] && !isolated[i]) begin
          if (attest_match[i])
            trusted[i] <= 1'b1;
          else begin
            trusted[i]  <= 1'b0;
            isolated[i] <= 1'b1;
          end
        end

        if (tamper[i]) begin
          trusted[i]  <= 1'b0;
          isolated[i] <= 1'b1;
        end
      end
    end
  end
endmodule
