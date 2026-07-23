"""
Koti Player provider for Music Assistant.

Plays audio directly on Koti tablets via their REST API. Supports automatic
discovery via the Home Assistant Plugin and the Koti HA integration, or
manual configuration by IP address.
"""

from __future__ import annotations

from typing import TYPE_CHECKING, cast

from music_assistant_models.config_entries import ConfigEntry, ConfigValueOption, ConfigValueType
from music_assistant_models.enums import ConfigEntryType

from music_assistant.providers.hass import DOMAIN as HASS_DOMAIN

from .constants import CONF_MANUAL_PLAYERS, CONF_PLAYERS, KOTI_HA_DOMAIN
from .provider import KotiProvider

if TYPE_CHECKING:
    from music_assistant_models.config_entries import ProviderConfig
    from music_assistant_models.provider import ProviderManifest

    from music_assistant import MusicAssistant
    from music_assistant.models import ProviderInstanceType
    from music_assistant.providers.hass import HomeAssistantProvider


async def setup(
    mass: MusicAssistant, manifest: ProviderManifest, config: ProviderConfig
) -> ProviderInstanceType:
    """Initialize provider(instance) with given configuration."""
    raw_prov = mass.get_provider(HASS_DOMAIN)
    hass_prov = cast("HomeAssistantProvider", raw_prov) if raw_prov else None
    return KotiProvider(mass, manifest, config, hass_prov)


async def get_config_entries(
    mass: MusicAssistant,
    instance_id: str | None = None,  # noqa: ARG001
    action: str | None = None,  # noqa: ARG001
    values: dict[str, ConfigValueType] | None = None,  # noqa: ARG001
) -> tuple[ConfigEntry, ...]:
    """Return Config entries to setup this provider."""
    hass_prov = cast("HomeAssistantProvider|None", mass.get_provider(HASS_DOMAIN))
    koti_devices: list[ConfigValueOption] = []
    if hass_prov and hass_prov.hass.connected:
        # The Koti HA integration registers a device with its own direct-
        # control media_player.koti_{name} entity (see
        # custom_components/koti/media_player.py), but this dropdown finds
        # it via the device registry directly rather than scanning entities
        # — this provider creates its own separate player for Music
        # Assistant control, independent of that entity.
        for device in await hass_prov.hass.get_device_registry():
            if not any(domain == KOTI_HA_DOMAIN for domain, _ in device["identifiers"]):
                continue
            name = f"{device['name']} ({device['id']})"
            koti_devices.append(ConfigValueOption(name, device["id"]))
    return (
        ConfigEntry(
            key=CONF_PLAYERS,
            type=ConfigEntryType.STRING,
            multi_value=True,
            label="Koti devices (via Home Assistant)",
            required=False,
            default_value=[],
            options=koti_devices,
            description="Select Koti tablets discovered through the Koti HA "
            "integration. Requires the Home Assistant Plugin.",
        ),
        ConfigEntry(
            key=CONF_MANUAL_PLAYERS,
            type=ConfigEntryType.STRING,
            multi_value=True,
            label="Manual Koti addresses",
            required=False,
            default_value=[],
            description="Manually add Koti tablets by IP address and port "
            "(e.g. 192.168.1.100:8127). Use this if you don't have the Koti "
            "HA integration installed.",
            advanced=True,
        ),
    )
