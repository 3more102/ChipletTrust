module secure_attestation_session #(
  parameter int unsigned CACHE_DEPTH = 4
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        request_valid,
  input  logic        commit,
  input  logic [31:0] session_id,
  input  logic [31:0] challenge,
  input  logic [31:0] device_id,
  input  logic [31:0] measurement_digest,
  input  logic [31:0] secret_word,
  input  logic        key_valid,
  output logic        replay_detected,
  output logic        accepted,
  output logic        busy,
  output logic        done,
  output logic        error,
  output logic [31:0] response,
  output logic [31:0] nonce_counter
);
  import chiplettrust_pkg::*;

  logic [31:0] bound_challenge;
  logic        guard_commit;
  logic        attest_start;

  // Bind the session identifier into the attestation transcript. This is
  // intentionally still a verification primitive, not a cryptographic KDF.
  always_comb begin
    bound_challenge = challenge ^ rotl32(session_id, 13) ^ 32'h5345_5353;
  end

  // Only commit freshness state when a usable key exists. A request made
  // before provisioning can therefore be retried after provisioning.
  assign guard_commit = commit && key_valid;

  replay_guard #(
    .CACHE_DEPTH(CACHE_DEPTH)
  ) u_replay_guard (
    .clk(clk),
    .rst_n(rst_n),
    .request_valid(request_valid),
    .session_id(session_id),
    .challenge(challenge),
    .commit(guard_commit),
    .replay_detected(replay_detected),
    .accepted(accepted)
  );

  // Replayed requests never reach the attestation engine. Fresh requests with
  // an invalid key still reach it so the existing error/done behavior is kept.
  assign attest_start = request_valid && commit && !replay_detected;

  attestation_engine u_attestation_engine (
    .clk(clk),
    .rst_n(rst_n),
    .start(attest_start),
    .challenge(bound_challenge),
    .device_id(device_id),
    .measurement_digest(measurement_digest),
    .secret_word(secret_word),
    .key_valid(key_valid),
    .busy(busy),
    .done(done),
    .error(error),
    .response(response),
    .nonce_counter(nonce_counter)
  );

endmodule
