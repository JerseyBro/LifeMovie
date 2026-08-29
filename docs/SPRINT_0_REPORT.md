# Sprint 0 acceptance report

## Implemented

- Flutter app plus package workspace scaffold.
- Platform-independent models: `MediaAsset`, `Person`, `Place`, `Event`, `Memory`, `MemoryCandidate`, `MemoryStory`, `MovieProject`.
- `MediaRepository`, mock repository, paginated `MediaIndex`, and permission enum.
- iOS PhotoKit permission mapping for NotDetermined, Full, Limited, Denied, and Restricted; paginated metadata bridge and iOS 14 deployment target.
- Plugin `MemoryEngine` with `DateClusterRule`, `SamePlaceRule`, and `YearRecapRule`.
- Separate weighted ranker and `MemoryScoreBreakdown`.
- Mock-first AI gateway, analytics interface, movie-processing boundary, and neutral design tokens.
- Onboarding, permission request, scan state, discovery feed (up to 3 candidates), and memory detail demo.
- README, AGENTS, module boundaries, architecture V0, ADR-001 through ADR-004.

## Verification

- `flutter analyze` in `apps/memory_app`: passed.
- App widget test: passed.
- `dart test` in `packages/memory_domain`: passed.
- `flutter test` in `packages/media_library`: passed.
- `flutter test` in `packages/memory_engine`: passed.
- `flutter build ios --no-codesign`: passed on iOS deployment target 14.0.

## Not implemented / intentionally deferred

- Native PhotoKit `fetchAssetsByDateRange` and `loadThumbnail` are explicit channel stubs; the V0 demo does not display real thumbnails.
- The local index is in-memory, not yet backed by SQLite/Drift.
- Remote/local AI providers and movie rendering are interfaces/placeholders.
- No device run, real-library scan, Limited Library interaction, or live-data acceptance was performed in this environment.

## Risks and next steps

1. Complete PhotoKit date-range and thumbnail requests, including cancellation and memory limits.
2. Add iOS integration tests with a controlled photo-library fixture and verify permission changes after revocation/additions.
3. Persist `MediaIndex` with a migration-ready local database.
4. Decide the first product hypothesis before adding more rules or story generation.
