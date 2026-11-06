# V3 shared-node proof-of-concept protocol

Status: implementation contract for `Heltec_v3_unifi_shared_ble_us`, protocol 1.
Firmware identification string: `unifi-0.5.0-poc`. This protocol and opcode 112
(`0x70`) are private to this opt-in PoC target, not an upstream MeshCore
extension allocation; audit and obtain an allocation before upstream/release
integration.

## Scope

Two Uni-Fi Android app clients share a V3 node. A second V3 exchanges ordinary
Public-channel messages with it. No PSRAM, GPS, phone-to-phone recovery, gateway
or personal private inboxes. Keep the existing 64-frame legacy queue and add a
separate 128-record RAM journal. Preserve LoRa framing, NUS UUIDs, standard
MeshCore encryption and standard command meanings. Concurrent stock-app sessions
are not supported by this PoC; use the new app for the sharing test.

One node is one MeshCore identity. Phone labels are self-declared text prefixes.
Public is not confidential. Pairing/bonding remains OS-managed with the node PIN;
the app does not contain a universal credential. Pairing is not authorization
to act as an independently authenticated radio user.

## Transport and framing

Existing Nordic UART Service:

- Service: `6e400001-b5a3-f393-e0a9-e50e24dcca9e`.
- Write RX: `6e400002-b5a3-f393-e0a9-e50e24dcca9e`.
- Notify TX: `6e400003-b5a3-f393-e0a9-e50e24dcca9e`.

App requests MTU 185; firmware configures 176. Require negotiated MTU at least
176 for this first PoC rather than silently dropping larger packets. Subscribe
before probing, permit OS pairing time, and use writes with response. Firmware
checks each connection's authentication, notification subscription and payload
budget. A third connection must not disrupt the first two.

All multibyte numbers below are unsigned little endian. Text lengths are UTF-8
bytes, not characters. No trailing NUL. One request is pending per phone;
responses echo operation/request ID and are directed to its connection.

```text
request:  [0x70][0x55][0x46][version=1][operation][request_id:u16][payload...]
response: [0x70][0x55][0x46][version=1][operation][request_id:u16][status][payload...]
```

Request IDs correlate a reply, not a durable idempotency key. Do not retry a
SEND automatically after timeout/disconnect: the message may already be queued.
Legacy asynchronous pushes are not journal replies and must not satisfy a
pending extension request. An unsupported/old target must fail the handshake
clearly, not enter a retry storm.

| Status | Meaning |
| --- | --- |
| 0 | Success |
| 1 | Invalid request/length/text/offset |
| 2 | No such retained record / no new data |
| 3 | Requested sequence overwritten; bounds supplied |
| 4 | Busy / radio submission not accepted |
| 5 | Feature or required Public channel unavailable |
| 6 | Denied |

## Operation 1 — INFO

Request payload: empty.

Success payload in order:

| Field | Bytes |
| --- | ---: |
| Fresh ESP32 hardware-RNG boot nonce | 16 |
| Oldest retained sequence | 4 |
| Newest retained sequence | 4 |
| Journal slot capacity | 2 |
| Public channel slot; 255 if absent | 1 |
| Node public key | 32 |
| Node-name byte length | 1 |
| Node name | 0–32 |

Empty journal reports oldest/newest zero. Sequence starts at 1. Node public
key + boot nonce + sequence uniquely identifies a local observation, not the
original over-the-air message across different radios. The nonce is an identifier,
not proof of authentication. A fresh hardware-RNG nonce is generated at boot and
when the sequence stream resets before wrap.

## Operation 2 — READ

Request payload: `[requested_sequence:u32][text_offset:u8]`.

Success payload:

```text
[sequence:u32][kind:u8][timestamp:u32][channel:u8]
[total_text_length:u8][offset:u8][chunk_length:u8][text_chunk:0..128]
```

Kind 0 means received Public text; kind 1 means locally queued Public text,
including extension SEND and the hardware preset. Text is the complete standard
rendered text, including node-name prefix. For received text, timestamp is the
sender timestamp; for local sends it is the unique timestamp used in the radio
packet. It is metadata, not the cursor. Maximum retained text is 160 bytes.

Request the exact sequence, starting at offset 0. Continue the same sequence at
the next offset until all bytes are assembled, then decode UTF-8 (a chunk can
split a multibyte character). Reject inconsistent metadata, lengths or offsets.
Status 3 supplies `[oldest:u32][newest:u32]`; status 2 means no record. Reads do
not delete or pin a record. Overwrite between fragments must produce an explicit
gap, not mixed data. No private-channel, contact or administrative data exports.

## Operation 3 — SEND

Request payload:

```text
[timestamp:u32][label_length:u8][label:1..16][body:1..80]
```

Reject invalid UTF-8, embedded NUL/control characters and malformed lengths.
Also reject C1 controls, Unicode line/paragraph separators, and bidi override
and isolate characters in labels and bodies to reduce misleading display text.
Render the ordinary group message as `<node name>: [<label>] <body>` and check
the entire rendered text against the existing 160-byte limit. Locate Public by
its standard key, not a presumed slot/name. Never overwrite saved channels.

The radio timestamp is generated uniquely by the node to avoid duplicate radio
message timestamps. On the first valid SEND per boot with a timestamp from 2020
through 2100, the node advances its RTC to that timestamp only if it is not older
than the current node time. Otherwise the existing clock is preserved. This also
handles the V3 platform's synthetic 2024 fallback time. The one-shot initialization
then prevents later phones from changing the node clock. A hardware preset sent
before any phone supplies a plausible timestamp retains the platform clock time.
Extension SENDs and hardware preset sends share a global one-attempt-per-second
limit across connected phones; a throttled request returns status 4.

Success payload: `[local_journal_sequence:u32]`. Success means locally queued,
not delivered or read. Append a kind-1 record; do not synthesize a received
message. The same node's other phone sees this record through its own READs.
Remote nodes receive normal MeshCore group text without this local wrapper.

## Synchronization and storage

Poll INFO approximately once per second while connected and in foreground.
Bound each catch-up burst so sends and radio processing retain time. Read after
that phone's committed cursor, through the observed newest sequence. Persist
the fully assembled record and cursor in one SQLite transaction. Unique record
IDs make repeated downloads idempotent. Display an explicit gap if records
were overwritten. A reboot starts a new stream without deleting saved history.

There is no automatic replay over LoRa. Downloading the same record on two phones
does not cause two transmissions. At capacity the journal overwrites oldest;
power loss clears it. Phone copies survive according to local application data
retention. First V3 implementation uses 32-bit sequences; the broader V4 draft's
64-bit sequence remains a later protocol-version decision.

## Golden example

INFO request with request ID 1:

```text
70 55 46 01 01 01 00
```

READ sequence 1, offset 0, request ID 2:

```text
70 55 46 01 02 02 00 01 00 00 00 00
```

SEND label `A`, body `Hi`, timestamp 1, request ID 3:

```text
70 55 46 01 03 03 00 01 00 00 00 01 41 48 69
```

Hardware qualification must include independent clients with identical request
IDs: replies still belong to the requesting connection, not whichever phone
last connected. Disconnect/reconnect must not deliver a stale reply to a reused
connection ID. See the test guide added with the resulting build artifacts.

## Operations 4 and 5 — node custom message (0.5.0)

GET_PRESET (operation 4) has an empty request payload. SET_PRESET (operation 5)
has a raw UTF-8 request payload of up to 80 bytes; an empty payload clears it.
Success for either returns `[length:u8][UTF-8 body:length]`, with no trailing NUL.
SET succeeds only after the node saves the replacement. Unsupported older
firmware must report the unsupported operation; the app must not fake success.

The single preset is node-owned, so the latest successful overwrite by an
authorized paired connection wins. Saving does not send a radio packet or append
a chat record. Double-tapping the Custom Message page submits the saved body
as ordinary node-originated Public text; triple-tapping that page or Public
submits the original simulated check-in. Normal queue limits and the distinction
between queued and received still apply. The preset survives reboot, unlike the
RAM journal. It is separate from identity/channel settings and contains no key.
