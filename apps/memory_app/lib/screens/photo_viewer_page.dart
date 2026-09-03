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

class _FullscreenPhotoViewerPageState extends State<FullscreenPhotoViewerPage> {
  late final PageController _pageController;
  late int _currentIndex;
  final Map<int, Future<Uint8List?>> _imageFutures = {};
  final TransformationController _transformController =
      TransformationController();
  bool _chromeVisible = true;
  double _scale = 1;
  TapDownDetails? _doubleTapDetails;
  Offset? _tapDownPosition;
  DateTime? _tapDownAt;

  bool get _isZoomed => _scale > 1.01;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.assets.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.assets.length - 1);
    _currentIndex = initialIndex;
    _pageController = PageController(initialPage: initialIndex);
    _transformController.addListener(_syncScale);
  }

  @override
  void dispose() {
    _transformController.removeListener(_syncScale);
    _transformController.dispose();
    _pageController.dispose();
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

  void _toggleChrome() {
    setState(() => _chromeVisible = !_chromeVisible);
  }

  void _handlePointerDown(PointerDownEvent event) {
    _tapDownPosition = event.position;
    _tapDownAt = DateTime.now();
  }

  void _handlePointerUp(PointerUpEvent event) {
    final start = _tapDownPosition;
    final startedAt = _tapDownAt;
    _tapDownPosition = null;
    _tapDownAt = null;
    if (_isZoomed || start == null || startedAt == null) return;
    final moved = (event.position - start).distance;
    final elapsed = DateTime.now().difference(startedAt);
    if (moved < 12 && elapsed < const Duration(milliseconds: 350)) {
      _toggleChrome();
    }
  }

  void _handleDoubleTap() {
    final details = _doubleTapDetails;
    if (_isZoomed) {
      _transformController.value = Matrix4.identity();
      return;
    }
    final position = details?.localPosition ?? Offset.zero;
    _transformController.value = Matrix4.identity()
      ..translateByDouble(-position.dx, -position.dy, 0, 1)
      ..scaleByDouble(2.4, 2.4, 1, 1);
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_isZoomed) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 700) Navigator.of(context).pop();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _scale = 1;
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
              onVerticalDragEnd: _handleVerticalDragEnd,
              child: PageView.builder(
                controller: _pageController,
                physics: _isZoomed
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                itemCount: widget.assets.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  return Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _handlePointerDown,
                    onPointerUp: _handlePointerUp,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onDoubleTapDown: (details) => _doubleTapDetails = details,
                      onDoubleTap: _handleDoubleTap,
                      child: Center(
                        child: InteractiveViewer(
                          transformationController: _transformController,
                          minScale: 1,
                          maxScale: 5,
                          boundaryMargin: const EdgeInsets.all(96),
                          child: FutureBuilder<Uint8List?>(
                            future: _loadPreview(index),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState !=
                                  ConnectionState.done) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                );
                              }
                              final bytes = snapshot.data;
                              if (snapshot.hasError || bytes == null) {
                                return _ViewerError(
                                  onRetry: () {
                                    setState(() {
                                      _imageFutures.remove(index);
                                    });
                                  },
                                );
                              }
                              return Image.memory(
                                bytes,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
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
