# Architecture

## M0 trust plane

ChipletTrust M0 separates a chiplet endpoint from the system trust manager.

Each endpoint contains:

1. **Lifecycle controller** — enforces a one-way state graph and disables the endpoint on tamper.
2. **Measurement bank** — four PCR-like registers extended with boot/runtime measurements.
3. **Attestation engine** — produces a deterministic challenge response from device ID, measurement digest, secret word, and a monotonically increasing nonce.
4. **Debug policy** — debug is allowed only in TEST and RMA states.

The system manager receives the result of an attestation comparison rather than implementing policy inside the endpoint. This keeps policy independently testable and allows future protocol adapters to feed the same manager.

## Containment policy

A chiplet is isolated when any of these occurs:

- attestation completes with a mismatch;
- tamper is asserted;
- the heartbeat counter reaches its configured limit.

Isolation is sticky until reset. Later successful attestation cannot silently re-admit an isolated chiplet.

## Cryptography boundary

The M0 mixing function is intentionally reversible and therefore not suitable for authentication. It is a verification seam. Future cryptographic backends can replace it without changing lifecycle, measurement, containment, or test APIs.
