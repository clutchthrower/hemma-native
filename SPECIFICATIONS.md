1. App foundation & HA connectivity (REST API, WebSocket, webhooks)
2. State management (replicating all the helper entities locally)
3. Layout engine (responsive grid, screen layout, entity layout)
4. Theme system (base theme, glass theme, CSS variables, light/dark mode)
5. Navigation system (mobile docked, tablet floating, desktop top-bar)
6. Hero Room Card (backgrounds, parallax, badge system, expanded row)
7. Smart Row (FLIP animation, active state detection)
8. All entity card templates (climate, lighting, media, security, utility)
9. Badge system (climate group, media group, presence group, light group)
10. Popup system (all domain popups)
11. Static assets (fonts, icons, weather SVGs, backgrounds)
12. JavaScript behaviors (navbar-scroll, smart-row, swipe-card-patch, etc.)
13. Settings menu (new, comprehensive)

---

# Hemma Native App — Full Build Specification

---

## SECTION 1 — Home Assistant Connectivity Layer

This is the foundation everything else depends on. All data is read-only from the device's perspective except for service calls.

### 1.1 REST API Client
- **Base URL**: `http(s)://<ha-host>:<port>/api/`
- **Auth**: Long-Lived Access Token sent as `Authorization: Bearer <token>` header
- **Endpoints to implement**:
  - `GET /api/states` — fetch all entity states on startup
  - `GET /api/states/<entity_id>` — fetch a single entity state
  - `GET /api/config` — fetch HA config (unit system, location, timezone)
  - `GET /api/services` — enumerate available services
  - `POST /api/services/<domain>/<service>` — call a service (e.g., `light.turn_on`, `input_select.select_option`, `script.turn_on`)
  - `GET /api/history/period/<timestamp>` — fetch historical data for mini-graph rendering
  - `GET /api/template` — evaluate Jinja2 templates server-side (used for computed sensor values)
  - `GET /api/camera_proxy/<entity_id>` — fetch camera still image for doorbell card
- **Error handling**: Retry with exponential backoff on 5xx; surface 401/403 as "re-authenticate" prompt; surface network errors as a connection status banner

### 1.2 WebSocket API Client
- **URL**: `ws(s)://<ha-host>:<port>/api/websocket`
- **Auth flow**: On connect, receive `auth_required` message → send `{"type":"auth","access_token":"<token>"}` → receive `auth_ok`
- **Subscriptions to implement**:
  - `subscribe_events` with `event_type: state_changed` — real-time entity state updates (drives all reactive UI)
  - `subscribe_trigger` — used for automation-like reactions (e.g., auto-expand media row when playing)
  - `call_service` — all service calls should go through WebSocket when connected (lower latency than REST)
  - `get_states` — initial bulk state load (faster than REST `/api/states`)
  - `subscribe_entities` (HA 2022.4+) — compressed entity diff stream, preferred over `state_changed` for performance
- **Reconnection**: Implement exponential backoff reconnect loop; show a subtle "Reconnecting…" indicator in the nav bar; replay subscriptions on reconnect
- **Message queue**: Buffer outgoing service calls during disconnection; flush on reconnect

### 1.3 Local State Store
- Maintain an in-memory dictionary `{ entity_id → EntityState }` mirroring `hass.states`
- On `state_changed` WebSocket event, update the store and notify all subscribed UI components
- Persist the last-known state to local storage/SQLite so the app renders immediately on cold launch before the WebSocket connects
- Implement a reactive pub/sub system (e.g., `StateStore.subscribe(entity_id, callback)`) so individual cards only re-render when their specific entities change

### 1.4 Helper Entity State Machine (replaces `hemma_helpers.yaml`)
Since the app is standalone, all HA helper entities defined in `packages/hemma_helpers.yaml` must be replicated as local app state. These are the entities that drive UI state:

| Local State Key | Replaces HA Entity | Type | Default |
|---|---|---|---|
| `thermostatOverlay` | `input_boolean.hemma_thermostat_overlay` | bool | false |
| `mobileNavigation` | `input_boolean.hemma_mobile_navigation` | bool | false |
| `lockOverlay` | `input_boolean.hemma_lock_overlay` | bool | false |
| `motionBadges` | `input_boolean.hemma_motion_badges` | bool | true |
| `restartConfirm1` | `input_boolean.hemma_restart_confirm_1` | bool | false |
| `restartConfirm2` | `input_boolean.hemma_restart_confirm_2` | bool | false |
| `restartDone1` | `input_boolean.hemma_restart_done_1` | bool | false (auto-clear 3s) |
| `restartDone2` | `input_boolean.hemma_restart_done_2` | bool | false (auto-clear 3s) |
| `expandedRow` | `input_select.hemma_expanded_row` | enum: `none\|climate\|presence\|media\|lights` | `none` |
| `thermostatTargetTemp` | `input_number.hemma_thermostat_target_temperature` | float | 72 |
| `thermostatMode` | `input_select.hemma_thermostat_mode` | enum: `cool\|heat` | `cool` |
| `motionSensors` | `input_text.hemma_motion_*` | map of room→entity_id | {} |

- `restartDone1` and `restartDone2` must auto-clear after 3 seconds (replicate the HA automation)
- `expandedRow` must auto-set to `media` when any `media_player` entity enters `playing` or `buffering` state AND `expandedRow` is currently `none` (replicate the HA automation)
- `dynamicBackground` must be computed locally from `sun.sun` elevation and rising attributes (replicate `sensor.hemma_mobile_dynamic_background` template logic: `sunset/dawn/morning/goldenhour/afternoon/midday`)

### 1.5 Dynamic Background Sensor (local computation)
Replicate `sensor.hemma_mobile_dynamic_background` entirely in-app:
- Subscribe to `sun.sun` state changes via WebSocket
- Compute phase from `elevation` float and `rising` bool:
  - `elevation < -6` → `sunset`
  - `elevation < 6` → `dawn` (rising) or `sunset` (setting)
  - `elevation < 24` → `morning` (rising) or `goldenhour` (setting)
  - `elevation < 50` → `morning` (rising) or `afternoon` (setting)
  - else → `midday`
- Map phase to background filename: `morning/dawn` → `morning`, `night/evening/sunset` → `night`, else → `day`
- Append `-dark` suffix if `sun.sun` state is `below_horizon`
- Result: `mobile-{phase}{dark}.jpg`

### 1.6 Computed Color Sensors (local computation)
Replicate `sensor.hemma_temp_color` and `sensor.hemma_humidity_color` as pure functions:
- **Temp color**: map float °F/°C to CSS variable name based on thresholds (≤65°F → very-cold, ≤70 → cool, ≤76 → comfortable, ≤81 → warm, ≤85 → hot, else → very-hot)
- **Humidity color**: ≤29.99% → dry, ≥61% → high, else → normal climate color

---

## SECTION 2 — App Foundation & Platform

### 2.1 Platform Choice
- **Recommended**: React Native (iOS + Android) or Flutter (iOS + Android + Desktop)
- **Alternative for desktop-only**: Electron + React/Vue
- The app must support: iOS, Android, macOS, Windows (optional)
- All rendering is client-side; no server component

### 2.2 Project Structure
```
/app
  /api          — REST + WebSocket clients
  /store        — StateStore, LocalHelperStore, SettingsStore
  /theme        — CSS variable tokens, light/dark/glass theme definitions
  /assets
    /fonts       — Hanken Grotesk WOFF2 files
    /icons       — All 75+ SVG icons (bundled in-app)
    /weather     — 21 weather SVGs
    /rooms       — Room background images (user-provided or downloaded)
    /mobile      — Time-of-day mobile backgrounds
  /components
    /layout      — ScreenLayout, EntityLayout, SmartRow
    /navigation  — MobileNavbar, TabletNavbar, DesktopNavbar
    /hero        — HeroRoomCard, BadgeSystem, ExpandedRow
    /cards       — All entity card components
    /badges      — All badge components
    /popups      — All popup components
  /screens
    /rooms       — One screen per configured room
    /settings    — Settings screen
  /utils         — Device detection, animation helpers, date utils
```

### 2.3 Typography
- Bundle **Hanken Grotesk** in 6 weights: 400, 500, 600, 700, 800, 900
- Load via `@font-face` declarations (replicate `www/hemma/fonts/hanken-grotesk.css`)
- Apply globally as the default font family
- Map weights to semantic roles: 400=body, 500=label, 600=subtitle, 700=title, 800=hero, 900=display

---

## SECTION 3 — Theme System

### 3.1 CSS Variable Token Architecture
Implement a token system with two layers:
1. **Mode tokens** — raw values for light and dark
2. **Alias tokens** — functional names that point to mode tokens (e.g., `--hemma-entity-background` resolves differently in light vs dark)

All tokens must be switchable at runtime without re-rendering the entire tree.

### 3.2 Base Theme Tokens (replicate `themes/hemma/hemma.yaml`)

**Surface tokens:**
- `--hemma-entity-background` — primary card background (semi-transparent)
- `--hemma-entity-background-active` — card background when entity is active/on
- `--ha-card-background` — base card surface
- `--hemma-dialog-bg` — popup/dialog background
- `--hemma-nav-bg` — navigation bar background

**State/color tokens:**
- `--hemma-active-color` — primary active highlight (used for icon tinting)
- `--hemma-puck-cool-color` — thermostat cool mode color
- `--hemma-puck-heat-color` — thermostat heat mode color
- `--hemma-icon-circle-bg` — icon container background (inactive)
- `--hemma-badge-temp-very-cold-color` through `--hemma-badge-temp-very-hot-color` — 6 temperature gradient colors
- `--hemma-badge-humidity-dry-color`, `--hemma-badge-humidity-high-color`, `--hemma-badge-climate-color`

**Layout tokens:**
- `--hemma-nav-height` — navigation bar height
- `--hemma-entity-col-width-desktop` — entity card column width on desktop (default 300px)
- `--page-gutter` — horizontal page margin (desktop: 8vw)
- `--page-gutter-mobile` — horizontal page margin (mobile: 11px)
- `--hemma-tiles-top-portrait` — top offset for entity grid in portrait (default 350px)
- `--hero-gutter` — hero card internal gutter

**Animation tokens:**
- `--hemma-anim-delay` — stagger delay for card entrance animations
- `--hemma-active-overlay-opacity` — 0 or 1, drives active state overlay visibility

**Typography tokens:**
- `--text-primary-color`
- `--secondary-text-color`
- `--primary-text-color`

### 3.3 Light Mode Values
- Surfaces: high transparency (e.g., `rgba(255,255,255,0.55)`), dark text
- Active states: high contrast
- Popups: scrim-based dimming

### 3.4 Dark Mode Values
- Surfaces: lower transparency (e.g., `rgba(20,20,30,0.6)`), light text
- Active states: subtle glow
- Popups: backdrop-filter focus

### 3.5 Glass Theme Variant (replicate `themes/hemma/hemma_glass.yaml`)
Override the base tokens with:
- **Specular tokens**: `--hemma-nav-specular-start`, `--hemma-nav-specular-mid`, `--hemma-nav-specular-end` — used for simulated light reflection gradients on nav bars
- **Multi-stop gradients**: `--hemma-entity-top-gradient` — curved glass simulation on card tops
- **Backdrop filters**: `blur()` on all surfaces
- **Liquid Glass aesthetic**: All card borders use a 1px gradient border simulating light hitting glass edge

### 3.6 Theme Switching
- Detect system light/dark preference automatically
- Allow manual override in Settings
- Allow switching between Base and Glass variants in Settings
- Store preference in local settings store

---

## SECTION 4 — Layout Engine

### 4.1 Screen Layout (replicate `hemma_screen_layout.yaml`)
- Root container occupies full viewport height (`100svh` / `100dvh`)
- Uses CSS Grid with two named areas: `hero` (full-screen background) and `entities` (scrollable grid)
- The hero and entity grid are absolutely positioned and overlap — the entity grid floats over the hero background
- Relative positioning context for parallax and absolute children

### 4.2 Entity Grid Layout (replicate `hemma_entity_layout.yaml`)

**Desktop / Tablet (landscape):**
- `grid-auto-flow: column` — horizontal scroll
- Column width: `var(--hemma-entity-col-width-desktop, 300px)`
- `touch-action: pan-x` with `scroll-snap-type: x proximity`
- Anchored to bottom of screen using inset logic
- Z-index: 3

**Mobile Portrait (width < 768px):**
- `grid-auto-flow: row`
- `grid-template-columns: repeat(2, minmax(0, 1fr))`
- Top offset: `var(--hemma-tiles-top-portrait, 350px)` from top
- Bottom padding: `env(safe-area-inset-bottom)` + nav height
- Z-index: 4

**Mobile Landscape (height < 600px):**
- 2-column fixed width (160px per column)
- Reduced top offset (~105px)

### 4.3 Smart Row (replicate `hemma-smart-row.js`)
This is a custom container component that wraps entity cards and provides FLIP-animated sorting.

**Active state detection (two-tier):**
1. State string matching: `on`, `playing`, `buffering`, `unlocked`, `problem`, `cleaning`, `returning` → active
2. CSS variable inspection: if `--hemma-active-overlay-opacity` resolves to `1` on a card → active (allows complex threshold-based logic to drive sorting)

**Sort timeline:**
- `t=0`: Pre-sort based on initial states before first render
- `t=100ms`: DOM pass — detect active states via CSS variables; correct order before animations start
- `t=900ms`: Page animation budget — `hemmaFadeInRight` animation completes
- `t=PAGE_ANIM_MS`: Re-seed — final silent re-sort to catch late-loading states

**FLIP animation algorithm:**
1. **First**: Record `getBoundingClientRect()` of all cards
2. **Last**: Change DOM order of card wrappers
3. **Invert**: Calculate delta between old and new positions; apply `transform: translate(dx, dy)` to snap cards back to starting position
4. **Play**: Remove transform with CSS transition `cubic-bezier(0.4, 0, 0.2, 1)` to animate to final position

**Sorting behavior:**
- Desktop: Full FLIP sorting enabled
- Mobile portrait/landscape: Sorting disabled — maintain stable vertical list

**Additional properties:**
- `_activeSet`: Set of indices of currently active cards
- `_activationOrder`: FIFO queue tracking order cards became active (stable sort)
- `SORT_DELAY_MS`: 2500ms hold time to prevent flickering from transient states (e.g., motion sensors)
- `--hemma-anim-delay`: Dynamically overwritten per card to synchronize stagger animation with sorted position
- `--hsr-anim-paused`: CSS variable to pause fan spin animations during sort transitions

---

## SECTION 5 — Navigation System

### 5.1 Device Detection
Implement a `DeviceMode` utility that returns `mobile | tablet | desktop` based on:
- Screen width < 768px AND touch input → `mobile`
- Screen width 768–1024px OR landscape mobile → `tablet`
- Screen width > 769px AND `pointer: fine` (hover capability) → `desktop`
- Re-evaluate on orientation change and window resize

### 5.2 Mobile Navbar (replicate `hemma_navbar_mobile.yaml`)
- **Position**: Docked to bottom of screen
- **Style**: Glassmorphism — `backdrop-filter: blur()` + specular highlight border
- **Specular border**: Implemented as a `linear-gradient` mask using `-webkit-mask-composite` to create a glass-like top edge
- **Items**: Room links + Scenes button + Rooms button
- **Motion dots**: Small colored dot badge on room links when `motionSensors[room]` entity is `on` AND `motionBadges` is true
- **Scroll behavior** (replicate `navbar-scroll.js`): Hide navbar on scroll down, reveal on scroll up; use `IntersectionObserver` or scroll event with velocity detection
- **Safe area**: Respect `env(safe-area-inset-bottom)` for iPhone notch/home indicator

### 5.3 Tablet Navbar (replicate `hemma_navbar_mobile.yaml` tablet section)
- **Position**: Floating at bottom (not edge-docked)
- **Style**: Same glassmorphism as mobile but with rounded pill shape
- **Items**: Same as mobile

### 5.4 Desktop Navbar (replicate `hemma_navigation.yaml`)
- **Position**: Fixed top bar
- **Sidebar offset** (replicate `navbar-sidebar-offset.js`): Detect if HA sidebar is open and offset the navbar's left position accordingly — in the native app, this means detecting if a side panel is open
- **Items**: Room links + Scenes dropdown + Rooms dropdown
- **Rooms dropdown**: Shows all configured rooms with motion dot badges
- **Scenes dropdown**: Shows all HA scenes filtered to exclude any scene with name prefixed `hemma_`
- **Caret animation** (replicate `navbar-popup-caret.js`): Animated caret/arrow on dropdown triggers

### 5.5 Shared Navigation Features
- **Motion sensor badges**: Read from `motionSensors` local state map; each room maps to a `binary_sensor` entity_id; show dot when entity state is `on`
- **Global motion toggle**: `motionBadges` local state; when false, hide all motion dots
- **Rooms popup**: Modal/sheet showing all rooms with motion status; used on mobile to save nav space
- **Scenes popup**: Modal/sheet showing filtered HA scenes; tapping a scene calls `scene.turn_on`

---

## SECTION 6 — Hero Room Card

### 6.1 Overview (replicate `hemma_room.yaml` + `hemma_shared.yaml`)
- Full-screen card (`100svh`) serving as the visual identity of each room
- Accepts entity references: sensors, media players, lights, climate entities
- Monitors `expandedRow` local state to show/hide badge sub-rows

### 6.2 Dynamic Backgrounds & Image Preloading (replicate `hemma_shared.yaml` preload logic)
- **Desktop/tablet backgrounds**: Located in `/assets/rooms/` — naming convention: `{room}.jpg` (light) and `{room}-night.jpg` (dark)
- **Mobile backgrounds**: Located in `/assets/mobile/` — naming convention: `mobile-{phase}{dark}.jpg` where phase is `morning|day|night`
- **Light/dark switching**: Automatically swap between light and dark variants based on `sun.sun` state (`below_horizon` → dark variant)
- **Preloading**: On app launch and room navigation, preload all configured room background images into memory (`window.hemmaPreloadedImages` equivalent — an in-memory image cache) to prevent white-flash flickering during transitions
- **Parallax entry animation** (`hemmaRoomParallax`): On room load, scale the background image slightly (e.g., 1.05→1.0) and shift it vertically — CSS keyframe animation
- **Phase transitions on mobile**: When `dynamicBackground` phase changes, crossfade to the new background image

### 6.3 Hero Layout
- **Padding bottom**: Dynamically calculated to avoid overlapping with mobile navbar (`--hemma-nav-height`) or desktop safe areas
- **Responsive padding**: Different values for mobile portrait vs desktop
- **Grid areas**: `badges` (top-level summary), `badges_climate`, `badges_media`, `badges_lights`, `badges_presence`

### 6.4 Badge System & Expanded Row Logic (replicate `hemma_shared.yaml` expansion logic)
The hero card contains a grid of badge rows. Only one row is expanded at a time, controlled by `expandedRow` local state.

| Grid Area | Visible When | Content |
|---|---|---|
| `badges` | Always | Climate group badge, media group badge, light group badge, presence group badge |
| `badges_climate` | `expandedRow === 'climate'` | Detailed temp/humidity/AQI sensors |
| `badges_media` | `expandedRow === 'media'` | Individual media player badges with controls |
| `badges_lights` | `expandedRow === 'lights'` | Individual light group controls |
| `badges_presence` | `expandedRow === 'presence'` | Individual person/device tracker badges |

- Transitions between rows use CSS opacity + height transitions (not display:none toggling)
- Tapping a group badge toggles its row: if already expanded → collapse to `none`; if collapsed → expand to that row
- Auto-expand media row: when any `media_player` enters `playing`/`buffering` AND `expandedRow === 'none'`

---

## SECTION 7 — Entity Card Base System

### 7.1 Base Card: `HemmaEntity` (replicate `hemma_entity.yaml`)
Every interactive tile in the entity grid inherits from this base component.

**Visual features:**
- **Specular border** (`::before` pseudo-element equivalent): 1px gradient border simulating light hitting a glass edge — implemented as an absolutely-positioned overlay with a `linear-gradient` border
- **Active state overlay** (`::after` pseudo-element equivalent): Background color/gradient overlay controlled by `--hemma-active-overlay-opacity` (0 = inactive, 1 = active)
- **Entrance animations**:
  - Desktop/tablet: `hemmaFadeInRight` — slide in from right with fade
  - Mobile portrait: `hemmaFadeIn` — fade in only
  - Staggered by `position` variable: `animation-delay = position * 50ms`
- **Progress ring**: Built-in SVG circular progress ring (used by media players, vacuums) — `stroke-dasharray` / `stroke-dashoffset` technique
- **Battery indicator**: Optional battery level shown on hover/focus — small pill at bottom of card

**Layout:**
- Fixed card dimensions with responsive sizing (desktop vs mobile portrait)
- Icon container (`#img-cell`): 44px circle on desktop, 38px on mobile portrait
- Icon: 26px on desktop, 23px on mobile portrait

**State-driven CSS variables set per card:**
- `--hemma-active-overlay-opacity`: `1` when active, `0` when inactive
- `--hemma-anim-delay`: Set by SmartRow to synchronize stagger

### 7.2 Base Card: `HemmaDefault` (replicate `hemma_default.yaml`)
- Provides core CSS variable defaults
- Inherited by `HemmaEntity`
- Sets font family, base spacing, and color fallbacks

### 7.3 Action Card Variant: `HemmaEntityActions` (replicate `hemma_entity_actions.yaml`)
- Extends `HemmaEntity` with a vertical rail on the right side of the card
- Contains two configurable action buttons (icon + label)
- Used for entities needing secondary controls without opening a popup (e.g., fridge modes)

---

## SECTION 8 — Climate & Environment Cards

### 8.1 Thermostat Card (`hemma_thermostat`)
- Inherits `HemmaEntity`
- **Temperature puck**: Custom SVG circle displaying current temperature
  - Size: 44px desktop, 38px mobile portrait
  - Color: `--hemma-puck-cool-color` (cool mode), `--hemma-puck-heat-color` (heat mode), `--hemma-icon-circle-bg` (off)
  - Data source: `variables.temp_sensor` if provided, else `climate.current_temperature` attribute
- **Overlay state machine**: Controlled by `thermostatOverlay` local state
  - Tap card → call `hemma_thermostat_overlay_toggle` equivalent (debounced toggle, 400ms cooldown, mode: single)
  - Overlay shows: horizontal temperature slider + HVAC mode selectors (cool/heat)
  - Temperature slider bound to `thermostatTargetTemp` local state
  - Changing temperature calls `climate.set_temperature` via WebSocket
- **HVAC mode switching**: Calls `climate.set_hvac_mode` using `thermostatMode` local state
- **Target temperature display**: Shows `thermostatTargetTemp` value

### 8.2 Fan Card (`hemma_fan`)
- Inherits `HemmaEntity`
- **Spin animations**:
  - `hemma-fan-spin`: 0.9s linear infinite rotation when fan is `on`
  - `hemma-fan-coast`: 1.5s ease-out rotation played once when fan turns `off`
  - Track previous state with `_prevFanState` to determine which animation to play
  - Applied to icon element; respects `--hsr-anim-paused` variable (paused during SmartRow sort)
- **Active state**: When `on`, sets `--hemma-active-overlay-opacity: 1`

### 8.3 Humidifier Card (`hemma_humidifier`)
- Inherits `HemmaEntity`
- **Dynamic icon**: `humidifier-on.svg` when `on`, `humidifier.svg` when `off`
- Tap calls `humidifier.toggle`

### 8.4 Air Purifier Card (`hemma_air_purifier`)
- Inherits `HemmaEntity`
- Uses `purifier.svg` icon
- Tap calls `fan.toggle` or `humidifier.toggle` depending on domain
- Responsive icon sizing (44px → 38px)

---

## SECTION 9 — Lighting Cards

### 9.1 Light Card (`hemma_light`)
- Inherits `HemmaEntity`
- **Smart Toggle** (replicate `script.hemma_light_smart_toggle`):
  - If light is `on`: snapshot current state via `scene.create` (or local equivalent), then call `light.turn_off` with `transition: 2`
  - If light is `off`: if snapshot scene exists, call `scene.turn_on` with `transition: 2`; else call `light.turn_on` with `transition: 2`
  - For light groups: snapshot each individual member entity, not the group
  - Store snapshots in local state keyed by `hemma_restore_{entity_id}`
- **Entity expansion engine** (recursive JS):
  - Read `entity_id` attribute from root entity
  - If it's a group (array of entity_ids), recursively expand each member
  - Filter to only `light.` domain entities
  - Count `onCount` from leaf entity states
  - Display: `"{onCount} On"` or `"Off"`
- **Popup**: On hold/long-press (non-mobile), open light group popup:
  - Two-column layout: `main` area (full group `more-info` equivalent) + `list` area (individual `mushroom-light-card` equivalent per member)
  - Hide default HA header/action buttons via CSS overrides
  - Apply `--hemma-popup-entity-background` to member cards

### 9.2 Light Badge (`hemma_badge_light`)
- Compact badge for hero card
- Same smart toggle logic
- Hold action on non-mobile: open group popup

### 9.3 Light Group Badge (`hemma_badge_light_group`)
- Aggregates up to 8 distinct light entities (`entity_1` through `entity_8`) + optional `light_group_entity`
- Tap: toggle `expandedRow` to `lights` (or back to `none`)
- Shows count of active lights across all configured entities

---

## SECTION 10 — Media Cards

### 10.1 Media Entity Card (`hemma_media`)
- Inherits `HemmaEntity`
- **Artwork logic**:
  - If playing YouTube (detected via `sensor.youtube_watching` or app name attribute): use YouTube thumbnail
  - Else: use `entity_picture` attribute from `media_player`
  - Fallback: `speaker.svg` icon
- **Rich media detection**: Check `media_content_type` and `app_name` against known rich sources (Plex, Spotify, Netflix, Apple TV, etc.)
  - Rich + has metadata: `--hemma-media-artwork-overlay` opacity = 0.4 (0.3 on mobile)
  - Bare input (HDMI, Optical, AUX): suppress artwork, show input name
- **Progress ring**: Show playback progress using `media_position` / `media_duration` attributes; update every second via local timer when playing
- **State display**: Format as `"{artist} — {title}"` or `"{app_name}"` depending on available metadata

### 10.2 Media Player Badge (`hemma_badge_media_player`)
- Used in hero card expanded media row
- **Glassmorphism**: `backdrop-filter: blur(14px) saturate(1.2)`
- **Dynamic background**: Set `--bg-url` to current album art; art bleeds through blur
- **Pause timeout**: `pause_timeout_minutes` variable (default 5); if `last_changed` exceeds timeout while paused, set badge opacity to 0
- **Controls**: Play/Pause button (calls `media_player.media_play_pause`), Skip button (calls `media_player.media_next_track`)
- **Volume**: Optional volume slider

### 10.3 Media Group Badge (`hemma_badge_media_group`)
- Aggregates up to 14 media players + optional Steam integration
- **Active count calculation**:
  - Players in `playing`, `buffering`, or `on` → active
  - Players in `paused` that haven't exceeded `pause_timeout_minutes` → active
  - Steam: if `steam_online_entity` is `online` AND a game is being played → active
- If `activeCount > 0`: badge is visible
- Tap: toggle `expandedRow` between `media` and `none`

### 10.4 Plex Recently Added Card (`hemma_plex_recently_added`)
- Reads from `sensor.recently_added_movies` and `sensor.recently_added_tv` attributes
- **State display**: Count of items added in last 7 days (replicate `sensor.plex_recently_added_count` logic)
- Tap: open Recently Added popup

### 10.5 Recently Added Popup (`hemma_popup_recently_added`)
- **Data merging**: Combine `recently_added_movies.data[1:]` and `recently_added_tv.data[1:]`
- **Recency filter**: Items added within last 3 days (`Date.now() - 3*24*60*60*1000`)
- **Sort**: By `airdate` descending
- **Carousel**: Swipe-based carousel (replicate `swipe-card` behavior)
  - Pill pagination indicators (replicate `swipe-card-patch.js` styling)
  - Each slide: poster art, title, year, rating, summary
  - Watched state: overlay dot on watched items

---

## SECTION 11 — Security & Access Cards

### 11.1 Lock Card (`hemma_lock`)
- Inherits `HemmaEntity`
- **Dynamic SVG icons** based on state:
  - `locked` → `lock.svg`
  - `unlocked` → `lock-open.svg`
  - `locking` → `lock.svg` (with transition animation)
  - `unlocking` → `lock-unlocking.svg`
- **Active state**: When `unlocked`, set `--hemma-active-overlay-opacity: 1` and change icon circle background to primary theme color
- **State display**: `"Locked"`, `"Unlocked"`, `"Locking..."`, `"Unlocking..."`
- **Responsive scaling**: 44px → 38px icon container
- Tap: call `lock.lock` or `lock.unlock` depending on current state

### 11.2 Motion Card (`hemma_motion`)
- Inherits `HemmaEntity`
- **Multi-sensor aggregation**: Accepts `sensor_1` through `sensor_6` variables
- **Primary entity**: Dynamically assigned to first defined sensor in variable list
- **Active detection**: Active if ANY of the provided sensors reports `on`
- **Dynamic label**: Shows the label of the currently-active sensor (e.g., `label_1` when `sensor_1` is `on`)
- **Tap action**: If any sensor is `on`, open `more-info` for that sensor; else open `more-info` for most recently triggered sensor (sort by `last_changed`)

### 11.3 Doorbell Card (`hemma_doorbell`)
- Inherits `HemmaEntity`
- Circular image cell for doorbell icon
- Tap: open camera stream (call `GET /api/camera_proxy/<entity_id>` or open native camera view)
- Uses `doorbell.svg` icon

### 11.4 Presence Group Badge (`hemma_badge_presence_group`)
- Aggregates up to 4 `person` or `device_tracker` entities
- **Status logic**:
  - All `home` or `just_arrived` → `"All Home"`
  - Some away → `"{n} Away"`
- **Icon masking**: Use `person.svg` with `-webkit-mask-image` technique for consistent styling
- Tap: toggle `expandedRow` between `presence` and `none`
- Individual person badges shown in expanded row

---

## SECTION 12 — Utility & Monitoring Cards

### 12.1 Energy Card (`hemma_energy`)
- Inherits `HemmaEntity` + popup base
- **State**: Displays current wattage from `entity_power`
- **Active state**: When power > `high_threshold` (default 500W) → glow yellow
- **Icon**: `energy.svg`; yellow icon circle background when active
- Tap: open Energy popup

### 12.2 Network Card (`hemma_network`)
- Inherits `HemmaEntity` + popup base
- **Tiered status** (based on max of download/upload speeds):
  - < `idle_threshold` (1 Mbps) → Idle
  - < `light_threshold` (10 Mbps) → Light (card becomes visually active)
  - < `heavy_threshold` (50 Mbps) → Active
  - ≥ `heavy_threshold` → Heavy (card glows, text turns yellow)
- **Directionality**: Compare download vs upload; show `"Download"` or `"Upload"` as primary label
- **WAN-only**: Only count external internet traffic, not LAN
- Tap: open Network popup

### 12.3 Plant Card (`hemma_plant`)
- Inherits `HemmaEntity` + popup base
- **Health scoring**: Map sensor IDs containing `moisture`, `temp`, `illuminance`, `conductivity` to their `*_status` attributes
- **Health ratio**: `goodCount / totalCount`
- **Status labels**: 1.0=Healthy, 0.8-0.99=Needs care, 0.6-0.79=Struggling, 0.4-0.59=Poor, <0.4=Critical
- **Active state**: When ratio < 1.0
- Tap: open Plant popup

### 12.4 Updates Card (`hemma_updates`)
- Inherits `HemmaEntity` + popup base
- **State**: Count of `update` domain entities with state `on`
- **Active state**: When count > 0 → teal glow
- Tap: open Updates popup

### 12.5 Battery Card (`hemma_battery`)
- Inherits `HemmaEntity` + popup base
- **State**: Scan all entities with `device_class: battery` (or filtered list via `entity_filter` variable)
- **Display**: `"Needs Attention"` if any battery ≤ 20%; else `"All Good"`
- **Active state**: When any battery ≤ 20%
- Tap: open Battery popup

### 12.6 Vacuum Card (`hemma_vacuum`)
- Inherits `HemmaEntity`
- **Dynamic icon**:
  - `cleaning` / `returning` → `vacuum-clean.svg`
  - `charging` → `vacuum-charge.svg`
  - `idle` / `docked` → `vacuum.svg`
- **Progress ring**: Show cleaning progress percentage
- Tap: call `vacuum.start` or `vacuum.return_to_base` depending on state

### 12.7 Curtain Card (`hemma_curtain`)
- Inherits `HemmaEntity`
- **Dynamic icon**: `curtain-open.svg` when open, `curtain-closed.svg` when closed
- **Tap logic**: If `open` or `opening` → call `cover.close_cover`; else → call `cover.open_cover`
- **Progress ring**: Show cover position percentage

---

## SECTION 13 — Badge System (Hero Card Badges)

### 13.1 Climate Group Badge (`hemma_badge_climate_group`)
- Shows aggregated climate status: temperature, humidity, AQI
- Tap: toggle `expandedRow` to `climate`
- Color-coded using computed temp/humidity color values (from Section 1.6)
- Individual climate sensor badges shown in expanded row

### 13.2 Climate Expanded Row
- Shows up to 3 climate entities (`climate_entity_1`, `climate_entity_2`, `climate_entity_3`)
- Each shows: temperature, humidity, AQI value with color coding
- Tap individual badge: open Climate popup

---

## SECTION 14 — Popup System

### 14.1 Popup Base (replicate `hemma_popup_base.yaml`)
- **Trigger**: Tap on card that has popup template
- **Container**: Native modal/sheet component
- **Sizing**: `adaptive: true`, `size: auto` — size to content
- **Vertical positioning**: Push dialog down from top of viewport (100px mobile, 150px desktop)
- **Backdrop**: Semi-transparent scrim with blur
- **Dismiss**: Tap outside or swipe down

### 14.2 Climate Popup (`hemma_popup_climate`)
- **Header**: Room name + status pill
- **Hero metric**: Mini graph card showing temperature history (last 24h via `GET /api/history/period/`)
- **AQI thresholds** (implement `sensorThresh` function):
  - PM2.5: Good (<12), Moderate (12-35), High (>35)
  - PM10: Good (<54), Moderate (54-154), High (>154)
  - CO2: Good (<800ppm), Moderate (800-1500ppm), High (>1500ppm)
  - VOCs: Good (<220ppb), Moderate (220-660ppb), High (>660ppb)
- **Detail grid**: Temperature, humidity, AQI sensors as tiles

### 14.3 Battery Popup (`hemma_popup_battery`)
- **Header**: Count of batteries needing attention
- **Filter**: `entity_filter` variable to limit to specific devices/rooms
- **List**: All battery entities sorted lowest → highest percentage
- **Visual**: Colored charge pills (red <20%, yellow <50%, green ≥50%)
- **Health counts**: Critical / Low / Good counts

### 14.4 Updates Popup (`hemma_popup_updates`)
- **Header pill**: Green `"Up to date"` or blue `"{n} available"`
- **List**: All `update` domain entities with state `on`
- Each item: entity name, current version, available version
- Tap item: navigate to HA update page (deep link or in-app webview)

### 14.5 Energy Popup (`hemma_popup_energy`)
- **Hero metric**: Real-time wattage with color-coded graph
  - Green (<200W), Yellow (<1000W), Orange (<3000W), Red (>3000W)
- **Cost tracking**: "Today" and "Month" usage (kWh) and cost (currency)
- **History graph**: Power consumption over last 24h

### 14.6 Network Popup (`hemma_popup_network`)
- **Stats**: WAN download speed, upload speed, ping latency
- **Restart flow** (replicate `script.hemma_restart_toggle`):
  - Action tile 1 (e.g., Router): Tap → `"Confirm?"` state → Tap again → execute restart service → `"Done"` (green, 3s) → auto-clear
  - Action tile 2 (e.g., Access Point): Same flow
  - Uses `restartConfirm1/2` and `restartDone1/2` local state
  - `restartDone` auto-clears after 3 seconds

### 14.7 Plant Popup (`hemma_popup_plant`)
- **Health score**: 0–100% calculated from sensor status attributes
- **SVG gauge**: Circular gauge with `stroke-dashoffset` representing health percentage
- **Advice string**: Dynamically generated based on which sensor is out of range (e.g., `"Needs more water"`, `"Move to brighter location"`)
- **Sensor grid**: Moisture, illuminance, temperature, conductivity tiles

---

## SECTION 15 — Static Assets (Bundled In-App)

### 15.1 Icon Library (replicate `www/hemma/icons/`)
Bundle all 75+ SVG icons. Key icons:

**Climate**: `thermostat.svg`, `fan.svg`, `purifier.svg`, `humidifier.svg`, `humidifier-on.svg`, `cooling.svg`, `heating.svg`, `humidity.svg`, `temp-high.svg`, `temp-medium.svg`, `temp-low.svg`

**Lighting**: `light.svg`, `lamp.svg`, `pendant-light.svg`, `pendent.svg`

**Media**: `media.svg`, `speaker.svg`, `music.svg`, `tv.svg`, `tv-play.svg`, `apple_tv.svg`, `homepod.svg`, `sony.svg`, `plex.svg`, `play.svg`, `pause.svg`, `play-next.svg`, `skip_next.svg`, `skip_previous.svg`, `mute.svg`, `unmute.svg`

**Security**: `lock.svg`, `lock-open.svg`, `lock-unlocking.svg`, `door.svg`, `door_open.svg`, `doorbell.svg`, `motion.svg`, `person.svg`

**Utility**: `battery.svg`, `energy.svg`, `electric.svg`, `gas.svg`, `wifi.svg`, `access_point.svg`, `updates.svg`, `plug.svg`, `vacuum.svg`, `vacuum-clean.svg`, `vacuum-charge.svg`, `curtain-open.svg`, `curtain-closed.svg`, `plant.svg`

**Navigation**: `home.svg`, `bedroom.svg`, `kitchen.svg`, `living-room.svg`, `menu.svg`, `scenes.svg`, `close.svg`

**UI Controls**: `arrow-up.svg`, `arrow-down.svg`, `increase.svg`, `decrease.svg`, `power_on.svg`, `power_off.svg`, `clock.svg`

**AQI**: `aqi-low.svg`, `aqi-medium.svg`, `aqi-high.svg`

**Icon colorization technique**: All icons use CSS masking (`-webkit-mask-image: url(icon.svg); background-color: var(--hemma-active-color)`) so they can be dynamically tinted without SVG fill manipulation.

### 15.2 Weather SVGs (replicate `www/hemma/weather/`)
Bundle 21 weather state SVGs mapping to HA weather states:
`clear-night`, `cloudy`, `exceptional`, `fog`, `hail`, `lightning`, `lightning-rainy`, `partlycloudy`, `pouring`, `rainy`, `snowy`, `snowy-rainy`, `sunny`, `windy`, `windy-variant` (and variants)

Map HA `weather.` entity state strings directly to SVG filenames.

### 15.3 Background Images
- **Room backgrounds**: User provides or downloads; stored in app's local documents directory
- **Mobile time-of-day backgrounds**: `mobile-morning.jpg`, `mobile-morning-dark.jpg`, `mobile-day.jpg`, `mobile-day-dark.jpg`, `mobile-night.jpg`, `mobile-night-dark.jpg`
- **Naming convention**: `{room_id}.jpg` and `{room_id}-night.jpg` for each room
- **Download from HA**: Optionally allow user to point to HA `/local/hemma/rooms/` URL to download backgrounds on first launch

---

## SECTION 16 — JavaScript Behaviors (Native Equivalents)

### 16.1 Navbar Scroll Behavior (replicate `navbar-scroll.js`)
- On scroll down past threshold: animate navbar out (translate Y + fade)
- On scroll up: animate navbar back in
- Use native scroll event listener with velocity/direction detection
- Threshold: ~50px scroll before triggering hide

### 16.2 Sidebar Offset (replicate `navbar-sidebar-offset.js`)
- In native app context: detect if a side drawer/panel is open
- Offset the desktop navbar's left position by the drawer width
- Animate offset change with the drawer open/close animation

### 16.3 Swipe Card Patch (replicate `swipe-card-patch.js`)
- Custom pagination pill styling for the Plex Recently Added carousel
- Replace default dot indicators with pill-shaped bars
- Active pill: wider/brighter; inactive: narrow/dimmer
- Animate pill width transition on swipe

### 16.4 Navbar Popup Caret (replicate `navbar-popup-caret.js`)
- Animated caret/chevron on dropdown triggers in desktop navbar
- Rotate 180° when dropdown is open; rotate back on close
- CSS transform transition

---

## SECTION 17 — Settings Screen (New — In-Depth)

This is a new screen not present in the original Hemma dashboard. It provides all configuration needed to connect to any Home Assistant instance and customize the app to match the user's setup.

---

### 17.1 Connection Settings

**Home Assistant Instance**
- `HA URL` — text field; full URL including protocol and port (e.g., `http://192.168.1.100:8123` or `https://myhome.duckdns.org`)
- `Long-Lived Access Token` — secure text field (stored in device keychain/secure storage, never in plain text)
- `Connection Mode` — toggle: `Local Only | Remote Only | Auto (Local preferred)`
- `Local URL` — text field (for auto mode; used when on home network)
- `Remote URL` — text field (for auto mode; used when away)
- `Network detection method` — `SSID match | IP range | Manual toggle`
- `Home SSID` — text field (for SSID-based local/remote switching)
- `Test Connection` — button; pings `/api/` and shows latency + HA version
- `WebSocket Reconnect Interval` — slider: 1–30 seconds (default 5s)
- `Request Timeout` — slider: 5–60 seconds (default 15s)

---

### 17.2 Appearance & Theme

**Theme**
- `Theme Variant` — segmented control: `Base | Glass`
- `Color Mode` — segmented control: `System | Light | Dark`
- `Accent Color` — color picker (overrides `--hemma-active-color`)
- `Background Blur Intensity` — slider: 0–30px (overrides backdrop-filter blur values)
- `Card Transparency` — slider: 0–100% (overrides `--hemma-entity-background` alpha)
- `Navigation Bar Style` — segmented control: `Solid | Frosted | Transparent`

**Typography**
- `Font Size Scale` — slider: 80%–130% (scales all text proportionally)
- `Use Custom Font` — toggle; if off, use Hanken Grotesk; if on, allow font file import

**Animations**
- `Enable Entrance Animations` — toggle (disables `hemmaFadeIn`/`hemmaFadeInRight`)
- `Enable Smart Row Sorting` — toggle (disables FLIP sort on desktop)
- `Animation Speed` — slider: 0.5×–2× (scales all animation durations)
- `Parallax Background Effect` — toggle (disables `hemmaRoomParallax`)

---

### 17.3 Room Configuration

For each room (add/remove/reorder):

**Room Identity**
- `Room Name` — text field
- `Room ID` — auto-generated slug (used for background image naming)
- `Room Icon` — icon picker from bundled icon library
- `Navigation Order` — drag-to-reorder

**Room Backgrounds**
- `Desktop Background` — image picker (from device library or URL)
- `Mobile Background Override` — toggle; if on, use room-specific mobile background instead of time-of-day global
- `Use Time-of-Day Backgrounds` — toggle (enables phase-based mobile backgrounds)
- `Background Brightness` — slider: 50%–150%

**Room Entities**
- `Climate Entity` — entity picker (filtered to `climate` domain)
- `Temperature Sensor` — entity picker (filtered to `sensor` domain, `device_class: temperature`)
- `Humidity Sensor` — entity picker (filtered to `sensor` domain, `device_class: humidity`)
- `AQI Sensor` — entity picker (optional)
- `Light Group Entity` — entity picker (filtered to `light` domain)
- `Additional Light Entities` — multi-entity picker (up to 8)
- `Media Players` — multi-entity picker (up to 14, filtered to `media_player` domain)
- `Motion Sensor (for nav badge)` — entity picker (filtered to `binary_sensor`, `device_class: motion`)
- `Lock Entities` — multi-entity picker (filtered to `lock` domain)
- `Cover/Curtain Entities` — multi-entity picker (filtered to `cover` domain)
- `Presence Entities` — multi-entity picker (up to 4, filtered to `person` or `device_tracker`)

**Entity Grid Cards** (add/remove/reorder per room)
- Card type selector: `Light | Thermostat | Fan | Humidifier | Air Purifier | Media | Lock | Motion | Doorbell | Vacuum | Curtain | Energy | Network | Battery | Updates | Plant | Custom`
- Per card: entity assignment, label override, position index

---

### 17.4 Climate Settings

- `Temperature Unit` — segmented control: `°F | °C`
- `Thermostat Min Temperature` — number input
- `Thermostat Max Temperature` — number input
- `Thermostat Step` — number input (0.5 or 1)
- `Default HVAC Mode` — segmented control: `Cool | Heat | Auto`
- `Temperature Color Thresholds` — 6 threshold values (very cold / cool / comfortable / warm / hot / very hot) with color pickers for each

---

### 17.5 Media Settings

- `Pause Timeout` — slider: 1–60 minutes (default 5); after this time, paused media badges fade out
- `Auto-Expand Media Row` — toggle (enables/disables the auto-expand automation)
- `Rich Media Sources` — multi-select list of app names considered "rich" (Plex, Spotify, Netflix, etc.); user can add custom entries
- `Bare Input Keywords` — text list of keywords that identify physical inputs (HDMI, Optical, AUX, etc.)
- `Steam Integration` — toggle; if on, show `Steam Online Entity` picker
- `Steam Online Entity` — entity picker (filtered to `binary_sensor` or `sensor`)
- `YouTube Sensor` — entity picker (optional; for YouTube thumbnail support)
- `Plex Recently Added — Movies Sensor` — entity picker
- `Plex Recently Added — TV Sensor` — entity picker
- `Recently Added Recency Filter` — slider: 1–14 days (default 3 for popup, 7 for badge count)

---

### 17.6 Navigation Settings

- `Show Motion Badges` — toggle (maps to `motionBadges` local state; persisted)
- `Motion Sensor Assignments` — per-room motion sensor entity picker (maps to `motionSensors` map)
- `Desktop Navbar Position` — segmented control: `Top | Left Sidebar`
- `Mobile Navbar Style` — segmented control: `Docked Bottom | Floating Bottom`
- `Show Scenes Button` — toggle
- `Scenes Filter Prefix` — text field (default `hemma_`; scenes with this prefix are hidden)
- `Show Rooms Button` — toggle
- `Navbar Scroll Hide` — toggle (enables/disables scroll-to-hide behavior on mobile)

---

### 17.7 Network Monitoring Settings

- `Download Speed Sensor` — entity picker
- `Upload Speed Sensor` — entity picker
- `Ping Sensor` — entity picker
- `Idle Threshold` — number input (default 1 Mbps)
- `Light Threshold` — number input (default 10 Mbps)
- `Heavy Threshold` — number input (default 50 Mbps)
- `Network Device 1 Name` — text field (e.g., "Router")
- `Network Device 1 Restart Entity` — entity picker (filtered to `button` or `switch` domain)
- `Network Device 2 Name` — text field (e.g., "Access Point")
- `Network Device 2 Restart Entity` — entity picker

---

### 17.8 Energy Settings

- `Power Sensor` — entity picker (filtered to `sensor`, `device_class: power`)
- `Energy Today Sensor` — entity picker (filtered to `sensor`, `device_class: energy`)
- `Energy Month Sensor` — entity picker
- `Cost Today Sensor` — entity picker (optional)
- `Cost Month Sensor` — entity picker (optional)
- `High Power Threshold` — number input (default 500W; triggers active state on energy card)
- `Energy Cost Thresholds` — 4 wattage thresholds with color pickers (green/yellow/orange/red)
- `Currency Symbol` — text field (default `$`)

---

### 17.9 Battery Settings

- `Low Battery Threshold` — slider: 5–50% (default 20%)
- `Battery Filter Mode` — segmented control: `All Devices | By Room | Custom List`
- `Custom Battery Entity List` — multi-entity picker (when filter mode is Custom List)
- `Room Battery Assignments` — per-room entity filter prefix/label

---

### 17.10 Plant Settings

Per plant card:
- `Plant Entity` — entity picker
- `Moisture Sensor` — entity picker
- `Illuminance Sensor` — entity picker
- `Temperature Sensor` — entity picker
- `Conductivity Sensor` — entity picker
- `Plant Name` — text field

---

### 17.11 Presence Settings

Per person slot (up to 4):
- `Person Entity` — entity picker (filtered to `person` or `device_tracker`)
- `Display Name` — text field
- `Avatar Image` — image picker or URL

---

### 17.12 Background & Asset Management

- `Background Source` — segmented control: `Bundled | HA Server | Local Device`
- `HA Backgrounds Base URL` — text field (e.g., `http://192.168.1.100:8123/local/hemma/rooms/`)
- `Download Backgrounds from HA` — button; fetches all room backgrounds from HA server
- `Background Cache Size` — shows current cache size with `Clear Cache` button
- `Time-of-Day Backgrounds` — toggle (enables `sensor.hemma_mobile_dynamic_background` equivalent)
- `Sun Entity` — entity picker (default `sun.sun`; used for phase calculation)

---

### 17.13 Advanced / Developer Settings

- `WebSocket Debug Log` — toggle; shows raw WebSocket messages in a scrollable log view
- `State Inspector` — searchable list of all entity states in the local store; tap to see full state object
- `Force Refresh All States` — button; re-fetches all states via REST
- `Clear Local State Cache` — button; wipes persisted state from local storage
- `Export Settings` — button; exports all settings as JSON file
- `Import Settings` — button; imports settings from JSON file
- `Reset to Defaults` — button with confirmation dialog
- `App Version` — display only
- `HA Version` — display only (fetched from `/api/config`)
- `WebSocket Status` — live indicator: Connected / Reconnecting / Disconnected + latency

---

## SECTION 18 — App-Level Behaviors & Lifecycle

### 18.1 Cold Launch Sequence
1. Load settings from secure storage
2. Render last-known state from local cache (instant UI)
3. Connect WebSocket
4. On `auth_ok`: call `get_states` to refresh all entity states
5. Subscribe to `state_changed` events
6. Start `dynamicBackground` computation from `sun.sun`
7. Preload all room background images
8. Check `expandedRow` auto-expand condition for media

### 18.2 Background / Foreground Transitions
- On app background: pause WebSocket keepalive; stop local timers (media progress, etc.)
- On app foreground: reconnect WebSocket; refresh all states via REST; resume timers

### 18.3 Offline Mode
- Show subtle "Offline" banner in navbar
- All entity cards render last-known state with reduced opacity or a subtle indicator
- Service calls are queued and replayed on reconnect (with user-configurable queue limit)
- Background images and icons always available (bundled/cached)

### 18.4 Haptic Feedback
- Light haptic on card tap
- Medium haptic on toggle (light on/off, lock lock/unlock)
- Heavy haptic on destructive actions (network restart confirm)

### 18.5 Accessibility
- All interactive elements have accessibility labels
- Support Dynamic Type / system font size scaling
- High contrast mode: increase card border opacity, reduce transparency
- VoiceOver/TalkBack: announce entity state changes for active entities

---

## SECTION 19 — Key Implementation Notes for LLM Agents

1. **`--hemma-active-overlay-opacity`** is the single most important CSS variable in the system. Every card sets it to `0` (inactive) or `1` (active). The SmartRow reads it to determine sort order. The `::after` overlay uses it for opacity. Implement this as a per-card state variable that drives both visual and sort behavior.

2. **The FLIP algorithm** in SmartRow must record positions *before* DOM reorder and apply inverse transforms *after* DOM reorder, then remove transforms with a transition. This is the only way to achieve smooth card reordering without teleporting.

3. **The `hemma_light_smart_toggle` script** must be replicated exactly — snapshot before off, restore on next on. Store snapshots keyed by `hemma_restore_{entity_id}` in local state. For groups, snapshot individual members.

4. **The `expandedRow` state machine** is the backbone of the hero card. Only one row is ever expanded. Tapping the same badge again collapses it. The media auto-expand automation must not override a user's manual selection.

5. **Background preloading** is critical for smooth room transitions. Preload all room images on startup into an in-memory cache. Never load a background image on-demand during a navigation transition.

6. **The specular border** on cards and nav bars is a 1px gradient border, not a box-shadow. It must be implemented as an absolutely-positioned pseudo-element with a `linear-gradient` and `-webkit-mask-composite` to create the glass-edge illusion.

7. **The `thermostatOverlay` toggle** must be debounced (400ms, mode: single) to prevent animation stutter from rapid taps.

8. **All service calls** should go through the WebSocket `call_service` message type when connected, falling back to REST `POST /api/services/<domain>/<service>` when disconnected.

9. **The `entity_filter` in battery popup** allows scoping battery monitoring to a specific room or device set. Implement as a prefix filter or explicit entity list.

10. **The network restart flow** is a 3-state machine per device: `idle → confirm → done(3s) → idle`. The `done` state auto-clears after exactly 3 seconds. Never allow the restart service to be called without going through the confirm state. Hemma:37-110 Hemma:253-300 Hemma:317-367
### Citations
**File:** packages/hemma_helpers.yaml (L37-110)
```yaml
input_boolean:
  hemma_thermostat_overlay:
    name: Thermostat Overlay
    initial: off

  hemma_mobile_navigation:
    name: Mobile Navigation
    initial: off

  hemma_lock_overlay:
    name: Lock Overlay
    initial: off

  hemma_motion_badges:
    name: Motion Badges
    initial: on

  hemma_restart_confirm_1:
    name: Network Restart Confirm 1
    initial: off

  hemma_restart_confirm_2:
    name: Network Restart Confirm 2
    initial: off

  hemma_restart_done_1:
    name: Network Restart Done 1
    initial: off

  hemma_restart_done_2:
    name: Network Restart Done 2
    initial: off

input_text:
  # Motion sensor entity IDs for navbar badges (desktop + mobile).
  # Leave initial as "" to disable the badge for that room.
  hemma_motion_living_room:
    name: "Hemma Motion - Living Room"
    initial: "binary_sensor.living_room_hub_motion"
  hemma_motion_bedroom:
    name: "Hemma Motion - Bedroom"
    initial: "binary_sensor.hue_motion_sensor_motion"
  hemma_motion_kitchen:
    name: "Hemma Motion - Kitchen"
    initial: ""   # set to your kitchen motion sensor entity ID to enable

input_number:
  hemma_thermostat_target_temperature:
    name: Thermostat Target Temperature
    # Celsius users: min: 15, max: 30, step: 0.5, unit_of_measurement: "°C"
    min: 68
    max: 75
    step: 1
    unit_of_measurement: "°F"
    mode: slider

input_select:
  hemma_expanded_row:
    name: Expanded Badge Row
    options:
      - none
      - climate
      - presence
      - media
      - lights
    initial: none

  hemma_thermostat_mode:
    name: Thermostat Mode
    options:
      - cool
      - heat
    initial: cool

```
**File:** packages/hemma_helpers.yaml (L253-300)
```yaml
  hemma_light_smart_toggle:
    alias: "Hemma - Smart Light Toggle"
    description: >
      Saves the current light state before turning off.
      For light groups, snapshots each individual member so only
      the lights that were on get restored (not the whole group).
      Falls back to a plain turn_on if no saved state exists yet.
    mode: queued
    max: 5
    sequence:
      - variables:
          scene_id: "hemma_restore_{{ light_entity | replace('.', '_') }}"
          scene_entity: "scene.hemma_restore_{{ light_entity | replace('.', '_') }}"
      - choose:
          # Light is ON → snapshot current state then turn off
          - conditions:
              - condition: template
                value_template: "{{ states(light_entity) == 'on' }}"
            sequence:
              - service: scene.create
                data:
                  scene_id: "{{ scene_id }}"
                  snapshot_entities: >-
                    {% set m = state_attr(light_entity, 'entity_id') %}
                    {% if m %}{{ m }}{% else %}{{ [light_entity] }}{% endif %}
              - service: light.turn_off
                data:
                  transition: 2
                target:
                  entity_id: "{{ light_entity }}"
        # Light is OFF → restore snapshot if it exists, otherwise turn on normally
        default:
          - choose:
              - conditions:
                  - condition: template
                    value_template: >-
                      {{ scene_entity in (states.scene | map(attribute='entity_id') | list) }}
                sequence:
                  - service: scene.turn_on
                    data:
                      entity_id: "{{ scene_entity }}"
                      transition: 2
            default:
              - service: light.turn_on
                data:
                  transition: 2
                target:
                  entity_id: "{{ light_entity }}"
```
**File:** packages/hemma_helpers.yaml (L317-367)
```yaml
automation:
  - alias: "Hemma - Auto clear restart done state 1"
    id: hemma_auto_clear_restart_done_1
    trigger:
      - platform: state
        entity_id: input_boolean.hemma_restart_done_1
        to: "on"
    action:
      - delay: "00:00:03"
      - service: input_boolean.turn_off
        target:
          entity_id: input_boolean.hemma_restart_done_1

  - alias: "Hemma - Auto clear restart done state 2"
    id: hemma_auto_clear_restart_done_2
    trigger:
      - platform: state
        entity_id: input_boolean.hemma_restart_done_2
        to: "on"
    action:
      - delay: "00:00:03"
      - service: input_boolean.turn_off
        target:
          entity_id: input_boolean.hemma_restart_done_2

  # Auto-expand the media row when media is actively playing.
  # Triggers on HA startup (handles page-load defaults) and whenever
  # any media player begins playing. Only acts if the row is currently
  # collapsed so manual selections by the user are never overridden.
  - alias: "Hemma - Auto-expand media row when playing"
    id: hemma_auto_expand_media_row
    trigger:
      - platform: homeassistant
        event: start
      - platform: template
        value_template: >
          {{ states.media_player
             | selectattr('state', 'in', ['playing', 'buffering'])
             | list | count > 0 }}
    condition:
      - condition: template
        value_template: >
          {{ states('input_select.hemma_expanded_row') == 'none'
             and (states.media_player
                  | selectattr('state', 'in', ['playing', 'buffering'])
                  | list | count > 0) }}
    action:
      - service: input_select.select_option
        data:
          entity_id: input_select.hemma_expanded_row
          option: media
```
