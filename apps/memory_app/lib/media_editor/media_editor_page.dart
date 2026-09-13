import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_library/media_library.dart';
import 'package:memory_app/l10n/app_localizations.dart';
import 'package:memory_app/media_editor/edit_render.dart';
import 'package:memory_app/media_editor/edit_recipe_store.dart';
import 'package:memory_domain/memory_domain.dart';

/// Photo editor V1 — 调整 / 滤镜 / 裁剪.
///
/// Non-destructive by contract: [EditRecipe] metadata is saved locally and
/// originals are never modified. Preview renders the recipe live.
class MediaEditorPage extends StatefulWidget {
  const MediaEditorPage({
    super.key,
    required this.repository,
    required this.asset,
    required this.store,
    this.initialRecipe,
  });

  final MediaRepository repository;
  final MediaAsset asset;
  final EditRecipeStore store;
  final EditRecipe? initialRecipe;

  @override
  State<MediaEditorPage> createState() => _MediaEditorPageState();
}

class _MediaEditorPageState extends State<MediaEditorPage> {
  late EditRecipe _recipe;
  Uint8List? _bytes;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _recipe = widget.initialRecipe ?? const EditRecipe();
    widget.repository.loadPreview(widget.asset.id, maxPixelSize: 1200).then((
      bytes,
    ) {
      if (mounted && bytes != null) setState(() => _bytes = bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _EditorTopBar(
              onCancel: () => Navigator.of(context).pop(),
              onDone: _saveAndClose,
            ),
            Expanded(
              child: _PreviewPanel(
                asset: widget.asset,
                recipe: _recipe,
                bytes: _bytes,
              ),
            ),
            _EditorTabBar(
              tab: _tab,
              onTab: (value) => setState(() => _tab = value),
              labels: (
                adjust: l10n.editorTabAdjust,
                filters: l10n.editorTabFilter,
                crop: l10n.editorTabCrop,
              ),
            ),
            SizedBox(
              height: 180,
              child: switch (_tab) {
                0 => _AdjustPanel(
                  recipe: _recipe,
                  onChanged: (adjustments) => setState(
                    () => _recipe = _recipe.copyWith(adjustments: adjustments),
                  ),
                ),
                1 => _FilterPanel(
                  selected: _recipe.filter,
                  onSelected: (filter) {
                    HapticFeedback.selectionClick();
                    setState(() => _recipe = _recipe.copyWith(filter: filter));
                  },
                ),
                _ => _CropPanel(
                  recipe: _recipe,
                  onRotate: (turns) {
                    HapticFeedback.selectionClick();
                    setState(() => _recipe = _recipe.rotated(turns));
                  },
                  onStraighten: (degrees) => setState(
                    () =>
                        _recipe = _recipe.copyWith(straightenDegrees: degrees),
                  ),
                  onAspect: (aspect) => setState(() {
                    _recipe = aspect == EditAspectRatio.free
                        ? _recipe.copyWith(removeCrop: true)
                        : _recipe.copyWith(
                            crop: EditCropRect.centerForAspect(aspect.value!),
                          );
                  }),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAndClose() async {
    await widget.store.save(widget.asset.id, _recipe);
    if (mounted) Navigator.of(context).pop(_recipe);
  }
}

class _EditorTopBar extends StatelessWidget {
  const _EditorTopBar({required this.onCancel, required this.onDone});

  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
      child: Row(
        children: [
          TextButton(onPressed: onCancel, child: Text(l10n.editorCancel)),
          const Spacer(),
          TextButton(
            onPressed: onDone,
            child: Text(
              l10n.editorDone,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.asset,
    required this.recipe,
    required this.bytes,
  });

  final MediaAsset asset;
  final EditRecipe recipe;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final image = bytes == null
        ? const ColoredBox(color: Colors.white12)
        : Image.memory(bytes!, fit: BoxFit.contain);
    final quarterTurns = recipe.rotationQuarterTurns % 4;
    final crop = recipe.crop;
    final matrix = ColorFilter.matrix(
      colorMatrixFor(recipe.adjustments, recipe.filter),
    );

    Widget content = Padding(
      padding: const EdgeInsets.all(AppSpacing.small),
      child: image,
    );
    if (crop != null) {
      content = AspectRatio(
        aspectRatio: crop.width / crop.height,
        child: ClipRect(
          child: Align(
            alignment: Alignment(
              -1 + 2 * crop.left + crop.width,
              -1 + 2 * crop.top + crop.height,
            ),
            widthFactor: crop.width,
            heightFactor: crop.height,
            child: content,
          ),
        ),
      );
    }
    if (recipe.straightenDegrees != 0) {
      content = ClipRect(
        child: Transform.rotate(
          angle: straightenRadians(recipe.straightenDegrees),
          child: content,
        ),
      );
    }
    if (quarterTurns != 0) {
      content = RotatedBox(quarterTurns: quarterTurns, child: content);
    }
    return ColorFiltered(colorFilter: matrix, child: content);
  }
}

class _EditorTabBar extends StatelessWidget {
  const _EditorTabBar({
    required this.tab,
    required this.onTab,
    required this.labels,
  });

  final int tab;
  final ValueChanged<int> onTab;
  final ({String adjust, String filters, String crop}) labels;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _tabButton(0, labels.adjust),
      _tabButton(1, labels.filters),
      _tabButton(2, labels.crop),
    ],
  );

  Widget _tabButton(int value, String label) => TextButton(
    onPressed: () => onTab(value),
    child: Text(
      label,
      style: TextStyle(
        color: tab == value ? Colors.white : Colors.white54,
        fontWeight: tab == value ? FontWeight.w600 : FontWeight.w400,
      ),
    ),
  );
}

class _AdjustPanel extends StatelessWidget {
  const _AdjustPanel({required this.recipe, required this.onChanged});

  final EditRecipe recipe;
  final ValueChanged<EditAdjustments> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final a = recipe.adjustments;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
      children: [
        _slider(
          l10n.editorExposure,
          a.exposure,
          (v) => onChanged(a.copyWith(exposure: v)),
        ),
        _slider(
          l10n.editorBrightness,
          a.brightness,
          (v) => onChanged(a.copyWith(brightness: v)),
        ),
        _slider(
          l10n.editorContrast,
          a.contrast,
          (v) => onChanged(a.copyWith(contrast: v)),
        ),
        _slider(
          l10n.editorHighlights,
          a.highlights,
          (v) => onChanged(a.copyWith(highlights: v)),
        ),
        _slider(
          l10n.editorShadows,
          a.shadows,
          (v) => onChanged(a.copyWith(shadows: v)),
        ),
        _slider(
          l10n.editorSaturation,
          a.saturation,
          (v) => onChanged(a.copyWith(saturation: v)),
        ),
        _slider(
          l10n.editorWarmth,
          a.warmth,
          (v) => onChanged(a.copyWith(warmth: v)),
        ),
        if (!a.isIdentity || recipe.filter != EditFilter.none)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                onChanged(const EditAdjustments());
              },
              icon: const Icon(
                Icons.restart_alt,
                color: Colors.white70,
                size: 18,
              ),
              label: Text(
                l10n.editorReset,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
      ],
    );
  }

  Widget _slider(String label, double value, ValueChanged<double> onChanged) =>
      Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 2,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: value,
                min: -1,
                max: 1,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      );
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({required this.selected, required this.onSelected});

  final EditFilter selected;
  final ValueChanged<EditFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = <EditFilter, String>{
      EditFilter.none: l10n.editorFilterNone,
      EditFilter.vivid: l10n.editorFilterVivid,
      EditFilter.warm: l10n.editorFilterWarm,
      EditFilter.cool: l10n.editorFilterCool,
      EditFilter.mono: l10n.editorFilterMono,
    };
    return Center(
      child: Wrap(
        spacing: AppSpacing.small,
        children: [
          for (final entry in entries.entries)
            ChoiceChip(
              label: Text(entry.value),
              selected: selected == entry.key,
              onSelected: (_) => onSelected(entry.key),
            ),
        ],
      ),
    );
  }
}

class _CropPanel extends StatelessWidget {
  const _CropPanel({
    required this.recipe,
    required this.onRotate,
    required this.onStraighten,
    required this.onAspect,
  });

  final EditRecipe recipe;
  final ValueChanged<int> onRotate;
  final ValueChanged<double> onStraighten;
  final ValueChanged<EditAspectRatio> onAspect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final aspects = <EditAspectRatio, String>{
      EditAspectRatio.free: l10n.editorAspectFree,
      EditAspectRatio.square: l10n.editorAspectSquare,
      EditAspectRatio.ratio4x3: '4:3',
      EditAspectRatio.ratio16x9: '16:9',
      EditAspectRatio.ratio3x4: '3:4',
      EditAspectRatio.ratio9x16: '9:16',
    };
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: l10n.editorRotateLeft,
              onPressed: () => onRotate(3),
              icon: const Icon(Icons.rotate_left, color: Colors.white),
            ),
            IconButton(
              tooltip: l10n.editorRotateRight,
              onPressed: () => onRotate(1),
              icon: const Icon(Icons.rotate_right, color: Colors.white),
            ),
            const SizedBox(width: AppSpacing.small),
            Expanded(
              child: Row(
                children: [
                  Text(
                    l10n.editorStraighten,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Expanded(
                    child: Slider(
                      value: recipe.straightenDegrees,
                      min: -10,
                      max: 10,
                      onChanged: onStraighten,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Wrap(
          spacing: AppSpacing.small,
          children: [
            for (final entry in aspects.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _isAspectSelected(entry.key),
                onSelected: (_) => onAspect(entry.key),
              ),
          ],
        ),
      ],
    );
  }

  bool _isAspectSelected(EditAspectRatio aspect) {
    final crop = recipe.crop;
    if (aspect == EditAspectRatio.free) return crop == null;
    if (crop == null) return false;
    return crop == EditCropRect.centerForAspect(aspect.value!);
  }
}
