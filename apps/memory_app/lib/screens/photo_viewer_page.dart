import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_app/widgets/media_preview.dart';
import 'package:memory_domain/memory_domain.dart';

class FullscreenPhotoViewerPage extends StatefulWidget {
  const FullscreenPhotoViewerPage({
    super.key,
    required this.repository,
    required this.assets,
    required this.initialIndex,
  });

  final MediaRepository repository;
  final List<MediaAsset> assets;
  final int initialIndex;

  @override
  State<FullscreenPhotoViewerPage> createState() =>
      _FullscreenPhotoViewerPageState();
}

class _FullscreenPhotoViewerPageState extends State<FullscreenPhotoViewerPage>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _motionController;
  late int _currentIndex;
  final Map<int, Future<Uint8List?>> _imageFutures = {};
  final Map<int, Future<Uint8List?>> _thumbFutures = {};
  final TransformationController _transformController =
      TransformationController();
  bool _chromeVisible = true;
  double _scale = 1;
  double _dismissDy = 0;
  bool _interacting = false;
  TapDownDetails? _doubleTapDetails;

  bool get _isZoomed => _scale > 1.01;

  /// Page swipe stays locked for the whole touch sequence once the photo
  /// owns it, even if the scale passes through 1x mid-gesture.
  bool get _pageLocked => _isZoomed || _interacting;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.assets.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.assets.length - 1);
    _currentIndex = initialIndex;
    _pageController = PageController(initialPage: initialIndex);
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _transformController.addListener(_syncScale);
  }

  @override
  void dispose() {
    _transformController.removeListener(_syncScale);
    _transformController.dispose();
    _pageController.dispose();
    _motionController.dispose();
    super.dispose();
  }

  void _syncScale() {
    final next = _transformController.value.getMaxScaleOnAxis();
    if ((next - _scale).abs() > 0.01 && mounted) {
      setState(() => _scale = next);
    }
  }

  Future<Uint8List?> _loadPreview(int index) {
    return _imageFutures.putIfAbsent(index, () {
      final asset = widget.assets[index];
      return widget.repository.loadPreview(
        asset.id,
        maxPixelSize: viewerPreviewSize,
        requestId: 'viewer-${asset.id}-$index',
      );
    });
  }

  /// Fast local thumbnail shown instantly behind the high-quality preview.
  Future<Uint8List?> _loadThumb(int index) {
    return _thumbFutures.putIfAbsent(index, () {
      final asset = widget.assets[index];
      return widget.repository.loadThumbnail(
        asset.id,
        size: gridPreviewSize,
        requestId: 'viewer-thumb-${asset.id}-$index',
      );
    });
  }

  void _runMatrixAnimation(Matrix4 end) {
    _motionController.stop();
    final animation = Matrix4Tween(begin: _transformController.value, end: end)
        .animate(
          CurvedAnimation(parent: _motionController, curve: Curves.easeOut),
        );
    void listener() {
      _transformController.value = animation.value;
    }

    animation.addListener(listener);
    _motionController.reset();
    _motionController.forward().whenComplete(
      () => animation.removeListener(listener),
    );
  }

  void _toggleChrome() {
    setState(() => _chromeVisible = !_chromeVisible);
  }

  void _handleDoubleTap() {
    _motionController.stop();
    if (_isZoomed) {
      _runMatrixAnimation(Matrix4.identity());
      return;
    }
    // Zoom into the tapped point: translate keeps the focal pixel stationary.
    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    const zoom = 2.4;
    _runMatrixAnimation(
      Matrix4.identity()
        ..translateByDouble(
          -position.dx * (zoom - 1),
          -position.dy * (zoom - 1),
          0,
          1,
        )
        ..scaleByDouble(zoom, zoom, 1, 1),
    );
  }

  void _handleInteractionStart(ScaleStartDetails details) {
    _motionController.stop();
    if (!_interacting && mounted) setState(() => _interacting = true);
  }

  void _handleInteractionEnd(ScaleEndDetails details) {
    if (_interacting && mounted) setState(() => _interacting = false);
  }

  void _handleVerticalDragStart(DragStartDetails details) {
    _motionController.stop();
    _dismissDy = 0;
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_pageLocked) return;
    setState(() {
      _dismissDy = (_dismissDy + details.delta.dy).clamp(0, 420).toDouble();
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_pageLocked) {
      _dismissDy = 0;
      return;
    }
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 500 || _dismissDy > 100) {
      Navigator.of(context).pop();
      return;
    }
    // Snap back with animation instead of jumping.
    final start = _dismissDy;
    final animation = Tween<double>(begin: start, end: 0).animate(
      CurvedAnimation(parent: _motionController, curve: Curves.easeOut),
    );
    void listener() {
      if (mounted) setState(() => _dismissDy = animation.value);
    }

    animation.addListener(listener);
    _motionController.reset();
    _motionController.forward().whenComplete(() {
      animation.removeListener(listener);
      if (mounted) setState(() => _dismissDy = 0);
    });
  }

  void _onPageChanged(int index) {
    _motionController.stop();
    setState(() {
      _currentIndex = index;
      _scale = 1;
      _dismissDy = 0;
      _interacting = false;
      _transformController.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.assets.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: _handleVerticalDragStart,
              onVerticalDragUpdate: _handleVerticalDragUpdate,
              onVerticalDragEnd: _handleVerticalDragEnd,
              child: Transform.translate(
                offset: Offset(0, _dismissDy),
                child: PageView.builder(
                  controller: _pageController,
                  physics: _pageLocked
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  itemCount: widget.assets.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleChrome,
                      onDoubleTapDown: (details) => _doubleTapDetails = details,
                      onDoubleTap: _handleDoubleTap,
                      child: Center(
                        child: InteractiveViewer(
                          transformationController: _transformController,
                          minScale: 1,
                          maxScale: 5,
                          boundaryMargin: const EdgeInsets.all(96),
                          onInteractionStart: _handleInteractionStart,
                          onInteractionEnd: _handleInteractionEnd,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              FutureBuilder<Uint8List?>(
                                future: _loadThumb(index),
                                builder: (context, snapshot) {
                                  final bytes = snapshot.data;
                                  if (bytes == null) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white54,
                                      ),
                                    );
                                  }
                                  return Image.memory(
                                    bytes,
                                    fit: BoxFit.contain,
                                    gaplessPlayback: true,
                                    filterQuality: FilterQuality.low,
                                  );
                                },
                              ),
                              FutureBuilder<Uint8List?>(
                                future: _loadPreview(index),
                                builder: (context, snapshot) {
                                  final bytes = snapshot.data;
                                  if (snapshot.hasError) {
                                    return _ViewerError(
                                      onRetry: () {
                                        setState(() {
                                          _imageFutures.remove(index);
                                        });
                                      },
                                    );
                                  }
                                  if (bytes == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return Image.memory(
                                    bytes,
                                    fit: BoxFit.contain,
                                    gaplessPlayback: true,
                                    filterQuality: FilterQuality.high,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_chromeVisible) ...[
              Positioned(
                top: 8,
                left: 12,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                top: 18,
                left: 0,
                right: 0,
                child: Text(
                  '${_currentIndex + 1} / ${widget.assets.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ViewerError extends StatelessWidget {
  const _ViewerError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.broken_image, color: Colors.white54, size: 48),
        const SizedBox(height: 12),
        const Text(
          '无法加载图片',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('重试')),
      ],
    ),
  );
}
