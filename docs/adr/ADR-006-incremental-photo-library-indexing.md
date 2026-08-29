# ADR-006 Incremental Photo Library Indexing

## Status

Accepted

## Decision

Sprint 0.5 implements reconciliation rather than real-time PhotoKit observation. The app fetches the currently accessible asset set in bounded batches, upserts new/modified assets and deletes stale rows that are no longer accessible.

## Rationale

Limited Library access can change after the first scan. Reconciliation handles Full, Limited add/remove and permission recovery without assuming a stable asset set. `PHPhotoLibraryChangeObserver` remains compatible with the architecture, but it is not required to prove the real-data vertical slice.

## Consequences

- App launch or manual refresh can repair the local index.
- Scan cancellation records status and checkpoint offset.
- Real-time updates are a future enhancement and must not be described as implemented.
