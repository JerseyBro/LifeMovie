import 'package:flutter_test/flutter_test.dart';
import 'package:memory_app/main.dart';

void main() {
  testWidgets('Chinese onboarding explains local-first photo access', (
    tester,
  ) async {
    await tester.pumpWidget(const MemoryApp());
    expect(find.text('发现相册里那些你已经忘记的故事'), findsOneWidget);
    expect(find.text('开始看看'), findsOneWidget);
    expect(find.textContaining('你的照片留在设备里'), findsOneWidget);
  });
}
