import 'dart:collection';
import 'dart:typed_data';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:media_library/media_library.dart';

const int feedPreviewSize = 720;
const int detailPreviewSize = 1200;
const int viewerPreviewSize = 2200;
const int gridPreviewSize = 360;

/// Small app-wide LRU of last loaded bytes per asset id. Lets the viewer's
/// open transition start from the exact thumbnail the user tapped, with no
/// spinner in between (ADR open-transition contract).
class ThumbnailBytesCache {
  ThumbnailBytesCache._();

  static final ThumbnailBytesCache instance = ThumbnailBytesCache._();

  static const int _maxEntries = 80;
  final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();

  Uint8List? get(String assetId) => _cache[assetId];

  void put(String assetId, Uint8List bytes) {
    _cache.remove(assetId);
    _cache[assetId] = bytes;
    while (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }
}

class MediaPreview extends StatefulWidget {
  const MediaPreview({
    super.key,
    required this.repository,
    required this.assetId,
    required this.size,
    this.fit = BoxFit.cover,
    this.borderRadius = AppRadius.hero,
    this.usePreview = false,
  });

  final MediaRepository repository;
  final String? assetId;
  final int size;
  final BoxFit fit;
  final double borderRadius;
  final bool usePreview;

  @override
  State<MediaPreview> createState() => _MediaPreviewState();
}

class _MediaPreviewState extends State<MediaPreview> {
  String? _requestId;
  Future<Uint8List?>? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId ||
        oldWidget.size != widget.size ||
        oldWidget.usePreview != widget.usePreview) {
      _cancelCurrent();
      _load();
    }
  }

  void _load() {
    final assetId = widget.assetId;
    if (assetId == null) {
      _requestId = null;
      _image = Future.value();
      return;
    }
    _requestId =
        '$assetId-${widget.size}-${DateTime.now().microsecondsSinceEpoch}';
    _image = widget.usePreview
        ? widget.repository.loadPreview(
            assetId,
            maxPixelSize: widget.size,
            requestId: _requestId,
          )
        : widget.repository.loadThumbnail(
            assetId,
            size: widget.size,
            requestId: _requestId,
          );
  }

  void _cancelCurrent() {
    final requestId = _requestId;
    if (requestId != null) {
      widget.repository.cancelThumbnailRequest(requestId);
    }
  }

  @override
  void dispose() {
    _cancelCurrent();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(widget.borderRadius),
    child: FutureBuilder<Uint8List?>(
      future: _image,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return const _PreviewPlaceholder();
        if (assetId != null) {
          ThumbnailBytesCache.instance.put(assetId!, bytes);
        }
        return Image.memory(
          bytes,
          fit: widget.fit,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
        );
      },
    ),
  );

  String? get assetId => widget.assetId;
}

class MediaPreviewTile extends StatelessWidget {
  const MediaPreviewTile({
    super.key,
    required this.repository,
    required this.assetId,
    required this.size,
    this.onTap,
    this.usePreview = false,
  });

  final MediaRepository repository;
  final String? assetId;
  final int size;
  final VoidCallback? onTap;
  final bool usePreview;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: GestureDetector(
      onTap: onTap,
      child: MediaPreview(
        repository: repository,
        assetId: assetId,
        size: size,
        usePreview: usePreview,
      ),
    ),
  );
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColor.accent.withValues(alpha: .14),
    child: const Center(
      child: Icon(Icons.photo_library_outlined, color: AppColor.accent),
    ),
  );
}
