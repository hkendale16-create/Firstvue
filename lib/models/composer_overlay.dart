import 'dart:convert';
import 'dart:ui' show TextAlign;

/// Structured Story / media text overlay (normalized 0–1 coordinates).
class ComposerTextOverlay {
  final String id;
  final String text;
  /// Horizontal center as fraction of canvas width (0–1).
  final double x;
  /// Vertical center as fraction of canvas height (0–1).
  final double y;
  /// Relative font scale (1.0 = base).
  final double scale;
  /// Rotation in radians.
  final double rotation;
  final TextAlign align;
  final String styleKey;
  final String? fillKey;

  const ComposerTextOverlay({
    required this.id,
    required this.text,
    this.x = 0.5,
    this.y = 0.45,
    this.scale = 1.0,
    this.rotation = 0,
    this.align = TextAlign.center,
    this.styleKey = 'classic',
    this.fillKey,
  });

  ComposerTextOverlay copyWith({
    String? id,
    String? text,
    double? x,
    double? y,
    double? scale,
    double? rotation,
    TextAlign? align,
    String? styleKey,
    Object? fillKey = _sentinel,
  }) {
    return ComposerTextOverlay(
      id: id ?? this.id,
      text: text ?? this.text,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      align: align ?? this.align,
      styleKey: styleKey ?? this.styleKey,
      fillKey: identical(fillKey, _sentinel) ? this.fillKey : fillKey as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'x': x,
        'y': y,
        'scale': scale,
        'rotation': rotation,
        'align': align.name,
        'styleKey': styleKey,
        if (fillKey != null) 'fillKey': fillKey,
      };

  static ComposerTextOverlay fromJson(Map<String, dynamic> json) {
    return ComposerTextOverlay(
      id: (json['id'] as String?) ?? 'overlay',
      text: (json['text'] as String?) ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0.5,
      y: (json['y'] as num?)?.toDouble() ?? 0.45,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      align: _parseAlign(json['align'] as String?),
      styleKey: (json['styleKey'] as String?) ?? 'classic',
      fillKey: json['fillKey'] as String?,
    );
  }

  static TextAlign _parseAlign(String? raw) {
    return switch (raw) {
      'left' => TextAlign.left,
      'right' => TextAlign.right,
      'justify' => TextAlign.justify,
      _ => TextAlign.center,
    };
  }

  static List<ComposerTextOverlay> listFromJson(dynamic raw) {
    if (raw == null) return const [];
    List<dynamic> list;
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! List) return const [];
        list = decoded;
      } catch (_) {
        return const [];
      }
    } else if (raw is List) {
      list = raw;
    } else {
      return const [];
    }
    return [
      for (final item in list)
        if (item is Map)
          fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  static List<Map<String, dynamic>> listToJson(List<ComposerTextOverlay> items) {
    return [for (final item in items) item.toJson()];
  }
}

const Object _sentinel = Object();

/// Optional Story / post link attachment.
class ComposerLinkAttachment {
  final String url;
  final String? label;
  final String kind;

  const ComposerLinkAttachment({
    required this.url,
    this.label,
    this.kind = 'external',
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        if (label != null && label!.trim().isNotEmpty) 'label': label,
        'kind': kind,
      };

  static ComposerLinkAttachment? fromFields({
    String? url,
    String? label,
    String? kind,
  }) {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return ComposerLinkAttachment(
      url: trimmed,
      label: label?.trim().isEmpty == true ? null : label?.trim(),
      kind: kind ?? 'external',
    );
  }
}

/// Named Story / text-post background keys (FirstVue palette-aware fills).
class ComposerBackgroundKeys {
  ComposerBackgroundKeys._();

  static const keys = <String>[
    'coral',
    'teal',
    'navy',
    'forest',
    'sunset',
    'midnight',
    'bronze',
    'gold',
  ];
}
