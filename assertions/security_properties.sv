module security_properties #(
  parameter int unsigned NUM_CHIPLETS = 4
) (
  input logic                    clk,
  input logic                    rst_n,
  input logic [NUM_CHIPLETS-1:0] trusted,
  input logic [NUM_CHIPLETS-1:0] isolated,
  input logic [NUM_CHIPLETS-1:0] tamper
);
  genvar g;
  generate
    for (g = 0; g < NUM_CHIPLETS; g = g + 1) begin : gen_security_sva
      // A chiplet may never be both trusted and isolated.
      assert property (@(posedge clk) disable iff (!rst_n)
        !(trusted[g] && isolated[g]));

      // Tamper must cause isolation no later than the following sampled cycle.
      assert property (@(posedge clk) disable iff (!rst_n)
        tamper[g] |=> isolated[g]);

      // Isolation is sticky until reset.
      assert property (@(posedge clk) disable iff (!rst_n)
        isolated[g] |=> isolated[g]);
    end
  endgenerate
endmodule
