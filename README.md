# MeshUSF

## Experimental standalone branch

This branch publishes the focused shared-node prototype for review. It has an
independent root history and is **not a merge-ready replacement** for the full
client on `dev`. No files or runtime behavior on `dev` are changed by publishing
this branch. Integration must be ported in small reviewed patches after the
extension and compatibility questions in the documentation proposal are agreed.

Firmware requirement: Heltec V3 `unifi-0.5.0-poc` with UF1 support. Exact wire
rules are in [the protocol reference](documentation/uf1-protocol.md). Source
origin: `MESH-USF/Uni-Fi`, client snapshot from commit `286ee70`.

The official focused MeshUSF Android client. Its visual theme and fonts are
adapted from https://github.com/MeshUSF/MeshUSF-client at
`f9edcecb6a91e9a26df1cc31cecf53894a8874bb` (MeshCore Open lineage).
The original theme is in `lib/theme/mesh_theme.dart`; upstream license and font
licenses are retained. This is a curated integration, not the entire upstream
application or a claim to support all of its features.

Dashboard, Public chat, Map and Device are the only sections. The app exclusively
uses UF1 shared-history Bluetooth commands; it does not run a legacy destructive
queue consumer alongside them. The transport and transactional SQLite journal
come from the tested `mobile/` prototype.

The map is an actual interactive map, but there are no live node locations yet.
Map tiles need Internet. No fake GPS positions or inferred node positions are
displayed. Opening a map is not an Internet radio bridge.

The Device screen can read/save/clear one node-owned preset (80 UTF-8 bytes).
It requires preset-capable firmware; an older node rejecting the command is
reported as an error, not treated as success. Double-tap on the firmware Custom
page sends it; triple-tap keeps the old check-in behavior.

Build: `flutter pub get`, `flutter test`, `flutter analyze`,
`flutter build apk --release --split-per-abi`. APK signing is test-only, not a
production distribution key. Android pairing/PIN is still needed. Public text
is not confidential; queued is not remote delivery. Hardware acceptance is needed.

The Android application ID remains `org.meshusf.unifi_poc`, with the same local
prototype signing setup and database name, so a matching-key upgrade preserves
the earlier app's history. Build number 10000 exceeds the previous ABI split
version codes. Do not uninstall merely to update a matching-key installation.

Linux tests use SQLite FFI and require the system SQLite shared library. The
SQLite test and path-provider dependencies are pinned to avoid native build-hook
tooling that writes outside restricted build directories. These are tooling
choices, not changes to the radio protocol.
