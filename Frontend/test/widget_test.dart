import 'package:flutter_test/flutter_test.dart';
import 'package:liftoff_auth_test/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LiftOffApp());
    // Verify the app renders without crashing
    expect(find.byType(LiftOffApp), findsOneWidget);
  });
}
