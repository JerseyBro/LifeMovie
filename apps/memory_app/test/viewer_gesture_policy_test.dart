import 'package:flutter_test/flutter_test.dart';
import 'package:memory_app/media_viewer/viewer_gesture_policy.dart';

void main() {
  const policy = ViewerGesturePolicy();

  group('single finger ownership', () {
    test('1x horizontal belongs to paging', () {
      expect(
        policy.resolveSingleFinger(
          zoomed: false,
          axis: ViewerAxisDominance.horizontal,
        ),
        ViewerGestureOwner.pageView,
      );
    });

    test('1x vertical belongs to interactive dismiss', () {
      expect(
        policy.resolveSingleFinger(
          zoomed: false,
          axis: ViewerAxisDominance.vertical,
        ),
        ViewerGestureOwner.dismiss,
      );
    });

    test('zoomed photo owns every direction until back to 1x', () {
      for (final axis in ViewerAxisDominance.values) {
        expect(
          policy.resolveSingleFinger(zoomed: true, axis: axis),
          ViewerGestureOwner.pan,
          reason: 'ADR invariant: zoom > 1 blocks paging and dismiss',
        );
      }
    });

    test('locked page scroll yields no owner', () {
      expect(
        policy.resolveSingleFinger(
          zoomed: false,
          axis: ViewerAxisDominance.horizontal,
          pageScrollable: false,
        ),
        ViewerGestureOwner.none,
      );
    });
  });

  group('multi finger ownership', () {
    test('pinch always zooms regardless of zoom state', () {
      expect(policy.resolveMultiFinger(zoomed: false), ViewerGestureOwner.zoom);
      expect(policy.resolveMultiFinger(zoomed: true), ViewerGestureOwner.zoom);
    });
  });

  group('dismiss completion', () {
    test('completes on distance threshold', () {
      expect(policy.shouldCompleteDismiss(distance: 130, velocity: 0), isTrue);
    });

    test('completes on velocity threshold', () {
      expect(policy.shouldCompleteDismiss(distance: 20, velocity: 800), isTrue);
    });

    test('springs back below both thresholds', () {
      expect(
        policy.shouldCompleteDismiss(distance: 60, velocity: 300),
        isFalse,
      );
    });

    test('downward and upward drags both count (system Photos behavior)', () {
      expect(policy.shouldCompleteDismiss(distance: -140, velocity: 0), isTrue);
    });
  });

  group('zoom clamping', () {
    test('clamps between 1x and max zoom', () {
      expect(policy.clampZoom(0.4), 1.0);
      expect(policy.clampZoom(2.5), 2.5);
      expect(policy.clampZoom(9), policy.maxZoom);
    });
  });

  group('axis dominance', () {
    test('classifies dominant axis with slop', () {
      expect(
        policy.dominantAxis(const Offset(40, 2)),
        ViewerAxisDominance.horizontal,
      );
      expect(
        policy.dominantAxis(const Offset(2, 40)),
        ViewerAxisDominance.vertical,
      );
      expect(
        policy.dominantAxis(const Offset(2, 2)),
        ViewerAxisDominance.undetermined,
      );
    });
  });
}
