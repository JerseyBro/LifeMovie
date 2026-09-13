/// Non-destructive photo editing model (Sprint 1.0).
///
/// An [EditRecipe] describes *how to render* an asset; it never touches the
/// original media. Recipes are stored as local metadata keyed by the asset's
/// stable localIdentifier. PhotoKit originals stay untouched — exporting a
/// copy or saving back to Photos is deliberately out of scope for V1.
library;

/// Color / geometry edits captured as normalized, serializable values.
class EditRecipe {
  const EditRecipe({
    this.rotationQuarterTurns = 0,
    this.straightenDegrees = 0,
    this.crop,
    this.adjustments = const EditAdjustments(),
    this.filter = EditFilter.none,
  });

  /// 0 = 0°, 1 = 90° cw, 2 = 180°, 3 = 270°.
  final int rotationQuarterTurns;

  /// -10..10 degrees.
  final double straightenDegrees;

  /// Normalized crop within the rotated display rect (0..1). Null = no crop.
  final EditCropRect? crop;

  final EditAdjustments adjustments;
  final EditFilter filter;

  bool get isIdentity =>
      rotationQuarterTurns == 0 &&
      straightenDegrees == 0 &&
      crop == null &&
      adjustments.isIdentity &&
      filter == EditFilter.none;

  EditRecipe copyWith({
    int? rotationQuarterTurns,
    double? straightenDegrees,
    EditCropRect? crop,
    bool removeCrop = false,
    EditAdjustments? adjustments,
    EditFilter? filter,
  }) => EditRecipe(
    rotationQuarterTurns: rotationQuarterTurns ?? this.rotationQuarterTurns,
    straightenDegrees: straightenDegrees ?? this.straightenDegrees,
    crop: removeCrop ? null : (crop ?? this.crop),
    adjustments: adjustments ?? this.adjustments,
    filter: filter ?? this.filter,
  );

  EditRecipe rotated(int quarterTurns) => EditRecipe(
    rotationQuarterTurns: (rotationQuarterTurns + quarterTurns) % 4,
    straightenDegrees: straightenDegrees,
    crop: crop,
    adjustments: adjustments,
    filter: filter,
  );

  Map<String, Object?> toJson() => {
    'rotationQuarterTurns': rotationQuarterTurns,
    'straightenDegrees': straightenDegrees,
    if (crop != null) 'crop': crop!.toJson(),
    'adjustments': adjustments.toJson(),
    'filter': filter.name,
  };

  static EditRecipe fromJson(Map<String, Object?> json) {
    final cropJson = json['crop'];
    return EditRecipe(
      rotationQuarterTurns:
          (json['rotationQuarterTurns'] as num?)?.toInt() ?? 0,
      straightenDegrees: (json['straightenDegrees'] as num?)?.toDouble() ?? 0,
      crop: cropJson is Map<Object?, Object?>
          ? EditCropRect.fromJson(cropJson.cast<String, Object?>())
          : null,
      adjustments: EditAdjustments.fromJson(
        (json['adjustments'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
      filter: EditFilter.values.firstWhere(
        (f) => f.name == json['filter'],
        orElse: () => EditFilter.none,
      ),
    );
  }
}

/// Normalized crop window within the rotated display rect. Values are 0..1.
class EditCropRect {
  const EditCropRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  }) : assert(left >= 0 && left <= 1),
       assert(top >= 0 && top <= 1),
       assert(width > 0 && width <= 1),
       assert(height > 0 && height <= 1);

  final double left;
  final double top;
  final double width;
  final double height;

  /// Center crop for the requested aspect (width/height), inside 0..1 space.
  factory EditCropRect.centerForAspect(double aspect) {
    var width = 1.0;
    var height = 1.0;
    if (aspect >= 1) {
      height = 1 / aspect;
    } else {
      width = aspect;
    }
    return EditCropRect(
      left: (1 - width) / 2,
      top: (1 - height) / 2,
      width: width,
      height: height,
    );
  }

  Map<String, Object?> toJson() => {
    'left': left,
    'top': top,
    'width': width,
    'height': height,
  };

  static EditCropRect fromJson(Map<String, Object?> json) => EditCropRect(
    left: (json['left'] as num).toDouble(),
    top: (json['top'] as num).toDouble(),
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
  );

  @override
  bool operator ==(Object other) =>
      other is EditCropRect &&
      other.left == left &&
      other.top == top &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);
}

/// Basic tonal/color adjustments. All values normalized -1..1.
class EditAdjustments {
  const EditAdjustments({
    this.exposure = 0,
    this.brightness = 0,
    this.contrast = 0,
    this.highlights = 0,
    this.shadows = 0,
    this.saturation = 0,
    this.warmth = 0,
  });

  final double exposure;
  final double brightness;
  final double contrast;
  final double highlights;
  final double shadows;
  final double saturation;
  final double warmth;

  bool get isIdentity => [
    exposure,
    brightness,
    contrast,
    highlights,
    shadows,
    saturation,
    warmth,
  ].every((value) => value == 0);

  EditAdjustments copyWith({
    double? exposure,
    double? brightness,
    double? contrast,
    double? highlights,
    double? shadows,
    double? saturation,
    double? warmth,
  }) => EditAdjustments(
    exposure: exposure ?? this.exposure,
    brightness: brightness ?? this.brightness,
    contrast: contrast ?? this.contrast,
    highlights: highlights ?? this.highlights,
    shadows: shadows ?? this.shadows,
    saturation: saturation ?? this.saturation,
    warmth: warmth ?? this.warmth,
  );

  Map<String, Object?> toJson() => {
    'exposure': exposure,
    'brightness': brightness,
    'contrast': contrast,
    'highlights': highlights,
    'shadows': shadows,
    'saturation': saturation,
    'warmth': warmth,
  };

  static EditAdjustments fromJson(Map<String, Object?> json) => EditAdjustments(
    exposure: (json['exposure'] as num?)?.toDouble() ?? 0,
    brightness: (json['brightness'] as num?)?.toDouble() ?? 0,
    contrast: (json['contrast'] as num?)?.toDouble() ?? 0,
    highlights: (json['highlights'] as num?)?.toDouble() ?? 0,
    shadows: (json['shadows'] as num?)?.toDouble() ?? 0,
    saturation: (json['saturation'] as num?)?.toDouble() ?? 0,
    warmth: (json['warmth'] as num?)?.toDouble() ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      other is EditAdjustments &&
      other.exposure == exposure &&
      other.brightness == brightness &&
      other.contrast == contrast &&
      other.highlights == highlights &&
      other.shadows == shadows &&
      other.saturation == saturation &&
      other.warmth == warmth;

  @override
  int get hashCode => Object.hash(
    exposure,
    brightness,
    contrast,
    highlights,
    shadows,
    saturation,
    warmth,
  );
}

enum EditFilter { none, vivid, warm, cool, mono }

/// Aspect ratio choices for crop V1.
enum EditAspectRatio {
  free(null),
  square(1),
  ratio4x3(4 / 3),
  ratio16x9(16 / 9),
  ratio3x4(3 / 4),
  ratio9x16(9 / 16);

  const EditAspectRatio(this.value);
  final double? value;
}
