@TestOn('browser')
library;

import 'package:conclock/storage/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  test('moves localStorage data over, then holds far more than 5 MB', () async {
    web.window.localStorage.setItem('conclock.data', '{"legacy":true}');
    final s = createStorage();
    expect(await s.read(), '{"legacy":true}');
    expect(web.window.localStorage.getItem('conclock.data'), isNull);

    final big = 'x' * (20 * 1000 * 1000); // 20 MB
    await s.write(big);
    expect((await createStorage().read())!.length, big.length);

    await s.keepCopy('pre-import', null);
    await s.write('{"small":1}');
    expect(await createStorage().read(), '{"small":1}');
  });

  test('other tabs hear about saves', () async {
    final other = createStorage();
    final heard = <String>[];
    other.watch(heard.add);
    await createStorage().write('{"from":"tab 1"}');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(heard, ['{"from":"tab 1"}']);
  });
}
