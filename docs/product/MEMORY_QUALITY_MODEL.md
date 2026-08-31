# Memory Quality Model

Sprint 0.8 separates algorithmic score from human product evaluation. Sprint 0.8.1 hardens privacy and factual accuracy before 5–10 real-library validation.

## Human evaluation fields

Each `MemoryEvaluation` records:

- Accuracy: 1-5
- Meaningfulness: 1-5
- Surprise: 1-5
- Clarity: 1-5
- Sensitivity: 1-5, where 5 means safe
- Labels (structured, anonymous)
- **Opaque candidate id** `eval-<16hex>` — derived via `MemoryEvaluation.opaqueCandidateId(rawId, type)` with salt `LifeMovie-eval-v1`, never raw `place-years-22.54321,114.06789` / `personId` / `assetId`
- Rule type
- Created time

## Privacy rules (0.8.1)

Evaluation data must not contain real photos, videos, precise GPS, file paths, names, relationship labels, image bytes or private free text. Current feedback is local first and saved as anonymous structured labels.

- **0.8.1:** `memory_evaluations.json` contains only `candidateId: eval-…` and `anonymousCandidateId: eval-…`. Tests assert file `not contains 22.54321/114.06789/rawId`. `InMemory` / `JsonFile` stores keyed by opaque id. Candidate internal id may still be deterministic (`place-years-…`) but never persisted in evaluation.
- Candidate `personIds` are injected/mock for validation only, not PhotoKit identity; they are also hashed before persistence if referenced in evaluation id.

## Accuracy stakes for validation (0.8.1)

The following would directly pollute Meaningful/WOW/Wrong/Sensitivity rates and are therefore blocked before real-user testing:

- Non-consecutive years labeled `连续 X 年` — now `longestConsecutiveYearRun >=3` required.
- Same place split by `toStringAsFixed(1)` boundary or merged by coarse grid — now distance-based `LocationClusterConfig(radiusMeters:500)` with bucket+distance.
- Travel trip missing unlocated photos — now two-phase enrichment with `locationCoverage`.
- Chinese copy owned by engine — now `MemoryCandidateCopyMapper` + ARB placeholders; engine only emits facts/metadata.
- Library >50K silently truncated — now `allAssetsPaged` paginates full library with explicit warning, never silent cap.
