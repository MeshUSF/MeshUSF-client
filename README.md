# MeshUSF

MeshUSF is a student-led project developing off-grid emergency communication and coordination tools for the USF Community Emergency Response Team (CERT). It is developed by SCOPE in partnership with ACM at the University of South Florida.

The project uses MeshCore-compatible LoRa radios to support communication without cellular service or Wi-Fi. Development focuses on application reliability, mapping, and incident coordination for emergency-response teams.

## Built on

MeshUSF extends MeshCore Open, an open-source Flutter/Dart client that provides direct and channel messaging, contact management, node maps, and radio configuration.

The application connects to a companion radio over Bluetooth Low Energy (BLE). MeshCore provides the radio firmware and mesh protocol that carry messages over LoRa. The mapping interface uses `flutter_map` and OpenStreetMap-based tiles.

## Implemented work

MeshUSF development so far includes:

- **Bluetooth reliability:** Improved disconnect detection, automatic reconnection, and connection-state handling.
- **Message retries:** Local retry handling for interrupted private messages and retries for pending channel messages after reconnection.
- **Contact and location sharing:** Sharing contacts and locations in direct and channel conversations, with shared locations opening in the built-in map.
- **Map interactions:** Interactive pin selection, information cards, zoom-responsive sizing for highlighted pins and cards, and local pin color controls.

These improvements build on the messaging and mapping features inherited from MeshCore Open.

## Roadmap

MeshUSF is under active development. Upcoming work centers on offline incident planning and team coordination.

| Feature | Status | Planned functionality |
| --- | --- | --- |
| Incident planning and sharing | In progress | Create and save map plans with pins, lines, circles, polygons, labels, and team assignments, then share them over the LoRa mesh. |
| Task assignment | In progress | Assign and manage operational tasks for volunteer teams. |
| Offline routing | Planned | Calculate routes between map locations on the device using local road-network data, with support for waypoints and route adjustments. |
| Polls | Planned | Support group coordination and decision-making. |

The incident-plan transfer design aims to conserve radio bandwidth through compact encoding and packet fragmentation, with recipient acknowledgments and missing-packet recovery. The goal is to let incident managers track which volunteers have received and saved a plan.

Additional capabilities will be guided by CERT operational needs.

## Contributing

Contributions are welcome from USF students and the wider community. To get involved, email [meshusf@gmail.com](mailto:meshusf@gmail.com).

USF students can attend project meetings on **Thursdays from 7 to 9 p.m. in ENG 004**.

Follow the guidelines in [CONTRIBUTING.md](CONTRIBUTING.md), inherited from MeshCore Open, for feature branches, pull requests, implementation reviews, and testing. Open issues and pull requests in the MeshUSF repository.

## Credits and license

MeshUSF builds on the work of the [MeshCore Open](https://github.com/zjs81/meshcore-open) and [MeshCore](https://github.com/meshcore-dev/MeshCore) founders & contributors.

This project is distributed under the [MIT License](LICENSE). The original `Copyright (c) 2025 zjs81` notice and full license terms are preserved in `LICENSE`.
