import 'dart:convert';

import 'package:PiliPlus/features/shielding/shielding_store.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show ReplyInfo;
import 'package:PiliPlus/utils/storage.dart';

class CommentShieldingConfig {
  const CommentShieldingConfig({
    this.levelThreshold,
    this.genderFilter = const [],
    this.memberFilter = const [],
    this.ipLocationFilter = const [],
    this.minCharCount,
    this.maxCharCount,
    this.likeThreshold,
    this.blockWithPicture = false,
    this.blockWithEmote = false,
    this.hideHomeFeedItemsWithoutVisibleComments = false,
    this.version = 1,
  });

  final int? levelThreshold;
  final List<String> genderFilter;
  final List<String> memberFilter;
  final List<String> ipLocationFilter;
  final int? minCharCount;
  final int? maxCharCount;
  final int? likeThreshold;
  final bool blockWithPicture;
  final bool blockWithEmote;
  final bool hideHomeFeedItemsWithoutVisibleComments;
  final int version;

  CommentShieldingConfig copyWith({
    Object? levelThreshold = _copyWithUnset,
    List<String>? genderFilter,
    List<String>? memberFilter,
    List<String>? ipLocationFilter,
    Object? minCharCount = _copyWithUnset,
    Object? maxCharCount = _copyWithUnset,
    Object? likeThreshold = _copyWithUnset,
    bool? blockWithPicture,
    bool? blockWithEmote,
    bool? hideHomeFeedItemsWithoutVisibleComments,
    int? version,
  }) => CommentShieldingConfig(
    levelThreshold: levelThreshold == _copyWithUnset
        ? this.levelThreshold
        : levelThreshold as int?,
    genderFilter: genderFilter ?? this.genderFilter,
    memberFilter: memberFilter ?? this.memberFilter,
    ipLocationFilter: ipLocationFilter ?? this.ipLocationFilter,
    minCharCount: minCharCount == _copyWithUnset
        ? this.minCharCount
        : minCharCount as int?,
    maxCharCount: maxCharCount == _copyWithUnset
        ? this.maxCharCount
        : maxCharCount as int?,
    likeThreshold: likeThreshold == _copyWithUnset
        ? this.likeThreshold
        : likeThreshold as int?,
    blockWithPicture: blockWithPicture ?? this.blockWithPicture,
    blockWithEmote: blockWithEmote ?? this.blockWithEmote,
    hideHomeFeedItemsWithoutVisibleComments:
        hideHomeFeedItemsWithoutVisibleComments ??
        this.hideHomeFeedItemsWithoutVisibleComments,
    version: version ?? this.version,
  );

  Map<String, Object?> toJson() => {
    'version': version,
    if (levelThreshold != null) 'level_threshold': levelThreshold,
    'gender_filter': genderFilter,
    'member_filter': memberFilter,
    'ip_location_filter': ipLocationFilter,
    if (minCharCount != null) 'min_char_count': minCharCount,
    if (maxCharCount != null) 'max_char_count': maxCharCount,
    if (likeThreshold != null) 'like_threshold': likeThreshold,
    'block_with_picture': blockWithPicture,
    'block_with_emote': blockWithEmote,
    'hide_home_feed_items_without_visible_comments':
        hideHomeFeedItemsWithoutVisibleComments,
  };

  factory CommentShieldingConfig.fromJson(Map<String, Object?> json) {
    int? readInt(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    int? readRangeInt(String key, {int? max}) {
      final value = readInt(key);
      if (value == null || value < 0) return null;
      if (max != null && value > max) return null;
      return value;
    }

    List<String> readStringList(String key) {
      final value = json[key];
      if (value is List) {
        return value.whereType<String>().toList();
      }
      return const [];
    }

    final minCharCount = readRangeInt('min_char_count');
    final maxCharCount = readRangeInt('max_char_count');
    final hasInvertedCharRange =
        minCharCount != null &&
        maxCharCount != null &&
        minCharCount > maxCharCount;

    return CommentShieldingConfig(
      version: json['version'] as int? ?? 1,
      levelThreshold: readRangeInt('level_threshold', max: 6),
      genderFilter: readStringList('gender_filter'),
      memberFilter: readStringList('member_filter'),
      ipLocationFilter: readStringList('ip_location_filter'),
      minCharCount: hasInvertedCharRange ? null : minCharCount,
      maxCharCount: hasInvertedCharRange ? null : maxCharCount,
      likeThreshold: readRangeInt('like_threshold'),
      blockWithPicture: json['block_with_picture'] as bool? ?? false,
      blockWithEmote: json['block_with_emote'] as bool? ?? false,
      hideHomeFeedItemsWithoutVisibleComments:
          json['hide_home_feed_items_without_visible_comments'] as bool? ??
          false,
    );
  }

  factory CommentShieldingConfig.tryFromJson(Map<String, Object?> json) {
    try {
      return CommentShieldingConfig.fromJson(json);
    } catch (_) {
      return const CommentShieldingConfig();
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommentShieldingConfig &&
          runtimeType == other.runtimeType &&
          levelThreshold == other.levelThreshold &&
          _listEquals(genderFilter, other.genderFilter) &&
          _listEquals(memberFilter, other.memberFilter) &&
          _listEquals(ipLocationFilter, other.ipLocationFilter) &&
          minCharCount == other.minCharCount &&
          maxCharCount == other.maxCharCount &&
          likeThreshold == other.likeThreshold &&
          blockWithPicture == other.blockWithPicture &&
          blockWithEmote == other.blockWithEmote &&
          hideHomeFeedItemsWithoutVisibleComments ==
              other.hideHomeFeedItemsWithoutVisibleComments &&
          version == other.version;

  @override
  int get hashCode => Object.hash(
    levelThreshold,
    Object.hashAll(genderFilter),
    Object.hashAll(memberFilter),
    Object.hashAll(ipLocationFilter),
    minCharCount,
    maxCharCount,
    likeThreshold,
    blockWithPicture,
    blockWithEmote,
    hideHomeFeedItemsWithoutVisibleComments,
    version,
  );

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

const Object _copyWithUnset = Object();

class CommentShieldingStore {
  CommentShieldingStore({ShieldSettingsBox? box})
    : _box = box ?? HiveShieldSettingsBox(GStorage.setting) {
    if (box != null) {
      _cachedSnapshot = null;
    }
  }

  static const namespace = 'piliavalon.comment_shielding.v1';
  static const configKey = '$namespace.config';

  final ShieldSettingsBox _box;

  static CommentShieldingConfig? _cachedSnapshot;

  CommentShieldingConfig snapshot() {
    final cached = _cachedSnapshot;
    if (cached != null) return cached;

    final raw = _box.get(configKey);
    if (raw == null) {
      return _cachedSnapshot = const CommentShieldingConfig();
    }
    if (raw is! String || raw.isEmpty) {
      return _cachedSnapshot = const CommentShieldingConfig();
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final config = CommentShieldingConfig.tryFromJson(
        json.cast<String, Object?>(),
      );
      _cachedSnapshot = config;
      return config;
    } catch (_) {
      return _cachedSnapshot = const CommentShieldingConfig();
    }
  }

  Future<void> save(CommentShieldingConfig config) async {
    try {
      final payload = jsonEncode(config.toJson());
      await _box.put(configKey, payload);
      _cachedSnapshot = config;
    } catch (e) {
      throw ShieldStoreException(
        'Failed to save comment shielding config: $e',
      );
    }
  }
}

/// Canonical VIP key from membership fields.
String vipKey(int vipType, int vipStatus) => 'vip:$vipType:$vipStatus';

/// Canonical IP location by stripping the Bilibili prefix.
String canonicalIpLocation(String raw) =>
    raw.trim().replaceFirst(RegExp(r'^IP属地[:：]\s*'), '').trim();

/// Result of matching a reply against comment shielding config.
class CommentShieldMatch {
  const CommentShieldMatch.visible() : blockedBy = null;
  const CommentShieldMatch.blocked(this.blockedBy);

  final String? blockedBy;
  bool get visible => blockedBy == null;
}

/// Matches a [ReplyInfo] against [CommentShieldingConfig] thresholds and filters.
abstract final class CommentShieldMatcher {
  static CommentShieldMatch match(
    ReplyInfo reply,
    CommentShieldingConfig config,
  ) {
    // Use ReplyInfo access.
    final member = reply.member;
    final content = reply.content;

    // 1. Level threshold
    if (config.levelThreshold != null && config.levelThreshold! > 0) {
      final level = member.level.toInt();
      if (level < config.levelThreshold!) {
        return const CommentShieldMatch.blocked('levelThreshold');
      }
    }

    // 2. Gender filter
    if (config.genderFilter.isNotEmpty) {
      final sex = member.sex;
      if (config.genderFilter.contains(sex)) {
        return const CommentShieldMatch.blocked('genderFilter');
      }
    }

    // 3. Member/VIP filter
    if (config.memberFilter.isNotEmpty) {
      final key = vipKey(member.vipType.toInt(), member.vipStatus.toInt());
      if (config.memberFilter.contains(key)) {
        return const CommentShieldMatch.blocked('memberFilter');
      }
    }

    // 4. IP location filter
    if (config.ipLocationFilter.isNotEmpty) {
      final rawLocation = reply.replyControl.location;
      final canonical = canonicalIpLocation(rawLocation);
      if (canonical.isNotEmpty && config.ipLocationFilter.contains(canonical)) {
        return const CommentShieldMatch.blocked('ipLocationFilter');
      }
    }

    // 5. Min char count
    if (config.minCharCount != null) {
      final length = content.message.length;
      if (length < config.minCharCount!) {
        return const CommentShieldMatch.blocked('minCharCount');
      }
    }

    // 6. Max char count
    if (config.maxCharCount != null) {
      final length = content.message.length;
      if (length > config.maxCharCount!) {
        return const CommentShieldMatch.blocked('maxCharCount');
      }
    }

    // 7. Like threshold
    if (config.likeThreshold != null && config.likeThreshold! > 0) {
      final like = reply.like.toInt();
      if (like < config.likeThreshold!) {
        return const CommentShieldMatch.blocked('likeThreshold');
      }
    }

    // 8. Block with picture
    if (config.blockWithPicture && content.pictures.isNotEmpty) {
      return const CommentShieldMatch.blocked('blockWithPicture');
    }

    // 9. Block with emote
    if (config.blockWithEmote && content.emotes.isNotEmpty) {
      return const CommentShieldMatch.blocked('blockWithEmote');
    }

    return const CommentShieldMatch.visible();
  }
}
