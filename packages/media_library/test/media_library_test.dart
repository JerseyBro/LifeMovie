import 'package:media_library/media_library.dart';
import 'package:memory_domain/memory_domain.dart';
import 'package:flutter/services.dart';
import 'package:test/test.dart';

void main() {
  test(
    'mock repository is pageable and index rebuilds without loading all thumbnails',
    () async {
      final repository = MockMediaRepository(
        List.generate(205, (i) => MediaAsset(id: '$i', type: MediaType.image)),
      );
      final index = MediaIndex();
      await index.rebuild(repository);
      expect(index.assets, hasLength(205));
      expect(await repository.loadThumbnail('1'), isNull);
    },
  );
  test('unknown platform permission maps to notDetermined', () async {
    final repository = PhotoKitMediaRepository(channel: _FakeChannel());
    expect(
      await repository.getPermissionStatus(),
      MediaPermissionStatus.notDetermined,
    );
  });
}

class _FakeChannel extends MethodChannel {
  _FakeChannel() : super('test');
  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async =>
      'unknown' as T?;
}
