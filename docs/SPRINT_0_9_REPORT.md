# Sprint 0.9 Product Experience & First WOW Report

## 1. Scope

Sprint 0.9 continues from Sprint 0.8.1 on `feat/product-experience-v0.9`. It does not add backend, LLM story generation, face recognition, cloud sync, movie rendering, or a new architecture.

Target: make the existing real-data Memory Discovery prototype usable enough for first WOW validation by improving Memory Detail, gallery/photo browsing, preview loading tiers, and internal feedback capture.

## 2. Baseline Inherited

- Sprint 0: Flutter workspace, domain/media/rule foundations.
- Sprint 0.5: PhotoKit adapter, PersistentMediaIndex, real-data vertical slice.
- Sprint 0.8: memory intelligence rules, Ranking V0.2, sensitivity/dedup/diversity, Chinese product UI, Memory Lab V0.2.
- Sprint 0.8.1: year semantics, distance location clustering, travel enrichment, opaque evaluation ids, CopyMapper/ARB boundary, large-library paging.

Manual device validation and real-user validation remain pending unless explicitly recorded by a human test run.

## 3. Implemented in Sprint 0.9

### Memory Detail V2 browsing

- Hero media now loads via `loadPreview(maxPixelSize: 1200)` instead of feed thumbnail size.
- Representative grid photos are tappable.
- Timeline grid photos are tappable.
- Each visible grid opens fullscreen viewer with the tapped item as `initialIndex`.

### Fullscreen Viewer V2

- Added `FullscreenPhotoViewerPage`.
- Supports PageView swipe, high-quality preview request (`maxPixelSize: 2200`), top close button, position indicator, tap chrome toggle, double-tap zoom, pinch zoom through `InteractiveViewer`, and downward dismiss when not zoomed.
- PageView is disabled while zoomed to reduce swipe/zoom conflict.
- Single tap no longer closes the viewer; it only hides/shows chrome.

### Preview-size policy

- Feed cards: `feedPreviewSize = 720`, thumbnail path.
- Detail hero: `detailPreviewSize = 1200`, preview path.
- Viewer: `viewerPreviewSize = 2200`, preview path.
- Grid: `gridPreviewSize = 360`, thumbnail path.

### First WOW internal evaluation

- Debug feed cards expose quick local feedback:
  - 👍 值得回看
  - ✨ 没想到
  - 😐 一般
  - ❌ 不准确
  - 🙈 不想看到
- Feedback continues through `MemoryEvaluation.forCandidate`, preserving opaque local candidate ids.

### Presentation split

- `apps/memory_app/lib/main.dart` reduced to 877 lines.
- Extracted:
  - `apps/memory_app/lib/screens/photo_viewer_page.dart`
  - `apps/memory_app/lib/screens/memory_lab_page.dart`
  - `apps/memory_app/lib/widgets/media_preview.dart`

No new state management framework or Clean Architecture rewrite was introduced.

## 4. Files Changed

- Modified `AGENTS.md`: current stage and Sprint 0.9 handoff rules.
- Modified `apps/memory_app/lib/main.dart`: Detail/gallery wiring, debug First WOW feedback, extracted viewer/lab/preview implementation.
- Added `apps/memory_app/lib/screens/photo_viewer_page.dart`: fullscreen viewer.
- Added `apps/memory_app/lib/screens/memory_lab_page.dart`: extracted debug lab.
- Added `apps/memory_app/lib/widgets/media_preview.dart`: thumbnail/preview loading widgets and size constants.
- Added `apps/memory_app/test/photo_viewer_page_test.dart`: viewer and preview-size contract tests.
- Modified `apps/memory_app/test/copy_mapper_test.dart`: removed deprecated safe-template dependency.
- Modified `apps/memory_app/test/vertical_slice_test.dart`: validates CopyMapper output instead of engine safe template.
- Modified `packages/memory_engine/lib/memory_engine.dart` and legacy tests: keep public deprecation warnings for external callers while suppressing internal compatibility-field noise.

## 5. Tests Added

- Viewer opens at requested initial index and swipes pages.
- Viewer tap toggles chrome without closing.
- Media preview separates feed thumbnail requests from detail/high-quality preview requests.

## 6. Performance Evidence

Latest app test synthetic baseline, macOS `ADa-Yvonne.local`, Flutter test mode, in-memory SQLite, warm-up discarded:

| Dataset | Reconcile | Date query | Place query | All rules | Ranking | Dedup | Top 10 | RSS delta |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1K | 6 ms | 0 ms | 1 ms | 8 ms | 4 ms | 0 ms | 15 ms | +1 MB |
| 10K | 44 ms | 1 ms | 14 ms | 93 ms | 9 ms | 5 ms | 102 ms | +0 MB |
| 50K | 246 ms | 7 ms | 77 ms | 478 ms | 58 ms | 28 ms | 565 ms | +26 MB |

Smoke:

- 60K: top10 704 ms.
- 75K: top10 963 ms.

These are synthetic metadata tests, not real-device Photos timing.

## 7. Validation Status

- `dart analyze`:
  - `packages/ai_gateway`: pass, no issues.
  - `packages/analytics`: pass, no issues.
  - `packages/media_processing`: pass, no issues.
  - `packages/memory_domain`: pass, no issues.
  - `packages/memory_engine`: pass, no issues.
- `dart test`:
  - `packages/memory_domain`: pass.
  - `packages/memory_engine`: pass, 31 tests.
  - `packages/ai_gateway`, `packages/analytics`, `packages/media_processing`: no dart test target configured.
- `flutter analyze`:
  - `packages/design_system`: pass, no issues.
  - `packages/media_library`: pass, no issues.
  - `apps/memory_app`: pass, no issues.
- `flutter test`:
  - `packages/media_library`: pass, 11 tests.
  - `apps/memory_app`: pass, 10 tests.
  - `packages/design_system`: no Flutter test files.
- `flutter build ios --debug --no-codesign` in `apps/memory_app`: pass, built `build/ios/iphoneos/Runner.app`.

Direct `flutter analyze` at repo root is not the authoritative command for this repository because the root `pubspec.yaml` only owns Melos and not the app/package dependency graph. Package-scoped analyze/test above is the verified workspace result.

## 8. Device Run Attempt

Available devices from `flutter devices`:

- iPhone 17 Pro simulator.
- Jersey 17 Pro Max wireless, iOS 26.6.
- iPhone 13 was not available; Flutter reported LAN browsing failure for `jersey iphone13`.

Attempted:

```bash
flutter run --debug -d 00008150-000A51AC0208401C --no-pub
```

Result:

- Xcode build completed.
- App install/launch reached UIKit lifecycle output.
- Flutter VM Service was not discovered after 75 seconds over wireless debug; Flutter reported no application errors and recommended using USB / local-network permission.
- This is not counted as full real-device smoke validation.

## 9. Pending Manual Validation

Still pending unless separately completed:

- Real iPhone 20K+ library smoke.
- Feed 60s fast scroll.
- Open 10 cards.
- Open 5 details.
- Navigate 20+ viewer photos.
- Pinch/double-tap/tap chrome/downward dismiss on device.
- Normal kill/reopen.
- Scan kill/reopen.
- Limited library add/remove.
- 5–10 real-user Top10 First WOW evaluation.

## 10. Risks

- Viewer gesture behavior is covered by widget tests but still needs real-device touch validation.
- Preview size policy uses PhotoKit preview/thumbnail requests, not original media; true memory pressure must be verified on device.
- First WOW labels capture qualitative feedback, but ranking has not been tuned against real users.
- Memory Lab remains debug-only and technical; formal UI must continue to hide rules/scores/signals.

## 11. Current Verdict

Engineering progress: Sprint 0.9 product-experience implementation complete at code/test/build level.

Final Sprint 0.9 verdict: `PASS WITH MINOR ISSUES`.

Reason: automated package analyze/test and iOS debug build pass; product-experience code for detail/gallery/viewer/feedback is implemented. Remaining issues are manual/real-user validation and wireless debug attach, not failing automated checks.
