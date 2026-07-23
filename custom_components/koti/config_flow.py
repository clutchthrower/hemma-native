"""Config flow for Koti — auto-discovers players via zeroconf, no setup."""

from __future__ import annotations

from typing import Any

import aiohttp
import voluptuous as vol

from homeassistant.config_entries import ConfigFlow
from homeassistant.helpers.aiohttp_client import async_get_clientsession
from homeassistant.helpers.service_info.zeroconf import ZeroconfServiceInfo

from .const import CONF_ID, DEFAULT_PORT, DOMAIN

CONF_HOST = "host"
CONF_PORT = "port"
CONF_NAME = "name"


def _normalize_host(raw_host: str) -> tuple[str, int | None]:
    """Normalize a user-entered host into a bare host + optional embedded port.

    Tolerates copy/paste mistakes that otherwise produce a broken URL and a
    misleading "cannot connect": an `http://`/`https://` scheme, a trailing
    slash or path, surrounding whitespace, and an embedded `:port`.

    Returns `(host, port)` where `port` is `None` if none was embedded.
    IPv6 (multiple colons / bracketed) is left untouched.
    """
    host = (raw_host or "").strip()
    if "://" in host:
        host = host.split("://", 1)[1]
    for sep in ("/", "?", "#"):
        host = host.split(sep, 1)[0]
    host = host.strip().strip(".")

    port: int | None = None
    if host.count(":") == 1 and not host.startswith("["):
        candidate_host, _, candidate_port = host.partition(":")
        if candidate_port.isdigit():
            host, port = candidate_host, int(candidate_port)

    return host, port


def _select_discovery_host(discovery_info: ZeroconfServiceInfo) -> str | None:
    """Pick the best address from a zeroconf discovery, preferring IPv4.

    A tablet can advertise an IPv4 plus an IPv6 (ULA + `fe80::` link-local).
    `discovery_info.host` can surface an IPv6 first; a link-local address
    needs a zone id HA core can't use, and a bare IPv6 breaks the
    unbracketed `host:port` URL this integration builds — either of which
    silently breaks the discovered entry. Prefer the first IPv4, then a
    non-link-local IPv6, and only fall back to `.host` as a last resort.
    """
    candidates = [str(ip) for ip in (discovery_info.ip_addresses or [])]
    if not candidates and discovery_info.host:
        candidates.append(discovery_info.host)

    for h in candidates:  # IPv4 first
        if "." in h and ":" not in h:
            return h
    for h in candidates:  # then any non-link-local IPv6
        if not h.lower().startswith("fe80:") and "%" not in h:
            return h
    return candidates[0] if candidates else discovery_info.host


class KotiConfigFlow(ConfigFlow, domain=DOMAIN):
    """Handles both zeroconf auto-discovery and manual fallback entry."""

    VERSION = 1

    def __init__(self) -> None:
        self._discovered: dict[str, Any] = {}

    async def async_step_zeroconf(
        self, discovery_info: ZeroconfServiceInfo
    ) -> Any:
        device_id = discovery_info.properties.get(CONF_ID)
        name = discovery_info.properties.get(CONF_NAME) or discovery_info.name
        if not device_id:
            return self.async_abort(reason="no_device_id")

        host = _select_discovery_host(discovery_info)
        if not host:
            return self.async_abort(reason="no_host")

        await self.async_set_unique_id(device_id)
        self._abort_if_unique_id_configured(
            updates={
                CONF_HOST: host,
                CONF_PORT: discovery_info.port,
            }
        )

        self._discovered = {
            CONF_HOST: host,
            CONF_PORT: discovery_info.port,
            CONF_ID: device_id,
            CONF_NAME: name,
        }
        self.context["title_placeholders"] = {"name": name}
        return await self.async_step_discovery_confirm()

    async def async_step_discovery_confirm(
        self, user_input: dict[str, Any] | None = None
    ) -> Any:
        if user_input is not None:
            return self.async_create_entry(
                title=self._discovered[CONF_NAME], data=self._discovered
            )

        return self.async_show_form(
            step_id="discovery_confirm",
            description_placeholders={"name": self._discovered[CONF_NAME]},
        )

    async def async_step_user(
        self, user_input: dict[str, Any] | None = None
    ) -> Any:
        errors: dict[str, str] = {}
        if user_input is not None:
            host, embedded_port = _normalize_host(user_input[CONF_HOST])
            port = embedded_port or user_input.get(CONF_PORT, DEFAULT_PORT)
            info = await self._try_connect(host, port)
            if info is None:
                errors["base"] = "cannot_connect"
            else:
                device_id = info.get("deviceID", host)
                await self.async_set_unique_id(device_id)
                self._abort_if_unique_id_configured(
                    updates={CONF_HOST: host, CONF_PORT: port}
                )
                name = info.get("deviceName", host)
                return self.async_create_entry(
                    title=name,
                    data={
                        CONF_HOST: host,
                        CONF_PORT: port,
                        CONF_ID: device_id,
                        CONF_NAME: name,
                    },
                )

        return self.async_show_form(
            step_id="user",
            data_schema=vol.Schema(
                {
                    vol.Required(CONF_HOST): str,
                    vol.Optional(CONF_PORT, default=DEFAULT_PORT): int,
                }
            ),
            errors=errors,
        )

    async def _try_connect(self, host: str, port: int) -> dict[str, Any] | None:
        session = async_get_clientsession(self.hass)
        try:
            async with session.get(
                f"http://{host}:{port}/?cmd=deviceInfo",
                timeout=aiohttp.ClientTimeout(total=5),
            ) as response:
                if response.status != 200:
                    return None
                return await response.json()
        except (TimeoutError, aiohttp.ClientError):
            return None
