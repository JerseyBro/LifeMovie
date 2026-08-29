library;

export 'src/media_index.dart';

import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:memory_domain/memory_domain.dart';

enum MediaPermissionStatus {
  notDetermined,
  authorized,
  limited,
  denied,
  restricted,
}

abstract interface class MediaRepository {
  Future<List<MediaAsset>> fetchAssets({int offset = 0, int limit = 100});
  Future<List<MediaAsset>> fetchAssetsByDateRange(DateTimeRange range);
  Future<Uint8List?> loadThumbnail(String assetId, {int size = 320});
  Future<MediaPermissionStatus> getPermissionStatus();
  Future<MediaPermissionStatus> requestPermission();
}

class MockMediaRepository implements MediaRepository {
  MockMediaRepository([List<MediaAsset>? assets])
    : assets = assets ?? _sampleAssets();
  final List<MediaAsset> assets;
  @override
  Future<List<MediaAsset>> fetchAssets({
    int offset = 0,
    int limit = 100,
  }) async => assets.skip(offset).take(limit).toList();
  @override
  Future<List<MediaAsset>> fetchAssetsByDateRange(DateTimeRange range) async =>
      assets
          .where(
            (a) =>
                a.creationDate != null &&
                !a.creationDate!.isBefore(range.start) &&
                !a.creationDate!.isAfter(range.end),
          )
          .toList();
  @override
  Future<Uint8List?> loadThumbnail(String assetId, {int size = 320}) async =>
      null;
  @override
  Future<MediaPermissionStatus> getPermissionStatus() async =>
      MediaPermissionStatus.authorized;
  @override
  Future<MediaPermissionStatus> requestPermission() async =>
      MediaPermissionStatus.authorized;
  static List<MediaAsset> _sampleAssets() => List.generate(
    12,
    (i) => MediaAsset(
      id: 'mock-$i',
      type: MediaType.image,
      creationDate: DateTime(2025, 7, 10 + i ~/ 3),
      width: 1200,
      height: 900,
      isFavorite: i % 4 == 0,
      location: const GeoPoint(31.2304, 121.4737),
    ),
  );
}

class PhotoKitMediaRepository implements MediaRepository {
  PhotoKitMediaRepository({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.lifemovie/media_library');
  final MethodChannel _channel;
  @override
  Future<List<MediaAsset>> fetchAssets({
    int offset = 0,
    int limit = 100,
  }) async => _decodeAssets(
    await _channel.invokeMethod<List<dynamic>>('fetchAssets', {
      'offset': offset,
      'limit': limit,
    }),
  );
  @override
  Future<List<MediaAsset>> fetchAssetsByDateRange(DateTimeRange range) async =>
      _decodeAssets(
        await _channel.invokeMethod<List<dynamic>>('fetchAssetsByDateRange', {
          'start': range.start.toIso8601String(),
          'end': range.end.toIso8601String(),
        }),
      );
  @override
  Future<Uint8List?> loadThumbnail(String assetId, {int size = 320}) async =>
      await _channel.invokeMethod<Uint8List>('loadThumbnail', {
        'id': assetId,
        'size': size,
      });
  @override
  Future<MediaPermissionStatus> getPermissionStatus() async => _mapPermission(
    await _channel.invokeMethod<String>('getPermissionStatus'),
  );
  @override
  Future<MediaPermissionStatus> requestPermission() async =>
      _mapPermission(await _channel.invokeMethod<String>('requestPermission'));
  static MediaPermissionStatus _mapPermission(String? value) => switch (value) {
    'authorized' => MediaPermissionStatus.authorized,
    'limited' => MediaPermissionStatus.limited,
    'denied' => MediaPermissionStatus.denied,
    'restricted' => MediaPermissionStatus.restricted,
    _ => MediaPermissionStatus.notDetermined,
  };
  static List<MediaAsset> _decodeAssets(List<dynamic>? raw) =>
      (raw ?? const []).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return MediaAsset(
          id: m['id'] as String,
          type: MediaType.values.byName(m['type'] as String),
          creationDate: m['creationDate'] == null
              ? null
              : DateTime.parse(m['creationDate'] as String),
          duration: m['durationMs'] == null
              ? null
              : Duration(milliseconds: m['durationMs'] as int),
          width: m['width'] as int?,
          height: m['height'] as int?,
          isFavorite: m['isFavorite'] as bool? ?? false,
          isLivePhoto: m['isLivePhoto'] as bool? ?? false,
          localIdentifier: m['localIdentifier'] as String?,
        );
      }).toList();
}
