# Agent instructions

## Goal

Build an AI Native personal memory app that helps people rediscover stories already present in their photo library.

## Principles

- Local First and Privacy First: metadata/indexing are local; originals are never uploaded by default.
- Keep platform APIs behind repositories/adapters. Domain code must not import PhotoKit, PHAsset, AVFoundation or iOS types.
- Memory discovery is plugin-based. Add a `MemoryRule`; do not grow a God Service or put weights in widgets.
- Keep app presentation thin and business logic testable.

## Boundaries

`apps/memory_app` is the composition root. `memory_domain` has no Flutter dependency. `media_library` owns normalized media and permission APIs. `memory_engine` owns candidates and ranking. `ai_gateway`, `media_processing`, and `analytics` are replaceable boundaries.

## Current stage

Sprint 0.8 Memory Intelligence Prototype.

The product is Simplified Chinese first. The immediate goal is not an AI video editor; it is Memory Discovery that can surface meaningful, surprising, safe and explainable stories from a local photo library.

## Engineering principles

- Simple Architecture over premature framework layers.
- Local First and Privacy First.
- Explainable candidates over black-box magic.
- Cross-platform maintainability.
- Chinese-first product UI; English localization may be key-compatible but not fully copy-polished.

## Forbidden in Sprint 0 / 0.5 / 0.8

No account system, family sharing, cloud album, payment, complex AI, identity-confirmed face recognition, full editor, marketplace, social feed, or real user media/API keys in the repository.

Do not add backend, cloud sync, commercial analytics, production face identity, vector database, LLM story pipeline, FFmpeg editor, subscription, social/community, template marketplace, mascot/IP or broad branding work unless the user explicitly expands scope.

## Sprint 0.5 implementation rules

- Real iOS data must flow through `PhotoKitMediaRepository`, normalized `MediaAsset`, local `PersistentMediaIndex`, `MemoryRule` plugins and `MemoryRanker`.
- PhotoKit types, raw image objects and AV assets stay out of Dart domain models.
- `localIdentifier` is the stable media identity in the database.
- Limited Library changes must be reconciled; do not assume accessible assets are permanent.
- Developer diagnostics must avoid exact GPS, file paths, raw media exports and person identity logs.
- True device validation must be reported separately from automated build/test results.

## Sprint 0.8 implementation rules

- Add memory intelligence as `MemoryRule` plugins; do not move rule logic into widgets or a God service.
- Ranking, deduplication, diversity and sensitivity checks stay in `memory_engine`.
- Formal user UI must use safe Chinese copy and avoid technical terms like MemoryCandidate, Rule, Score, Signal or MediaIndex.
- Debug-only Memory Lab may expose technical rule names, score breakdown and raw reasons, but must not log exact GPS, photo paths, image bytes, person names or private user text.
- `personIds` are injected/derived annotations for product validation only, not PhotoKit native metadata and not confirmed identity.

## Tests and style

Every rule, ranker, repository behavior, permission mapping, and cross-package pipeline needs tests. Run `dart format` and `flutter analyze` before handoff. Prefer simple public interfaces and immutable models.

## Git

One clear task per commit; no real photos, secrets, generated build outputs, or private test material.
