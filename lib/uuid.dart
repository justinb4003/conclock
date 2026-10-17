import 'dart:math';

/// UUIDv7 ids (RFC 9562): a 48-bit Unix-millisecond timestamp, then random
/// bits, so ids sort by creation time. The 12 bits after the version hold
/// the microseconds within the millisecond (the RFC's "increased clock
/// precision" option), keeping ids made in the same millisecond in order.
///
/// Built from bytes rather than 64-bit ints: on the web, ints are doubles
/// and bitwise operators only see 32 bits.

final _rng = Random.secure();

/// A new UUIDv7 for now.
String newUuid() {
  final micros = DateTime.now().microsecondsSinceEpoch;
  return _uuid7(
    millis: micros ~/ 1000,
    subMillis: micros % 1000,
    random: [for (var i = 0; i < 8; i++) _rng.nextInt(256)],
  );
}

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// Ids from before UUIDs: microseconds since the epoch in base 36 (10
/// digits for 1973–2086), then a random number below 2^30 in base 36.
final _legacyPattern = RegExp(r'^([0-9a-z]{10})([0-9a-z]{1,6})$');

/// [id] as a UUID: UUIDs pass through; ids from older versions convert the
/// same way every time, so references, re-imported backups and other
/// copies of the data all agree. Legacy ids keep their creation time, and
/// so their order.
String toUuid(String id) {
  if (_uuidPattern.hasMatch(id)) return id;
  final legacy = _legacyPattern.firstMatch(id);
  if (legacy != null) {
    final micros = int.parse(legacy[1]!, radix: 36);
    final random = int.parse(legacy[2]!, radix: 36);
    if (random < 1 << 30) {
      return _uuid7(
        millis: micros ~/ 1000,
        subMillis: micros % 1000,
        random: [0, 0, 0, 0, ..._bytes(random, 4)],
      );
    }
  }
  // Anything else (hand-made data): no time to keep, so it sorts first;
  // the rest comes from a hash of the id.
  return _uuid7(millis: 0, subMillis: 0, random: _hash(id));
}

/// Lays out a v7 UUID: [millis] (48 bits), version 7, [subMillis] (12
/// bits), variant 10, then 62 bits from [random] (8 bytes; the top two bits
/// of the first are dropped for the variant).
String _uuid7({
  required int millis,
  required int subMillis,
  required List<int> random,
}) {
  final b = [
    ..._bytes(millis, 6),
    0x70 | (subMillis >> 8 & 0x0f),
    subMillis & 0xff,
    0x80 | (random[0] & 0x3f),
    ...random.skip(1),
  ];
  final hex = [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// [v]'s low [n] bytes, big-endian. Division, not shifts, so values over 32
/// bits work on the web.
List<int> _bytes(int v, int n) {
  final out = List.filled(n, 0);
  for (var i = n - 1; i >= 0; i--) {
    out[i] = v % 256;
    v ~/= 256;
  }
  return out;
}

/// 8 bytes from two 32-bit FNV-1a hashes of [s] (different offsets).
List<int> _hash(String s) {
  int fnv(int h) {
    for (final c in s.codeUnits) {
      h = _mul32(h ^ c, 0x01000193);
    }
    return h;
  }

  return [..._bytes(fnv(0x811c9dc5), 4), ..._bytes(fnv(0x050c5d1f), 4)];
}

/// 32-bit multiply, exact on the web too (like JavaScript's Math.imul).
int _mul32(int a, int b) {
  final lo = (a & 0xffff) * b;
  final hi = ((a >>> 16) * b) & 0xffff;
  return (lo + (hi << 16)) & 0xffffffff;
}
