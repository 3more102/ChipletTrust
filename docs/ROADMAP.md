# Roadmap

## M0 — Trusted bring-up baseline

- [x] lifecycle FSM
- [x] measurement bank
- [x] deterministic attestation seam
- [x] sticky isolation manager
- [x] Python golden model
- [x] adversarial unit tests
- [x] RTL smoke test
- [x] CI baseline

## M1 — Transcript integrity and mailbox

- [ ] request/response mailbox registers
- [ ] explicit session ID and challenge freshness window
- [ ] replay cache and replay error reason
- [ ] per-chiplet evidence record
- [ ] negative protocol tests
- [ ] functional coverage model

## M2 — Cryptographic backend

- [ ] pluggable SHA-256 measurement backend
- [ ] HMAC/signature abstraction
- [ ] public identity/certificate representation
- [ ] deterministic test keys separate from production interfaces
- [ ] known-answer tests

## M3 — Multi-chiplet verification platform

- [ ] UVM environment
- [ ] fault/attack sequence library
- [ ] coverage-guided scenario generation
- [ ] protocol adapter layer for management transport
- [ ] evidence JSON and HTML security dossier
- [ ] synthesis/area/frequency reporting
