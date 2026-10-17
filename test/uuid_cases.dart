import 'package:conclock/uuid.dart';
import 'package:flutter_test/flutter_test.dart';

/// UUID checks, run on the VM (uuid_test.dart) and in Chrome
/// (web/uuid_web_test.dart), where ints are doubles.
void uuidCases() {
  final shape = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  int millisOf(String uuid) =>
      int.parse(uuid.replaceAll('-', '').substring(0, 12), radix: 16);

  test('new ids are v7 with the current time, in order', () {
    final before = DateTime.now().millisecondsSinceEpoch;
    final ids = [for (var i = 0; i < 200; i++) newUuid()];
    final after = DateTime.now().millisecondsSinceEpoch;
    for (final id in ids) {
      expect(id, matches(shape));
      expect(millisOf(id), inInclusiveRange(before, after));
    }
    expect(ids.toSet().length, ids.length);
  });

  test('legacy ids convert the same way every time, keeping their time', () {
    // A real pre-UUID id: microseconds in base 36, then random.
    const legacy = 'hna4hb9tal6mrfkf';
    final micros = int.parse(legacy.substring(0, 10), radix: 36);
    final uuid = toUuid(legacy);
    expect(uuid, matches(shape));
    expect(toUuid(legacy), uuid);
    expect(millisOf(uuid), micros ~/ 1000);
    // The leftover microseconds sit right after the version digit.
    expect(int.parse(uuid.substring(15, 18), radix: 16), micros % 1000);
    expect(toUuid(uuid), uuid); // UUIDs pass through
  });

  test('legacy ids keep their order', () {
    final older = toUuid('hna4hb9tal6mrfkf');
    final newer = toUuid('hna4hdmr7tmdzpi');
    expect(older.compareTo(newer), lessThan(0));
    expect(toUuid('hna4hb9tal6aaaa'), isNot(older)); // same time, other id
  });

  test('conversions match exactly on every platform', () {
    expect(toUuid('hna4hb9tal6mrfkf'), '01a14756-176f-71f5-8000-000017e7358f');
    expect(toUuid('c1'), '00000000-0000-7000-8829-dfd9ea9725df');
  });

  test('other ids get a stable UUID too', () {
    expect(toUuid('c1'), matches(shape));
    expect(toUuid('c1'), toUuid('c1'));
    expect(toUuid('c1'), isNot(toUuid('c2')));
    expect(millisOf(toUuid('c1')), 0);
  });
}
