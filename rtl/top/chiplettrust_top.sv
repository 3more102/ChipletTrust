module chiplettrust_top #(
  parameter int unsigned NUM_CHIPLETS = 4,
  parameter int unsigned HEARTBEAT_LIMIT = 8
) (
  input  logic                       clk,
  input  logic                       rst_n,
  input  logic [NUM_CHIPLETS-1:0]    attest_done,
  input  logic [NUM_CHIPLETS-1:0]    attest_match,
  input  logic [NUM_CHIPLETS-1:0]    tamper,
  input  logic [NUM_CHIPLETS-1:0]    heartbeat,
  input  logic [NUM_CHIPLETS-1:0]    clear_trust,
  output logic [NUM_CHIPLETS-1:0]    trusted,
  output logic [NUM_CHIPLETS-1:0]    isolated,
  output logic [NUM_CHIPLETS-1:0]    heartbeat_fault
);
  chiplet_manager #(
    .NUM_CHIPLETS(NUM_CHIPLETS),
    .HEARTBEAT_LIMIT(HEARTBEAT_LIMIT)
  ) u_manager (
    .clk(clk), .rst_n(rst_n),
    .attest_done(attest_done), .attest_match(attest_match),
    .tamper(tamper), .heartbeat(heartbeat), .clear_trust(clear_trust),
    .trusted(trusted), .isolated(isolated), .heartbeat_fault(heartbeat_fault)
  );
endmodule
