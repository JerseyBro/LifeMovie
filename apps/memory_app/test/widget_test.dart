import 'package:flutter_test/flutter_test.dart';
import 'package:memory_app/main.dart';

void main() {
  testWidgets('onboarding explains local-first photo access', (tester) async {
    await tester.pumpWidget(const MemoryApp());
    expect(
      find.text('Rediscover the stories already in your photos.'),
      findsOneWidget,
    );
  });
}
