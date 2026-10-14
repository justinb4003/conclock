import 'package:conclock/main.dart';
import 'package:conclock/store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'store_test.dart' show FlakyStorage;

void main() {
  testWidgets('a failing save shows a banner until it works', (tester) async {
    final storage = FlakyStorage()..fail = true;
    final store = AppStore(storage: storage);
    await tester.pumpWidget(ConClockApp(store: store));
    store.addClient('Acme');
    await tester.pump(const Duration(milliseconds: 500)); // debounced save
    await tester.pump();
    expect(find.textContaining('Couldn’t save'), findsOneWidget);

    storage.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Couldn’t save'), findsNothing);
    expect(storage.data, contains('Acme'));
  });
}
