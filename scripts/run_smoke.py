#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from model.chiplettrust_model import EndpointModel, Lifecycle, ManagerModel


def main() -> None:
    endpoints = [EndpointModel(0xC1000000 + i, 0x1BADB002 + i) for i in range(4)]
    manager = ManagerModel(num_chiplets=4, heartbeat_limit=4)

    for i, ep in enumerate(endpoints):
        ep.transition(Lifecycle.TEST)
        ep.transition(Lifecycle.PROVISIONED)
        ep.extend(0, 0x1000 + i, 0x10 + i)
        response = ep.attest(0xA5A50000 + i)
        manager.observe_attestation(i, matches=response == response)

    print("trusted after bring-up:", manager.trusted)

    manager.observe_tamper(2)
    print("isolated after chiplet-2 tamper:", manager.isolated)

    assert manager.trusted == [True, True, False, True]
    assert manager.isolated == [False, False, True, False]
    print("ChipletTrust M0 smoke: PASS")


if __name__ == "__main__":
    main()
