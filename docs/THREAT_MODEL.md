# Threat model — M0

## Assets

- chiplet identity
- boot/runtime measurements
- lifecycle state
- trust decision
- isolation state
- future attestation keys and certificates

## Adversary capabilities covered in M0

- substitute or alter a measured firmware image
- replay an old response against a reused challenge
- request an illegal lifecycle rollback
- assert a hardware tamper indication
- stop heartbeat traffic
- submit a mismatched attestation result

## Security invariants

- lifecycle transitions never roll backward
- DISABLED has no outgoing transition
- debug is unavailable in provisioned/active operation
- tamper revokes trust and causes isolation
- a failed attestation causes isolation
- isolation is sticky until reset
- a trusted chiplet is never simultaneously isolated

## Explicitly out of scope for M0

- cryptographic strength
- certificate parsing and PKI validation
- side-channel resistance
- physical invasive attack resistance
- complete SPDM or UCIe protocol compliance
- key provisioning implementation
