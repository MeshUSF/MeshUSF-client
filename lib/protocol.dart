import 'dart:convert';
import 'dart:typed_data';

const extensionOpcode = 0x70;
const extensionMagic = [0x55, 0x46, 0x01];

class ProtocolException implements Exception {
  const ProtocolException(this.message);
  final String message;
  @override
  String toString() => message;
}

class UnsupportedFirmwareException implements Exception {
  const UnsupportedFirmwareException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ExtensionResponse {
  const ExtensionResponse(
      {required this.op,
      required this.requestId,
      required this.status,
      required this.payload});
  final int op;
  final int requestId;
  final int status;
  final Uint8List payload;
}

class NodeInfo {
  const NodeInfo(
      {required this.bootNonce,
      required this.oldestSeq,
      required this.newestSeq,
      required this.capacity,
      required this.publicSlot,
      required this.publicKey,
      required this.name});
  final Uint8List bootNonce;
  final int oldestSeq;
  final int newestSeq;
  final int capacity;
  final int publicSlot;
  final Uint8List publicKey;
  final String name;

  factory NodeInfo.decode(Uint8List b) {
    if (b.length < 60) throw const ProtocolException('Short INFO payload');
    final n = b[59];
    if (n > 32 || b.length != 60 + n) {
      throw const ProtocolException('Invalid INFO name length');
    }
    return NodeInfo(
        bootNonce: b.sublist(0, 16),
        oldestSeq: _u32(b, 16),
        newestSeq: _u32(b, 20),
        capacity: _u16(b, 24),
        publicSlot: b[26],
        publicKey: b.sublist(27, 59),
        name: utf8.decode(b.sublist(60), allowMalformed: true));
  }
}

class JournalEntry {
  const JournalEntry(
      {required this.seq,
      required this.kind,
      required this.timestamp,
      required this.channel,
      required this.text});
  final int seq, kind, timestamp, channel;
  final String text;
}

class JournalChunk {
  const JournalChunk(
      {required this.seq,
      required this.kind,
      required this.timestamp,
      required this.channel,
      required this.totalLength,
      required this.offset,
      required this.data});
  final int seq, kind, timestamp, channel, totalLength, offset;
  final Uint8List data;
}

class JournalGap {
  const JournalGap(this.oldest, this.newest);
  final int oldest, newest;
  factory JournalGap.decode(Uint8List b) {
    if (b.length != 8) {
      throw const ProtocolException('Invalid GAP payload length');
    }
    final gap = JournalGap(_u32(b, 0), _u32(b, 4));
    if (gap.oldest == 0 || gap.newest < gap.oldest) {
      throw const ProtocolException('Invalid GAP bounds');
    }
    return gap;
  }
}

class JournalAssembler {
  JournalAssembler(this.expectedSeq);
  final int expectedSeq;
  final BytesBuilder _bytes = BytesBuilder(copy: false);
  int? _total, _kind, _timestamp, _channel;
  int _offset = 0;
  int get receivedBytes => _offset;
  bool get isComplete => _total != null && _offset == _total;

  void add(JournalChunk c) {
    if (c.seq != expectedSeq || c.offset != _offset) {
      throw const ProtocolException('Unexpected READ sequence or offset');
    }
    if (_total == null) {
      _total = c.totalLength;
      _kind = c.kind;
      _timestamp = c.timestamp;
      _channel = c.channel;
    }
    if (c.totalLength != _total ||
        c.kind != _kind ||
        c.timestamp != _timestamp ||
        c.channel != _channel ||
        c.offset + c.data.length > _total!) {
      throw const ProtocolException('Inconsistent READ chunks');
    }
    if (c.data.isEmpty && !(_total == 0 && _offset == 0)) {
      throw const ProtocolException('Empty READ fragment');
    }
    _bytes.add(c.data);
    _offset += c.data.length;
  }

  JournalEntry finish() {
    if (!isComplete) throw const ProtocolException('READ entry is incomplete');
    return JournalEntry(
        seq: expectedSeq,
        kind: _kind!,
        timestamp: _timestamp!,
        channel: _channel!,
        text: utf8.decode(_bytes.takeBytes()));
  }
}

Uint8List encodeRequest(int op, int requestId,
        [List<int> payload = const []]) =>
    Uint8List.fromList([
      extensionOpcode,
      ...extensionMagic,
      op,
      requestId & 255,
      (requestId >> 8) & 255,
      ...payload,
    ]);

ExtensionResponse decodeResponse(List<int> bytes) {
  if (bytes.length < 8 ||
      bytes[0] != extensionOpcode ||
      bytes[1] != 0x55 ||
      bytes[2] != 0x46 ||
      bytes[3] != 1) {
    throw const ProtocolException('Not a UF1 response');
  }
  return ExtensionResponse(
      op: bytes[4],
      requestId: bytes[5] | bytes[6] << 8,
      status: bytes[7],
      payload: Uint8List.fromList(bytes.sublist(8)));
}

JournalChunk decodeJournalChunk(Uint8List b) {
  if (b.length < 13) throw const ProtocolException('Short READ payload');
  final totalLength = b[10], offset = b[11], chunkLength = b[12];
  if ((b[4] != 0 && b[4] != 1) ||
      totalLength > 160 ||
      chunkLength > 128 ||
      b.length != 13 + chunkLength ||
      offset + chunkLength > totalLength) {
    throw const ProtocolException('Invalid READ chunk');
  }
  return JournalChunk(
      seq: _u32(b, 0),
      kind: b[4],
      timestamp: _u32(b, 5),
      channel: b[9],
      totalLength: totalLength,
      offset: offset,
      data: Uint8List.fromList(b.sublist(13)));
}

Uint8List readRequestPayload(int seq, int offset) => Uint8List.fromList([
      seq & 255,
      seq >> 8 & 255,
      seq >> 16 & 255,
      seq >> 24 & 255,
      offset & 255
    ]);

int utf8Length(String value) => utf8.encode(value).length;
bool _hasControl(String value) => value.runes.any((c) =>
    c < 0x20 ||
    (c >= 0x7f && c <= 0x9f) ||
    c == 0x2028 ||
    c == 0x2029 ||
    (c >= 0x202a && c <= 0x202e) ||
    (c >= 0x2066 && c <= 0x2069));
bool validUsername(String value) =>
    value.trim().isNotEmpty && utf8Length(value) <= 16 && !_hasControl(value);
bool validBody(String value) =>
    value.trim().isNotEmpty && utf8Length(value) <= 80 && !_hasControl(value);

int _u16(List<int> b, int i) => b[i] | b[i + 1] << 8;
int _u32(List<int> b, int i) =>
    (b[i] | b[i + 1] << 8 | b[i + 2] << 16 | b[i + 3] << 24) >>> 0;
