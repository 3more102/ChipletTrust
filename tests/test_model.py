import pytest

from model.chiplettrust_model import (
    EndpointModel,
    Lifecycle,
    ManagerModel,
    attestation_mix,
    bind_session_challenge,
)


def provisioned_endpoint() -> EndpointModel:
    ep = EndpointModel(device_id=0xC1000001, secret_word=0x1BADB002)
    assert ep.transition(Lifecycle.TEST)
    assert ep.transition(Lifecycle.PROVISIONED)
    return ep


def test_lifecycle_rejects_rollback():
    ep = provisioned_endpoint()
    assert ep.transition(Lifecycle.ACTIVE)
    assert not ep.transition(Lifecycle.TEST)
    assert ep.lifecycle == Lifecycle.ACTIVE


def test_debug_only_test_or_rma():
    ep = EndpointModel(1, 2)
    assert not ep.debug_allowed
    assert ep.transition(Lifecycle.TEST)
    assert ep.debug_allowed
    assert ep.transition(Lifecycle.PROVISIONED)
    assert not ep.debug_allowed
    assert ep.transition(Lifecycle.ACTIVE)
    assert ep.transition(Lifecycle.RMA)
    assert ep.debug_allowed


def test_tamper_permanently_disables_lifecycle():
    ep = provisioned_endpoint()
    ep.tamper()
    assert ep.lifecycle == Lifecycle.DISABLED
    assert not ep.transition(Lifecycle.ACTIVE)
    assert not ep.key_valid


def test_measurement_changes_digest():
    ep = provisioned_endpoint()
    before = ep.digest
    ep.extend(0, 0xDEADBEEF, 0x11)
    assert ep.digest != before


def test_attestation_nonce_blocks_same_response_replay():
    ep = provisioned_endpoint()
    challenge = 0x12345678
    first = ep.attest(challenge)
    second = ep.attest(challenge)
    assert first != second


def test_attestation_matches_reference_transform():
    ep = provisioned_endpoint()
    ep.extend(2, 0xCAFEBABE, 0x22)
    challenge = 0x01020304
    expected = attestation_mix(challenge, ep.device_id, ep.digest, ep.secret_word, 1)
    assert ep.attest(challenge) == expected


def test_attestation_unavailable_before_provisioning():
    ep = EndpointModel(1, 2)
    with pytest.raises(PermissionError):
        ep.attest(0xAA)


def test_bad_attestation_isolates_chiplet():
    mgr = ManagerModel()
    mgr.observe_attestation(2, matches=False)
    assert mgr.isolated[2]
    assert not mgr.trusted[2]


def test_isolation_is_sticky_across_later_good_attestation():
    mgr = ManagerModel()
    mgr.observe_attestation(1, matches=False)
    mgr.observe_attestation(1, matches=True)
    assert mgr.isolated[1]
    assert not mgr.trusted[1]


def test_tamper_revokes_trust():
    mgr = ManagerModel()
    mgr.observe_attestation(0, matches=True)
    assert mgr.trusted[0]
    mgr.observe_tamper(0)
    assert mgr.isolated[0]
    assert not mgr.trusted[0]


def test_heartbeat_timeout_isolates():
    mgr = ManagerModel(heartbeat_limit=3)
    mgr.observe_attestation(3, matches=True)
    for _ in range(3):
        mgr.heartbeat_tick(3, seen=False)
    assert mgr.heartbeat_fault[3]
    assert mgr.isolated[3]
    assert not mgr.trusted[3]


def test_heartbeat_resets_timeout_counter():
    mgr = ManagerModel(heartbeat_limit=3)
    mgr.heartbeat_tick(0, seen=False)
    mgr.heartbeat_tick(0, seen=False)
    mgr.heartbeat_tick(0, seen=True)
    mgr.heartbeat_tick(0, seen=False)
    assert not mgr.isolated[0]


def test_replay_cache_rejects_same_session_challenge_pair():
    ep = provisioned_endpoint()
    assert ep.accept_fresh_request(0x10, 0xAA01)
    assert not ep.accept_fresh_request(0x10, 0xAA01)


def test_replay_cache_allows_same_challenge_in_new_session():
    ep = provisioned_endpoint()
    assert ep.accept_fresh_request(0x10, 0xAA01)
    assert ep.accept_fresh_request(0x11, 0xAA01)


def test_replay_cache_has_bounded_window():
    ep = provisioned_endpoint()
    for sid in range(4):
        assert ep.accept_fresh_request(sid, 0x1000 + sid)
    assert ep.accept_fresh_request(4, 0x1004)
    assert ep.accept_fresh_request(0, 0x1000)


def test_session_attestation_matches_bound_reference():
    ep = provisioned_endpoint()
    sid = 0x44
    challenge = 0x10203040
    expected = attestation_mix(
        bind_session_challenge(sid, challenge),
        ep.device_id,
        ep.digest,
        ep.secret_word,
        1,
    )
    assert ep.attest_session(sid, challenge) == expected


def test_session_attestation_rejects_exact_replay():
    ep = provisioned_endpoint()
    ep.attest_session(0x10, 0xAA01)
    with pytest.raises(ValueError, match="replayed"):
        ep.attest_session(0x10, 0xAA01)


def test_session_binding_changes_response_for_new_session():
    ep = provisioned_endpoint()
    challenge = 0xAA01
    first = ep.attest_session(0x10, challenge)
    second = ep.attest_session(0x11, challenge)
    assert first != second


def test_invalid_key_does_not_consume_freshness_pair():
    ep = EndpointModel(device_id=1, secret_word=2)
    with pytest.raises(PermissionError):
        ep.attest_session(0x77, 0x1234)

    assert ep.transition(Lifecycle.PROVISIONED)
    ep.attest_session(0x77, 0x1234)
