import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_app/media_editor/edit_recipe_store.dart';
import 'package:memory_app/media_editor/media_editor_page.dart';
import 'package:memory_app/media_viewer/viewer_bottom_bar.dart';
import 'package:memory_app/media_viewer/viewer_filmstrip.dart';
import 'package:memory_app/media_viewer/viewer_gesture_policy.dart';
import 'package:memory_app/media_viewer/viewer_info_sheet.dart';
import 'package:memory_app/media_viewer/viewer_media_loader.dart';
import 'package:memory_app/media_viewer/viewer_photo_view.dart';
import 'package:memory_app/media_viewer/viewer_top_bar.dart';
import 'package:memory_app/media_viewer/viewer_video_page.dart';
import 'package:memory_domain/memory_domain.dart';

/// Fullscreen media viewer V3 (ADR_MEDIA_VIEWER_ARCHITECTURE).
///
/// Gesture ownership is exclusive per touch sequence:
///   horizontal -> PageView paging
///   vertical   -> interactive dismiss (photo follows finger, background dims)
///   pinch/double-tap -> zoom (zoomed photo owns everything until back to 1x)
class MediaViewerPage extends StatefulWidget {
  const MediaViewerPage({
    super.key,
    required this.repository,
    required this.assets,
    required this.initialIndex,
    this.initialSourceRect,
    this.initialThumb,
    this.memoryScopeLabel,
    this.editStore,
  });

  final MediaRepository repository;
  final List<MediaAsset> assets;
  final int initialIndex;
  final Rect? initialSourceRect;
  final Uint8List? initialThumb;
  final String? memoryScopeLabel;
  final EditRecipeStore? editStore;

  @override
  State<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage>
    with SingleTickerProviderStateMixin {
  static const Duration _dismissDuration = Duration(milliseconds: 200);

  late final ViewerMediaLoader _loader;
  late final PageController _pageController;
  late int _currentIndex;
  final ViewerGesturePolicy _policy = const ViewerGesturePolicy();

  bool _chromeVisible = true;
  bool _zoomed = false;
  double _dismissOffset = 0;
  bool _dismissing = false;
  late final AnimationController _dismissMotion = AnimationController(
    vsync: this,
    duration: _dismissDuration,
  );

  // Non-destructive edits: recipes per asset id, favorites per asset id.
  late final EditRecipeStore _editStore =
      widget.editStore ?? EditRecipeStore.inMemory();
  final Map<String, EditRecipe> _recipes = {};
  final Map<String, bool> _favorites = {};

  @override
  void initState() {
    super.initState();
    final index = widget.assets.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.assets.length - 1);
    _currentIndex = index;
    _pageController = PageController(initialPage: index);
    _loader = ViewerMediaLoader(
      repository: widget.repository,
      assets: widget.assets,
    );
    for (final asset in widget.assets) {
      _favorites[asset.id] = asset.isFavorite;
    }
    _loader.focus(index);
    _loadRecipe(index);
  }

  Future<void> _loadRecipe(int index) async {
    if (index < 0 || index >= widget.assets.length) return;
    final asset = widget.assets[index];
    if (asset.type == MediaType.video || asset.type == MediaType.audio) return;
    final recipe = await _editStore.load(asset.id);
    if (mounted && recipe != null) {
      setState(() => _recipes[asset.id] = recipe);
    }
  }

  @override
  void dispose() {
    _tapResetTimer?.cancel();
    _dismissMotion.dispose();
    _pageController.dispose();
    _loader.dispose();
    super.dispose();
  }

  bool get _interactive => !_dismissing;

  // --- Chrome ---------------------------------------------------------------

  Timer? _tapResetTimer;
  bool _chromeToggledByTap = false;

  void _handleTap() {
    if (!_interactive || _zoomed) return;
    setState(() => _chromeVisible = !_chromeVisible);
    _chromeToggledByTap = true;
    _tapResetTimer?.cancel();
    _tapResetTimer = Timer(const Duration(milliseconds: 300), () {
      _chromeToggledByTap = false;
    });
  }

  /// If the tap turns out to be the first tap of a double-tap, revert the
  /// chrome toggle so double-tap zoom leaves chrome state unchanged.
  void _handleDoubleTap() {
    _tapResetTimer?.cancel();
    if (_chromeToggledByTap) {
      _chromeToggledByTap = false;
      if (mounted && !_zoomed) {
        setState(() => _chromeVisible = !_chromeVisible);
      }
    }
  }

  // --- Paging ----------------------------------------------------------------

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _dismissOffset = 0;
    });
    _loader.focus(index);
    _loadRecipe(index);
  }

  void _jumpTo(int index) {
    if (index == _currentIndex) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  // --- Zoom -------------------------------------------------------------------

  void _onZoomChanged(bool zoomed) {
    if (_zoomed == zoomed) return;
    setState(() => _zoomed = zoomed);
    if (zoomed && _chromeVisible) {
      setState(() => _chromeVisible = false);
    }
  }

  // --- Interactive dismiss ------------------------------------------------------

  void _onDismissUpdate(double delta) {
    if (!_interactive || _zoomed) return;
    setState(() => _dismissOffset += delta);
  }

  void _onDismissEnd(double velocity) {
    if (!_interactive || _zoomed) return;
    final complete = _policy.shouldCompleteDismiss(
      distance: _dismissOffset.abs(),
      velocity: velocity,
    );
    if (complete) {
      _completeDismiss();
    } else {
      _springBack();
    }
  }

  void _completeDismiss() {
    final height = MediaQuery.sizeOf(context).height;
    final animation = Tween<double>(
      begin: _dismissOffset,
      end: _dismissOffset + height,
    ).animate(CurvedAnimation(parent: _dismissMotion, curve: Curves.easeIn));
    void listener() {
      if (mounted) setState(() => _dismissOffset = animation.value);
    }

    animation.addListener(listener);
    setState(() => _dismissing = true);
    _dismissMotion.forward().whenComplete(() {
      animation.removeListener(listener);
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _springBack() {
    final animation = Tween<double>(begin: _dismissOffset, end: 0).animate(
      CurvedAnimation(parent: _dismissMotion, curve: Curves.easeOutCubic),
    );
    void listener() {
      if (mounted) setState(() => _dismissOffset = animation.value);
    }

    animation.addListener(listener);
    _dismissMotion.forward().whenComplete(() {
      animation.removeListener(listener);
      if (mounted) setState(() => _dismissOffset = 0);
    });
  }

  // --- Bottom actions ------------------------------------------------------------

  Future<void> _toggleFavorite() async {
    final asset = widget.assets[_currentIndex];
    final next = !(_favorites[asset.id] ?? asset.isFavorite);
    setState(() => _favorites[asset.id] = next);
    final ok = await widget.repository.setFavorite(asset.id, favorite: next);
    if (!ok && mounted) {
      setState(() => _favorites[asset.id] = !next);
    }
  }

  Future<void> _shareCurrent() async {
    await widget.repository.presentShareSheet(widget.assets[_currentIndex].id);
  }

  void _showInfo() {
    showViewerInfoSheet(
      context,
      asset: widget.assets[_currentIndex],
      repository: widget.repository,
      memoryScopeLabel: widget.memoryScopeLabel,
    );
  }

  Future<void> _openEditor() async {
    final asset = widget.assets[_currentIndex];
    if (asset.type == MediaType.video || asset.type == MediaType.audio) return;
    await Navigator.of(context).push(
      MaterialPageRoute<EditRecipe>(
        builder: (_) => MediaEditorPage(
          repository: widget.repository,
          asset: asset,
          store: _editStore,
          initialRecipe: _recipes[asset.id],
        ),
      ),
    );
    await _loadRecipe(_currentIndex);
  }

  // --- Build ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (widget.assets.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }
    final progress = (_dismissOffset.abs() / 420).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Photo layer: follows the dismiss finger, dims the background.
          Opacity(
            opacity: 1 - progress * 0.92,
            child: Transform.translate(
              offset: Offset(0, _dismissOffset),
              child: Transform.scale(
                scale: 1 - progress * 0.06,
                child: PageView.builder(
                  controller: _pageController,
                  physics: _zoomed
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  itemCount: widget.assets.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    final asset = widget.assets[index];
                    if (asset.type == MediaType.video ||
                        asset.type == MediaType.audio) {
                      return ViewerVideoPage(
                        key: ValueKey('video-$index'),
                        repository: widget.repository,
                        asset: asset,
                        isActive: index == _currentIndex,
                        onTap: _handleTap,
                        onDoubleTap: _handleDoubleTap,
                        onDismissUpdate: _onDismissUpdate,
                        onDismissEnd: _onDismissEnd,
                      );
                    }
                    return ViewerPhotoView(
                      key: ValueKey('photo-$index'),
                      loader: _loader,
                      index: index,
                      asset: asset,
                      isActive: index == _currentIndex,
                      initialThumb: index == _currentIndex
                          ? widget.initialThumb
                          : null,
                      recipe: _recipes[asset.id],
                      onZoomChanged: _onZoomChanged,
                      onDismissUpdate: _onDismissUpdate,
                      onDismissEnd: _onDismissEnd,
                      onTap: _handleTap,
                      onDoubleTap: _handleDoubleTap,
                    );
                  },
                ),
              ),
            ),
          ),
          // Chrome layer fades with dismiss progress and chrome visibility.
          IgnorePointer(
            ignoring: !_chromeVisible,
            child: AnimatedOpacity(
              opacity: _chromeVisible ? 1 - progress : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: Column(
                children: [
                  ViewerTopBar(
                    currentIndex: _currentIndex,
                    total: widget.assets.length,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ViewerBottomBar(
                          asset: widget.assets[_currentIndex],
                          isFavorite:
                              _favorites[widget.assets[_currentIndex].id] ??
                              false,
                          onToggleFavorite: _toggleFavorite,
                          onShare: _shareCurrent,
                          onInfo: _showInfo,
                          onEdit: _openEditor,
                        ),
                        ViewerFilmstrip(
                          repository: widget.repository,
                          assets: widget.assets,
                          currentIndex: _currentIndex,
                          onIndexSelected: _jumpTo,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
