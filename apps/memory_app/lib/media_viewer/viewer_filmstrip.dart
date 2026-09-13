import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_domain/memory_domain.dart';

/// Memory-scoped thumbnail filmstrip (system Photos pattern):
/// shows only the assets of the current memory, highlights the current
/// photo, supports tap-to-jump and horizontal scrub with selection haptics.
class ViewerFilmstrip extends StatefulWidget {
  const ViewerFilmstrip({
    super.key,
    required this.repository,
    required this.assets,
    required this.currentIndex,
    required this.onIndexSelected,
  });

  final MediaRepository repository;
  final List<MediaAsset> assets;
  final int currentIndex;
  final ValueChanged<int> onIndexSelected;

  @override
  State<ViewerFilmstrip> createState() => _ViewerFilmstripState();
}

class _ViewerFilmstripState extends State<ViewerFilmstrip> {
  static const double _itemExtent = 46;
  static const double _gap = 4;

  late final ScrollController _scrollController;
  bool _scrubbing = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerOnCurrent());
  }

  @override
  void didUpdateWidget(ViewerFilmstrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex && !_scrubbing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerOnCurrent());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _centerOnCurrent() {
    if (!mounted || !_scrollController.hasClients) return;
    final target = widget.currentIndex * (_itemExtent + _gap);
    final viewport = _scrollController.position.viewportDimension;
    final max = _scrollController.position.maxScrollExtent;
    final offset = (target - viewport / 2 + _itemExtent / 2).clamp(0.0, max);
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleScrubStart(DragStartDetails details) {
    _scrubbing = true;
  }

  void _handleScrubUpdate(DragUpdateDetails details) {
    final shift = (details.delta.dx / (_itemExtent + _gap)).round();
    if (shift == 0) return;
    final next = (widget.currentIndex + shift).clamp(
      0,
      widget.assets.length - 1,
    );
    if (next == widget.currentIndex) return;
    HapticFeedback.selectionClick();
    widget.onIndexSelected(next);
  }

  void _handleScrubEnd(DragEndDetails details) {
    _scrubbing = false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.assets.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: _itemExtent + 12,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: _handleScrubStart,
        onHorizontalDragUpdate: _handleScrubUpdate,
        onHorizontalDragEnd: _handleScrubEnd,
        child: ListView.separated(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: widget.assets.length,
          separatorBuilder: (_, _) => const SizedBox(width: _gap),
          itemBuilder: (context, index) {
            final isCurrent = index == widget.currentIndex;
            return _FilmstripThumb(
              repository: widget.repository,
              asset: widget.assets[index],
              isCurrent: isCurrent,
              onTap: () => widget.onIndexSelected(index),
            );
          },
        ),
      ),
    );
  }
}

class _FilmstripThumb extends StatefulWidget {
  const _FilmstripThumb({
    required this.repository,
    required this.asset,
    required this.isCurrent,
    required this.onTap,
  });

  final MediaRepository repository;
  final MediaAsset asset;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  State<_FilmstripThumb> createState() => _FilmstripThumbState();
}

class _FilmstripThumbState extends State<_FilmstripThumb> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    widget.repository.loadThumbnail(widget.asset.id, size: 120).then((bytes) {
      if (mounted && bytes != null) setState(() => _bytes = bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: 46,
        height: widget.isCurrent ? 50 : 42,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: widget.isCurrent ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: _bytes == null
              ? const ColoredBox(color: Colors.white12)
              : Image.memory(
                  _bytes!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.low,
                ),
        ),
      ),
    );
  }
}
