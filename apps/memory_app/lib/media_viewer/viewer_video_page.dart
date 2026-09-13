import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_app/l10n/app_localizations.dart';
import 'package:memory_app/media_viewer/viewer_photo_gestures.dart';
import 'package:memory_domain/memory_domain.dart';
import 'package:video_player/video_player.dart';

/// Minimal video capability inside the viewer: poster first, then
/// play/pause, scrub and mute. No trimming, no filters, no editor.
class ViewerVideoPage extends StatefulWidget {
  const ViewerVideoPage({
    super.key,
    required this.repository,
    required this.asset,
    required this.isActive,
    required this.onTap,
    required this.onDoubleTap,
    required this.onDismissUpdate,
    required this.onDismissEnd,
  });

  final MediaRepository repository;
  final MediaAsset asset;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final ValueChanged<double> onDismissUpdate;
  final ValueChanged<double> onDismissEnd;

  @override
  State<ViewerVideoPage> createState() => _ViewerVideoPageState();
}

class _ViewerVideoPageState extends State<ViewerVideoPage> {
  Uint8List? _poster;
  VideoPlayerController? _controller;
  bool _muted = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    widget.repository.loadThumbnail(widget.asset.id, size: 1200).then((bytes) {
      if (mounted && bytes != null) setState(() => _poster = bytes);
    });
    _preparePlayback();
  }

  Future<void> _preparePlayback() async {
    final url = await widget.repository.loadVideoPlaybackUrl(widget.asset.id);
    if (!mounted || url == null) return;
    try {
      final uri = Uri.parse(url);
      final controller = uri.scheme == 'file' || uri.scheme == ''
          ? VideoPlayerController.file(File.fromUri(uri))
          : VideoPlayerController.networkUrl(uri);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onPlaybackTick);
      setState(() => _controller = controller);
    } on Object {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  void _onPlaybackTick() {
    if (!mounted) return;
    final controller = _controller;
    if (controller != null && !controller.value.isInitialized) return;
    setState(() {});
  }

  @override
  void didUpdateWidget(ViewerVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && oldWidget.isActive) {
      _controller?.pause();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlaybackTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final l10n = AppLocalizations.of(context)!;
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        TapSequenceRecognizer:
            GestureRecognizerFactoryWithHandlers<TapSequenceRecognizer>(
              () => TapSequenceRecognizer(
                onTap: widget.onTap,
                onDoubleTap: (_) => widget.onDoubleTap(),
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
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            )
          else if (_poster != null)
            Image.memory(
              _poster!,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
            )
          else
            const SizedBox.shrink(),
          if (controller != null && controller.value.isInitialized)
            _VideoControls(
              controller: controller,
              muted: _muted,
              onToggleMute: () {
                setState(() {
                  _muted = !_muted;
                  controller.setVolume(_muted ? 0 : 1);
                });
              },
              labels: (
                play: l10n.viewerVideoPlay,
                pause: l10n.viewerVideoPause,
                mute: l10n.viewerVideoMute,
                unmute: l10n.viewerVideoUnmute,
              ),
            )
          else if (_loadFailed)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 96),
                child: Text(
                  l10n.viewerVideoUnavailable,
                  style: TextStyle(color: Colors.white.withValues(alpha: .7)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoControls extends StatelessWidget {
  const _VideoControls({
    required this.controller,
    required this.muted,
    required this.onToggleMute,
    required this.labels,
  });

  final VideoPlayerController controller;
  final bool muted;
  final VoidCallback onToggleMute;
  final ({String play, String pause, String mute, String unmute}) labels;

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    final position = value.position;
    final duration = value.duration;
    final playing = value.isPlaying;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                playing
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
                color: Colors.white,
                size: 36,
              ),
              onPressed: () {
                playing ? controller.pause() : controller.play();
              },
            ),
            Text(
              _label(position),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Expanded(
              child: SliderTheme(
                data: const SliderThemeData(
                  trackHeight: 2,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  value: position.inMilliseconds
                      .clamp(0, duration.inMilliseconds)
                      .toDouble(),
                  max: duration.inMilliseconds.toDouble(),
                  onChanged: (value) {
                    controller.seekTo(Duration(milliseconds: value.round()));
                  },
                ),
              ),
            ),
            Text(
              _label(duration),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            IconButton(
              icon: Icon(
                muted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
              ),
              onPressed: onToggleMute,
            ),
          ],
        ),
      ),
    );
  }

  String _label(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
