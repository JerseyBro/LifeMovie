# ADR-005 Persistent Media Index

## Status

Accepted

## Decision

Use Drift with SQLite for the Sprint 0.5 media index. Store one row per accessible PhotoKit asset and use `localIdentifier` as the primary key.

## Rationale

The product needs local-first persistence, date/type/place queries, migrations and predictable behavior with large metadata collections. SQLite fits this shape, and Drift gives Dart-side database access with an explicit `schemaVersion`.

## Consequences

- Media index schema starts at version 1.
- Future schema changes must use migrations, not delete-and-rebuild as the formal upgrade path.
- Raw photos, videos, face embeddings, AI captions, vectors and movie timelines stay out of MediaIndex V1.
