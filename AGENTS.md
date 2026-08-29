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

## Forbidden in Sprint 0 / 0.5

No account system, family sharing, cloud album, payment, complex AI, identity-confirmed face recognition, full editor, marketplace, social feed, or real user media/API keys in the repository.

## Sprint 0.5 implementation rules

- Real iOS data must flow through `PhotoKitMediaRepository`, normalized `MediaAsset`, local `PersistentMediaIndex`, `MemoryRule` plugins and `MemoryRanker`.
- PhotoKit types, raw image objects and AV assets stay out of Dart domain models.
- `localIdentifier` is the stable media identity in the database.
- Limited Library changes must be reconciled; do not assume accessible assets are permanent.
- Developer diagnostics must avoid exact GPS, file paths, raw media exports and person identity logs.
- True device validation must be reported separately from automated build/test results.

## Tests and style

Every rule, ranker, repository behavior, permission mapping, and cross-package pipeline needs tests. Run `dart format` and `flutter analyze` before handoff. Prefer simple public interfaces and immutable models.

## Git

One clear task per commit; no real photos, secrets, generated build outputs, or private test material.
