import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';

/// A pinch recognizer that never steals single-finger gestures at 1x.
///
/// Contract (ADR_MEDIA_VIEWER_ARCHITECTURE):
/// - Two pointers down -> accepted immediately (before any movement), so it
///   wins the arena over PageView's horizontal drag and the dismiss drag.
/// - One pointer -> only accepted when [canPan] is true (the photo is
///   zoomed); otherwise the recognizer rejects itself on first movement so
///   PageView (horizontal) and the dismiss drag (vertical) keep ownership.
/// - With one of two pointers lifted, the remaining finger continues as a pan.
class PinchPanRecognizer extends OneSequenceGestureRecognizer {
  PinchPanRecognizer({
    required this.canPan,
    required this.onBegin,
    required this.onUpdate,
    required this.onEnd,
    super.debugOwner,
  });

  final bool Function() canPan;
  final void Function(PinchPanBeginDetails details) onBegin;
  final void Function(PinchPanUpdateDetails details) onUpdate;
  final void Function(PinchPanEndDetails details) onEnd;

  final Map<int, Offset> _pointers = {};
  VelocityTracker? _tracker;
  bool _accepted = false;
  bool _isPan = false;
  bool _moved = false;
  double _lastSpan = 0;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointers.isEmpty) {
      _tracker = VelocityTracker.withKind(event.kind);
      _accepted = false;
      _isPan = false;
      _moved = false;
    }
    startTrackingPointer(event.pointer, event.transform);
    _pointers[event.pointer] = event.position;
    _tracker?.addPosition(event.timeStamp, event.position);
    if (_pointers.length >= 2) {
      _accept(isPan: false);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent && _pointers.containsKey(event.pointer)) {
      _pointers[event.pointer] = event.position;
      _tracker?.addPosition(event.timeStamp, event.position);
      if (!_accepted) {
        _moved = _moved || event.delta.distance > kTouchSlop;
        if (!_moved) return;
        if (canPan()) {
          _accept(isPan: true);
        } else {
          resolve(GestureDisposition.rejected);
          _reset();
          return;
        }
      }
      _fireUpdate();
    } else if (event is PointerUpEvent) {
      _pointers.remove(event.pointer);
      if (_pointers.isEmpty) {
        if (_accepted) {
          final velocity = _tracker?.getVelocity() ?? Velocity.zero;
          onEnd(PinchPanEndDetails(velocity: velocity, isPan: _isPan));
        }
        resolve(
          _accepted ? GestureDisposition.accepted : GestureDisposition.rejected,
        );
        _reset();
      } else {
        // One finger lifted: continue with the remaining finger as pan.
        if (_accepted) _accept(isPan: true);
      }
    } else if (event is PointerCancelEvent) {
      _pointers.remove(event.pointer);
      if (_pointers.isEmpty) {
        if (_accepted) {
          onEnd(
            PinchPanEndDetails(
              velocity: Velocity.zero,
              isPan: _isPan,
              cancelled: true,
            ),
          );
        }
        _reset();
      }
    }
  }

  void _accept({required bool isPan}) {
    _accepted = true;
    _isPan = isPan;
    resolve(GestureDisposition.accepted);
    _recomputeSpan();
    onBegin(PinchPanBeginDetails(focalPoint: _focalPoint(), isPan: isPan));
  }

  void _fireUpdate() {
    final count = _pointers.length;
    if (count >= 2) {
      final span = _currentSpan();
      var ratio = 1.0;
      if (_lastSpan > 0 && span > 0) ratio = span / _lastSpan;
      _lastSpan = span;
      onUpdate(
        PinchPanUpdateDetails(
          focalPoint: _focalPoint(),
          scaleDelta: ratio,
          pointerCount: count,
        ),
      );
    } else if (count == 1) {
      onUpdate(
        PinchPanUpdateDetails(
          focalPoint: _pointers.values.first,
          scaleDelta: 1,
          pointerCount: 1,
        ),
      );
    }
  }

  double _currentSpan() {
    if (_pointers.length < 2) return 0;
    final it = _pointers.values.iterator;
    it.moveNext();
    final a = it.current;
    it.moveNext();
    final b = it.current;
    return (a - b).distance;
  }

  void _recomputeSpan() {
    _lastSpan = _currentSpan();
  }

  Offset _focalPoint() {
    if (_pointers.isEmpty) return Offset.zero;
    if (_pointers.length == 1) return _pointers.values.first;
    var x = 0.0;
    var y = 0.0;
    for (final p in _pointers.values) {
      x += p.dx;
      y += p.dy;
    }
    return Offset(x / _pointers.length, y / _pointers.length);
  }

  void _reset() {
    _pointers.clear();
    _accepted = false;
    _isPan = false;
    _moved = false;
    _lastSpan = 0;
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'pinch_pan';
}

class PinchPanBeginDetails {
  const PinchPanBeginDetails({required this.focalPoint, required this.isPan});
  final Offset focalPoint;
  final bool isPan;
}

class PinchPanUpdateDetails {
  const PinchPanUpdateDetails({
    required this.focalPoint,
    required this.scaleDelta,
    required this.pointerCount,
  });
  final Offset focalPoint;
  final double scaleDelta;
  final int pointerCount;
}

class PinchPanEndDetails {
  const PinchPanEndDetails({
    required this.velocity,
    required this.isPan,
    this.cancelled = false,
  });
  final Velocity velocity;
  final bool isPan;
  final bool cancelled;
}

/// Tap + double-tap in ONE recognizer.
///
/// Flutter's DoubleTapGestureRecognizer cannot coexist with an instantly-
/// accepting tap recognizer: it relies on holding the first tap's arena,
/// which an immediate tap recognizer steals (that hold is exactly what
/// causes the standard ~300ms tap delay). So the viewer owns the sequence:
/// a tap fires immediately; if the next tap lands within the double-tap
/// window, onDoubleTap fires and the shell reverts the chrome toggle.
class TapSequenceRecognizer extends OneSequenceGestureRecognizer {
  TapSequenceRecognizer({
    required this.onTap,
    required this.onDoubleTap,
    super.debugOwner,
  });

  final VoidCallback onTap;
  final ValueChanged<Offset> onDoubleTap;

  static const Duration _doubleTapWindow = Duration(milliseconds: 300);
  static const double _doubleTapSlop = 48;

  Offset? _downPosition;
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;
  bool _moved = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    _downPosition = event.position;
    _moved = false;
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent && _downPosition != null) {
      if ((event.position - _downPosition!).distance > kTouchSlop) {
        _moved = true;
        resolve(GestureDisposition.rejected);
        _downPosition = null;
      }
    } else if (event is PointerUpEvent) {
      if (_moved || _downPosition == null) {
        resolve(GestureDisposition.rejected);
        _downPosition = null;
        return;
      }
      resolve(GestureDisposition.accepted);
      _downPosition = null;
      final now = DateTime.now();
      final last = _lastTapTime;
      final lastPosition = _lastTapPosition;
      final isDouble =
          last != null &&
          lastPosition != null &&
          now.difference(last) <= _doubleTapWindow &&
          (event.position - lastPosition).distance <= _doubleTapSlop;
      if (isDouble) {
        _lastTapTime = null;
        _lastTapPosition = null;
        onDoubleTap(event.position);
      } else {
        _lastTapTime = now;
        _lastTapPosition = event.position;
        onTap();
      }
    } else if (event is PointerCancelEvent) {
      resolve(GestureDisposition.rejected);
      _downPosition = null;
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'tap_sequence';
}
