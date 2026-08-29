# AI Memory Foundation

AI Native personal memory video app foundation. The product direction is intentionally open: `Memory Discovery → Person Story → Memory Movie → Family Memory`.

## Sprint 0 status

This repository contains a Local First, Privacy First Flutter foundation. The demo uses mock metadata by default so it runs without a photo library. On iOS, `PhotoKitMediaRepository` and a native `MethodChannel` cover permission states and paginated metadata reads; thumbnail and date-range native calls remain explicit follow-up work.

## Sprint 0.5 status

Sprint 0.5 upgrades the foundation to a real-data vertical slice:

```text
iPhone Photos -> PhotoKit -> MediaAsset -> PersistentMediaIndex
  -> MemoryEngine -> MemoryRanker -> Discovery Feed -> Memory Detail
```

On iOS, PhotoKit now provides real metadata batch fetches, date-range queries, media filters and thumbnail requests. Media metadata is persisted locally with Drift/SQLite using `localIdentifier` as the stable primary key. Mock repositories remain available for tests, non-iOS development and UI iteration.

Manual iPhone validation is still pending. Do not mark the product foundation as fully passed until Full/Limited/Denied permission flows and interrupted scans have been exercised on a real device.

## Run

```bash
flutter pub get
flutter test packages/memory_domain/test packages/media_library/test packages/memory_engine/test
cd apps/memory_app && flutter run
```

For the full Sprint 0.5 verification report, see [Sprint 0.5 Report](docs/SPRINT_0_5_REPORT.md).

## Architecture entry points

- `packages/memory_domain`: platform-independent models.
- `packages/media_library`: normalized media access, permission abstraction, mock repository and local index.
- `packages/memory_engine`: rule registry, discovery rules and ranking.
- `packages/ai_gateway`: swappable AI provider interface; Mock is the default.
- `apps/memory_app`: thin composition root and demo screens.
- [Architecture V0](docs/architecture/ARCHITECTURE_V0.md)

Original photos and videos are not uploaded by this foundation.
