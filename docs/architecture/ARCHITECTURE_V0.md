# Architecture V0

```text
Flutter screens
  -> app composition root
  -> MediaRepository / MediaIndex
  -> MemoryEngine -> MemoryRule plugins -> MemoryCandidate
  -> MemoryRanker -> scored candidates
  -> AiService (Mock by default)
```

The domain layer contains only Dart models and value objects. Platform-specific PhotoKit code is reached through `MediaRepository`; iOS returns normalized metadata in pages. `MemoryEngine` executes registered rules and does not know which product hypothesis will be chosen later. Ranking is separate and returns a factor breakdown for debugging. Local indexing is an in-memory V0 implementation with a stable seam for SQLite/Drift later.

The app starts with a mock repository to keep the demo deterministic and offline. A future composition root can select `PhotoKitMediaRepository` on iOS and an Android MediaStore implementation without changing rules or UI contracts.
