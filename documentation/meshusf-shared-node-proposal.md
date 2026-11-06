# MeshUSF shared-node integration proposal

This proposal does not enable new runtime functionality in the existing full
client. Its navigation, settings and radio behavior remain unchanged.

## Separate prototype

The focused MeshUSF prototype supports two phones using a node's 128-record
Public-message journal. Downloads do not delete records; each phone stores an
independent cursor and local history. Capacity overwrites oldest records and a
node reboot clears its RAM journal. A separate persistent custom-message slot
can be read or overwritten by a paired phone and sent with a hardware double-tap.

The prototype uses INFO/READ/SEND/GET_PRESET/SET_PRESET in an opt-in UF1 envelope
over the existing Nordic UART UUIDs. Opcode `0x70` is experimental, not an
upstream allocation. Standard MeshCore radio framing and cryptography stay the
same. Phone labels are not verified identities and Public is not confidential.
Queued acceptance does not prove remote receipt. Initial OS pairing/PIN remains.

Its focused Flutter app has Dashboard, Public, Map and Device sections. The map
is an interactive foundation, not live GPS tracking. The app adapts the theme
and fonts from John Badr's MeshUSF-client revision
`f9edcecb6a91e9a26df1cc31cecf53894a8874bb` and the separate Uni-Fi prototype's
transport. It is not a feature-complete replacement for this full client.

## Gates before integration into the full client

1. Agree on an extension allocation and capability negotiation. Ordinary
   firmware must keep working; unsupported extensions must fail clearly.
2. Keep one connection owner. Do not run a legacy destructive queue consumer
   beside a shared-history reader. Retain per-request/session reply checks.
3. Reconcile this client's 172-byte frame cap with the prototype's MTU >=176
   requirement without silently increasing frames or truncating content.
4. Adapt history to the existing models, screens and localization. Show gaps
   and distinguish a new node boot from old sequence numbers.
5. Test pairing, reconnects, two phones sharing one node, separate radio receipt
   and custom-message overwrite/clear/reboot persistence on physical devices.

The focused app has 20 passing Flutter tests, clean analysis and buildable
Android APKs with prototype signing. Firmware builds and host checks pass.
Earlier multi-phone and node-to-node success is user-reported; the new app and
preset workflow still need device acceptance. These results do not prove the
full client's compatibility with a future integration.

Internet routing is a separate one-way USB-host experiment. No mobile Internet
gateway, background relay or two-way Internet route is enabled by this proposal.
