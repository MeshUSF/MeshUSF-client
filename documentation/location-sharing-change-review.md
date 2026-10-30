# Location sharing change review

## Result

The connected node still takes priority when it reports GPS enabled and has valid stored coordinates. Device fallback now has a 10-second deadline. Browser fallback can reuse fixes at most 60 seconds old with reported accuracy within 50 meters; rejected cached fixes trigger a fresh request within the same deadline. Fresh device fixes retain coordinate validation without the 50-meter restriction. Both chat types show progress and send a localized **My location:** label.

The original browser path could acquire location while requesting permission, then acquire it again for the message. It also prohibited cached positions. The installed geolocator_web implementation passes timeout microseconds to the browser's millisecond option, so its nominal 30-second timeout did not enforce the intended limit. The application now enforces its own deadline without modifying dependencies.

## Production code

### lib/services/location_sharing_service.dart

- Added the Flutter foundation import for `kIsWeb`, which selects browser-specific lookup and permission behavior.
- Added `_maxCachedPositionAge`: constant 60-second maximum age for a reusable browser fix.
- Added `_maxCachedAccuracyMeters`: constant 50.0-meter maximum reported accuracy radius for a reusable browser fix.
- Added `_lookupTimeout`: constant 10-second allowance for the whole device fallback, including permission handling and a possible fresh-fix retry.
- Changed `getCurrentCoordinates(MeshCoreConnector connector)`: its signature and immediate node-GPS return remain the same. It now encloses device service checks, native permission handling, location acquisition, cache validation, and optional retry in one asynchronous operation with a Dart timeout. Browser location acquisition handles its own permission prompt, avoiding the separate permission lookup. Native permission checking/requesting remains explicit. `PositionUpdateException` is now mapped to the existing unavailable-location failure, along with timeout and platform errors.
- Added local `lookupExpired`: becomes true when the Dart deadline expires. Checks after asynchronous preflight steps and the first position result prevent a late completion from starting a new permission or location request.
- Added local `requestStartedAt`: records when coordinate acquisition begins, to distinguish a new browser result from a cached result.
- Changed local `position` from final to mutable: holds the initial fix and, when needed, its fresh replacement.
- Added local `cacheAge`: elapsed time since the returned browser position's timestamp.
- Added local `isFresh`: identifies a position timestamp at or after request start and not in the future. New positions can use the existing accuracy behavior.
- Added local `isReusable`: requires a nonfuture fix no older than 60 seconds, finite positive reported accuracy at most 50 meters, and valid coordinates.
- Moved existing local `permission` into the native-only branch. Existing `radioLatitude`, `radioLongitude`, node validation, returned `SharedCoordinates`, exception types, and `_isValidCoordinates()` were not changed.
- Added two anonymous callbacks: an async operation containing the device workflow and an `onTimeout` callback marking expiration and throwing `TimeoutException`. No new named production functions or public parameters were added.

### lib/screens/chat_screen.dart

- Added `_ChatScreenState._isSharingLocation`, initially false: tracks an active location action.
- Changed `_buildInputBar()`: replaces the location icon with a 24-pixel spinner while busy, adds a localized progress tooltip and accessibility label, and disables the location button until completion.
- Changed `_sendLocation()`: rejects duplicate actions and disconnected starts, sets busy state immediately, discards a result after screen disposal or disconnection, and clears busy state in `finally` if mounted. Existing local `coordinates`, `mapCoordinates`, `error`, and `message` keep their purposes. The outgoing prefix now uses `context.l10n.chat_myLocation`; coordinate precision, map link, send method, and draft handling remain unchanged.

### lib/screens/channel_chat_screen.dart

- Added `_ChannelChatScreenState._isSharingLocation`, initially false: tracks an active channel location action.
- Changed `_buildInputBar()`: displays the spinner and localized progress tooltip/accessibility label on the add menu. Only the location menu item is disabled while busy; the other actions remain available.
- Changed `_sendLocation()`: adds the same duplicate, connection, mounted, busy-state, and `finally` handling as direct chat. The outgoing prefix now uses `context.l10n.chat_myLocation`. Existing locals keep their purposes; existing reply/region behavior and draft handling remain unchanged.

## Localization files

| File | Changes |
|---|---|
| lib/l10n/app_en.arb | Added `chat_myLocation` = "My location" and `chat_gettingLocation` = "Getting location…". |
| lib/l10n/app_es.arb | Added `chat_myLocation` = "Mi ubicación" and `chat_gettingLocation` = "Obteniendo ubicación…". Preserved the pre-existing `chat_location` edit. |
| lib/l10n/app_fr.arb | Added `chat_myLocation` = "Ma position" and `chat_gettingLocation` = "Obtention de la position…". |
| lib/l10n/app_localizations.dart | Generated abstract `chat_myLocation` and `chat_gettingLocation` getters and their documentation. |
| lib/l10n/app_localizations_en.dart | Generated both new English getter implementations. |
| lib/l10n/app_localizations_es.dart | Generated both new Spanish getter implementations; regeneration also reflects the pre-existing Spanish `chat_location` change. |
| lib/l10n/app_localizations_fr.dart | Generated both new French getter implementations. |

`chat_myLocation` supplies the outgoing message prefix. `chat_gettingLocation` supplies loading tooltips and screen-reader descriptions. Generic `chat_location` uses were not repurposed.

## Test code

### test/services/location_sharing_service_test.dart (new)

- Added `_LocationConnector`: a controllable connector. Fields `connected`, `gpsEnabled`, `latitude`, and `longitude` define the simulated node; getters `isConnected`, `hasGps`, `selfLatitude`, and `selfLongitude` expose them to the production service.
- Added `_LocationPlatform`: replaces the geolocator platform during each test. Fields `serviceEnabled`, `permission`, and `requestedPermission` control service/permission results. Counters `serviceChecks`, `permissionChecks`, and `permissionRequests` verify which APIs were used. List `settings` records coordinate requests. Optional callbacks `checkService` and `locate` simulate delays, fixes, and errors.
- Added platform overrides `isLocationServiceEnabled()`, `checkPermission()`, `requestPermission()`, and `getCurrentPosition({locationSettings})`: record calls and return the configured results.
- Added `_position({timestamp, latitude, longitude, accuracy})`: builds a test position; remaining required motion/altitude fields are zero because these tests only exercise horizontal location.
- Added `_failure(failure)`: matches `LocationLookupException.failure` for user-facing error mapping.
- Added `main()`, setup, teardown, and test callbacks: install/restore `originalPlatform`, create the `platform` and `connector` fixtures, and dispose the connector.
- Test locals `reason`, `latitude`, `accuracy`, `permission`, and `entry` select parameterized scenarios; `result` holds coordinates or an expected failure's completion; `pending`, `first`, and `second` control unfinished requests; `completed` records whether the timeout fired; `tester` advances fake time. Matcher callback `error` exposes the exception's failure. No production state is changed by these fixtures.
- Tests cover node priority; device fallback for disabled GPS, invalid node coordinates, and disconnection; disabled services; five exception mappings; invalid fresh coordinates; exact 10-second expiration; late preflight/results; native permission behavior; browser single-request prompting, recent cache reuse including exactly 50-meter accuracy, stale/future/inaccurate/unknown/nonfinite/invalid cached fixes, fresh coarse fixes, and retries sharing one deadline.

### test/screens/location_sharing_test.dart (new)

- Added the `app_settings.dart` model import and `_ChatSettings`: its overridden `settings` field disables the unrelated image action so these tests focus on the location/GIF menu. No production image setting was changed.
- Added `_ChatConnector`: fields `connected`, `directMessages`, and `channelMessages` represent connection state and captured outgoing messages. Getters `isConnected`, `selfName`, and `hasGps` simulate a connected node without GPS. `getMessages()` and `getChannelMessages()` feed the actual screen lists. `sendMessage()` and `sendChannelMessage()` capture outgoing text, create displayable messages with fixed example timestamps, and notify listeners. `acquireRadioStatsPolling()`, `releaseRadioStatsPolling()`, `setActiveContact()`, and `setActiveChannel()` are no-op overrides to avoid hardware and storage side effects. Send overrides accept the existing connector's contact/channel, text, translation, region, and reply parameters; these tests capture text and region and do not simulate translation or reply delivery.
- Added `_ChatLocationPlatform`: field `lookups` counts requests and optional callback `locate` controls their completion. Overrides `isLocationServiceEnabled()`, `checkPermission()`, and `getCurrentPosition({locationSettings})` provide enabled services, granted permission, and configured fixes so actual screen buttons run through the production location service.
- Added `_position()`: returns simulated coordinates 45.5,-122.6 with 10-meter reported accuracy and a current timestamp.
- Added `_pumpChat(tester, connector, {channel, language})`: mounts the requested real chat screen with its providers, localized Material app, and dark theme. A keyed `RepaintBoundary` supports screenshot capture; the debug banner is disabled and teardown unmounts the screen.
- Added `_tapLocation(tester, {channel, label})`: dismisses existing snackbar feedback before a retry, uses the direct-chat button or channel add menu, and advances both the initial and ending menu-animation frames.
- Added `_capture(tester, name)`: writes the documented screenshots only when Flutter's standard `--update-goldens` option is enabled. Normal test runs do not write or compare documentation screenshots.
- Added `main()`, setup/teardown, and test callbacks: install/restore `originalPlatform`, initialize `platform` and `connector`, and load the real Inter, JetBrains Mono, and MaterialIcons fonts. Captured messages use sent status to avoid a continuously animated pending-message indicator. Loading captures advance the spinner by 250 milliseconds so its progress arc is visible.
- Test locals `channel`, `kind`, `language`, `label`, `entry`, and `leaveScreen` select chat type, localization, and navigation scenarios; `pending` controls a delayed fix; `item` and `button` inspect the location action's enabled state; `messages` and `text` inspect transmitted contents; `font` selects a font-family/asset pair and `fontLoader` registers it; `tester`, provider `context`, and screenshot `name` support UI interaction and rendering.
- Tests cover progress, duplicate actions, other channel-menu actions remaining available, preserved drafts, exact outgoing labels in all three locales, map links, timeout/retry/late completion, error recovery, leaving the screen, and disconnection in both chat types.

### test/helpers/location_map_link_test.dart

- Added one test callback for extracting the coordinates and display text from a **My location:** message. Its `link` local is the generated internal URL and `extracted` is the parsed result. Existing tests still cover older **Location:** messages and Google Maps links. No named helper functions were added here.

## Documentation and images

- `documentation/chat-and-messaging.md`: documents node priority, browser cache limits, the whole-operation timeout, loading/error/retry behavior, localized message text, preserved drafts, and screenshot regeneration.
- `documentation/map-and-location.md`: corrects the obsolete claim that phone GPS is never used and links to the chat-location behavior.
- `documentation/location-sharing-change-review.md`: this complete change inventory and validation record.
- `docs/screenshots/direct-location-sharing-loading.png`: simulated direct chat during lookup.
- `docs/screenshots/direct-location-sharing-message.png`: simulated direct chat showing **My location** and **View on map**.
- `docs/screenshots/channel-location-sharing-loading.png`: simulated channel chat during lookup.
- `docs/screenshots/channel-location-sharing-message.png`: simulated channel chat showing the corrected message.

## Validation

- `flutter gen-l10n`: passed; both new keys are supplied in all three supported locales.
- `flutter test --no-pub --reporter expanded`: passed, **767 tests**.
- `flutter test --no-pub --update-goldens test/screens/location_sharing_test.dart`: passed, **16 screen tests**, including the final screenshot/font fixture changes; all four screenshots generated and visually inspected.
- `flutter analyze --fatal-infos --fatal-warnings`: passed with no issues. A test-only unnecessary import reported on the first run was removed before the passing run.
- Final strict analysis after screenshot fixture changes: passed with no issues.
- Formatting check of all 10 changed Dart files: passed, zero formatting changes required.
- Local-link check of both updated user guides: passed; all linked local files and screenshots exist.
- Repository-wide `dart format --output=none --set-exit-if-changed .` reports three pre-existing, out-of-scope formatting differences: `lib/screens/scanner_screen.dart`, `lib/utils/browser_detection_stub.dart`, and `lib/utils/browser_detection_web.dart`. These files were not edited. Formatting of the changed Dart files is checked separately.
- Browser execution is **unverified**. On the installed Flutter 3.47.2 SDK, the Chrome runner stalled before executing tests, both inside and outside the sandbox. The same issue occurred with the existing map-link helper test alone. Retrying the targeted service, screen, and map-link tests with `--platform chrome --wasm` successfully generated the WebAssembly module, but execution again stalled at suite loading. These stalled runs were stopped; no browser test pass is claimed. The browser-only cache cases are included for execution with a working browser runner.

Physical node/GPS, Android, and iOS testing was not performed. The added browser tests use simulated geolocation responses rather than querying a real location provider. The four documentation screenshots come from the passing Flutter widget tests with simulated messages.

## Existing edits and compatibility

The pre-existing Spanish `chat_location` edit was retained. The pre-existing status entries for macOS and Windows generated plugin registrants were not edited as part of this change. No dependencies, BLE command/frame formats, radio-location priority, or stored message formats were migrated. Previously sent location messages still open through the existing map-link parser.
