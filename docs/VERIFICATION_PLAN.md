# Verification plan

## Functional categories

- lifecycle legal transitions
- lifecycle illegal transition rejection
- debug policy by lifecycle state
- measurement extend and digest propagation
- attestation nonce monotonicity
- good attestation grants trust
- bad attestation isolates
- tamper isolates and revokes trust
- heartbeat timeout isolates
- isolated chiplet cannot be re-trusted without reset

## Adversarial campaigns

1. firmware measurement mutation
2. repeated challenge with old response
3. illegal ACTIVE -> TEST rollback request
4. tamper during trusted operation
5. heartbeat suppression
6. good attestation after prior isolation

## M0 pass criteria

- all Python model tests pass
- RTL smoke compiles with Icarus Verilog and passes
- no trusted+isolated state observed
- all documented M0 adversarial scenarios have an automated check
