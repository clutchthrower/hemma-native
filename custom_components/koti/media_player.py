"""Media player platform for Koti players."""

from __future__ import annotations

from homeassistant.components.media_player import (
    MediaPlayerEntity,
    MediaPlayerEntityFeature,
    MediaPlayerState,
    MediaType,
)
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.helpers.device_registry import DeviceInfo
from homeassistant.helpers.entity_platform import AddEntitiesCallback
from homeassistant.helpers.update_coordinator import CoordinatorEntity

from .const import DOMAIN
from .coordinator import KotiCoordinator

SUPPORTED_FEATURES = (
    MediaPlayerEntityFeature.PLAY_MEDIA
    | MediaPlayerEntityFeature.STOP
    | MediaPlayerEntityFeature.VOLUME_SET
)


async def async_setup_entry(
    hass: HomeAssistant,
    entry: ConfigEntry,
    async_add_entities: AddEntitiesCallback,
) -> None:
    coordinator: KotiCoordinator = hass.data[DOMAIN][entry.entry_id]
    async_add_entities([KotiMediaPlayer(coordinator, entry)])


class KotiMediaPlayer(CoordinatorEntity[KotiCoordinator], MediaPlayerEntity):
    """A Koti tablet acting as a Music Assistant player."""

    _attr_has_entity_name = True
    _attr_name = None
    _attr_supported_features = SUPPORTED_FEATURES
    _attr_media_content_type = MediaType.MUSIC

    def __init__(self, coordinator: KotiCoordinator, entry: ConfigEntry) -> None:
        super().__init__(coordinator)
        self._entry = entry
        self._attr_unique_id = entry.unique_id
        self._attr_device_info = DeviceInfo(
            identifiers={(DOMAIN, entry.unique_id)},
            name=entry.data.get("name", entry.title),
            manufacturer="Koti",
            model="Koti Tablet",
        )
        self._update_from_coordinator()

    def _update_from_coordinator(self) -> None:
        data = self.coordinator.data or {}
        playing = bool(data.get("playing"))
        self._attr_state = (
            MediaPlayerState.PLAYING if playing else MediaPlayerState.IDLE
        )
        volume = data.get("volume")
        self._attr_volume_level = volume / 100 if volume is not None else None

    def _handle_coordinator_update(self) -> None:
        self._update_from_coordinator()
        super()._handle_coordinator_update()

    async def async_play_media(self, media_type: str, media_id: str, **kwargs) -> None:
        await self.coordinator.send_command("play", url=media_id)
        await self.coordinator.async_request_refresh()

    async def async_media_stop(self) -> None:
        await self.coordinator.send_command("stop")
        await self.coordinator.async_request_refresh()

    async def async_set_volume_level(self, volume: float) -> None:
        await self.coordinator.send_command("volume", level=round(volume * 100))
        await self.coordinator.async_request_refresh()
