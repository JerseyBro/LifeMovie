# Architecture V0

```text
Flutter screens
  -> app composition root
  -> MediaRepository / PersistentMediaIndex
  -> MemoryEngine -> MemoryRule plugins -> MemoryCandidate
  -> MemoryRanker -> scored candidates
  -> AiService (Mock by default)
```

The domain layer contains only Dart models and value objects. Platform-specific PhotoKit code is reached through `MediaRepository`; iOS returns normalized metadata in bounded batches and never exposes `PHAsset`, `UIImage` or `AVAsset` to Dart domain code. `MemoryEngine` executes registered rules and does not know which product hypothesis will be chosen later. Ranking is separate and returns a factor breakdown for debugging. Local indexing now has a Drift/SQLite implementation with schema version 1.

The app uses `PhotoKitMediaRepository` and `PersistentMediaIndex` on iOS. Non-iOS and tests keep `MockMediaRepository` / in-memory index paths. A future Android MediaStore implementation can be added behind the same repository contract without changing rules.

## Sprint 0.5 real data path

```text
iPhone Photos
  -> PhotoKitMediaRepository
  -> MediaAsset
  -> PersistentMediaIndex (Drift/SQLite)
  -> MemoryContext
  -> DateClusterRule / SamePlaceRule / YearRecapRule / PersonTimelineRule
  -> WeightedMemoryRanker
  -> Discovery Feed
  -> Memory Detail
```

Reconciliation compares current accessible PhotoKit assets with the local index and applies insert/update/delete operations. This supports Limited Library add/remove flows without assuming that photo access is stable forever. Real-time `PHPhotoLibraryChangeObserver` remains a future enhancement; reconciliation is the Sprint 0.5 recovery mechanism.
