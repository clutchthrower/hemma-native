"""Deterministic MAC derivation, mirroring lib/api/ble_proxy.dart's BleProxy.macFrom().

Both sides must resolve to the exact same MAC for the same device id and
variant: this is what lets Home Assistant's device registry recognize the
Koti integration's device and the ESPHome Bluetooth-proxy device (whose
`connections` HA keys on the ESPHome-reported `mac_address`, variant 0) as
the same physical tablet and merge them into one Device instead of two.
"""

from __future__ import annotations


def mac_from(device_id: str, variant: int = 0) -> str:
    """Return the locally-administered MAC for `device_id`/`variant`."""
    hex_part = (device_id + "0" * 12)[:12].upper()
    pairs = ["02" if variant == 0 else "06"]
    for i in range(2, 12, 2):
        pairs.append(hex_part[i : i + 2])
    return ":".join(pairs)
