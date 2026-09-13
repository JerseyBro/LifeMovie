import 'dart:convert';
import 'dart:io';

import 'package:memory_domain/memory_domain.dart';

/// Local, non-destructive persistence for photo edits.
///
/// Stores [EditRecipe] metadata only, keyed by the asset's stable
/// localIdentifier. Originals are never modified; exporting copies or
/// writing back to PhotoKit is out of scope for V1.
class EditRecipeStore {
  EditRecipeStore(this.file) : _inMemory = false;

  /// Cache-only store for tests and pre-initialization fallback.
  EditRecipeStore.inMemory() : file = null, _inMemory = true;

  final File? file;
  final bool _inMemory;
  final Map<String, EditRecipe> _cache = {};
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded || _inMemory) return;
    _loaded = true;
    final f = file;
    if (f == null || !await f.exists()) return;
    try {
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is! Map) return;
      decoded.forEach((key, value) {
        if (value is Map) {
          _cache[key as String] = EditRecipe.fromJson(
            value.cast<String, Object?>(),
          );
        }
      });
    } on FormatException {
      // Corrupt file: start clean rather than crashing the editor.
      _cache.clear();
    }
  }

  Future<EditRecipe?> load(String assetId) async {
    await _ensureLoaded();
    return _cache[assetId];
  }

  Future<void> save(String assetId, EditRecipe recipe) async {
    await _ensureLoaded();
    if (recipe.isIdentity) {
      await remove(assetId);
      return;
    }
    _cache[assetId] = recipe;
    await _flush();
  }

  Future<void> remove(String assetId) async {
    await _ensureLoaded();
    if (_cache.remove(assetId) != null) {
      await _flush();
    }
  }

  Future<void> _flush() async {
    final f = file;
    if (f == null) return;
    final parent = f.parent;
    if (!await parent.exists()) await parent.create(recursive: true);
    await f.writeAsString(
      jsonEncode({
        for (final entry in _cache.entries) entry.key: entry.value.toJson(),
      }),
    );
  }
}
