enum JevProvider { typeSafe, openRouter }

enum JevSurface {
  homeWeb('首页 Web 推荐'),
  homeApp('首页 App 推荐'),
  related('相关视频'),
  hot('热门视频'),
  ranking('排行榜'),
  live('直播推荐'),
  pgc('PGC 推荐'),
  music('BGM / 音乐推荐');

  const JevSurface(this.label);
  final String label;
}

class JevSettings {
  const JevSettings({
    this.enabled = false,
    this.provider,
    this.surfaceEnabled = const {},
    this.hideThreshold = 0.95,
    this.batchSize = 3,
  });

  final bool enabled;
  final JevProvider? provider;
  final Map<JevSurface, bool> surfaceEnabled;
  final double hideThreshold;
  final int batchSize;

  bool enabledFor(JevSurface surface) =>
      enabled && provider != null && (surfaceEnabled[surface] ?? true);

  JevSettings copyWith({
    bool? enabled,
    JevProvider? provider,
    bool clearProvider = false,
    Map<JevSurface, bool>? surfaceEnabled,
    double? hideThreshold,
    int? batchSize,
  }) => JevSettings(
    enabled: enabled ?? this.enabled,
    provider: clearProvider ? null : (provider ?? this.provider),
    surfaceEnabled: surfaceEnabled ?? this.surfaceEnabled,
    hideThreshold: hideThreshold ?? this.hideThreshold,
    batchSize: batchSize ?? this.batchSize,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'provider': provider?.name,
    'surfaces': {
      for (final surface in JevSurface.values)
        surface.name: surfaceEnabled[surface] ?? true,
    },
    'hideThreshold': hideThreshold,
    'batchSize': batchSize,
  };

  factory JevSettings.fromJson(Map<String, Object?> json) {
    final rawSurfaces = json['surfaces'];
    final surfaces = <JevSurface, bool>{};
    if (rawSurfaces is Map) {
      for (final surface in JevSurface.values) {
        final value = rawSurfaces[surface.name];
        if (value is bool) surfaces[surface] = value;
      }
    }
    final provider = JevProvider.values.where((item) => item.name == json['provider']);
    final threshold = json['hideThreshold'];
    final batchSize = json['batchSize'];
    return JevSettings(
      enabled: json['enabled'] == true,
      provider: provider.isEmpty ? null : provider.first,
      surfaceEnabled: surfaces,
      hideThreshold: threshold is num && threshold >= 0 && threshold <= 1
          ? threshold.toDouble()
          : 0.95,
      batchSize: batchSize is int && batchSize >= 1 && batchSize <= 5
          ? batchSize
          : 3,
    );
  }
}

class JevCandidate {
  const JevCandidate({required this.title, this.description, this.category, this.tags = const []});

  final String title;
  final String? description;
  final String? category;
  final List<String> tags;

  Map<String, Object?> toProviderJson() => {
    'title': _limit(title, 240),
    if (_nonBlank(description) case final value?) 'description': _limit(value, 600),
    if (_nonBlank(category) case final value?) 'category': _limit(value, 100),
    if (tags.isNotEmpty) 'tags': tags.take(12).map((tag) => _limit(tag, 80)).toList(growable: false),
  };
}

class JevTheme {
  const JevTheme({required this.label, required this.count, required this.updatedAt});

  final String label;
  final int count;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'label': label,
    'count': count,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory JevTheme.fromJson(Map<String, Object?> json) => JevTheme(
    label: json['label'] as String,
    count: (json['count'] as num).toInt(),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
  );
}

String? _nonBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _limit(String value, int maxLength) =>
    value.length <= maxLength ? value : value.substring(0, maxLength);
