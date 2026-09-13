import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_app/l10n/app_localizations.dart';
import 'package:memory_domain/memory_domain.dart';

/// Asset info sheet (system Photos pattern): date, time, place, type,
/// dimensions, duration and memory membership. Camera/EXIF metadata is only
/// shown when actually available — no invented rows.
Future<void> showViewerInfoSheet(
  BuildContext context, {
  required MediaAsset asset,
  required MediaRepository repository,
  String? memoryScopeLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xff1c1c1e),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _InfoSheet(
      asset: asset,
      repository: repository,
      memoryScopeLabel: memoryScopeLabel,
    ),
  );
}

class _InfoSheet extends StatefulWidget {
  const _InfoSheet({
    required this.asset,
    required this.repository,
    required this.memoryScopeLabel,
  });

  final MediaAsset asset;
  final MediaRepository repository;
  final String? memoryScopeLabel;

  @override
  State<_InfoSheet> createState() => _InfoSheetState();
}

class _InfoSheetState extends State<_InfoSheet> {
  String? _placeLabel;

  @override
  void initState() {
    super.initState();
    final location = widget.asset.location;
    if (location != null) {
      widget.repository.loadPlaceLabel(location).then((label) {
        if (mounted && label != null) setState(() => _placeLabel = label);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final asset = widget.asset;
    final date = asset.creationDate;
    final rows = <(String, String)>[
      if (date != null)
        (l10n.infoDate, '${date.year}年${date.month}月${date.day}日'),
      if (date != null)
        (
          l10n.infoTime,
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
        ),
      if (_placeLabel != null) (l10n.infoLocation, _placeLabel!),
      (
        l10n.infoType,
        switch (asset.type) {
          MediaType.video => l10n.infoTypeVideo,
          MediaType.livePhoto => l10n.infoTypeLivePhoto,
          MediaType.audio => l10n.infoTypeVideo,
          MediaType.image => l10n.infoTypePhoto,
        },
      ),
      if (asset.width != null && asset.height != null)
        (l10n.infoSize, '${asset.width} × ${asset.height}'),
      if (asset.type == MediaType.video && asset.duration != null)
        (l10n.infoDuration, _formatDuration(asset.duration!)),
      if (widget.memoryScopeLabel != null)
        (l10n.infoMemory, widget.memoryScopeLabel!),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.infoTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
            for (final (label, value) in rows) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.small),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
