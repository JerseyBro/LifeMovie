# ADR-007 Memory Explainability

## Status

Accepted

## Decision

Keep memory scoring outside rules and UI. `MemoryRanker` returns `MemoryScoreBreakdown` with a final score and named factors, while each `MemoryCandidate` carries human-readable reasons from the rule that produced it.

## Rationale

The product direction depends on iterating memory intelligence. Scores and reasons need to be inspectable in a developer lab without burying ranking behavior inside widgets or individual rules.

## Consequences

- Debug Memory Lab can show why candidates exist and why they rank.
- Production UI can hide technical score details while still using ranked candidates.
- Ranking weights can change independently from rule discovery.
