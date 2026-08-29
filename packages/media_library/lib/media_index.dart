library;

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:memory_domain/memory_domain.dart';

import 'media_repository.dart';

class IndexFailure implements Exception {
  const IndexFailure(this.code, this.message, [this.cause]);
  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'IndexFailure($code): $message';
}

class ScanCancellationToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

class IndexProgress {
  const IndexProgress({required this.scanned, required this.indexed});
  final int scanned;
  final int indexed;
}

class IndexReconciliationResult {
  const IndexReconciliationResult({
    required this.scanned,
    required this.inserted,
    required this.updated,
    required this.deleted,
    this.cancelled = false,
    this.failure,
  });

  final int scanned;
  final int inserted;
  final int updated;
  final int deleted;
  final bool cancelled;
  final MediaFailure? failure;
}

class MediaIndexStats {
  const MediaIndexStats({
    required this.total,
    required this.photos,
    required this.videos,
    required this.livePhotos,
    required this.favorites,
    required this.placeClusterCount,
  });

  final int total;
  final int photos;
  final int videos;
  final int livePhotos;
  final int favorites;
  final int placeClusterCount;
}

class DateDistributionBucket {
  const DateDistributionBucket({required this.month, required this.count});
  final String month;
  final int count;
}

class MediaIndex {
  final List<MediaAsset> _assets = [];
  List<MediaAsset> get assets => List.unmodifiable(_assets);

  Future<void> rebuild(
    MediaRepository repository, {
    int batchSize = 200,
    MediaTypeFilter filter = MediaTypeFilter.all,
    ScanCancellationToken? cancellationToken,
  }) async {
    _assets.clear();
    var offset = 0;
    while (true) {
      if (cancellationToken?.isCancelled ?? false) return;
      final page = await repository.fetchAssets(
        offset: offset,
        limit: batchSize,
        filter: filter,
      );
      _assets.addAll(page);
      if (page.length < batchSize) break;
      offset += page.length;
    }
  }

  Future<IndexReconciliationResult> reconcile(
    MediaRepository repository, {
    int batchSize = 200,
    MediaTypeFilter filter = MediaTypeFilter.all,
    ScanCancellationToken? cancellationToken,
    void Function(IndexProgress progress)? onProgress,
  }) async {
    await rebuild(
      repository,
      batchSize: batchSize,
      filter: filter,
      cancellationToken: cancellationToken,
    );
    onProgress?.call(
      IndexProgress(scanned: _assets.length, indexed: _assets.length),
    );
    return IndexReconciliationResult(
      scanned: _assets.length,
      inserted: _assets.length,
      updated: 0,
      deleted: 0,
      cancelled: cancellationToken?.isCancelled ?? false,
    );
  }

  List<MediaAsset> byDateRange(DateTimeRange range) => _assets
      .where(
        (a) =>
            a.creationDate != null &&
            !a.creationDate!.isBefore(range.start) &&
            !a.creationDate!.isAfter(range.end),
      )
      .toList(growable: false);

  List<MediaAsset> byType(MediaType type) =>
      _assets.where((a) => a.type == type).toList(growable: false);

  List<MediaAsset> favorites() =>
      _assets.where((a) => a.isFavorite).toList(growable: false);
}

class PersistentMediaIndex {
  PersistentMediaIndex._(this._database);

  factory PersistentMediaIndex.fromExecutor(QueryExecutor executor) =>
      PersistentMediaIndex._(_MediaIndexDatabase(executor));

  factory PersistentMediaIndex.appDatabase({
    String name = 'lifemovie_media_index',
  }) => PersistentMediaIndex._(
    _MediaIndexDatabase.connect(driftDatabase(name: name)),
  );

  factory PersistentMediaIndex.memory() =>
      PersistentMediaIndex._(_MediaIndexDatabase(NativeDatabase.memory()));

  final _MediaIndexDatabase _database;

  Future<void> initialize() async {
    await _database.customSelect('SELECT 1').get();
  }

  Future<void> close() => _database.close();

  Future<List<MediaAsset>> allAssets({int limit = 500, int offset = 0}) async {
    await initialize();
    final rows = await _database
        .customSelect(
          'SELECT * FROM media_assets ORDER BY creation_date_ms ASC LIMIT ? OFFSET ?',
          variables: [Variable.withInt(limit), Variable.withInt(offset)],
        )
        .get();
    return rows.map(_assetFromRow).toList(growable: false);
  }

  Future<List<MediaAsset>> byDateRange(
    DateTimeRange range, {
    MediaTypeFilter filter = MediaTypeFilter.all,
    int limit = 1000,
  }) async {
    await initialize();
    final filterSql = _filterSql(filter);
    final rows = await _database
        .customSelect(
          '''
SELECT * FROM media_assets
WHERE creation_date_ms >= ? AND creation_date_ms <= ? $filterSql
ORDER BY creation_date_ms ASC
LIMIT ?
''',
          variables: [
            Variable.withInt(_toMs(range.start)!),
            Variable.withInt(_toMs(range.end)!),
            Variable.withInt(limit),
          ],
        )
        .get();
    return rows.map(_assetFromRow).toList(growable: false);
  }

  Future<List<MediaAsset>> byType(MediaType type, {int limit = 1000}) async {
    await initialize();
    final rows = await _database
        .customSelect(
          'SELECT * FROM media_assets WHERE media_type = ? ORDER BY creation_date_ms ASC LIMIT ?',
          variables: [Variable.withString(type.name), Variable.withInt(limit)],
        )
        .get();
    return rows.map(_assetFromRow).toList(growable: false);
  }

  Future<List<MediaAsset>> favorites({int limit = 1000}) async {
    await initialize();
    final rows = await _database
        .customSelect(
          'SELECT * FROM media_assets WHERE favorite = 1 ORDER BY creation_date_ms ASC LIMIT ?',
          variables: [Variable.withInt(limit)],
        )
        .get();
    return rows.map(_assetFromRow).toList(growable: false);
  }

  Future<List<MediaAsset>> byCoarsePlace(
    GeoPoint point, {
    int precision = 1,
    int limit = 1000,
  }) async {
    await initialize();
    final rows = await _database
        .customSelect(
          '''
SELECT * FROM media_assets
WHERE ROUND(latitude, ?) = ROUND(?, ?)
  AND ROUND(longitude, ?) = ROUND(?, ?)
ORDER BY creation_date_ms ASC
LIMIT ?
''',
          variables: [
            Variable.withInt(precision),
            Variable.withReal(point.latitude),
            Variable.withInt(precision),
            Variable.withInt(precision),
            Variable.withReal(point.longitude),
            Variable.withInt(precision),
            Variable.withInt(limit),
          ],
        )
        .get();
    return rows.map(_assetFromRow).toList(growable: false);
  }

  Future<void> upsertAssets(
    List<MediaAsset> assets, {
    DateTime? indexedAt,
  }) async {
    await initialize();
    final now = _toMs(indexedAt ?? DateTime.now())!;
    const sql = '''
INSERT INTO media_assets (
  local_identifier, media_type, creation_date_ms, modification_date_ms,
  latitude, longitude, duration_ms, width, height, favorite, is_live_photo,
  person_ids, indexed_at_ms
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(local_identifier) DO UPDATE SET
  media_type = excluded.media_type,
  creation_date_ms = excluded.creation_date_ms,
  modification_date_ms = excluded.modification_date_ms,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  duration_ms = excluded.duration_ms,
  width = excluded.width,
  height = excluded.height,
  favorite = excluded.favorite,
  is_live_photo = excluded.is_live_photo,
  person_ids = excluded.person_ids,
  indexed_at_ms = excluded.indexed_at_ms
''';
    await _database.batch((batch) {
      for (final asset in assets) {
        batch.customStatement(sql, [
          asset.localIdentifier ?? asset.id,
          asset.type.name,
          _toMs(asset.creationDate),
          _toMs(asset.modificationDate),
          asset.location?.latitude,
          asset.location?.longitude,
          asset.duration?.inMilliseconds,
          asset.width,
          asset.height,
          asset.isFavorite ? 1 : 0,
          asset.isLivePhoto ? 1 : 0,
          asset.personIds.join(','),
          now,
        ]);
      }
    });
  }

  Future<int> deleteAssets(Set<String> localIdentifiers) async {
    await initialize();
    var deleted = 0;
    await _database.transaction(() async {
      for (final id in localIdentifiers) {
        await _database.customStatement(
          'DELETE FROM media_assets WHERE local_identifier = ?',
          [id],
        );
        deleted += 1;
      }
    });
    return deleted;
  }

  Future<IndexReconciliationResult> reconcile(
    MediaRepository repository, {
    int batchSize = 200,
    MediaTypeFilter filter = MediaTypeFilter.all,
    ScanCancellationToken? cancellationToken,
    void Function(IndexProgress progress)? onProgress,
  }) async {
    await initialize();
    await _setState('scan_status', 'started');
    var scanned = 0;
    var inserted = 0;
    var updated = 0;
    final existing = await _allLocalIdentifiers();
    final seen = <String>{};

    try {
      var offset = 0;
      while (true) {
        if (cancellationToken?.isCancelled ?? false) {
          await _setState('scan_status', 'cancelled');
          await _setState('checkpoint_offset', '$offset');
          return IndexReconciliationResult(
            scanned: scanned,
            inserted: inserted,
            updated: updated,
            deleted: 0,
            cancelled: true,
          );
        }

        final page = await repository.fetchAssets(
          offset: offset,
          limit: batchSize,
          filter: filter,
        );
        if (page.isEmpty) break;

        for (final asset in page) {
          final id = asset.localIdentifier ?? asset.id;
          seen.add(id);
          if (existing.contains(id)) {
            updated += 1;
          } else {
            inserted += 1;
          }
        }

        await upsertAssets(page);
        scanned += page.length;
        offset += page.length;
        await _setState('checkpoint_offset', '$offset');
        onProgress?.call(
          IndexProgress(scanned: scanned, indexed: await count()),
        );

        if (page.length < batchSize) break;
      }

      final deleted = await deleteAssets(existing.difference(seen));
      await _setState('checkpoint_offset', '0');
      await _setState('scan_status', 'completed');
      return IndexReconciliationResult(
        scanned: scanned,
        inserted: inserted,
        updated: updated,
        deleted: deleted,
      );
    } on MediaFailure catch (failure) {
      await _setState('scan_status', 'failed');
      return IndexReconciliationResult(
        scanned: scanned,
        inserted: inserted,
        updated: updated,
        deleted: 0,
        failure: failure,
      );
    }
  }

  Future<int> count() async {
    await initialize();
    final row = await _database
        .customSelect('SELECT COUNT(*) AS value FROM media_assets')
        .getSingle();
    return row.read<int>('value');
  }

  Future<MediaIndexStats> stats() async {
    await initialize();
    final total = await count();
    final photos = await _countWhere("media_type IN ('image', 'livePhoto')");
    final videos = await _countWhere("media_type = 'video'");
    final livePhotos = await _countWhere("is_live_photo = 1");
    final favorites = await _countWhere("favorite = 1");
    final placeClusters = await _placeClusterCount();
    return MediaIndexStats(
      total: total,
      photos: photos,
      videos: videos,
      livePhotos: livePhotos,
      favorites: favorites,
      placeClusterCount: placeClusters,
    );
  }

  Future<List<DateDistributionBucket>> dateDistribution() async {
    await initialize();
    final rows = await _database.customSelect('''
SELECT strftime('%Y-%m', creation_date_ms / 1000, 'unixepoch') AS month,
       COUNT(*) AS value
FROM media_assets
WHERE creation_date_ms IS NOT NULL
GROUP BY month
ORDER BY month ASC
''').get();
    return rows
        .map(
          (row) => DateDistributionBucket(
            month: row.read<String>('month'),
            count: row.read<int>('value'),
          ),
        )
        .toList(growable: false);
  }

  Future<String?> scanStatus() async => _state('scan_status');

  Future<int> schemaVersion() async {
    await initialize();
    final row = await _database.customSelect('PRAGMA user_version').getSingle();
    return row.read<int>('user_version');
  }

  Future<String?> _state(String key) async {
    await initialize();
    final rows = await _database
        .customSelect(
          'SELECT value FROM index_state WHERE key = ?',
          variables: [Variable.withString(key)],
        )
        .get();
    if (rows.isEmpty) return null;
    return rows.single.read<String>('value');
  }

  Future<void> _setState(String key, String value) async {
    await initialize();
    await _database.customStatement(
      '''
INSERT INTO index_state (key, value) VALUES (?, ?)
ON CONFLICT(key) DO UPDATE SET value = excluded.value
''',
      [key, value],
    );
  }

  Future<Set<String>> _allLocalIdentifiers() async {
    final rows = await _database
        .customSelect('SELECT local_identifier FROM media_assets')
        .get();
    return rows.map((row) => row.read<String>('local_identifier')).toSet();
  }

  Future<int> _countWhere(String where) async {
    final row = await _database
        .customSelect('SELECT COUNT(*) AS value FROM media_assets WHERE $where')
        .getSingle();
    return row.read<int>('value');
  }

  Future<int> _placeClusterCount() async {
    final row = await _database.customSelect('''
SELECT COUNT(*) AS value FROM (
  SELECT ROUND(latitude, 1) AS lat, ROUND(longitude, 1) AS lon
  FROM media_assets
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL
  GROUP BY lat, lon
)
''').getSingle();
    return row.read<int>('value');
  }

  static String _filterSql(MediaTypeFilter filter) => switch (filter) {
    MediaTypeFilter.all => '',
    MediaTypeFilter.photo => "AND media_type IN ('image', 'livePhoto')",
    MediaTypeFilter.video => "AND media_type = 'video'",
  };

  static int? _toMs(DateTime? value) => value?.millisecondsSinceEpoch;

  static MediaAsset _assetFromRow(QueryRow row) {
    final latitude = row.readNullable<double>('latitude');
    final longitude = row.readNullable<double>('longitude');
    final personIds = row.read<String>('person_ids');
    return MediaAsset(
      id: row.read<String>('local_identifier'),
      localIdentifier: row.read<String>('local_identifier'),
      type: MediaType.values.byName(row.read<String>('media_type')),
      creationDate: _fromMs(row.readNullable<int>('creation_date_ms')),
      modificationDate: _fromMs(row.readNullable<int>('modification_date_ms')),
      location: latitude == null || longitude == null
          ? null
          : GeoPoint(latitude, longitude),
      duration: row.readNullable<int>('duration_ms') == null
          ? null
          : Duration(milliseconds: row.read<int>('duration_ms')),
      width: row.readNullable<int>('width'),
      height: row.readNullable<int>('height'),
      isFavorite: row.read<int>('favorite') == 1,
      isLivePhoto: row.read<int>('is_live_photo') == 1,
      personIds: personIds.isEmpty
          ? const []
          : personIds.split(',').where((id) => id.isNotEmpty).toList(),
    );
  }

  static DateTime? _fromMs(int? value) =>
      value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
}

class _MediaIndexDatabase extends GeneratedDatabase {
  _MediaIndexDatabase(QueryExecutor executor) : super(executor);
  _MediaIndexDatabase.connect(DatabaseConnection connection)
    : super.connect(connection);

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => _createSchema(m.database),
    onUpgrade: (m, from, to) async {
      if (from < 1) await _createSchema(m.database);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static Future<void> _createSchema(GeneratedDatabase database) async {
    await database.customStatement('''
CREATE TABLE IF NOT EXISTS media_assets (
  local_identifier TEXT PRIMARY KEY NOT NULL,
  media_type TEXT NOT NULL,
  creation_date_ms INTEGER,
  modification_date_ms INTEGER,
  latitude REAL,
  longitude REAL,
  duration_ms INTEGER,
  width INTEGER,
  height INTEGER,
  favorite INTEGER NOT NULL DEFAULT 0,
  is_live_photo INTEGER NOT NULL DEFAULT 0,
  person_ids TEXT NOT NULL DEFAULT '',
  indexed_at_ms INTEGER NOT NULL
)
''');
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_media_assets_creation_date ON media_assets(creation_date_ms)',
    );
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_media_assets_type ON media_assets(media_type)',
    );
    await database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_media_assets_location ON media_assets(latitude, longitude)',
    );
    await database.customStatement('''
CREATE TABLE IF NOT EXISTS index_state (
  key TEXT PRIMARY KEY NOT NULL,
  value TEXT NOT NULL
)
''');
  }
}
