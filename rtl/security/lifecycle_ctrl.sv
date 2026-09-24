module lifecycle_ctrl (
  input  logic                             clk,
  input  logic                             rst_n,
  input  logic                             transition_req,
  input  chiplettrust_pkg::lifecycle_e     requested_state,
  input  logic                             tamper,
  output chiplettrust_pkg::lifecycle_e     state,
  output logic                             transition_ack,
  output logic                             transition_error,
  output logic                             debug_allowed
);
  import chiplettrust_pkg::*;

  lifecycle_e state_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q          <= LC_RAW;
      transition_ack   <= 1'b0;
      transition_error <= 1'b0;
    end else begin
      transition_ack   <= 1'b0;
      transition_error <= 1'b0;

      if (tamper) begin
        state_q <= LC_DISABLED;
      end else if (transition_req) begin
        if (lifecycle_transition_allowed(state_q, requested_state)) begin
          state_q        <= requested_state;
          transition_ack <= 1'b1;
        end else begin
          transition_error <= 1'b1;
        end
      end
    end
  end

  assign state = state_q;
  assign debug_allowed = (state_q == LC_TEST) || (state_q == LC_RMA);
endmodule
