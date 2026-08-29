# Sprint 0.5 acceptance report

## Workspace

- Path: `/Users/yvonne/Documents/CodeX/LifeMovie`
- Branch: `main`
- Baseline commit: `177e399 chore: 初始化 AI Memory Foundation Sprint 0 基础架构`
- Remote: `origin https://github.com/JerseyBro/LifeMovie.git`

## Implemented

- Real iOS PhotoKit metadata adapter for bounded asset fetch, date-range fetch and media type filters.
- Real iOS thumbnail requests through `PHCachingImageManager`, with request id cancellation.
- Normalized `MediaAsset` metadata for `localIdentifier`, media type, creation/modification date, duration, dimensions, location, favorite and live photo subtype.
- Drift/SQLite `PersistentMediaIndex` with schema version 1, migration entry, localIdentifier primary key, indexes, persistence and reopen behavior.
- Incremental reconciliation for new, updated and removed assets, including Limited Library add/remove recovery through the same reconciliation path.
- Scan cancellation state and checkpoint offset state for interrupted scans. Recovery runs a fresh reconciliation from offset 0 to avoid stale-delete mistakes.
- Lightweight `MediaFailure`, `PermissionFailure`, `IndexFailure` and `MemoryFailure`.
- `SamePlaceRule` now uses spatial cluster plus visit-session gap.
- `PersonTimelineRule` supports injected person ids for synthetic product validation only; no face recognition is implemented.
- Ranking returns final score plus named factor breakdown.
- iOS app path uses PhotoKit -> PersistentMediaIndex -> MemoryEngine -> MemoryRanker -> Discovery -> Detail.
- Debug-only Memory Lab displays index counts, rules, candidates, scores, factors and reasons.

## Performance baseline

Environment:

- Machine: macOS arm64
- Dart: 3.10.9
- Flutter mode: `flutter test`
- Dataset: synthetic metadata only, in-memory SQLite cold database

| Dataset | Reconciliation | Date query | Place query | Date rule | Place rule | Ranking | First useful result | Approx RSS delta |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1K | 1137 ms | 7 ms | 7 ms | 3 ms | 3 ms | 3 ms | 4 ms | 13 MB |
| 10K | 40 ms | 2 ms | 16 ms | 5 ms | 10 ms | 3 ms | 0 ms | 20 MB |
| 50K | 175 ms | 7 ms | 83 ms | 10 ms | 19 ms | 14 ms | 0 ms | 74 MB |

These numbers are not device-photo-library benchmarks. They validate that the metadata/index/rule/ranking path has no obvious O(n^2) disaster on synthetic 50K metadata.

## Automated verification

- `flutter analyze` in `apps/memory_app`: passed.
- `dart test` in `packages/memory_domain`: passed.
- `flutter test` in `packages/media_library`: passed.
- `dart test` in `packages/memory_engine`: passed.
- `flutter test` in `apps/memory_app`: passed, including vertical slice and performance baseline.
- `flutter build ios --no-codesign`: passed.

## Device validation

Status: `PENDING MANUAL DEVICE VALIDATION`

- NotDetermined -> Full: Pending
- NotDetermined -> Limited: Pending
- Limited -> Add More Photos: Pending
- Limited -> Remove Accessible Photos: Pending
- Full -> Limited: Pending
- Denied: Pending
- Re-authorize: Pending
- Large real library initial scan: Pending
- App kill during scan and reopen: Pending
- Scroll Discovery thumbnails: Pending

## Remaining gaps

- Real-time `PHPhotoLibraryChangeObserver` is not connected in Sprint 0.5. Reconciliation is implemented and documented as the current recovery path.
- Device performance is not measured. Current baseline uses synthetic metadata and in-memory SQLite.
- `PersonTimelineRule` uses injected person ids only; no face identity, embeddings or person graph exist.
- Remote AI, Local AI and MovieRenderer remain boundaries/placeholders.

## Risks

- Large real libraries can still expose PhotoKit lifecycle and permission-change edge cases that synthetic tests cannot cover.
- Limited Library picker behavior must be validated manually on a real device.
- Thumbnail request cancellation is implemented, but fast-scroll behavior still needs device observation.
- Ranking quality is explainable but not product-calibrated.
- Crash recovery relies on reconciliation plus checkpoint status; a future background job model may be needed.

## Verdict

`PASS WITH MANUAL DEVICE VALIDATION PENDING`

The real-data vertical slice is implemented and automated verification passes. Full PASS requires the manual iPhone validation checklist above.
