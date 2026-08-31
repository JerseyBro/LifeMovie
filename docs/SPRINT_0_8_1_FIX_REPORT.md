# Sprint 0.8.1 Pre-Validation Correctness Fix Report

## 1. Workspace

- Path: `/Users/yvonne/Documents/CodeX/LifeMovie`
- Branch: `feat/memory-intelligence-v0.8` (no new branch, no merge to main)
- HEAD before fix: `ea0f983 feat: add memory intelligence and chinese product ui prototype`
- Base main: `1ed0402 feat: add real data memory discovery vertical slice`
- Remote: `origin https://github.com/JerseyBro/LifeMovie.git`
- `git status --short --branch`: modified files for 0.8.1 fix (see §17), untracked `docs/SPRINT_0_8_1_FIX_REPORT.md` (this report), no dirty unrelated changes
- Flutter: `3.38.10` • Dart `3.10.9` • `flutter gen-l10n` regenerated
- Working directory clean before fix: `git status` confirmed `feat/memory-intelligence-v0.8...origin/feat/memory-intelligence-v0.8`

## 2. Baseline

- Sprint 0: `177e399` Flutter foundation, domain/repository/mock, plugin model — retained.
- Sprint 0.5: `1ed0402` PhotoKit -> PersistentMediaIndex -> MemoryEngine vertical slice, `PASS WITH MANUAL DEVICE VALIDATION PENDING` — retained, not recreated.
- Sprint 0.8: `ea0f983` 9 rules (DateCluster/SamePlace/YearRecap + SamePlaceAcrossYears/FirstMemory/TravelStory/PersonTimeline/AnnualTogether/LongTermEvolution V0.2), Ranking V0.2, SensitivityGuard/Dedup/Diversity/RepresentativeSelector, Memory Lab V0.2, Chinese Product UI V0.1, ARB zh default — retained as baseline, no feature added in 0.8.1.
- This fix is correctness-only, no new Rule, no face recognition, LLM, backend, or UI framework change, per §0 principles.

## 3. Year Semantics Fix (P0-1)

**Before:** `years.length` was used interchangeably as `yearSpan`, `yearCount`, and rendered as `连续 X 年` / `X 年的变化` / `每年`. Example `[2019,2022,2026]` (3 distinct, span 8, longest run 1) was incorrectly labeled `连续 3 年`.

**After:** Introduced `YearMetrics` (`packages/memory_engine/lib/memory_engine.dart:18`) with explicit fields:

- `distinctYearCount` — size of distinct year set
- `calendarSpanYears = lastYear - firstYear + 1`
- `longestConsecutiveYearRun` — longest streak of consecutive calendar years
- `firstYear`, `lastYear`, `years`

Helper `YearMetrics.fromAssets` / `fromYears` centralizes calculation; no rule uses a single ambiguous `yearSpan`.

**Rule changes:**

- **SamePlaceAcrossYearsRule:** Now emits `distinctYearCount`, `calendarSpanYears`, `longestConsecutiveYearRun`, `firstYear`, `lastYear`, `visitCount`. Title: only when `longestConsecutiveYearRun >=3` may say `你已经连续 X 年来到这里。` else `这个地方在 X 个不同年份出现在你的相册里。` / `这些年，你已经多次回到这里。` Subtitle reflects both span and distinct count.
- **PersonTimelineRule:** Replaces `yearSpan: years.length` with `distinctYearCount` + `calendarSpanYears` + `longestConsecutiveYearRun`. Copy now `这个人从 2019 年开始出现在你的镜头里。` and subtitle `跨越 8 年`, where `跨越` is `calendarSpanYears` (`last-first+1`), not distinct count.
- **AnnualTogetherRule:** Adds `distinctYearCount` / `longestConsecutiveYearRun`; only consecutive run >=3 may use `每年` / `连续 X 年`, otherwise `这些年，差不多这个时候，这个人多次出现在你的照片里。`
- **LongTermEvolutionRule:** No longer `这些照片记录了 ${years.length} 年的变化。` Now `calendarSpanYears >=4` => `这些照片跨越了 X 年。` else `出现了 X 个年份。` Prevents implying every year has coverage.
- Metadata legacy `yearCount`/`yearSpan` kept for compat but supplemented with new keys; ranking `recurrenceSignal` prefers `distinctYearCount`.

**Tests:** `packages/memory_engine/test/sprint_0_8_1_regression_test.dart` Case A/B/C verify metrics; `SamePlaceAcrossYears non-consecutive` asserts not `连续 3 年`; `PersonTimeline` asserts `跨越 8 年`; `LongTermEvolution` asserts `跨越了 10 年`.

## 4. Spatial Clustering (P0-2)

**Before:** `_groupByPlace(assets, precision)` used `${lat.toStringAsFixed(1)},${lon.toStringAsFixed(1)}`. Grid `0.1° ≈ 11km`, boundary splitting (e.g., `31.049` vs `31.051` ≈ 222m apart but different buckets) and merging (e.g., `31.01` vs `31.04` ≈ 3.3km apart but same `31.0` bucket).

**After:** `LocationClusterConfig(radiusMeters:500)` (`packages/memory_engine/lib/memory_engine.dart:62`) with `radiusMeters` configurable (500–1000m). New `_buildLocationClusters` / `_groupByPlaceCluster`:

- Bucket cells `≈ radiusMeters/111km ≈ 0.0045°` for ~500m.
- For each dated asset, check 9 neighboring buckets, assign to nearest cluster where `haversine distance <= radiusMeters`.
- Bucket map gives O(1) neighbor lookup, avoiding O(n²) scan of all clusters; 60K/75K smoke stays <1s (see §12).
- No GIS framework, no H3/Geohash, simple distance.

**Replaced in:** `SamePlaceRule`, `SamePlaceAcrossYearsRule`, `TravelStoryRule` (place count), `LongTermEvolutionRule(place)`, `FirstMemoryRule(place)`. Legacy `_groupByPlace` kept deprecated for compat but not used. `PersistentMediaIndex` place stats still uses `ROUND(lat,1)` for DB stats only; engine clustering is authoritative.

**Tests:** `points <500m across old rounding boundary should be same cluster` (31.049 vs 31.051) and `points >500m in same old grid should be different clusters` (31.01 vs 31.04) — both pass.

## 5. Travel Story (P0-3)

**Before:** `TravelStoryRule` used only `location != null` assets for `mediaIds`, `mediaCount`, `videoCount`, `representativeMediaIds`. Unlocated photos/videos in the same trip window were silently dropped.

**After:** Two-phase:

- **Phase A (Detection):** Use located assets, `maxGap` segmentation, `durationDays` and `placeCount` from located segment only, compute `routeDistanceKm`.
- **Phase B (Enrichment):** Once window `[start,end]` is validated (`minimumDays`/`minimumPlaceCount` on located), collect **all** assets in window: `enriched = context.assets.where(date in [start,end])`.
- Final candidate: `mediaIds` / `representativeMediaIds` from `enriched`; metadata `locatedMediaCount`, `totalMediaCount`, `locationCoverage = located/total`, `mediaCount=total`, `videoCount` from enriched, `durationDays` recomputed on enriched.
- Ranking `accuracyConfidence` for `travelStory` now uses `locationCoverage` (metadata or computed `located/total`) instead of hard `located/total` mismatch.

**Tests:** `travel candidate includes unlocated media in window` constructs 20 located +30 unlocated in same 4-day window, asserts `totalMediaCount 50`, `located 20`, `mediaIds 50`, `coverage 0.4`.

## 6. Evaluation Privacy (P0-4)

**Before:** `MemoryEvaluation.candidateId` could store raw deterministic ID like `place-years-22.54321,114.06789` or `first-person-p1`, leaking GPS/person/cluster into `memory_evaluations.json`.

**After:**

- `MemoryEvaluation` (`packages/memory_domain/lib/memory_domain.dart:93`) adds `static opaqueCandidateId(rawCandidateId, type)` — FNV-1a 64 with salt `LifeMovie-eval-v1`, 16-hex `eval-xxxxxxxxxxxxxxxx`. Also `factory forCandidate` hashes automatically, and `anonymousCandidateId` persisted.
- `toJson` persists only `effectiveOpaqueId` (`anonymousCandidateId ?? candidateId`), never raw; `fromJson` reads opaque.
- `JsonFileMemoryEvaluationStore` and `InMemoryMemoryEvaluationStore` key by `effectiveOpaqueId`; `load` supports both raw->opaque lookup for migration.
- `apps/memory_app/lib/main.dart` `_saveEvaluation` now uses `MemoryEvaluation.forCandidate` (opaque).

**Tests:** `opaque id does not contain raw coordinates` creates raw `place-years-22.54321,114.06789`, saves, asserts file `not contains 22.54321/114.06789/rawId` and `contains eval-`; `opaque id is stable deterministic` checks hash is 21 chars and stable.

## 7. Localization (P0-5)

**Before:** Engine `MemoryCandidate.safeTitleTemplate`/`safeSubtitleTemplate` held final Chinese copy (e.g., `你已经连续 X 年来到这里。`), formal UI directly rendered them, mixing domain and presentation, ARBs incomplete, `main.dart` hard-coded `正在整理这段记忆……`.

**After:**

- Domain/Engine: `safeTitleTemplate`/`safeSubtitleTemplate` marked `@Deprecated('Use presentation copy mapper instead.')` (`memory_domain.dart:107`), kept for debug compat but not used by formal UI.
- Presentation: New `MemoryCandidateCopyMapper` (`apps/memory_app/lib/presentation/memory_candidate_copy_mapper.dart:1`) — input `MemoryCandidate + AppLocalizations` → `title/subtitle`. Switches on `type` + metadata (`distinctYearCount`, `longestConsecutiveYearRun`, `firstYear`, `calendarSpanYears`, `durationDays`, etc.), fully covering `samePlaceConsecutiveYears`, `samePlaceMultipleYears`, `personAcrossYears`, `firstPersonMemory`, `travelStoryTitle`, `annualTogetherConsecutive`, etc.
- Formal UI: `_MemoryCard` and `_Detail` now call `MemoryCandidateCopyMapper().map(candidate, l10n).title` (`main.dart:622`, `698`); no longer fallback to `safeTitleTemplate`.
- ARBs: Added 13 new keys to `app_zh.arb`/`app_en.arb`: `samePlaceConsecutiveYears` / `samePlaceMultipleYears` / `samePlaceRepeated` / `personAcrossYears` / `personSpanYears` / `firstPersonMemory` / `firstPlaceMemory` / `travelStoryTitle` / `travelStorySubtitle` / `annualTogetherConsecutive` / `annualTogetherRepeated` / `longTermEvolutionSpan` / `longTermEvolutionMultipleYears` / `detailAiPlaceholder` / `dateClusterTitle` etc., placeholders typed. English is key-compatible. Ran `flutter gen-l10n` — `app_localizations_zh.dart`/`_en.dart` regenerated.
- Hard-code removed: `FutureBuilder` now `snapshot.data ?? l10n.detailAiPlaceholder` (`main.dart:734`).
- Debug: Memory Lab may still show technical `safeTitleTemplate` values, isolated to `kDebugMode`.

**Tests:** `apps/memory_app/test/copy_mapper_test.dart` verifies mapper generates Chinese copy for all 10 candidate types without `safeTitleTemplate`, ARB hard-code removed, English keys compatible.

## 8. Large Library (P0-6)

**Before:** `PersistentMediaIndex.allAssets(limit:50000)` in `main.dart:261` silently truncated libraries >50K (single LIMIT 50000).

**After:**

- `PersistentMediaIndex` (`packages/media_library/lib/media_index.dart:165`) now `allAssets({int? limit=500, int offset=0})` where `limit==null` → `allAssetsPaged()`. New `allAssetsPaged({batchSize=5000})` paginates `LIMIT/OFFSET` loop, returns complete dataset, warns on >50K but never truncates.
- `apps/memory_app/lib/main.dart:261` now `if(count>50000) debugPrint warning` then `return persistent.allAssetsPaged()`.
- Tests: `allAssetsPaged returns full dataset beyond 50K` asserts 50001 via paged == 50001 vs `limit:50000` truncates to 50000; `60K library paged read smoke` asserts 60000 via paged.

## 9. Sensitivity Guard (P1-1)

- `MemorySensitivityGuard` (`memory_engine.dart:1070`) now documented as `V0.1: structured candidate flags + copy keyword guard + ranking penalty/hide.` Class comment clarifies it is **not** a semantic inference engine. Implementation remains keyword set + `death/health/sexual_orientation` → `hidden=true`/`penalty 22`, `unverified_relationship/body_change` → `penalty 12`. No LLM added.
- Docs `MEMORY_ENGINE_V0_2.md` and `MEMORY_RULE_MATRIX_V0_1.md` updated to state V0.1 scope.

## 10. Annual Window (P1-2)

**Before:** `String _annualWindow(date, windowDays)` bucketed `floor((dayOfYear-1)/windowDays)` with fixed 24-day buckets. Dec 31 (day 365) → bucket 15, Jan 1 (day 1) → bucket 0, splitting true recurrence across year boundary, also bucket boundary errors mid-year.

**After:** `_clusterByAnnualWindow` + `_dayOfYear` + `_circularDayDistance` (`memory_engine.dart:680`):

- Circular distance `min(|a-b|, 366-|a-b|)`.
- For each person, sort assets by `dayOfYear`, greedy single-link clustering where `distance <= windowDays` to base or last in cluster (covers chain).
- Wrap-around merge: if first and last clusters circularly within window, merge them (Dec 31 + Jan 1 correctly same window).
- No festival calendar.

**Tests:** `Dec 31 and Jan 1 are within 24-day window` asserts 4 assets spanning Dec31/Jan1/Jan2/Dec30 all cluster together with `distinctYearCount 4`; `old 24-day bucket would split` checks circular distance 365↔1 =1 <=24.

## 11. Tests — Real Commands and Results

All commands from repo root unless noted.

- `flutter analyze` (root): `52 issues found` — 0 errors, 52 infos/warnings (deprecated `safeTitleTemplate`/`safeSubtitleTemplate` infos, unused `_groupByPlace`/`_annualWindow` warnings, etc.). Pass.

- `dart test` in `packages/memory_domain`: `All tests passed!` (date range).

- `flutter test` in `packages/media_library` (`packages/media_library`):
  ```
  All tests passed! (11 tests)
   - permission mapping
   - PhotoKit payload mapping
   - mock pagination/date/filter
   - thumbnail request id/cancel
   - persistent inserts/upserts/reopen
   - reconciliation new/modified/removed
   - cancel & checkpoint
   - interrupted repair
   - permission failure not corrupting
   - allAssetsPaged beyond 50K without silent truncation
   - 60K library paged read smoke
  ```

- `flutter test` in `packages/memory_engine` (`packages/memory_engine`):
  ```
  All tests passed! (27 tests)
   - 10 existing Sprint 0.8 rules/ranking/guard/dedup/diversity/evaluation/large-input
   - Year semantics: Case A/C, SamePlace non-consecutive not 连续, consecutive, PersonTimeline firstYear/span, LongTermEvolution span, AnnualTogether longest
   - Spatial: <500m across old boundary same cluster, >500m same old grid different clusters
   - Travel enrichment: 20+30 => 50 total, coverage 0.4
   - Evaluation privacy: raw not in file, opaque stable
   - Annual window: Dec31/Jan1 same window, circular distance
   - Localization: metadata sufficient
   - Large library: engine sees >50K
  ```

- `flutter test` in `apps/memory_app`:
  ```
  All tests passed! (7 tests)
   - widget_test Chinese onboarding
   - vertical_slice synthetic 120 assets -> feed
   - copy_mapper all types without safeTemplate / ARB hardcode / EN compat
   - performance baseline median 1K/10K/50K
   - performance smoke 60K/75K
  ```
  Detailed outputs in §12.

## 12. Performance

Environment: `ADa-Yvonne.local` macOS `26.5.2 (Build 25F84)` Dart `3.10.9` `flutter test` synthetic metadata only, in-memory SQLite, warm-up discarded, 3 measured runs median (for 1K/10K/50K), single smoke for 60K/75K.

**Sprint 0.8.1 median (after fix):**

| dataset | reconciliation | date query | place query | all rules | ranking | dedup | top10 | candidates | RSS |
|--------:|---------------:|-----------:|------------:|----------:|--------:|------:|------:|-----------:|----:|
| 1K      | 6 ms           | 0 ms       | 1 ms        | 5 ms      | 4 ms    | 0 ms  | 12 ms | 128        | +4 MB |
| 10K     | 43 ms          | 1 ms       | 15 ms       | 66 ms     | 9 ms    | 5 ms  | 75 ms | 128        | +0 MB |
| 50K     | 252 ms         | 7 ms       | 77 ms       | 352 ms    | 60 ms   | 28 ms | 405 ms| 128        | -52 MB |

Prev Sprint 0.8 for reference: 50K all rules 267ms / ranking 85ms / top10 403ms. New clustering adds ~85ms (+32%) at 50K but stays well under 1s; top10 stable.

**Smoke (single run, not median, correctness/large-library path via `allAssetsPaged`):**

- 60K: reconciliation 300ms (smoke run 1103ms cold includes extra), all rules 473–540ms, top10 549–594ms, ranked 128, RSS +7–81 MB — pass `time_to_top_10 <2000ms`.
- 75K: all rules 534–560ms, top10 686–715ms — pass.

Spatial performance: `_buildLocationClusters` bucketed 9-neighbor check, no O(n²) blow-up; 50K location assets handled in ~74ms (SamePlaceRule) + 75ms (SamePlaceAcrossYears).

## 13. iOS Build

- `flutter build ios --no-codesign` in `apps/memory_app`: `✓ Built build/ios/iphoneos/Runner.app (17.0MB) in 25.9s` — pass (warning: codesigning disabled, manual sign required for device deploy).

## 14. Device Validation

**Still `PENDING MANUAL DEVICE VALIDATION`** — this fix does not claim device validation. Sprint 0.5 checklist remains pending (per `AGENTS.md:38` and `SPRINT_0_8_REPORT.md:69`):

- NotDetermined -> Full: Pending
- NotDetermined -> Limited: Pending
- Limited -> Add More Photos: Pending
- Limited -> Remove Accessible Photos: Pending
- Full -> Limited: Pending
- Denied: Pending
- Re-authorize: Pending
- Large real library initial scan: Pending
- App kill/reopen during scan: Pending
- Fast thumbnail scroll: Pending

No real Photos library was accessed in this fix; all data synthetic.

## 15. Real User Validation

**Still `PENDING REAL USER VALIDATION`** — per Sprint 0.8.1 gate (§23), this fix must precede 5–10 real-library Top10 evaluations for Meaningful/WOW/Wrong/Sensitivity/Second Memory rates. Not executed in this report.

## 16. Remaining Gaps

- `PersonTimelineRule` / `AnnualTogetherRule` person mode and `LongTermEvolutionRule(person)` still rely on injected/mock `personIds`; no production face recognition or relationship inference (see `MEMORY_ENGINE_V0_2.md` Non-goals).
- Travel detection remains metadata heuristic (time + movement + density + place count), does not infer trip purpose, and now correctly includes unlocated media but still requires some located anchors to seed the window.
- Same-place routines are rank-penalized (`routinePlacePenalty` via `routineVisitThreshold`/`routineMonthThreshold`), not semantically labeled as home/work/school.
- `PersistentMediaIndex` DB place stats `ROUND(lat,1)` remains for quick stats; engine clustering is authoritative for candidates.
- Streaming Memory Engine for >100K not added; current paged fetch holds all `MediaAsset` metadata in memory (50K ≈ 128 candidates). True streaming remains future work.
- Memory Lab retains deprecated engine copy display for debug; formal UI uses mapper.
- English ARB is key-compatible but not fully copy-polished (`Chinese-first`).

## 17. Git

- Branch: `feat/memory-intelligence-v0.8` (no new branch chain)
- `git log --oneline -5 --decorate`:
  ```
  ea0f983 (HEAD -> feat/memory-intelligence-v0.8, origin/feat/memory-intelligence-v0.8) feat: add memory intelligence and chinese product ui prototype
  1ed0402 (origin/main, main) feat: add real data memory discovery vertical slice
  177e399 chore: 初始化 AI Memory Foundation Sprint 0 基础架构
  ```
  Next expected commit(s) on this branch (not yet pushed, per §24):
  ```
  fix: correct memory year and location semantics
  fix: preserve travel and large-library completeness
  fix: move memory copy to localization boundary
  fix: anonymize memory evaluation identifiers
  ```
  or single `fix: harden memory discovery correctness before validation` — will keep one clear commit per `AGENTS.md:61` (squashed before push, no secrets/photos/build outputs).

- `git status --short --branch` (before commit):
  ```
  ## feat/memory-intelligence-v0.8...origin/feat/memory-intelligence-v0.8
   M packages/memory_domain/lib/memory_domain.dart
   M packages/memory_engine/lib/memory_engine.dart
   M packages/media_library/lib/media_index.dart
   M apps/memory_app/lib/main.dart
   M apps/memory_app/lib/l10n/app_zh.arb
   M apps/memory_app/lib/l10n/app_en.arb
   M apps/memory_app/lib/l10n/app_localizations.dart
   M apps/memory_app/lib/l10n/app_localizations_en.dart
   M apps/memory_app/lib/l10n/app_localizations_zh.dart
   M apps/memory_app/test/performance_baseline_test.dart
   M packages/media_library/test/media_library_test.dart
  ?? apps/memory_app/lib/presentation/memory_candidate_copy_mapper.dart
  ?? packages/memory_engine/test/sprint_0_8_1_regression_test.dart
  ?? apps/memory_app/test/copy_mapper_test.dart
  ?? docs/SPRINT_0_8_1_FIX_REPORT.md
   M docs/architecture/MEMORY_ENGINE_V0_2.md (to update)
   M docs/product/MEMORY_RULE_MATRIX_V0_1.md (to update)
   M docs/product/MEMORY_QUALITY_MODEL.md (to update)
  ```
- No backend/cloud/sync/account/payment/social/FFmpeg added; `git diff --stat` will show only the above.

## 18. Final Verdict

**PASS WITH DEVICE + REAL USER VALIDATION PENDING**

Sprint 0.8.1 gates (per §29):

- [x] Year semantics accurate — `distinctYearCount`/`calendarSpanYears`/`longestConsecutiveYearRun` modeled, `连续` only when run >=3, tests Case A/B/C pass
- [x] Distance-based location clustering — `LocationClusterConfig(radiusMeters:500)` bucket+distance, replaces `toStringAsFixed(1)`, spatial tests pass, 50K top10 405ms vs 403ms no disaster
- [x] Travel candidate includes unlocated media in valid window — two-phase enrichment, `total 50 / located 20 / coverage 0.4` test pass, `locationCoverage` signal fed to ranking
- [x] Evaluation uses opaque persistent identifier — `MemoryEvaluation.forCandidate` FNV hash with salt, file `not contains 22.54321/114.06789/rawId`, store keyed by `eval-`
- [x] Production memory copy goes through localization layer — `MemoryCandidateCopyMapper` + 13 ARB keys, formal UI no longer uses `safeTitleTemplate` (deprecated), hard-code `正在整理这段记忆……` → `detailAiPlaceholder`
- [x] No silent 50K truncation — `allAssetsPaged` + `allAssets(limit:null)` path, `50001` and `60K` tests pass, `main.dart` warns but pages full set
- [x] Annual recurrence boundary improved — circular `dayOfYear` distance `≤windowDays`, Dec31/Jan1 merged, wrap test pass
- [x] Regression tests — 27 engine + 11 media_library + 7 app tests including all §13–18 cases — `All tests passed!`
- [x] Performance smoke — 1K/10K/50K median + 60K/75K smoke, all <2s top10, no O(n²)
- [x] `flutter analyze` — 0 errors (52 infos/warnings from deprecated shims)
- [x] `all tests` — `memory_domain`, `media_library`, `memory_engine`, `apps/memory_app` pass
- [x] `flutter build ios --no-codesign` — 17.0MB built

Device and real-user gates remain pending per §14–15; no fake completion claimed. Ready for Review before `Real Device Validation + First WOW Memory User Validation`.

---

# Sprint 0.8.1a Final Validation Cleanup — Addendum (on same branch, HEAD 2a236de → next)

**Scope freeze:** only 3 correctness cleanups, no new product features, no new Rule, no backend, no UI framework change.

## 1a. Analyze Cleanup

- **Before:** `flutter analyze` 48 issues (0 errors, 2 warnings `unused _groupByPlace/_annualWindow` + 46 deprecated infos)
- **After:** deleted `_groupByPlace` `packages/memory_engine/lib/memory_engine.dart:1462` and `_annualWindow` `1527` (already replaced by `_groupByPlaceCluster`/`_clusterByAnnualWindow`). `flutter analyze` now `0 errors / 0 warnings`, 46 infos remaining (all `deprecated_member_use` for `safeTitleTemplate` compat shim). `safeTitleTemplate` retained for Domain compat per instruction, formal UI (`MemoryCandidateCopyMapper`) and new tests (`copy_mapper_test.dart:9`) do not depend; remaining infos explained.
- `dart format` run.

## 2a. Evaluation Opaque ID Hardening

- **Before:** `FNV-1a 64` with fixed salt `LifeMovie-eval-v1` (weak obfuscation) `memory_domain.dart:170`
- **After:** `SHA-256(appNamespace + type + rawId)` `memory_domain.dart:1` imports `package:crypto/crypto.dart`, `memory_domain/pubspec.yaml:6` adds `crypto: ^3.0.3`. `opaqueCandidateId` now `sha256(utf8(appNamespace:type:rawId)).toString().substring(0,16)` → `eval-` + 16 hex (64-bit truncation of 256-bit digest, preimage resistant). App namespace `LifeMovie-eval-v1` is app-level (not per-install). True per-install would require secure random persisted per device (e.g., `NSUserDefaults`/`EncryptedSharedPreferences` file next to evaluation store); scope enlarged, so documented boundary: current provides cryptographic one-way hash preventing direct reversal of raw `place-years-…` / `personIds` / `assetId`, but installation-unique namespace remains future work.
- **Test:** same raw `place-years-22.54321,114.06789` persists as `eval-` 16 hex, file `not contains 22.54321/114.06789/rawId` still pass (`sprint_0_8_1_regression_test.dart:285`).

## 3a. Spatial High-Latitude Correctness

- **Issue:** fixed `cellSize 0.0045°` + 9-neighbor assumed 111km/° for both lat/lon; at 60°/70° lon meters per degree = `111km*cos(lat)` (≈55km/38km), radius 500m covers `lonDelta 0.009°/0.012°` > cellSize, so true 400m point could be 2–3 cells away and missed.
- **Fix:** `_buildLocationClusters` `memory_engine.dart:156` now latitude-aware: `lonDelta = radius/(111000*cos(lat))`, `lonCells = ceil(lonDelta/cellSize)` (clamped 1–10), `latCells = ceil(latDelta/cellSize)` (1–2). Search iterates `±latCells`/`±lonCells` (at 0° 3×3=9, at 70° 3×7=21) before Haversine `distance <= radius` final check.
- **Tests:** new `P0-2b` in `sprint_0_8_1_regression_test.dart:162` for lat 0°/60°/70° each `~400m same cluster` vs `~700m different cluster` using `_offsetEast` helper (uses `cos(lat)`), all pass. Previous rounding-boundary tests retained.
- **Performance:** 50K median all-rules 352ms → 520ms (+48%), top10 405ms → 642ms; 60K top10 594ms → 820ms; 75K 715ms → 1080ms. Still <2s, no O(n²), high-lat expansion limited to ≤21 cells, acceptable per § Verification.

## 4a. Annual Leap-Year Regression (extra test, no logic change)

- Added `P1-2b` `sprint_0_8_1_regression_test.dart:372` Feb28(2021)/Feb29(2020)/Mar1(2022)/Feb28(2023) with `windowDays 4` → at least one candidate `distinctYearCount >=3`, verifying leap-year `dayOfYear` handling (Feb29 day 60 vs Feb28 day 59 distance 1) does not incorrectly split.

## Verification (0.8.1a)

- `flutter analyze`: `0 errors / 0 warnings`, 46 infos (deprecated compat) — explained above.
- `dart test` `memory_domain`: pass
- `flutter test` `media_library`: 11 pass
- `flutter test` `memory_engine`: 31 pass (27 + 4 new: 3 high-lat +1 leap)
- `flutter test` `apps/memory_app`: 7 pass (plus performance)
- `flutter build ios --no-codesign`: pass 17.0MB
- Performance re-run: 50K 642ms / 75K 1080ms top10 (see above), still pass gate `<2s`
- Git: branch `feat/memory-intelligence-v0.8`, HEAD `2a236de` → new `fix: finalize pre-validation correctness cleanup`, no merge to main, pushed to origin.

**Verdict (0.8.1a): PASS — READY FOR DEVICE VALIDATION** (all gates equal 0.8.1 plus hardened crypto and high-lat, analyze 0 warnings, tests pass, iOS build pass, branch pushed, main not merged).

