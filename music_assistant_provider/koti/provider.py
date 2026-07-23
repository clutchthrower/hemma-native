"""Koti Player provider for Music Assistant."""

from __future__ import annotations

import asyncio
import logging
from typing import TYPE_CHECKING, Any, cast
from urllib.parse import urlparse

from music_assistant.models.player_provider import PlayerProvider

from .client import KotiClient
from .constants import CONF_MANUAL_PLAYERS, CONF_PLAYERS, KOTI_HA_DOMAIN, RETRY_INTERVAL
from .player import KotiPlayer

if TYPE_CHECKING:
    from hass_client.models import Device as HassDevice
    from music_assistant_models.config_entries import ProviderConfig
    from music_assistant_models.provider import ProviderManifest

    from music_assistant import MusicAssistant
    from music_assistant.providers.hass import HomeAssistantProvider

_LOGGER = logging.getLogger(__name__)


class KotiProvider(PlayerProvider):
    """Player provider for Koti Android tablets."""

    hass_prov: HomeAssistantProvider | None
    _pending_players: dict[str, HassDevice | None]
    # device_ids whose HA registry lookup itself never succeeded (typically
    # because the Home Assistant Plugin's websocket wasn't connected yet
    # when this provider loaded — a real startup-ordering race, since MA
    # doesn't guarantee the "hass" provider connects before this one loads)
    # — distinct from _pending_players, which is for device_ids where the
    # registry lookup succeeded but the tablet itself couldn't be reached.
    _pending_ha_lookup: set[str]

    def __init__(
        self,
        mass: MusicAssistant,
        manifest: ProviderManifest,
        config: ProviderConfig,
        hass_prov: HomeAssistantProvider | None,
    ) -> None:
        """Initialize the provider."""
        super().__init__(mass, manifest, config)
        self.hass_prov = hass_prov
        self._pending_players = {}
        self._pending_ha_lookup = set()
        self._retry_task: asyncio.Task[None] | None = None

    async def loaded_in_mass(self) -> None:
        """Call after the provider has been loaded."""
        await super().loaded_in_mass()
        # Set up HA-discovered players
        device_ids = cast("list[str]", self.config.get_value(CONF_PLAYERS)) or []
        if device_ids and self.hass_prov:
            await self._setup_ha_players(device_ids)
        # Set up manually configured players
        manual_addresses = cast("list[str]", self.config.get_value(CONF_MANUAL_PLAYERS)) or []
        for raw_address in manual_addresses:
            address = raw_address.strip()
            if not address:
                continue
            success = await self._setup_manual_player(address)
            if not success:
                self._pending_players[address] = None
        # Start retry loop for any devices that failed to connect
        if self._pending_players or self._pending_ha_lookup:
            _LOGGER.info(
                "%d device(s) offline (or Home Assistant not yet connected) at "
                "startup, will retry: %s",
                len(self._pending_players) + len(self._pending_ha_lookup),
                ", ".join((*self._pending_players.keys(), *self._pending_ha_lookup)),
            )
            self._retry_task = self.mass.create_task(self._retry_pending_players())

    async def _setup_ha_players(self, device_ids: list[str]) -> None:
        """Set up players discovered via Home Assistant's device registry."""
        assert self.hass_prov is not None
        if not self.hass_prov.hass.connected:
            # The Home Assistant Plugin hasn't finished connecting yet —
            # get_device_registry() would raise NotConnected. Queue these for
            # the retry loop instead of letting that exception abort the
            # rest of loaded_in_mass() (which would also skip any
            # manually-configured players below this call).
            _LOGGER.info(
                "Home Assistant Plugin not yet connected, will retry %d "
                "Koti device(s) shortly: %s",
                len(device_ids),
                ", ".join(device_ids),
            )
            self._pending_ha_lookup.update(device_ids)
            return
        try:
            device_registry = {
                x["id"]: x for x in await self.hass_prov.hass.get_device_registry()
            }
        except Exception as err:
            _LOGGER.warning("Could not read Home Assistant's device registry, will retry: %s", err)
            self._pending_ha_lookup.update(device_ids)
            return
        for device_id in device_ids:
            hass_device = device_registry.get(device_id)
            if not hass_device:
                _LOGGER.warning("Device %s not found in registry, skipping", device_id)
                continue
            if not any(
                domain == KOTI_HA_DOMAIN for domain, _ in hass_device.get("identifiers", [])
            ):
                _LOGGER.warning("Device %s is not a Koti device, skipping", device_id)
                continue
            _LOGGER.info(
                "Setting up device %s -> name=%s, config_url=%s",
                device_id,
                hass_device.get("name", "?"),
                hass_device.get("configuration_url", "?"),
            )
            success = await self._setup_player(device_id, hass_device)
            if not success:
                self._pending_players[device_id] = hass_device
            self._pending_ha_lookup.discard(device_id)

    async def unload(self, is_removed: bool = False) -> None:
        """Handle unload/close of the provider."""
        if self._retry_task and not self._retry_task.done():
            self._retry_task.cancel()
        await super().unload(is_removed)

    async def _retry_pending_players(self) -> None:
        """Periodically retry connecting to devices that were offline at startup."""
        while self._pending_players or self._pending_ha_lookup:
            await asyncio.sleep(RETRY_INTERVAL)
            if self._pending_ha_lookup and self.hass_prov:
                await self._setup_ha_players(list(self._pending_ha_lookup))
            for player_key in list(self._pending_players.keys()):
                hass_device = self._pending_players[player_key]
                _LOGGER.debug("Retrying connection for %s", player_key)
                if hass_device is not None:
                    success = await self._setup_player(player_key, hass_device)
                else:
                    success = await self._setup_manual_player(player_key)
                if success:
                    del self._pending_players[player_key]
                    _LOGGER.info("Successfully connected to %s on retry", player_key)
        _LOGGER.info("All pending devices connected")

    async def _setup_player(
        self,
        device_id: str,
        hass_device: HassDevice | None,
    ) -> bool:
        """Set up a player from an HA device. Returns True on success."""
        # Extract host and port from configuration_url (e.g. "http://192.168.1.30:8127")
        config_url = hass_device.get("configuration_url", "") if hass_device else ""
        if not config_url:
            _LOGGER.warning("No configuration_url for %s, cannot connect directly", device_id)
            return False
        parsed = urlparse(config_url)
        host = parsed.hostname
        port = str(parsed.port or 8127)
        if not host:
            _LOGGER.warning("Could not parse host from %s", config_url)
            return False
        # Create a direct REST API client
        client = KotiClient(self.mass.http_session_no_ssl, host, port, password="")
        try:
            async with asyncio.timeout(15):
                await client.get_device_info()
        except Exception as err:
            _LOGGER.warning("Unable to connect to Koti at %s:%s - %s", host, port, err)
            return False
        # Collect device info from HA registry
        dev_info: dict[str, Any] = {}
        if hass_device:
            if model := hass_device.get("model"):
                dev_info["model"] = model
            if manufacturer := hass_device.get("manufacturer"):
                dev_info["manufacturer"] = manufacturer
            if sw_version := hass_device.get("sw_version"):
                dev_info["software_version"] = sw_version
        # Use the tablet's own self-reported device ID as the player_id —
        # the same value _setup_manual_player derives — rather than HA's own
        # device registry id. If a user configures the same physical tablet
        # both via HA discovery and a manual address, this makes both paths
        # resolve to the identical player_id (MA registers it once,
        # idempotently) instead of creating two distinct players for one
        # device, which is what was actually producing the duplicate
        # media_player entities mirrored back into HA.
        player_id = client.device_info.get("deviceID", device_id)
        player = KotiPlayer(self, player_id, client, f"{host}:{port}", dev_info)
        player.set_attributes()
        await self.mass.players.register(player)
        return True

    async def _setup_manual_player(self, address: str) -> bool:
        """Set up a player from a manual IP:port address. Returns True on success."""
        if ":" in address:
            host, port = address.rsplit(":", 1)
        else:
            host = address
            port = "8127"
        client = KotiClient(self.mass.http_session_no_ssl, host, port, password="")
        try:
            async with asyncio.timeout(15):
                await client.get_device_info()
        except Exception as err:
            _LOGGER.warning("Unable to connect to Koti at %s:%s - %s", host, port, err)
            return False
        # Use the device ID from the device info, falling back to the address
        device_id = client.device_info.get("deviceID", address)
        player = KotiPlayer(self, device_id, client, f"{host}:{port}")
        player.set_attributes()
        await self.mass.players.register(player)
        return True
