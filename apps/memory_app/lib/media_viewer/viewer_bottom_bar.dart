import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:memory_app/l10n/app_localizations.dart';
import 'package:memory_domain/memory_domain.dart';

/// Viewer bottom chrome: only real actions (ADR contract — no placeholder
/// buttons). Share/Favorite/Info/Edit all map to implemented behavior.
class ViewerBottomBar extends StatelessWidget {
  const ViewerBottomBar({
    super.key,
    required this.asset,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onShare,
    required this.onInfo,
    required this.onEdit,
  });

  final MediaAsset asset;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onShare;
  final VoidCallback onInfo;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _action(
          icon: isFavorite ? Icons.favorite : Icons.favorite_border,
          label: l10n.viewerFavorite,
          onTap: () {
            HapticFeedback.lightImpact();
            onToggleFavorite();
          },
        ),
        _action(icon: Icons.ios_share, label: l10n.viewerShare, onTap: onShare),
        _action(
          icon: Icons.info_outline,
          label: l10n.viewerInfo,
          onTap: onInfo,
        ),
        _action(icon: Icons.tune, label: l10n.viewerEdit, onTap: onEdit),
      ],
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        icon: Icon(icon, color: Colors.white, size: 24),
        onPressed: onTap,
      ),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ],
  );
}
