library;

import 'package:flutter/services.dart';
import 'package:memory_domain/memory_domain.dart';

enum MediaPermissionStatus {
  notDetermined,
  authorized,
  limited,
  denied,
  restricted,
}

enum MediaTypeFilter { all, photo, video }

extension MediaTypeFilterValue on MediaTypeFilter {
  String get platformValue => switch (this) {
    MediaTypeFilter.all => 'all',
    MediaTypeFilter.photo => 'photo',
    MediaTypeFilter.video => 'video',
  };

  bool matches(MediaAsset asset) => switch (this) {
    MediaTypeFilter.all => true,
    MediaTypeFilter.photo =>
      asset.type == MediaType.image || asset.type == MediaType.livePhoto,
    MediaTypeFilter.video => asset.type == MediaType.video,
  };
}

class MediaFailure implements Exception {
  const MediaFailure(this.code, this.message, [this.cause]);
  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'MediaFailure($code): $message';
}

class PermissionFailure extends MediaFailure {
  const PermissionFailure(super.code, super.message, [super.cause]);
}

abstract interface class MediaRepository {
  Future<List<MediaAsset>> fetchAssets({
    int offset = 0,
    int limit = 200,
    MediaTypeFilter filter = MediaTypeFilter.all,
  });

  Future<List<MediaAsset>> fetchAssetsByDateRange(
    DateTimeRange range, {
    MediaTypeFilter filter = MediaTypeFilter.all,
    int offset = 0,
    int limit = 500,
  });

  Future<Uint8List?> loadThumbnail(
    String assetId, {
    int size = 320,
    String? requestId,
  });

  Future<void> cancelThumbnailRequest(String requestId);
  Future<MediaPermissionStatus> presentLimitedLibraryPicker();
  Future<MediaPermissionStatus> getPermissionStatus();
  Future<MediaPermissionStatus> requestPermission();
}

class MockMediaRepository implements MediaRepository {
  MockMediaRepository([
    List<MediaAsset>? assets,
    this.permissionStatus = MediaPermissionStatus.authorized,
    Map<String, Uint8List>? thumbnails,
  ]) : assets = assets ?? sampleAssets(),
       thumbnails = thumbnails ?? const {};

  final List<MediaAsset> assets;
  MediaPermissionStatus permissionStatus;
  final Map<String, Uint8List> thumbnails;

  @override
  Future<List<MediaAsset>> fetchAssets({
    int offset = 0,
    int limit = 200,
    MediaTypeFilter filter = MediaTypeFilter.all,
  }) async => assets
      .where(filter.matches)
      .skip(offset)
      .take(limit)
      .toList(growable: false);

  @override
  Future<List<MediaAsset>> fetchAssetsByDateRange(
    DateTimeRange range, {
    MediaTypeFilter filter = MediaTypeFilter.all,
    int offset = 0,
    int limit = 500,
  }) async => assets
      .where(filter.matches)
      .where(
        (a) =>
            a.creationDate != null &&
            !a.creationDate!.isBefore(range.start) &&
            !a.creationDate!.isAfter(range.end),
      )
      .skip(offset)
      .take(limit)
      .toList(growable: false);

  @override
  Future<Uint8List?> loadThumbnail(
    String assetId, {
    int size = 320,
    String? requestId,
  }) async => thumbnails[assetId];

  @override
  Future<void> cancelThumbnailRequest(String requestId) async {}

  @override
  Future<MediaPermissionStatus> presentLimitedLibraryPicker() async =>
      permissionStatus;

  @override
  Future<MediaPermissionStatus> getPermissionStatus() async => permissionStatus;

  @override
  Future<MediaPermissionStatus> requestPermission() async => permissionStatus;

  static List<MediaAsset> sampleAssets({int count = 12}) => List.generate(
    count,
    (i) => MediaAsset(
      id: 'mock-$i',
      type: i % 5 == 0 ? MediaType.video : MediaType.image,
      creationDate: DateTime(2025, 7, 10 + i ~/ 3),
      modificationDate: DateTime(2025, 7, 10 + i ~/ 3, 12),
      duration: i % 5 == 0 ? const Duration(seconds: 18) : null,
      width: 1200,
      height: 900,
      isFavorite: i % 4 == 0,
      location: const GeoPoint(31.2304, 121.4737),
      localIdentifier: 'mock-$i',
      personIds: i % 4 == 0 ? const ['person-a'] : const [],
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
    int limit = 200,
    MediaTypeFilter filter = MediaTypeFilter.all,
  }) async => _decodeAssets(
    await _invoke<List<dynamic>>('fetchAssets', {
      'offset': offset,
      'limit': limit,
      'filter': filter.platformValue,
    }),
  );

  @override
  Future<List<MediaAsset>> fetchAssetsByDateRange(
    DateTimeRange range, {
    MediaTypeFilter filter = MediaTypeFilter.all,
    int offset = 0,
    int limit = 500,
  }) async => _decodeAssets(
    await _invoke<List<dynamic>>('fetchAssetsByDateRange', {
      'start': range.start.toIso8601String(),
      'end': range.end.toIso8601String(),
      'filter': filter.platformValue,
      'offset': offset,
      'limit': limit,
    }),
  );

  @override
  Future<Uint8List?> loadThumbnail(
    String assetId, {
    int size = 320,
    String? requestId,
  }) async => _invoke<Uint8List>('loadThumbnail', {
    'id': assetId,
    'size': size,
    'requestId': requestId,
  });

  @override
  Future<void> cancelThumbnailRequest(String requestId) async {
    await _invoke<void>('cancelThumbnailRequest', {'requestId': requestId});
  }

  @override
  Future<MediaPermissionStatus> presentLimitedLibraryPicker() async =>
      mapPermission(await _invoke<String>('presentLimitedLibraryPicker'));

  @override
  Future<MediaPermissionStatus> getPermissionStatus() async =>
      mapPermission(await _invoke<String>('getPermissionStatus'));

  @override
  Future<MediaPermissionStatus> requestPermission() async =>
      mapPermission(await _invoke<String>('requestPermission'));

  static MediaPermissionStatus mapPermission(String? value) => switch (value) {
    'authorized' => MediaPermissionStatus.authorized,
    'limited' => MediaPermissionStatus.limited,
    'denied' => MediaPermissionStatus.denied,
    'restricted' => MediaPermissionStatus.restricted,
    _ => MediaPermissionStatus.notDetermined,
  };

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      throw MediaFailure(error.code, error.message ?? method, error);
    } on MissingPluginException catch (error) {
      throw MediaFailure('missing_plugin', method, error);
    }
  }

  static List<MediaAsset> decodeAssets(List<dynamic>? raw) => (raw ?? const [])
      .map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final localIdentifier =
            m['localIdentifier'] as String? ?? m['id'] as String;
        final isLivePhoto = m['isLivePhoto'] as bool? ?? false;
        return MediaAsset(
          id: localIdentifier,
          localIdentifier: localIdentifier,
          type: _mapMediaType(m['type'] as String?, isLivePhoto),
          creationDate: _parseDate(m['creationDate']),
          modificationDate: _parseDate(m['modificationDate']),
          duration: m['durationMs'] == null
              ? null
              : Duration(milliseconds: m['durationMs'] as int),
          width: m['width'] as int?,
          height: m['height'] as int?,
          location: _parseLocation(m),
          isFavorite: m['isFavorite'] as bool? ?? false,
          isLivePhoto: isLivePhoto,
          personIds: (m['personIds'] as List<dynamic>? ?? const [])
              .cast<String>()
              .toList(growable: false),
        );
      })
      .toList(growable: false);

  static List<MediaAsset> _decodeAssets(List<dynamic>? raw) =>
      decodeAssets(raw);

  static MediaType _mapMediaType(String? value, bool isLivePhoto) {
    if (isLivePhoto || value == 'livePhoto') return MediaType.livePhoto;
    return switch (value) {
      'video' => MediaType.video,
      'audio' => MediaType.audio,
      _ => MediaType.image,
    };
  }

  static DateTime? _parseDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  static GeoPoint? _parseLocation(Map<String, dynamic> map) {
    final latitude = (map['latitude'] as num?)?.toDouble();
    final longitude = (map['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return null;
    return GeoPoint(latitude, longitude);
  }
}
