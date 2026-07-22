# Koti Music Assistant provider

A `PlayerProvider` for [Music Assistant](https://github.com/music-assistant/server),
modeled directly on `music_assistant/providers/dashie_kiosk/` — Koti's tablet speaker
(`lib/speaker/koti_player_server.dart`) already speaks the same Fully Kiosk Browser REST
protocol Dashie's does, so this provider is close to a rename of theirs.

Discovers players two ways:
- Via the Home Assistant Plugin: reads `configuration_url` off devices registered by this
  repo's own `custom_components/koti` integration (filtered by `platform == "koti"`).
- Manually, by `host:port` — no Home Assistant involvement at all.

These are alternatives for the same tablet, not meant to be combined — pick whichever
fits your setup, not both. Both paths register the player under the tablet's own
self-reported `deviceID` (from its `deviceInfo` REST response), so configuring the same
physical tablet both ways now resolves to one player instead of two; before this, the HA
path keyed its player on the HA entity_id while the manual path keyed on `deviceID`,
so the same tablet configured both ways registered as two distinct MA players — which is
what was actually producing the duplicate `media_player.*` entities MA then mirrored back
into Home Assistant.

## Status

Not merged upstream. For now this is deployed locally into one real Home Assistant OS
install via a modified copy of the community `ma_provider_watcher` add-on, which
`docker cp`'s this folder into the running Music Assistant container's
`site-packages/music_assistant/providers/` and restarts it — the same trick that add-on
already used to install a third-party `ytmusic_free` provider. This is real-world testing
before (if it proves out) proposing it as a PR to `music-assistant/server`, the same path
`dashie_kiosk` took.

This folder is the canonical source; it's mirrored into the add-on's own directory
separately (not tracked in this repo) for deployment.
