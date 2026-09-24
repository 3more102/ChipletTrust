# M1 session freshness and replay protection

M1 adds a bounded replay cache keyed by `(session_id, challenge)`.

A request is considered a replay only when both the session ID and challenge match an entry still present in the cache. The RTL cache defaults to four entries and uses round-robin replacement. The Python golden model mirrors the same bounded-window behavior.

This mechanism provides deterministic replay/freshness verification for the control plane. It is not a replacement for cryptographic transcript binding, authenticated session establishment, or a standards-compliant secure session protocol.

## Automated checks

- first session/challenge pair is accepted
- exact repeated pair is rejected
- same challenge in a different session is accepted
- bounded cache evicts its oldest entry
