"""Diagnostics support for Koti.

Surfaces in HA via:
  Settings → Devices & services → Koti → ⋮ → Download diagnostics

Koti's REST API has no dedicated diagnostics-log endpoint (unlike some
similar integrations) — this instead dumps the config entry's own stored
data plus a fresh, live `deviceInfo` fetch, which is what actually matters
for troubleshooting a Koti tablet: is it reachable right now, and what does
it currently report.
"""

from __future__ import annotations

from typing import Any

from homeassistant.components.diagnostics import async_redact_data
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.helpers.device_registry import DeviceEntry

from .const import CONF_ID, DOMAIN
from .coordinator import KotiCoordinator

# Nothing sensitive is currently stored (no password field is used — the
# tablet's REST API accepts but never checks one), but redact defensively
# in case that ever changes.
TO_REDACT = {"password"}


async def async_get_config_entry_diagnostics(
    hass: HomeAssistant, entry: ConfigEntry
) -> dict[str, Any]:
    """Diagnostics for the config entry as a whole."""
    coordinator: KotiCoordinator = hass.data[DOMAIN][entry.entry_id]
    await coordinator.async_refresh()
    return {
        "config_entry": async_redact_data(dict(entry.data), TO_REDACT),
        "host": coordinator.host,
        "port": coordinator.port,
        "last_update_success": coordinator.last_update_success,
        "device_info": coordinator.data or {},
    }


async def async_get_device_diagnostics(
    hass: HomeAssistant, entry: ConfigEntry, device: DeviceEntry
) -> dict[str, Any]:
    """Diagnostics for a single Koti device."""
    coordinator: KotiCoordinator = hass.data[DOMAIN][entry.entry_id]
    await coordinator.async_refresh()
    return {
        "device": {
            "name": device.name,
            "model": device.model,
            "manufacturer": device.manufacturer,
            "identifiers": [list(i) for i in device.identifiers],
            "connections": [list(c) for c in device.connections],
        },
        "koti_id": entry.data.get(CONF_ID),
        "last_update_success": coordinator.last_update_success,
        "device_info": coordinator.data or {},
    }
