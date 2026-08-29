# ADR-002 Media abstraction

Status: accepted

All platform media access goes through `MediaRepository`. The domain uses `MediaAsset`, never PhotoKit types, enabling Mock and future Android adapters.
