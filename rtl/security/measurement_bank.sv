module measurement_bank #(
  parameter int unsigned NUM_REGS = 4
) (
  input  logic                        clk,
  input  logic                        rst_n,
  input  logic                        extend_valid,
  input  logic [$clog2(NUM_REGS)-1:0] extend_index,
  input  logic [31:0]                 extend_data,
  input  logic [7:0]                  extend_domain,
  output logic [NUM_REGS*32-1:0]      pcr_flat,
  output logic [31:0]                 digest
);
  import chiplettrust_pkg::*;

  logic [31:0] pcr [0:NUM_REGS-1];
  integer i;
  integer j;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < NUM_REGS; i = i + 1)
        pcr[i] <= 32'h0;
    end else if (extend_valid) begin
      pcr[extend_index] <= measurement_extend(pcr[extend_index], extend_data, extend_domain);
    end
  end

  always_comb begin
    pcr_flat = '0;
    digest = 32'h4354_0001;
    for (j = 0; j < NUM_REGS; j = j + 1) begin
      pcr_flat[j*32 +: 32] = pcr[j];
      digest = rotl32(digest, 3) ^ pcr[j] ^ (32'h0101_0101 * j);
    end
  end
endmodule
