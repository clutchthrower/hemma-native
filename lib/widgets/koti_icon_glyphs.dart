/// Maps this app's own icon names (used throughout `lib/`, e.g. `KotiIcon('lock', ...)`)
/// to a codepoint in the bundled Material Symbols Rounded font
/// (`assets/fonts/MaterialSymbolsRounded.ttf`, instanced at FILL=1/GRAD=0/opsz=24/wght=400 —
/// see `koti_icon.dart`'s doc comment for the full story of why icons render as font glyphs
/// rather than SVG/PNG images).
///
/// Codepoints come from Google's published mapping
/// (github.com/google/material-design-icons, `*.codepoints` files) — some of this app's
/// icon names have no literal Material Symbols equivalent (e.g. brand placeholders like
/// `sony`/`plex`, or Hemma-specific concepts like `aqi-high`) and were mapped to the closest
/// reasonable substitute by hand; if one looks visually wrong, look up the real name at
/// fonts.google.com/icons and swap the codepoint here — no font/asset regeneration needed,
/// the bundled font already contains the full ~4266-glyph set.
const Map<String, int> kKotiIconGlyphs = {
  'access_point': 0xe1ba, // network_wifi
  'apple': 0xe326, // devices
  'apple_tv': 0xe055, // airplay
  'aqi-high': 0xf163, // humidity_high
  'aqi-low': 0xf164, // humidity_low
  'aqi-medium': 0xf165, // humidity_mid
  'arrow-down': 0xe5db, // arrow_downward
  'arrow-up': 0xe5d8, // arrow_upward
  'battery': 0xe1a5, // battery_full
  'bedroom': 0xefdf, // bed
  'clock': 0xefd6, // schedule
  'close': 0xe5cd, // close
  'console': 0xea28, // sports_esports
  'cooling': 0xeb3b, // ac_unit
  'curtain-closed': 0xec1d, // curtains_closed
  'curtain-open': 0xec1e, // curtains
  'decrease': 0xe15b, // remove
  'door': 0xeffd, // door_front
  'door_open': 0xe77c, // door_open
  'doorbell': 0xefff, // doorbell
  'electric': 0xec1c, // electric_bolt
  'energy': 0xea0b, // bolt
  'fan': 0xf168, // mode_fan
  'fridge': 0xeb47, // kitchen
  'gas': 0xec14, // propane
  'heating': 0xef55, // local_fire_department
  'home': 0xe9b2, // home
  'homepod': 0xe32d, // speaker
  'hot_water': 0xe284, // water_heater
  'humidifier': 0xf164, // humidity_low
  'humidifier-on': 0xf163, // humidity_high
  'humidity': 0xf87e, // humidity_percentage
  'increase': 0xe145, // add
  'kitchen': 0xeb47, // kitchen
  'lamp': 0xe90f, // lightbulb
  'light': 0xe90f, // lightbulb
  'living-room': 0xe16b, // weekend
  'lock': 0xe899, // lock
  'lock-open': 0xe898, // lock_open
  'lock-unlocking': 0xe898, // lock_open
  'media': 0xf06a, // smart_display
  'menu': 0xe5d2, // menu
  'motion': 0xe51e, // sensors
  'music': 0xe405, // music_note
  'mute': 0xe04f, // volume_off
  'pause': 0xe034, // pause
  'pendant-light': 0xe90f, // lightbulb
  'pendent': 0xe90f, // lightbulb
  'person': 0xf0d3, // person
  'plant': 0xe545, // local_florist
  'play': 0xe037, // play_arrow
  'play-next': 0xe044, // skip_next
  'plex': 0xf06a, // smart_display
  'plug': 0xf1d4, // outlet
  'power_off': 0xe646, // power_off
  'power_on': 0xe63c, // power
  'purifier': 0xe97e, // air_purifier
  'scenes': 0xe65f, // auto_awesome
  'skip_next': 0xe044, // skip_next
  'skip_previous': 0xe045, // skip_previous
  'sony': 0xf06a, // smart_display
  'speaker': 0xe32d, // speaker
  'speaker-group': 0xe32e, // speaker_group
  'temp-high': 0xf379, // thermostat_arrow_up
  'temp-low': 0xf37a, // thermostat_arrow_down
  'temp-medium': 0xf076, // thermostat
  'thermostat': 0xf076, // thermostat
  'toggle_off': 0xe9f5, // toggle_off
  'toggle_on': 0xe9f6, // toggle_on
  'tv': 0xe63b, // tv
  'tv-play': 0xe63a, // live_tv
  'unmute': 0xe050, // volume_up
  'updates': 0xe923, // update
  'vacuum': 0xefc5, // vacuum
  'vacuum-charge': 0xe56d, // ev_station
  'vacuum-clean': 0xefc5, // vacuum
  'wifi': 0xe63e, // wifi

  // assets/weather/ — only the base names weather_widget.dart's
  // weatherAssetFor() actually maps to; the "-fill" variants alongside them
  // in that folder were unused leftovers even before this migration.
  'clear-day': 0xe81a, // sunny
  'clear-night': 0xf159, // bedtime
  'cloudy': 0xf15c, // cloud
  'fog': 0xe818, // foggy
  'lightning-rainy': 0xebdb, // thunderstorm
  'partly-cloudy-day': 0xf172, // partly_cloudy_day
  'rain': 0xf176, // rainy
  'rain-heavy': 0xf61f, // rainy_heavy
  'snow': 0xe80f, // snowing
  'thunder': 0xebdb, // thunderstorm
  'weather-mixed': 0xf60b, // weather_mix
  'wind': 0xefd8, // air
};
