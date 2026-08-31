# Memory Engine V0.2

Sprint 0.8 keeps the Sprint 0 plugin model and adds product-oriented memory intelligence without adding a new architecture layer.

## Rules

- `SamePlaceAcrossYearsRule`: finds repeated visits to a coarse place across multiple calendar years. It uses visit sessions and routine-place penalty signals so high-frequency home-like locations are ranked down rather than labeled as home.
- `FirstMemoryRule`: finds the earliest media group in the library for an injected person or coarse place. It only claims “相册里最早记录”, not real-world first meeting or first visit.
- `TravelStoryRule`: finds continuous time windows with location movement, media density, duration and video diversity.
- `PersonTimelineRule`: uses injected/mock `personIds` only.
- `AnnualTogetherRule`: finds recurring annual windows for an injected person without mapping to festivals or relationships.
- `LongTermEvolutionRule`: describes long-term person/place time span without judging appearance or body changes.

Existing `DateClusterRule`, `SamePlaceRule` and `YearRecapRule` remain available for baseline validation.

## Ranking V0.2

`WeightedMemoryRanker` remains independent from rules and UI. Factors are:

- accuracyConfidence
- timeSpan
- recurrence
- mediaDiversity
- rarity
- visualCoverage
- storyPotential
- sensitivityPenalty

Final score is positive signals minus risk penalty, clamped to 0-100.

## Candidate post-processing

- `MemorySensitivityGuard` flags risky text/metadata and hides high-risk candidates.
- `MemoryCandidateDeduplicator` removes high-overlap stories using precomputed media/person/place sets and time overlap.
- `FeedDiversityController` prevents the top feed from showing only one rule type.
- `RepresentativeMediaSelector` favors favorites, video/photo diversity, year coverage and near-duplicate avoidance.

## Non-goals

No face recognition, relationship inference, LLM story generation, embeddings, vector search, movie rendering or cloud processing were added.
