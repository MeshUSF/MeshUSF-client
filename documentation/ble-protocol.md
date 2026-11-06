# Shared-node commands

MeshUSF uses the existing Nordic UART service UUIDs but only consumes the UF1
retained Public journal. It does not drain MeshCore's legacy queue. Pairing and
MTU requirements, request IDs and connection-generation protection are inherited
from the tested local prototype; see [UF1 protocol](uf1-protocol.md).

Preset extension (UF1 v1, existing opcode `0x70`):

- operation 4: GET_PRESET, empty request payload.
- operation 5: SET_PRESET, raw UTF-8 body, 0–80 bytes. Empty clears it.
- successful replies: `[length:u8][UTF-8 body]`. A SET success means firmware
  persistence completed, not that a radio message was sent.

The app serializes these commands with INFO/READ/SEND, checks status and reply
length, and rejects stale replies after disconnect/reconnect. No automatic
retry is added. Old firmware can reject operations 4/5; the UI reports this.

No coordinates are exposed by UF1 yet. The Map tab intentionally has no device
markers. Its map tiles use Internet, but chat and presets do not need Internet.
