import 'package:memory_domain/memory_domain.dart';
import 'package:test/test.dart';

void main() {
  test('date range exposes duration without platform types', () {
    final range = DateTimeRange(DateTime(2025), DateTime(2025, 1, 2));
    expect(range.duration.inDays, 1);
  });
}
