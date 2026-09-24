`timescale 1ns/1ps
module tb_chiplettrust;
  localparam int N = 4;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic [N-1:0] attest_done = '0;
  logic [N-1:0] attest_match = '0;
  logic [N-1:0] tamper = '0;
  logic [N-1:0] heartbeat = '1;
  logic [N-1:0] clear_trust = '0;
  logic [N-1:0] trusted;
  logic [N-1:0] isolated;
  logic [N-1:0] heartbeat_fault;

  always #5 clk = ~clk;

  chiplettrust_top #(.NUM_CHIPLETS(N), .HEARTBEAT_LIMIT(4)) dut (
    .clk(clk), .rst_n(rst_n),
    .attest_done(attest_done), .attest_match(attest_match),
    .tamper(tamper), .heartbeat(heartbeat), .clear_trust(clear_trust),
    .trusted(trusted), .isolated(isolated), .heartbeat_fault(heartbeat_fault)
  );

  task pulse_attestation(input int idx, input logic matches);
    begin
      @(negedge clk);
      attest_done[idx]  = 1'b1;
      attest_match[idx] = matches;
      @(negedge clk);
      attest_done[idx]  = 1'b0;
      attest_match[idx] = 1'b0;
    end
  endtask

  initial begin
    repeat (2) @(negedge clk);
    rst_n = 1'b1;

    pulse_attestation(0, 1'b1);
    if (!trusted[0] || isolated[0]) $fatal(1, "chiplet 0 should be trusted");

    pulse_attestation(1, 1'b0);
    if (!isolated[1] || trusted[1]) $fatal(1, "chiplet 1 should be isolated after failed attestation");

    @(negedge clk); tamper[0] = 1'b1;
    @(negedge clk); tamper[0] = 1'b0;
    if (!isolated[0] || trusted[0]) $fatal(1, "tamper must isolate chiplet 0");

    $display("ChipletTrust RTL smoke: PASS");
    $finish;
  end
endmodule
