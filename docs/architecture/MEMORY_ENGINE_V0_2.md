# Memory Engine V0.2 (Sprint 0.8 + 0.8.1)

Sprint 0.8 keeps the Sprint 0 plugin model and adds product-oriented memory intelligence without adding a new architecture layer. Sprint 0.8.1 hardens correctness before validation without new rules or backends.

## Year Metrics (0.8.1)

`YearMetrics` centralizes year semantics to avoid `years.length` ambiguity:

- `distinctYearCount` — number of distinct calendar years
- `calendarSpanYears = lastYear - firstYear + 1`
- `longestConsecutiveYearRun` — longest consecutive-year streak
- `firstYear`, `lastYear`

Rules expose the above in `metadata` and use them for copy decisions. Only `longestConsecutiveYearRun >=3` may render `连续 X 年`; otherwise `X 个不同年份` / `多次`. `PersonTimeline` and `LongTermEvolution` use `calendarSpanYears` for `跨越 X 年`.

## Location Clustering (0.8.1)

Replaces `toStringAsFixed(1)` coarse grid with distance-based clustering:

- `LocationClusterConfig(radiusMeters:500, minimumAssets:3)` — configurable, default 500m.
- Bucket cells `≈ radius/111km`, 9-neighbor check with haversine `distance <= radius`, avoids O(n²) (50K top10 ~405ms, 60K ~594ms).
- Used in `SamePlaceRule`, `SamePlaceAcrossYearsRule`, `TravelStoryRule`, `LongTermEvolutionRule(place)`, `FirstMemoryRule(place)`.
- No H3/Geohash/SDK, simple bucket+distance.

## Rules

- `SamePlaceAcrossYearsRule`: groups by distance clusters, sessions `sessionGap 21d`, requires `distinctYearCount >=3` and `visitCount >=3`, routine-place penalty via `routineVisitThreshold`/`routineMonthThreshold`. Emits `distinctYearCount`/`calendarSpanYears`/`longestConsecutiveYearRun` etc.
- `FirstMemoryRule`: earliest `firstWindow 2d` for person/place clusters, claims only `相册里最早记录`.
- `TravelStoryRule`: **two-phase** — Phase A detects travel window from located assets (`maxGap 2d`, `minimumDays`, `minimumPlaceCount`, `routeDistanceKm`); Phase B enriches with **all** assets in `[start,end]`, emitting `locatedMediaCount`/`totalMediaCount`/`locationCoverage`. Ranking `accuracyConfidence` uses `locationCoverage`.
- `PersonTimelineRule`: injected/mock `personIds` only, metadata `distinctYearCount`/`calendarSpanYears`/`longestConsecutiveYearRun`.
- `AnnualTogetherRule`: circular `dayOfYear` distance `<=windowDays 24` with wrap-around merge (Dec31 + Jan1 same window), emits `distinctYearCount`/`longestConsecutiveYearRun`.
- `LongTermEvolutionRule`: long-term span per person/place cluster, title uses `calendarSpanYears >=4` → `跨越 X 年` else `X 个年份`, no appearance judgment.

Existing `DateClusterRule`, `SamePlaceRule` and `YearRecapRule` remain.

## Ranking V0.2 (unchanged factors, 0.8.1 accuracy tweak)

`WeightedMemoryRanker` remains independent from rules and UI. Factors:

- accuracyConfidence (travel now `locationCoverage`)
- timeSpan
- recurrence (`distinctYearCount` / `visitCount`)
- mediaDiversity
- rarity (routine penalty)
- visualCoverage
- storyPotential
- sensitivityPenalty

Final score is positive signals minus risk penalty, clamped to 0-100.

## Candidate post-processing

- `MemorySensitivityGuard` **V0.1**: keyword + structured flags → penalty/hide, not semantic inference. See § Non-goals.
- `MemoryCandidateDeduplicator` removes high-overlap stories using precomputed sets and time overlap.
- `FeedDiversityController` prevents the top feed from showing only one rule type.
- `RepresentativeMediaSelector` favors favorites, video/photo diversity, year coverage and near-duplicate avoidance.

## Evaluation & Presentation Boundaries (0.8.1)

- `MemoryEvaluation.candidateId` is opaque `eval-<16hex>` derived via `opaqueCandidateId(rawId, type)` (FNV-1a + salt), persisted as `anonymousCandidateId`. Raw `place-years-*, personId, assetId` never in JSON.
- Engine no longer owns final Chinese copy. `safeTitleTemplate`/`safeSubtitleTemplate` are deprecated; formal UI uses `MemoryCandidateCopyMapper` + `app_zh.arb`/`app_en.arb` (13 new keys, placeholders).

## Non-goals

No face recognition, relationship inference, LLM story generation, embeddings, vector search, movie rendering or cloud processing were added. Sensitivity remains keyword-based.
