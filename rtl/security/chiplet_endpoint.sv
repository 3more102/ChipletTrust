module chiplet_endpoint #(
  parameter logic [31:0] DEVICE_ID = 32'hC100_0001,
  parameter logic [31:0] SECRET_WORD = 32'h1BAD_B002
) (
  input  logic                           clk,
  input  logic                           rst_n,
  input  logic                           tamper,
  input  logic                           transition_req,
  input  chiplettrust_pkg::lifecycle_e   requested_state,
  input  logic                           extend_valid,
  input  logic [1:0]                     extend_index,
  input  logic [31:0]                    extend_data,
  input  logic [7:0]                     extend_domain,
  input  logic                           attest_start,
  input  logic [31:0]                    attest_challenge,
  output chiplettrust_pkg::lifecycle_e   lifecycle_state,
  output logic                           transition_ack,
  output logic                           transition_error,
  output logic                           debug_allowed,
  output logic [31:0]                    measurement_digest,
  output logic                           attest_busy,
  output logic                           attest_done,
  output logic                           attest_error,
  output logic [31:0]                    attest_response,
  output logic [31:0]                    nonce_counter
);
  import chiplettrust_pkg::*;

  logic [127:0] pcr_flat_unused;
  logic key_valid;

  lifecycle_ctrl u_lifecycle (
    .clk(clk), .rst_n(rst_n),
    .transition_req(transition_req), .requested_state(requested_state),
    .tamper(tamper), .state(lifecycle_state),
    .transition_ack(transition_ack), .transition_error(transition_error),
    .debug_allowed(debug_allowed)
  );

  measurement_bank #(.NUM_REGS(4)) u_measurement (
    .clk(clk), .rst_n(rst_n),
    .extend_valid(extend_valid), .extend_index(extend_index),
    .extend_data(extend_data), .extend_domain(extend_domain),
    .pcr_flat(pcr_flat_unused), .digest(measurement_digest)
  );

  assign key_valid = (lifecycle_state == LC_PROVISIONED) ||
                     (lifecycle_state == LC_ACTIVE) ||
                     (lifecycle_state == LC_RMA);

  attestation_engine u_attestation (
    .clk(clk), .rst_n(rst_n), .start(attest_start),
    .challenge(attest_challenge), .device_id(DEVICE_ID),
    .measurement_digest(measurement_digest), .secret_word(SECRET_WORD),
    .key_valid(key_valid), .busy(attest_busy), .done(attest_done),
    .error(attest_error), .response(attest_response), .nonce_counter(nonce_counter)
  );
endmodule
