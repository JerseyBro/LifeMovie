import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Zoom-continuity open transition: the tapped thumbnail's on-screen rect
/// expands into the fullscreen contain rect while the black background fades
/// in. No black flash, no thumbnail -> spinner break (ADR open transition).
class PhotoViewerRoute extends PageRouteBuilder<void> {
  PhotoViewerRoute({
    required WidgetBuilder builder,
    Rect? sourceRect,
    double targetAspectRatio = 3 / 4,
    Uint8List? sourceThumb,
  }) : super(
         opaque: false,
         barrierColor: Colors.transparent,
         transitionDuration: const Duration(milliseconds: 280),
         reverseTransitionDuration: const Duration(milliseconds: 220),
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionsBuilder: (context, animation, secondaryAnimation, child) =>
             _PhotoOpenTransition(
               animation: animation,
               sourceRect: sourceRect,
               targetAspectRatio: targetAspectRatio,
               sourceThumb: sourceThumb,
               child: child,
             ),
       );
}

class _PhotoOpenTransition extends StatelessWidget {
  const _PhotoOpenTransition({
    required this.animation,
    required this.sourceRect,
    required this.targetAspectRatio,
    required this.sourceThumb,
    required this.child,
  });

  final Animation<double> animation;
  final Rect? sourceRect;
  final double targetAspectRatio;
  final Uint8List? sourceThumb;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (sourceRect == null) {
      // Fallback: center fade + slight scale-up.
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    }
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        final t = curved.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Viewer content fades in during the last 20% of the zoom.
            Opacity(opacity: ((t - 0.8) / 0.2).clamp(0.0, 1.0), child: child),
            if (t < 1)
              Opacity(
                opacity: (1 - t).clamp(0.0, 1.0),
                child: _TransitionPhoto(
                  sourceRect: sourceRect!,
                  targetAspectRatio: targetAspectRatio,
                  thumb: sourceThumb,
                  progress: Curves.easeInOutCubicEmphasized.transform(t),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TransitionPhoto extends StatelessWidget {
  const _TransitionPhoto({
    required this.sourceRect,
    required this.targetAspectRatio,
    required this.thumb,
    required this.progress,
  });

  final Rect sourceRect;
  final double targetAspectRatio;
  final Uint8List? thumb;
  final double progress;

  Rect _targetRect(Size screen) {
    final aspect = targetAspectRatio;
    double width = screen.width;
    double height = width / aspect;
    if (height > screen.height) {
      height = screen.height;
      width = height * aspect;
    }
    final center = Offset(screen.width / 2, screen.height / 2);
    return Rect.fromCenter(center: center, width: width, height: height);
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final target = _targetRect(screen);
    final rect = Rect.lerp(sourceRect, target, progress)!;
    return Positioned.fromRect(
      rect: rect,
      child: thumb != null
          ? Image.memory(
              thumb!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
            )
          : const ColoredBox(color: Colors.white12),
    );
  }
}
