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

Sprint 1.0 Native Media Experience & Memory Discovery is complete (machine-verified) on branch `feat/native-memory-experience-v1.0` (not merged to main); real-device Gates (Media UX ≥B / Discovery 3-taps / Recovery / First WOW) await manual validation. See `docs/SPRINT_1_0_REPORT.md`.

Sprint 0.9 froze as Prototype Milestone (branch `feat/product-experience-v0.9` @ `11bc600`). Sprint 1.0 delivered Viewer V3 (explicit gesture ownership, progressive loading, filmstrip, zoom-open transition), Info sheet, non-destructive editor (`EditRecipe`), Discovery Home V3 (Discover/Timeline/Search), `MemoryDiscoveryQuery` filter model, and DiscoveryDimensionIndex. Key docs: `docs/adr/ADR_MEDIA_VIEWER_ARCHITECTURE.md`, `docs/product/PHOTO_EXPERIENCE_BENCHMARK.md`, `docs/product/DISCOVERY_HOME_BENCHMARK.md`.

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

## Sprint 0.9 implementation rules

- Treat Memory Detail and photo browsing as the immediate product surface; all visible gallery/timeline photos must open the fullscreen viewer at the tapped index.
- Use feed thumbnails for feed cards, medium preview for detail hero, and high-quality preview for fullscreen viewer. Do not load originals by default.
- Fullscreen viewer must support swipe, double-tap zoom, tap chrome toggle, close, position indicator, and downward dismiss while avoiding obvious PageView/zoom conflicts.
- First WOW evaluation is internal/debug only and must store local, anonymized feedback labels; do not upload real media or personal identifiers.
- Presentation files should remain small enough for handoff; split screens/widgets incrementally instead of introducing a new framework.

## Sprint 1.0 implementation rules

- Viewer gesture ownership follows `docs/adr/ADR_MEDIA_VIEWER_ARCHITECTURE.md`: exactly one owner per touch sequence (paging / dismiss / zoom / zoomedPan); do not add competing GestureDetectors or flip PageView physics mid-gesture.
- Media loading keeps the quality ladder (grid 360 / feed 720 / detail 1200 / viewer 2200 / original only explicit) with the viewer LRU budget and out-of-window cancellation; never reintroduce unbounded byte maps.
- Photo editing is non-destructive by contract: only `EditRecipe` metadata may be stored (`EditRecipeStore`); originals, PhotoKit metadata and export writes stay untouched unless the user explicitly expands scope.
- Discovery UI mutates `MemoryDiscoveryQuery` (AND across dimensions, OR within); filtering/sorting must go through `DiscoveryQueryEngine` — never re-rank or rescan in widgets.
- Explore sections render only when real data exists (`DiscoveryDimensionSummary`); People requires reliable person grouping and uses neutral copy without identity or relationship inference.
- Bottom chrome only exposes implemented actions; no placeholder buttons.

## Tests and style

Every rule, ranker, repository behavior, permission mapping, and cross-package pipeline needs tests. Run `dart format` and `flutter analyze` before handoff. Prefer simple public interfaces and immutable models.

## Git

One clear task per commit; no real photos, secrets, generated build outputs, or private test material.

<!-- JAES:BEGIN -->
# JAES Lite

开始任务前读取：

- `.jaes/ENTRY.md`
- `.jaes/AGENTS.md`
- `.jaes/projects/lifemovie/PROJECT.md`
- `.jaes/projects/lifemovie/ARCHITECTURE.md`
- `.jaes/projects/lifemovie/BOUNDARIES.md`
- `.jaes/projects/lifemovie/STATUS.md`
- 当前任务 Skill：`.jaes/skills/*/SKILL.md`

当前 tracked code 是事实来源。
JAES 生成缓存不得直接编辑。
仓库本地规则与 JAES 规则冲突时，停止并报告。
<!-- JAES:END -->
