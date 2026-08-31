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

## Sprint 0.8 memory intelligence path

```text
PersistentMediaIndex metadata
  -> MemoryContext
  -> MemoryRule plugins
       DateClusterRule
       SamePlaceRule
       YearRecapRule
       SamePlaceAcrossYearsRule
       FirstMemoryRule
       TravelStoryRule
       PersonTimelineRule
       AnnualTogetherRule
       LongTermEvolutionRule
  -> WeightedMemoryRanker V0.2
  -> MemorySensitivityGuard
  -> MemoryCandidateDeduplicator
  -> FeedDiversityController
  -> Chinese Discovery Feed / Detail
  -> Debug-only Memory Lab V0.2
```

Rules remain deterministic metadata heuristics. The system does not infer relationships, illness, death, pregnancy, marriage, body change or other sensitive facts. Product text uses safe templates such as “这个人” and “这些年” unless the user explicitly labels relationships in a future sprint.
