"""Golden model for ChipletTrust M1.

The attestation transform is intentionally non-cryptographic. It mirrors the
RTL so verification can be deterministic before a real crypto backend exists.
"""

from dataclasses import dataclass, field
from enum import IntEnum

MASK32 = 0xFFFF_FFFF


class Lifecycle(IntEnum):
    RAW = 0
    TEST = 1
    PROVISIONED = 2
    ACTIVE = 3
    RMA = 4
    DISABLED = 5


ALLOWED = {
    Lifecycle.RAW: {Lifecycle.TEST, Lifecycle.PROVISIONED, Lifecycle.DISABLED},
    Lifecycle.TEST: {Lifecycle.PROVISIONED, Lifecycle.DISABLED},
    Lifecycle.PROVISIONED: {Lifecycle.ACTIVE, Lifecycle.DISABLED},
    Lifecycle.ACTIVE: {Lifecycle.RMA, Lifecycle.DISABLED},
    Lifecycle.RMA: {Lifecycle.DISABLED},
    Lifecycle.DISABLED: set(),
}


def rotl32(x: int, sh: int) -> int:
    x &= MASK32
    sh %= 32
    return x if sh == 0 else ((x << sh) | (x >> (32 - sh))) & MASK32


def measurement_extend(current: int, measurement: int, domain: int) -> int:
    domain_word = (domain & 0xFF) * 0x0101_0101
    return (rotl32(current, 5) ^ measurement ^ domain_word ^ 0x4354_5255) & MASK32


def attestation_mix(challenge: int, device_id: int, digest: int, secret: int, nonce: int) -> int:
    x = challenge ^ rotl32(device_id, 3) ^ rotl32(digest, 11)
    x ^= rotl32(secret, 17) ^ nonce ^ 0xA77E_5710
    x &= MASK32
    return (rotl32(x, 7) ^ ((x + 0x9E37_79B9) & MASK32)) & MASK32


def bind_session_challenge(session_id: int, challenge: int) -> int:
    """Mirror the M1 RTL transcript-binding transform."""
    return (challenge ^ rotl32(session_id, 13) ^ 0x5345_5353) & MASK32


@dataclass
class EndpointModel:
    device_id: int
    secret_word: int
    lifecycle: Lifecycle = Lifecycle.RAW
    pcr: list[int] = field(default_factory=lambda: [0, 0, 0, 0])
    nonce: int = 1
    replay_cache_depth: int = 4
    replay_cache: list[tuple[int, int]] = field(default_factory=list)

    def transition(self, new_state: Lifecycle) -> bool:
        if new_state not in ALLOWED[self.lifecycle]:
            return False
        self.lifecycle = new_state
        return True

    def tamper(self) -> None:
        self.lifecycle = Lifecycle.DISABLED

    @property
    def debug_allowed(self) -> bool:
        return self.lifecycle in {Lifecycle.TEST, Lifecycle.RMA}

    @property
    def key_valid(self) -> bool:
        return self.lifecycle in {Lifecycle.PROVISIONED, Lifecycle.ACTIVE, Lifecycle.RMA}

    def extend(self, index: int, measurement: int, domain: int) -> None:
        if not 0 <= index < len(self.pcr):
            raise IndexError(index)
        self.pcr[index] = measurement_extend(self.pcr[index], measurement, domain)

    @property
    def digest(self) -> int:
        value = 0x4354_0001
        for idx, pcr in enumerate(self.pcr):
            value = rotl32(value, 3) ^ pcr ^ ((0x0101_0101 * idx) & MASK32)
            value &= MASK32
        return value

    def attest(self, challenge: int) -> int:
        if not self.key_valid:
            raise PermissionError("attestation key unavailable in current lifecycle")
        response = attestation_mix(
            challenge, self.device_id, self.digest, self.secret_word, self.nonce
        )
        self.nonce = (self.nonce + 1) & MASK32
        return response

    def accept_fresh_request(self, session_id: int, challenge: int) -> bool:
        key = (session_id & MASK32, challenge & MASK32)
        if key in self.replay_cache:
            return False
        if len(self.replay_cache) >= self.replay_cache_depth:
            self.replay_cache.pop(0)
        self.replay_cache.append(key)
        return True

    def attest_session(self, session_id: int, challenge: int) -> int:
        """Attest a fresh session/challenge pair using M1 transcript binding."""
        if not self.key_valid:
            raise PermissionError("attestation key unavailable in current lifecycle")
        if not self.accept_fresh_request(session_id, challenge):
            raise ValueError("replayed session/challenge pair")

        bound = bind_session_challenge(session_id, challenge)
        response = attestation_mix(
            bound, self.device_id, self.digest, self.secret_word, self.nonce
        )
        self.nonce = (self.nonce + 1) & MASK32
        return response


@dataclass
class ManagerModel:
    num_chiplets: int = 4
    heartbeat_limit: int = 8
    trusted: list[bool] = field(init=False)
    isolated: list[bool] = field(init=False)
    heartbeat_fault: list[bool] = field(init=False)
    hb_count: list[int] = field(init=False)

    def __post_init__(self) -> None:
        self.trusted = [False] * self.num_chiplets
        self.isolated = [False] * self.num_chiplets
        self.heartbeat_fault = [False] * self.num_chiplets
        self.hb_count = [0] * self.num_chiplets

    def observe_attestation(self, idx: int, matches: bool) -> None:
        if self.isolated[idx]:
            return
        if matches:
            self.trusted[idx] = True
        else:
            self.trusted[idx] = False
            self.isolated[idx] = True

    def observe_tamper(self, idx: int) -> None:
        self.trusted[idx] = False
        self.isolated[idx] = True

    def heartbeat_tick(self, idx: int, seen: bool) -> None:
        if seen:
            self.hb_count[idx] = 0
            return
        if self.isolated[idx]:
            return
        self.hb_count[idx] += 1
        if self.hb_count[idx] >= self.heartbeat_limit:
            self.heartbeat_fault[idx] = True
            self.trusted[idx] = False
            self.isolated[idx] = True
