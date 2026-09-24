package chiplettrust_pkg;
  typedef enum logic [2:0] {
    LC_RAW         = 3'd0,
    LC_TEST        = 3'd1,
    LC_PROVISIONED = 3'd2,
    LC_ACTIVE      = 3'd3,
    LC_RMA         = 3'd4,
    LC_DISABLED    = 3'd5
  } lifecycle_e;

  function automatic logic [31:0] rotl32(input logic [31:0] x, input int unsigned sh);
    int unsigned s;
    begin
      s = sh % 32;
      if (s == 0)
        rotl32 = x;
      else
        rotl32 = (x << s) | (x >> (32-s));
    end
  endfunction

  function automatic logic lifecycle_transition_allowed(
    input lifecycle_e from_state,
    input lifecycle_e to_state
  );
    begin
      lifecycle_transition_allowed = 1'b0;
      unique case (from_state)
        LC_RAW:         lifecycle_transition_allowed = (to_state == LC_TEST) || (to_state == LC_PROVISIONED) || (to_state == LC_DISABLED);
        LC_TEST:        lifecycle_transition_allowed = (to_state == LC_PROVISIONED) || (to_state == LC_DISABLED);
        LC_PROVISIONED: lifecycle_transition_allowed = (to_state == LC_ACTIVE) || (to_state == LC_DISABLED);
        LC_ACTIVE:      lifecycle_transition_allowed = (to_state == LC_RMA) || (to_state == LC_DISABLED);
        LC_RMA:         lifecycle_transition_allowed = (to_state == LC_DISABLED);
        default:        lifecycle_transition_allowed = 1'b0;
      endcase
    end
  endfunction

  function automatic logic [31:0] measurement_extend(
    input logic [31:0] current,
    input logic [31:0] measurement,
    input logic [7:0]  domain
  );
    logic [31:0] domain_word;
    begin
      domain_word = {4{domain}};
      measurement_extend = rotl32(current, 5) ^ measurement ^ domain_word ^ 32'h4354_5255;
    end
  endfunction

  function automatic logic [31:0] attestation_mix(
    input logic [31:0] challenge,
    input logic [31:0] device_id,
    input logic [31:0] measurement_digest,
    input logic [31:0] secret_word,
    input logic [31:0] nonce_counter
  );
    logic [31:0] x;
    begin
      x = challenge ^ rotl32(device_id, 3) ^ rotl32(measurement_digest, 11);
      x = x ^ rotl32(secret_word, 17) ^ nonce_counter ^ 32'hA77E_5710;
      attestation_mix = rotl32(x, 7) ^ (x + 32'h9E37_79B9);
    end
  endfunction
endpackage
