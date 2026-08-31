# Sprint 0.8 acceptance report

## Workspace

- Path: `/Users/yvonne/Documents/CodeX/LifeMovie`
- Branch: `feat/memory-intelligence-v0.8`
- Base: `1ed0402 feat: add real data memory discovery vertical slice`
- Remote: `origin https://github.com/JerseyBro/LifeMovie.git`

## Baseline inheritance

Sprint 0 and Sprint 0.5 are retained. The implementation does not recreate the Flutter project, replace repository boundaries, rewrite PhotoKit, or replace the persistent index. Sprint 0.5 remains `PASS WITH MANUAL DEVICE VALIDATION PENDING`.

## Implemented

- `SamePlaceAcrossYearsRule`
- `FirstMemoryRule`
- `TravelStoryRule`
- upgraded `PersonTimelineRule`
- `AnnualTogetherRule`
- `LongTermEvolutionRule`
- Ranking V0.2 with accuracy, time span, recurrence, media diversity, rarity, visual coverage, story potential and sensitivity penalty factors.
- `MemorySensitivityGuard` for neutral wording / rank-down / hide behavior.
- `MemoryCandidateDeduplicator` with optimized precomputed set comparison.
- `FeedDiversityController`.
- `RepresentativeMediaSelector`.
- `MemoryEvaluation` model and local JSON evaluation store.
- Memory Lab V0.2 with rule toggles, parameter tuning, Top 10 browser, score breakdown, sensitivity flags, feedback and candidate compare.
- Flutter ARB localization with Simplified Chinese default and English key-compatible placeholders.
- Product UI V0.1: Chinese onboarding, indexing, editorial Discovery Feed, Memory Detail and timeline sections.

## Rule limitations

- `PersonTimelineRule`, `AnnualTogetherRule`, `FirstMemoryRule` person mode and person evolution all rely on injected/mock `personIds`.
- No production face recognition, person identity engine or relationship inference exists.
- Travel detection is metadata heuristic only and does not infer trip purpose.
- Same-place routines are penalized by frequency/month coverage, not semantically labeled as home/work/school.

## Performance baseline

Environment:

- Machine: `ADa-Yvonne.local`
- OS: macOS `Version 26.5.2 (Build 25F84)`
- Dart: `3.10.9`
- Flutter mode: `flutter test`
- Dataset: synthetic metadata only
- Database: in-memory SQLite
- Method: warm-up discarded, 3 measured runs, median reported

| Dataset | Reconciliation | Date query | Place query | All rules | Ranking | Dedup | Diversity | First candidate | Top 10 | Candidates | Approx RSS |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1K | 8 ms | 0 ms | 2 ms | 4 ms | 5 ms | 1 ms | 0 ms | 0 ms | 12 ms | 108 | +2 MB |
| 10K | 56 ms | 2 ms | 18 ms | 47 ms | 13 ms | 5 ms | 0 ms | 0 ms | 68 ms | 108 | +2 MB |
| 50K | 309 ms | 8 ms | 103 ms | 267 ms | 85 ms | 30 ms | 0 ms | 0 ms | 403 ms | 108 | -3 MB |

These are synthetic metadata results, not device photo-library benchmarks.

## Automated verification status

- `flutter analyze` from repository root: passed.
- `dart test` in `packages/memory_domain`: passed.
- `flutter test` in `packages/media_library`: passed.
- `flutter test` in `packages/memory_engine`: passed.
- `flutter test` in `apps/memory_app`: passed.
- `flutter build ios --no-codesign` in `apps/memory_app`: passed.

## Manual validation

Foundation device validation remains pending:

- NotDetermined -> Full: Pending
- NotDetermined -> Limited: Pending
- Limited -> Add More Photos: Pending
- Limited -> Remove Accessible Photos: Pending
- Full -> Limited: Pending
- Denied: Pending
- Re-authorize: Pending
- Large real library: Pending
- App kill/reopen during scan: Pending
- Fast thumbnail scroll: Pending

Real user validation remains `PENDING REAL USER VALIDATION`.

## Verdict

Engineering work targets `PASS WITH REAL USER VALIDATION PENDING` if final automated verification passes. Full product PASS requires real user validation and Sprint 0.5 device validation.
