# M1 session freshness and replay protection

M1 adds a bounded replay cache keyed by `(session_id, challenge)` and integrates
it with attestation through `secure_attestation_session.sv`.

A request is considered a replay only when both the session ID and challenge
match an entry still present in the cache. The RTL cache defaults to four
entries and uses round-robin replacement. The Python golden model mirrors the
same bounded-window behavior.

## Transcript binding

Fresh requests derive an effective challenge from the external challenge and
session ID before the attestation transform:

```text
bound_challenge = challenge XOR ROTL32(session_id, 13) XOR 0x53455353
```

The response therefore depends on the session identifier as well as the
challenge, measurement digest, device identity, secret word, and nonce.

The transform is deterministic for verification. It is **not cryptographic**
and is not a substitute for SPDM transcript hashing, authenticated session
establishment, a cryptographic MAC/signature, or a secure KDF.

## Admission behavior

- a fresh, committed request with a valid key is cached and attested
- an exact replay is rejected before it reaches the attestation engine
- the same challenge in a different session is accepted
- an attempt made before the key is valid reports the attestation error but
  does not consume the freshness entry, so it can be retried after provisioning
- cache replacement remains bounded and deterministic

## Automated checks

The Python model and RTL regressions cover:

- first session/challenge acceptance
- exact replay rejection
- same challenge in a new session
- session-bound response calculation
- invalid-key retry behavior
- bounded cache eviction
