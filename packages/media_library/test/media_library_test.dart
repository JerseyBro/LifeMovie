import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_domain/memory_domain.dart';
import 'package:test/test.dart';

void main() {
  test('permission mapping covers every PhotoKit status', () {
    expect(
      PhotoKitMediaRepository.mapPermission('notDetermined'),
      MediaPermissionStatus.notDetermined,
    );
    expect(
      PhotoKitMediaRepository.mapPermission('authorized'),
      MediaPermissionStatus.authorized,
    );
    expect(
      PhotoKitMediaRepository.mapPermission('limited'),
      MediaPermissionStatus.limited,
    );
    expect(
      PhotoKitMediaRepository.mapPermission('denied'),
      MediaPermissionStatus.denied,
    );
    expect(
      PhotoKitMediaRepository.mapPermission('restricted'),
      MediaPermissionStatus.restricted,
    );
  });

  test(
    'PhotoKit payload maps photo, video, live photo, dates and location',
    () {
      final assets = PhotoKitMediaRepository.decodeAssets([
        {
          'localIdentifier': 'a',
          'type': 'image',
          'creationDate': '2026-08-01T00:00:00.000Z',
          'modificationDate': '2026-08-02T00:00:00.000Z',
          'width': 100,
          'height': 80,
          'latitude': 22.54,
          'longitude': 114.05,
          'isFavorite': true,
          'isLivePhoto': false,
        },
        {
          'localIdentifier': 'b',
          'type': 'video',
          'durationMs': 1200,
          'isLivePhoto': false,
        },
        {'localIdentifier': 'c', 'type': 'livePhoto', 'isLivePhoto': true},
      ]);

      expect(assets.map((a) => a.type), [
        MediaType.image,
        MediaType.video,
        MediaType.livePhoto,
      ]);
      expect(assets.first.location?.latitude, 22.54);
      expect(assets.first.isFavorite, isTrue);
      expect(assets.first.modificationDate, DateTime.utc(2026, 8, 2));
      expect(assets[1].duration, const Duration(milliseconds: 1200));
    },
  );

  test(
    'mock repository supports pagination, date range and media filter',
    () async {
      final repository = MockMediaRepository(_syntheticAssets(12));
      expect(await repository.fetchAssets(offset: 0, limit: 5), hasLength(5));
      expect(
        await repository.fetchAssets(filter: MediaTypeFilter.video),
        everyElement((MediaAsset asset) => asset.type == MediaType.video),
      );
      final ranged = await repository.fetchAssetsByDateRange(
        DateTimeRange(DateTime(2026, 1, 3), DateTime(2026, 1, 5)),
      );
      expect(ranged.map((a) => a.creationDate?.day), [3, 4, 5]);
    },
  );

  test(
    'PhotoKit thumbnail request contract supports request id and cancel',
    () async {
      final channel = _RecordingChannel();
      final repository = PhotoKitMediaRepository(channel: channel);
      await repository.loadThumbnail(
        'asset-1',
        size: 180,
        requestId: 'thumb-1',
      );
      await repository.cancelThumbnailRequest('thumb-1');
      expect(channel.calls.first.method, 'loadThumbnail');
      expect(channel.calls.first.arguments['size'], 180);
      expect(channel.calls.first.arguments['requestId'], 'thumb-1');
      expect(channel.calls.last.method, 'cancelThumbnailRequest');
    },
  );

  test('persistent index inserts, upserts, queries and reopens', () async {
    final dir = await Directory.systemTemp.createTemp('lifemovie-index-');
    final path = '${dir.path}/media.sqlite';
    final first = PersistentMediaIndex.fromExecutor(NativeDatabase(File(path)));
    await first.upsertAssets(_syntheticAssets(6));
    await first.upsertAssets([
      MediaAsset(
        id: 'asset-1',
        localIdentifier: 'asset-1',
        type: MediaType.video,
        creationDate: DateTime(2026, 1, 2),
        isFavorite: true,
      ),
    ]);
    expect(await first.count(), 6);
    expect(await first.byType(MediaType.video), isNotEmpty);
    expect(await first.favorites(), hasLength(2));
    expect(
      await first.byCoarsePlace(const GeoPoint(22.54, 114.05)),
      isNotEmpty,
    );
    expect(await first.schemaVersion(), 1);
    await first.close();

    final reopened = PersistentMediaIndex.fromExecutor(
      NativeDatabase(File(path)),
    );
    expect(await reopened.count(), 6);
    await reopened.close();
  });

  test('reconciliation handles new, modified and removed assets', () async {
    final index = PersistentMediaIndex.memory();
    final repository = MockMediaRepository(_syntheticAssets(5));
    final first = await index.reconcile(repository, batchSize: 2);
    expect(first.inserted, 5);

    repository.assets
      ..removeWhere((asset) => asset.id == 'asset-0')
      ..add(
        MediaAsset(
          id: 'asset-99',
          localIdentifier: 'asset-99',
          type: MediaType.image,
          creationDate: DateTime(2026, 1, 9),
        ),
      );
    final second = await index.reconcile(repository, batchSize: 2);
    expect(second.deleted, 1);
    expect(second.inserted, 1);
    expect(await index.count(), 5);
    await index.close();
  });

  test('reconciliation can cancel and records checkpoint status', () async {
    final token = ScanCancellationToken()..cancel();
    final index = PersistentMediaIndex.memory();
    final result = await index.reconcile(
      MockMediaRepository(_syntheticAssets(20)),
      cancellationToken: token,
    );
    expect(result.cancelled, isTrue);
    expect(await index.scanStatus(), 'cancelled');
    await index.close();
  });

  test('interrupted scan can be repaired by the next reconciliation', () async {
    final token = ScanCancellationToken();
    final index = PersistentMediaIndex.memory();
    final repository = MockMediaRepository(_syntheticAssets(12));
    final interrupted = await index.reconcile(
      repository,
      batchSize: 4,
      cancellationToken: token,
      onProgress: (_) => token.cancel(),
    );
    expect(interrupted.cancelled, isTrue);
    expect(await index.count(), 4);

    final repaired = await index.reconcile(repository, batchSize: 4);
    expect(repaired.cancelled, isFalse);
    expect(await index.count(), 12);
    expect(await index.scanStatus(), 'completed');
    await index.close();
  });

  test('permission failure is reported without corrupting index', () async {
    final index = PersistentMediaIndex.memory();
    final result = await index.reconcile(_FailingRepository());
    expect(result.failure?.code, 'permission_denied');
    expect(await index.scanStatus(), 'failed');
    expect(await index.count(), 0);
    await index.close();
  });

  test(
    'allAssetsPaged returns full dataset beyond 50K without silent truncation',
    () async {
      final index = PersistentMediaIndex.memory();
      final assets = _syntheticAssets(50001);
      await index.upsertAssets(assets);
      expect(await index.count(), 50001);
      final viaPaged = await index.allAssetsPaged(batchSize: 10000);
      expect(viaPaged.length, 50001);
      final viaLimitAll = await index.allAssets(limit: null);
      expect(viaLimitAll.length, 50001);
      // Ensure old limit 50000 would truncate but paged does not
      final truncated = await index.allAssets(limit: 50000);
      expect(truncated.length, 50000);
      expect(truncated.length, lessThan(viaPaged.length));
      await index.close();
    },
  );

  test('60K library paged read smoke', () async {
    final index = PersistentMediaIndex.memory();
    final assets = _syntheticAssets(60000);
    await index.upsertAssets(assets);
    expect(await index.count(), 60000);
    final paged = await index.allAssetsPaged(batchSize: 15000);
    expect(paged.length, 60000);
    await index.close();
  });
}

List<MediaAsset> _syntheticAssets(int count) => List.generate(count, (i) {
  final isVideo = i % 5 == 0;
  return MediaAsset(
    id: 'asset-$i',
    localIdentifier: 'asset-$i',
    type: isVideo ? MediaType.video : MediaType.image,
    creationDate: DateTime(2026, 1, 1 + i),
    modificationDate: DateTime(2026, 1, 1 + i, 12),
    duration: isVideo ? const Duration(seconds: 12) : null,
    width: 1200,
    height: 900,
    location: i.isEven ? const GeoPoint(22.54, 114.05) : null,
    isFavorite: i == 0 || i == 1,
    isLivePhoto: false,
  );
});

class _RecordingChannel extends MethodChannel {
  _RecordingChannel() : super('test');
  final calls = <({String method, Map<String, dynamic> arguments})>[];

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    calls.add((
      method: method,
      arguments: Map<String, dynamic>.from(arguments as Map),
    ));
    return Uint8List(0) as T?;
  }
}

class _FailingRepository implements MediaRepository {
  @override
  Future<void> cancelThumbnailRequest(String requestId) async {}

  @override
  Future<List<MediaAsset>> fetchAssets({
    int offset = 0,
    int limit = 200,
    MediaTypeFilter filter = MediaTypeFilter.all,
  }) async {
    throw const PermissionFailure('permission_denied', 'Photo access denied');
  }

  @override
  Future<List<MediaAsset>> fetchAssetsByDateRange(
    DateTimeRange range, {
    MediaTypeFilter filter = MediaTypeFilter.all,
    int offset = 0,
    int limit = 500,
  }) async => const [];

  @override
  Future<MediaPermissionStatus> getPermissionStatus() async =>
      MediaPermissionStatus.denied;

  @override
  Future<Uint8List?> loadThumbnail(
    String assetId, {
    int size = 320,
    String? requestId,
  }) async => null;

  @override
  Future<MediaPermissionStatus> presentLimitedLibraryPicker() async =>
      MediaPermissionStatus.denied;

  @override
  Future<MediaPermissionStatus> requestPermission() async =>
      MediaPermissionStatus.denied;
}
