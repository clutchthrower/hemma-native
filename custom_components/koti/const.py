"""Constants for the Koti integration."""

DOMAIN = "koti"

DEFAULT_PORT = 8127
DEFAULT_SCAN_INTERVAL = 10  # seconds

CONF_ID = "id"

# Koti's local player protocol (see lib/speaker/koti_player_server.dart in
# the Koti app repo) — a small unauthenticated HTTP API, trusted the same
# way as the rest of this LAN-only integration.
API_INFO = "info"
API_PLAY = "play"
API_STOP = "stop"
API_VOLUME = "volume"
