import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../lib/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Barakah launches without crashing', (tester) async {
    app.main();

    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(tester.takeException(), isNull);
  });
}
