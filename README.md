# AI Memory Foundation

AI Native personal memory video app foundation. The product direction is intentionally open: `Memory Discovery → Person Story → Memory Movie → Family Memory`.

## Sprint 0 status

This repository contains a Local First, Privacy First Flutter foundation. The demo uses mock metadata by default so it runs without a photo library. On iOS, `PhotoKitMediaRepository` and a native `MethodChannel` cover permission states and paginated metadata reads; thumbnail and date-range native calls remain explicit follow-up work.

## Run

```bash
flutter pub get
flutter test packages/memory_domain/test packages/media_library/test packages/memory_engine/test
cd apps/memory_app && flutter run
```

## Architecture entry points

- `packages/memory_domain`: platform-independent models.
- `packages/media_library`: normalized media access, permission abstraction, mock repository and local index.
- `packages/memory_engine`: rule registry, discovery rules and ranking.
- `packages/ai_gateway`: swappable AI provider interface; Mock is the default.
- `apps/memory_app`: thin composition root and demo screens.
- [Architecture V0](docs/architecture/ARCHITECTURE_V0.md)

Original photos and videos are not uploaded by this foundation.
