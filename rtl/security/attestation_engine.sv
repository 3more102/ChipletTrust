module attestation_engine (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [31:0] challenge,
  input  logic [31:0] device_id,
  input  logic [31:0] measurement_digest,
  input  logic [31:0] secret_word,
  input  logic        key_valid,
  output logic        busy,
  output logic        done,
  output logic        error,
  output logic [31:0] response,
  output logic [31:0] nonce_counter
);
  import chiplettrust_pkg::*;

  logic pending_q;
  logic [31:0] challenge_q;
  logic [31:0] digest_q;
  logic [31:0] device_id_q;
  logic [31:0] secret_q;
  logic [31:0] nonce_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pending_q     <= 1'b0;
      done          <= 1'b0;
      error         <= 1'b0;
      response      <= 32'h0;
      nonce_q       <= 32'h1;
      challenge_q   <= 32'h0;
      digest_q      <= 32'h0;
      device_id_q   <= 32'h0;
      secret_q      <= 32'h0;
    end else begin
      done  <= 1'b0;
      error <= 1'b0;

      if (start && !pending_q) begin
        if (!key_valid) begin
          error <= 1'b1;
          done  <= 1'b1;
        end else begin
          challenge_q <= challenge;
          digest_q    <= measurement_digest;
          device_id_q <= device_id;
          secret_q    <= secret_word;
          pending_q   <= 1'b1;
        end
      end else if (pending_q) begin
        response  <= attestation_mix(challenge_q, device_id_q, digest_q, secret_q, nonce_q);
        nonce_q   <= nonce_q + 32'd1;
        pending_q <= 1'b0;
        done      <= 1'b1;
      end
    end
  end

  assign busy = pending_q;
  assign nonce_counter = nonce_q;
endmodule
