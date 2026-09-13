import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:memory_app/l10n/app_localizations.dart';
import 'package:memory_app/media_viewer/viewer_gesture_policy.dart';
import 'package:memory_app/media_viewer/viewer_media_loader.dart';
import 'package:memory_app/media_viewer/viewer_photo_gestures.dart';
import 'package:memory_domain/memory_domain.dart';

/// One fullscreen photo page: progressive thumb->preview layers plus the
/// zoom/pan transform. Gesture decisions come from [ViewerGesturePolicy];
/// this widget only executes them (ADR decision layer).
class ViewerPhotoView extends StatefulWidget {
  const ViewerPhotoView({
    super.key,
    required this.loader,
    required this.index,
    required this.asset,
    required this.isActive,
    required this.onZoomChanged,
    required this.onDismissUpdate,
    required this.onDismissEnd,
    required this.onTap,
    required this.onDoubleTap,
    this.initialThumb,
    this.maxZoom = 5.0,
  });

  final ViewerMediaLoader loader;
  final int index;
  final MediaAsset asset;
  final bool isActive;
  final ValueChanged<bool> onZoomChanged;
  final ValueChanged<double> onDismissUpdate;
  final ValueChanged<double> onDismissEnd;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final Uint8List? initialThumb;
  final double maxZoom;

  @override
  State<ViewerPhotoView> createState() => _ViewerPhotoViewState();
}

class _ViewerPhotoViewState extends State<ViewerPhotoView>
    with TickerProviderStateMixin {
  final ViewerGesturePolicy _policy = const ViewerGesturePolicy();
  Matrix4 _matrix = Matrix4.identity();
  AnimationController? _motion;
  FrictionSimulation? _flingX;
  FrictionSimulation? _flingY;
  Ticker? _flingTicker;
  bool _zoomed = false;
  bool _rubberBanded = false;

  double get _scale => _matrix.getMaxScaleOnAxis();

  @override
  void initState() {
    super.initState();
    widget.loader.addListener(_onMediaChanged);
  }

  @override
  void didUpdateWidget(ViewerPhotoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && oldWidget.isActive) {
      _stopMotion();
      _matrix = Matrix4.identity();
      if (_zoomed) {
        _zoomed = false;
        widget.onZoomChanged(false);
      }
    }
  }

  @override
  void dispose() {
    widget.loader.removeListener(_onMediaChanged);
    _stopMotion();
    super.dispose();
  }

  void _onMediaChanged() {
    if (mounted) setState(() {});
  }

  // --- Matrix helpers (strict T·S form: translate then scale) -------------

  void _applyTransform(Offset focal, double scaleDelta) {
    // Keep the content pixel under [focal] stationary while scaling.
    final s = _scale;
    final tx = _matrix.storage[12];
    final ty = _matrix.storage[13];
    final contentX = (focal.dx - tx) / s;
    final contentY = (focal.dy - ty) / s;
    final next = _policy.clampZoom(s * scaleDelta);
    final newTx = focal.dx - contentX * next;
    final newTy = focal.dy - contentY * next;
    _setMatrix(next, newTx, newTy);
  }

  void _pan(Offset delta) {
    _setMatrix(
      _scale,
      _matrix.storage[12] + delta.dx,
      _matrix.storage[13] + delta.dy,
    );
  }

  void _setMatrix(double scale, double tx, double ty) {
    final size = _viewportSize();
    if (size == null || scale <= 1.0) {
      _matrix = Matrix4.identity();
      return;
    }
    final minX = size.width * (1 - scale);
    final minY = size.height * (1 - scale);
    var clampedTx = tx;
    var clampedTy = ty;
    _rubberBanded = false;
    if (tx > 0) {
      clampedTx = tx * _kRubberBand;
      _rubberBanded = true;
    } else if (tx < minX) {
      clampedTx = minX + (tx - minX) * _kRubberBand;
      _rubberBanded = true;
    }
    if (ty > 0) {
      clampedTy = ty * _kRubberBand;
      _rubberBanded = true;
    } else if (ty < minY) {
      clampedTy = minY + (ty - minY) * _kRubberBand;
      _rubberBanded = true;
    }
    _matrix = Matrix4.identity()
      ..translateByDouble(clampedTx, clampedTy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
    _syncZoomed(scale);
    setState(() {});
  }

  static const double _kRubberBand = 0.35;

  Size? _viewportSize() {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) return box.size;
    return null;
  }

  void _syncZoomed(double scale) {
    final next = scale > 1.01;
    if (next != _zoomed) {
      _zoomed = next;
      widget.onZoomChanged(next);
    }
  }

  void _stopMotion() {
    _motion?.stop();
    _motion?.dispose();
    _motion = null;
    _flingTicker?.stop();
    _flingTicker?.dispose();
    _flingTicker = null;
    _flingX = null;
    _flingY = null;
  }

  void _animateTo(Matrix4 target, Duration duration, Curve curve) {
    _stopMotion();
    final controller = AnimationController(vsync: this, duration: duration);
    final animation = Matrix4Tween(
      begin: _matrix,
      end: target,
    ).animate(CurvedAnimation(parent: controller, curve: curve));
    void listener() {
      if (!mounted) return;
      setState(() => _matrix = animation.value);
      _syncZoomed(_matrix.getMaxScaleOnAxis());
    }

    animation.addListener(listener);
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        animation.removeListener(listener);
        controller.dispose();
        if (identical(_motion, controller)) _motion = null;
      }
    });
    _motion = controller;
    controller.forward();
  }

  void _settleAfterGesture() {
    final scale = _scale;
    if (scale <= 1.01) {
      if (_zoomed || _matrix != Matrix4.identity()) {
        _animateTo(
          Matrix4.identity(),
          const Duration(milliseconds: 200),
          Curves.easeOutCubic,
        );
      }
      return;
    }
    // Snap any rubber-band overshoot back into bounds.
    final size = _viewportSize();
    if (size == null) return;
    final minX = size.width * (1 - scale);
    final minY = size.height * (1 - scale);
    final tx = _matrix.storage[12].clamp(minX, 0.0).toDouble();
    final ty = _matrix.storage[13].clamp(minY, 0.0).toDouble();
    final target = Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
    if (_rubberBanded) {
      _animateTo(
        target,
        const Duration(milliseconds: 200),
        Curves.easeOutCubic,
      );
    }
  }

  void _handleDoubleTap(Offset position) {
    if (_scale > 1.01) {
      _animateTo(
        Matrix4.identity(),
        const Duration(milliseconds: 240),
        Curves.easeOutCubic,
      );
      return;
    }
    const zoom = 2.4;
    final tx = position.dx * (1 - zoom);
    final ty = position.dy * (1 - zoom);
    _animateTo(
      Matrix4.identity()
        ..translateByDouble(tx, ty, 0, 1)
        ..scaleByDouble(zoom, zoom, 1, 1),
      const Duration(milliseconds: 240),
      Curves.easeOutCubic,
    );
  }

  // --- Gesture handlers ----------------------------------------------------

  void _onPinchBegin(PinchPanBeginDetails details) {
    _stopMotion();
    _lastPanPoint = details.focalPoint;
  }

  void _onPinchUpdate(PinchPanUpdateDetails details) {
    if (details.pointerCount >= 2) {
      _applyTransform(details.focalPoint, details.scaleDelta);
    } else {
      _pan(details.focalPoint - _lastPanPoint);
    }
    _lastPanPoint = details.focalPoint;
  }

  Offset _lastPanPoint = Offset.zero;

  void _onPinchEnd(PinchPanEndDetails details) {
    if (details.cancelled) {
      _settleAfterGesture();
      return;
    }
    if (details.isPan && _scale > 1.01) {
      final velocity = details.velocity.pixelsPerSecond;
      if (velocity.distance > 120) {
        _startFling(velocity);
        return;
      }
    }
    _settleAfterGesture();
  }

  void _startFling(Offset velocity) {
    if (_viewportSize() == null) return;
    final startTx = _matrix.storage[12];
    final startTy = _matrix.storage[13];
    _flingX = FrictionSimulation(0.015, startTx, velocity.dx);
    _flingY = FrictionSimulation(0.015, startTy, velocity.dy);
    final ticker = createTicker((elapsed) {
      final t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
      final x = _flingX!.x(t);
      final y = _flingY!.x(t);
      if (!_flingX!.isDone(t) && !_flingY!.isDone(t)) {
        _setMatrix(_scale, x, y);
      } else {
        _stopMotion();
        _settleAfterGesture();
      }
    });
    _flingTicker = ticker;
    ticker.start();
  }

  // --- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final size = MediaQuery.sizeOf(context);
    final maxDecode = math.max(size.width, size.height) * dpr;
    final int previewCacheWidth = math.min(
      widget.loader.previewPixelSize,
      maxDecode.round(),
    );

    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        PinchPanRecognizer:
            GestureRecognizerFactoryWithHandlers<PinchPanRecognizer>(
              () => PinchPanRecognizer(
                canPan: () => _zoomed,
                onBegin: _onPinchBegin,
                onUpdate: _onPinchUpdate,
                onEnd: _onPinchEnd,
              ),
              (instance) {},
            ),
        VerticalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
              () => VerticalDragGestureRecognizer(),
              (instance) {
                instance
                  ..onStart = (_) {}
                  ..onUpdate = (details) {
                    widget.onDismissUpdate(details.primaryDelta ?? 0);
                  }
                  ..onEnd = (details) {
                    widget.onDismissEnd(details.primaryVelocity ?? 0);
                  }
                  ..onCancel = () {
                    widget.onDismissEnd(0);
                  };
              },
            ),
        TapSequenceRecognizer:
            GestureRecognizerFactoryWithHandlers<TapSequenceRecognizer>(
              () => TapSequenceRecognizer(
                onTap: widget.onTap,
                onDoubleTap: (globalPosition) {
                  widget.onDoubleTap();
                  final box = context.findRenderObject();
                  final local = box is RenderBox
                      ? box.globalToLocal(globalPosition)
                      : Offset.zero;
                  _handleDoubleTap(local);
                },
              ),
              (instance) {},
            ),
      },
      child: Transform(
        transform: _matrix,
        child: _buildImageLayers(previewCacheWidth),
      ),
    );
  }

  Widget _buildImageLayers(int previewCacheWidth) {
    final l10n = AppLocalizations.of(context)!;
    final thumb = widget.initialThumb ?? widget.loader.thumbFor(widget.index);
    final preview = widget.loader.previewFor(widget.index);
    final failed = widget.loader.isPreviewFailed(widget.index);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumb != null)
          Image.memory(
            thumb,
            key: ValueKey('thumb-${widget.asset.id}'),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
          )
        else
          const SizedBox.shrink(),
        if (preview != null)
          Image.memory(
            preview,
            key: ValueKey('preview-${widget.asset.id}'),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            filterQuality: FilterQuality.high,
            cacheWidth: previewCacheWidth,
          ),
        if (failed && preview == null)
          _PreviewError(
            label: l10n.viewerLoadFailed,
            retryLabel: l10n.viewerRetry,
            onRetry: () => widget.loader.retryPreview(widget.index),
          ),
      ],
    );
  }
}

class _PreviewError extends StatelessWidget {
  const _PreviewError({
    required this.label,
    required this.retryLabel,
    required this.onRetry,
  });

  final String label;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 96),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: Colors.white.withValues(alpha: .6),
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .7),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: Text(
              retryLabel,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}
