import 'package:flutter/material.dart';

/// Viewer chrome: top bar (close + position counter). Chrome only fades with
/// single tap; no placeholder buttons for unbuilt features (ADR contract).
class ViewerTopBar extends StatelessWidget {
  const ViewerTopBar({
    super.key,
    required this.currentIndex,
    required this.total,
    required this.onClose,
  });

  final int currentIndex;
  final int total;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: .35),
      height: 88,
      padding: const EdgeInsets.only(top: 28),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 26),
              onPressed: onClose,
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Text(
              '${currentIndex + 1} / $total',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
