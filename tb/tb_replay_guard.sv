`timescale 1ns/1ps
module tb_replay_guard;
  logic clk = 1'b0;
  logic rst_n = 1'b0;
  logic request_valid = 1'b0;
  logic [31:0] session_id = 32'h0;
  logic [31:0] challenge = 32'h0;
  logic commit = 1'b0;
  logic replay_detected;
  logic accepted;

  always #5 clk = ~clk;

  replay_guard #(.CACHE_DEPTH(4)) dut (
    .clk(clk), .rst_n(rst_n), .request_valid(request_valid),
    .session_id(session_id), .challenge(challenge), .commit(commit),
    .replay_detected(replay_detected), .accepted(accepted)
  );

  task present(input logic [31:0] sid, input logic [31:0] ch);
    begin
      @(negedge clk);
      session_id = sid;
      challenge = ch;
      request_valid = 1'b1;
      commit = 1'b1;
      #1;
    end
  endtask

  task clear_req;
    begin
      @(negedge clk);
      request_valid = 1'b0;
      commit = 1'b0;
    end
  endtask

  initial begin
    repeat (2) @(negedge clk);
    rst_n = 1'b1;

    present(32'h10, 32'hAAAA0001);
    if (replay_detected) $fatal(1, "first request must be fresh");
    @(posedge clk); #1;
    if (!accepted) $fatal(1, "fresh request must be accepted");
    clear_req();

    present(32'h10, 32'hAAAA0001);
    if (!replay_detected) $fatal(1, "same session/challenge must be replay");
    clear_req();

    present(32'h11, 32'hAAAA0001);
    if (replay_detected) $fatal(1, "same challenge in a new session is fresh");
    clear_req();

    $display("ChipletTrust replay guard smoke: PASS");
    $finish;
  end
endmodule
