`timescale 1ns/1ps
module tb_secure_attestation_session;
  import chiplettrust_pkg::*;

  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic request_valid = 1'b0;
  logic commit = 1'b0;
  logic [31:0] session_id = 32'h0;
  logic [31:0] challenge = 32'h0;
  logic [31:0] device_id = 32'hC100_0001;
  logic [31:0] measurement_digest = 32'h0123_4567;
  logic [31:0] secret_word = 32'h1BAD_B002;
  logic key_valid = 1'b1;

  logic replay_detected;
  logic accepted;
  logic busy;
  logic done;
  logic error;
  logic [31:0] response;
  logic [31:0] nonce_counter;

  logic [31:0] first_response;
  logic [31:0] expected;

  always #5 clk = ~clk;

  secure_attestation_session #(.CACHE_DEPTH(4)) dut (
    .clk(clk), .rst_n(rst_n),
    .request_valid(request_valid), .commit(commit),
    .session_id(session_id), .challenge(challenge),
    .device_id(device_id), .measurement_digest(measurement_digest),
    .secret_word(secret_word), .key_valid(key_valid),
    .replay_detected(replay_detected), .accepted(accepted),
    .busy(busy), .done(done), .error(error),
    .response(response), .nonce_counter(nonce_counter)
  );

  task begin_request(input logic [31:0] sid, input logic [31:0] ch);
    begin
      @(negedge clk);
      session_id = sid;
      challenge = ch;
      request_valid = 1'b1;
      commit = 1'b1;
      #1;
    end
  endtask

  task end_request;
    begin
      @(negedge clk);
      request_valid = 1'b0;
      commit = 1'b0;
    end
  endtask

  task wait_done;
    begin
      while (!done) begin
        @(posedge clk);
        #1;
      end
    end
  endtask

  function automatic logic [31:0] bound(
    input logic [31:0] sid,
    input logic [31:0] ch
  );
    bound = ch ^ rotl32(sid, 13) ^ 32'h5345_5353;
  endfunction

  initial begin
    repeat (2) @(negedge clk);
    rst_n = 1'b1;

    // First request is fresh and its response binds session_id.
    begin_request(32'h10, 32'hAAAA_0001);
    if (replay_detected) $fatal(1, "first request must be fresh");
    expected = attestation_mix(
      bound(32'h10, 32'hAAAA_0001),
      device_id, measurement_digest, secret_word, 32'h1
    );
    @(posedge clk); #1;
    if (!accepted || !busy) $fatal(1, "fresh request must be admitted");
    end_request();
    wait_done();
    if (error) $fatal(1, "fresh attestation must not error");
    if (response !== expected) $fatal(1, "session-bound response mismatch");
    first_response = response;

    // Exact session/challenge replay is blocked before attestation.
    begin_request(32'h10, 32'hAAAA_0001);
    if (!replay_detected) $fatal(1, "exact replay must be detected");
    @(posedge clk); #1;
    if (accepted || busy) $fatal(1, "replay reached attestation engine");
    end_request();

    // Same challenge in a new session is fresh and produces a different
    // transcript-bound response.
    begin_request(32'h11, 32'hAAAA_0001);
    if (replay_detected) $fatal(1, "new session must be fresh");
    expected = attestation_mix(
      bound(32'h11, 32'hAAAA_0001),
      device_id, measurement_digest, secret_word, 32'h2
    );
    @(posedge clk); #1;
    if (!accepted) $fatal(1, "new session must be admitted");
    end_request();
    wait_done();
    if (response !== expected) $fatal(1, "new-session response mismatch");
    if (response === first_response) $fatal(1, "session binding did not change response");

    // A pre-provisioning attempt errors but is not burned into replay cache.
    key_valid = 1'b0;
    begin_request(32'h22, 32'hBBBB_0002);
    if (replay_detected) $fatal(1, "fresh invalid-key request marked replay");
    @(posedge clk); #1;
    if (accepted) $fatal(1, "invalid-key request must not commit freshness state");
    end_request();
    wait_done();
    if (!error) $fatal(1, "invalid-key request must error");

    key_valid = 1'b1;
    begin_request(32'h22, 32'hBBBB_0002);
    if (replay_detected) $fatal(1, "failed invalid-key request must remain retryable");
    @(posedge clk); #1;
    if (!accepted) $fatal(1, "retry after key provisioning must be accepted");
    end_request();
    wait_done();

    $display("ChipletTrust secure attestation session: PASS");
    $finish;
  end
endmodule
