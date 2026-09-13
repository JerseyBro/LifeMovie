import 'dart:ui' show Offset;

/// Decision table for Media Viewer V3 gesture arbitration.
///
/// ADR: docs/adr/ADR_MEDIA_VIEWER_ARCHITECTURE.md
///
/// The viewer must guarantee that exactly one gesture owner owns any active
/// touch sequence. This policy is the pure, unit-testable core of that
/// contract; the widget layer only executes the decisions.
enum ViewerGestureOwner {
  /// Horizontal page swipe owned by the PageView physics.
  pageView,

  /// Interactive vertical dismiss owned by the viewer shell.
  dismiss,

  /// Pinch zoom owned by the photo transform.
  zoom,

  /// Single-finger pan of a zoomed photo.
  pan,

  /// No owner: the sequence is ignored (e.g. locked page scroll).
  none,
}

enum ViewerAxisDominance { horizontal, vertical, undetermined }

class ViewerGesturePolicy {
  const ViewerGesturePolicy({
    this.maxZoom = 5.0,
    this.dismissDistanceThreshold = 120,
    this.dismissVelocityThreshold = 700,
    this.axisSlop = 8,
  });

  final double maxZoom;
  final double dismissDistanceThreshold;
  final double dismissVelocityThreshold;
  final double axisSlop;

  /// Single-finger decision. The zoomed photo always owns the sequence so
  /// paging and dismiss never fight the zoomed pan (ADR invariant 1).
  ViewerGestureOwner resolveSingleFinger({
    required bool zoomed,
    required ViewerAxisDominance axis,
    bool pageScrollable = true,
  }) {
    if (zoomed) return ViewerGestureOwner.pan;
    return switch (axis) {
      ViewerAxisDominance.vertical => ViewerGestureOwner.dismiss,
      ViewerAxisDominance.horizontal =>
        pageScrollable ? ViewerGestureOwner.pageView : ViewerGestureOwner.none,
      ViewerAxisDominance.undetermined => ViewerGestureOwner.none,
    };
  }

  /// Two or more fingers always zoom, regardless of axis. The pinch
  /// recognizer accepts on the second pointer down so it wins the arena
  /// before any drag recognizer can.
  ViewerGestureOwner resolveMultiFinger({bool zoomed = false}) =>
      ViewerGestureOwner.zoom;

  /// Dismiss completes when the user dragged far enough or flicked fast
  /// enough (ADR: distance threshold OR velocity threshold).
  bool shouldCompleteDismiss({
    required double distance,
    required double velocity,
  }) =>
      distance.abs() >= dismissDistanceThreshold ||
      velocity.abs() >= dismissVelocityThreshold;

  double clampZoom(double scale) => scale.clamp(1.0, maxZoom);

  ViewerAxisDominance dominantAxis(Offset delta) {
    final dx = delta.dx.abs();
    final dy = delta.dy.abs();
    if (dx < axisSlop && dy < axisSlop) return ViewerAxisDominance.undetermined;
    if (dx >= dy) return ViewerAxisDominance.horizontal;
    return ViewerAxisDominance.vertical;
  }
}
