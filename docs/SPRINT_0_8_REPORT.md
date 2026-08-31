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

## Sprint 0.8.1 (Pre-Validation Correctness Fix — not a new Sprint, on same branch)

See `docs/SPRINT_0_8_1_FIX_REPORT.md`. Sprint 0.8.1 hardens factual correctness, location accuracy, travel completeness, localization boundary, evaluation privacy and large-library completeness before 5–10 real-library validation. No new rule, no face/LLM/backend added. Changes:

- `YearMetrics` corrects `连续 X 年` / `跨越 X 年` semantics (`distinctYearCount`/`calendarSpanYears`/`longestConsecutiveYearRun`).
- Distance-based `LocationClusterConfig(radiusMeters:500)` replaces `toStringAsFixed(1)` in 5 rules.
- `TravelStoryRule` two-phase enriches with all assets in window, emits `locationCoverage`.
- `MemoryEvaluation` persists only opaque `eval-` id, never raw GPS/person/asset.
- Presentation copy via `MemoryCandidateCopyMapper` + ARB placeholders; engine `safeTitleTemplate` deprecated; hard-code `正在整理这段记忆……` → `detailAiPlaceholder`.
- `PersistentMediaIndex.allAssetsPaged` removes silent 50K cap, `main.dart` pages full library with warning.
- Annual window uses circular `dayOfYear` distance with Dec31/Jan1 wrap.
- Sensitivity guard documented as V0.1 keyword guard.

Performance after 0.8.1 (median 3 runs, synthetic, in-memory SQLite): 1K top10 12ms / 10K 75ms / 50K 405ms (vs 0.8: 12/68/403), 60K smoke top10 594ms / 75K 715ms — no O(n²).

All 0.8.1 gates passed, see `SPRINT_0_8_1_FIX_REPORT.md` §18. Device + real-user still pending, then `Real Device Validation + First WOW Memory User Validation`.

## Verdict

Engineering work targets `PASS WITH REAL USER VALIDATION PENDING` if final automated verification passes. Full product PASS requires real user validation and Sprint 0.5 device validation. Sprint 0.8.1 is `PASS WITH DEVICE + REAL USER VALIDATION PENDING` — ready for Review before real validation.
