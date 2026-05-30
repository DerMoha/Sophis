import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sophis/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('launched the app and rendered the home shell', (
    WidgetTester tester,
  ) async {
    app.main();

    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Sophis'), findsWidgets);
    expect(find.text('Today'), findsWidgets);
  });
}
