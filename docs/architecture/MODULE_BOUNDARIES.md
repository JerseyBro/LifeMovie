# Module boundaries

| Module | Owns | Must not own |
|---|---|---|
| `memory_domain` | Models and value objects | Flutter/platform APIs |
| `media_library` | Media repository, permissions, normalized index | Discovery/ranking |
| `memory_engine` | Rules, candidate discovery, score breakdown, ranking, dedup, diversity, sensitivity guard, local evaluation contracts | UI, PhotoKit, provider calls |
| `ai_gateway` | AI interface and providers | Media permissions or widgets |
| `media_processing` | Movie renderer boundary | Product editor |
| `analytics` | Event interface/providers | Business decisions |
| `design_system` | Tokens and reusable visual components | Domain rules |
| `apps/memory_app` | Composition, navigation, presentation | Platform API details |

## Actual dependency graph

```text
memory_domain
  <- media_library
  <- memory_engine
  <- ai_gateway
  <- media_processing

design_system
analytics

apps/memory_app
  -> analytics
  -> ai_gateway
  -> design_system
  -> media_library
  -> memory_domain
  -> memory_engine
```

`memory_engine` no longer depends on `media_library`; both depend on `memory_domain`. `design_system` has no business dependency. iOS PhotoKit and SQLite platform details are isolated behind `media_library` and the app composition root.

Sprint 0.8 keeps the same dependency direction:

```text
memory_domain
  <- media_library
  <- memory_engine

design_system
analytics
ai_gateway

apps/memory_app
  -> memory_domain
  -> media_library
  -> memory_engine
  -> design_system
  -> analytics
  -> ai_gateway
```

`personIds` currently remain a derived annotation on `MediaAsset` for injected/mock product validation. They are not native PhotoKit metadata and not a confirmed identity graph. A later Person Intelligence sprint can move this into a separate `media_person_links` style relation if real identity modeling is introduced.

## Public API surface

Consumers should import `package:media_library/media_library.dart`, `package:memory_engine/memory_engine.dart` and `package:memory_domain/memory_domain.dart`. Public media APIs live in `media_repository.dart` and `media_index.dart`; external packages should not import `src/` paths.
