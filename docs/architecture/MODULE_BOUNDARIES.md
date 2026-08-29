# Module boundaries

| Module | Owns | Must not own |
|---|---|---|
| `memory_domain` | Models and value objects | Flutter/platform APIs |
| `media_library` | Media repository, permissions, normalized index | Discovery/ranking |
| `memory_engine` | Rules, candidate discovery, score breakdown | UI, PhotoKit, provider calls |
| `ai_gateway` | AI interface and providers | Media permissions or widgets |
| `media_processing` | Movie renderer boundary | Product editor |
| `analytics` | Event interface/providers | Business decisions |
| `design_system` | Tokens and reusable visual components | Domain rules |
| `apps/memory_app` | Composition, navigation, presentation | Platform API details |
