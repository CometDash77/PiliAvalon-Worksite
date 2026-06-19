import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show ReplyInfo;
import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/models/model_hot_video_item.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/features/shielding/shielding_matcher.dart';
import 'package:PiliPlus/features/shielding/shielding_models.dart';

abstract final class ShieldingAdapters {
  static ShieldCandidate fromRecommendationJson(
    BaseRcmdVideoItemModel item,
    Map<String, dynamic> json,
  ) {
    final owner = json['owner'] as Map?;
    final args = json['args'] as Map?;
    final category = _string(json['tname'] ?? args?['tname']);
    final authorName = _firstString([
      owner?['name'],
      args?['up_name'],
      args?['uname'],
      json['owner_name'],
      item.owner.name,
    ]);
    final tags = _tags(json);
    final reason = _recommendationReason(
      itemReason: item.rcmdReason,
      jsonReason: json['rcmd_reason'],
    );
    // Direct structured fields from the source model.
    // item.duration is a direct int for both web and app models.
    final num? durationSeconds = item.duration > 0 ? item.duration : null;
    num? playbackCount;
    num? danmakuCount;
    if (item is RcmdVideoItemModel) {
      // Web recommendation: stat fields are direct JSON integers.
      playbackCount = item.stat.view;
      danmakuCount = item.stat.danmu;
    } else if (item is RcmdVideoItemAppModel) {
      // App recommendation: RcmdStat parses cover_left_text_1/2 into view/danmu.
      playbackCount = item.stat.view;
      danmakuCount = item.stat.danmu;
    }

    // task-066 detail-introduction candidate metadata from homepage.
    final description =
        _nonEmpty(item.desc) ?? _nonEmpty(json['desc']?.toString());
    final pubdate = item.pubdate ?? json['pubdate'] as int?;
    final isUpowerExclusive =
        json['charging_pay'] is Map && json['charging_pay']['level'] != null
        ? true
        : null;
    final staffNames = _staffNames(json['staff']);

    return ShieldCandidate(
      scope: ShieldScope.recommendation,
      title: item.title,
      reason: reason,
      uid: _string(owner?['mid'] ?? args?['up_id'] ?? item.owner.mid),
      authorName: authorName,
      authorTokens: _tokens([authorName]),
      category: category,
      tags: tags,
      tokens: _tokens([
        item.title,
        reason,
        ...tags,
      ]),
      durationSeconds: durationSeconds,
      playbackCount: playbackCount,
      danmakuCount: danmakuCount,
      description: description,
      pubdate: pubdate,
      staffNames: staffNames,
      isUpowerExclusive: isUpowerExclusive,
    );
  }

  static ShieldCandidate fromReplyInfo(ReplyInfo reply) {
    final uid = reply.hasMid()
        ? reply.mid.toString()
        : reply.hasMember()
        ? reply.member.mid.toString()
        : null;
    final pendantValues = <String>[
      if (reply.hasMember() && reply.member.garbPendantImage.isNotEmpty)
        reply.member.garbPendantImage,
      if (reply.hasMemberV2() &&
          reply.memberV2.hasGarb() &&
          reply.memberV2.garb.pendantImage.isNotEmpty)
        reply.memberV2.garb.pendantImage,
    ];
    final garbValues = <String>[
      if (reply.hasMember()) ...[
        if (reply.member.garbCardNumber.isNotEmpty) reply.member.garbCardNumber,
        if (reply.member.garbCardImage.isNotEmpty) reply.member.garbCardImage,
        if (reply.member.garbCardJumpUrl.isNotEmpty)
          reply.member.garbCardJumpUrl,
      ],
      if (reply.hasMemberV2() && reply.memberV2.hasGarb()) ...[
        if (reply.memberV2.garb.cardNumber.isNotEmpty)
          reply.memberV2.garb.cardNumber,
        if (reply.memberV2.garb.cardImage.isNotEmpty)
          reply.memberV2.garb.cardImage,
        if (reply.memberV2.garb.cardJumpUrl.isNotEmpty)
          reply.memberV2.garb.cardJumpUrl,
      ],
    ];
    return ShieldCandidate(
      scope: ShieldScope.comment,
      body: reply.hasContent() ? reply.content.message : null,
      uid: uid,
      authorName: reply.hasMember() ? reply.member.name : null,
      authorTokens: _tokens([
        if (reply.hasMember()) reply.member.name,
      ]),
      tokens: _tokens([
        if (reply.hasContent()) reply.content.message,
      ]),
      avatarPendantValues: pendantValues,
      garbValues: garbValues,
    );
  }

  static ShieldCandidate fromRelatedVideo(
    HotVideoItemModel item, {
    ShieldScope scope = ShieldScope.recommendation,
  }) => ShieldCandidate(
    scope: scope,
    title: item.title,
    uid: item.owner.mid?.toString(),
    authorName: item.owner.name,
    authorTokens: _tokens([item.owner.name]),
    category: item.tname,
    tokens: _tokens([
      item.title,
      item.tname,
    ]),
    // task-066: populate detail-introduction fields from related-video model.
    description: item.desc,
    pubdate: item.pubdate,
    staffNames: item.staffNames,
    isUpowerExclusive: item.badge == '充电专属'
        ? true
        : (item.badge == null ? null : false),
  );

  static List<T> filterList<T>(
    List<T> items, {
    required bool enabled,
    required ShieldRuleSet ruleSet,
    required ShieldCandidate Function(T item) toCandidate,
  }) {
    if (!enabled || !ruleSet.globalEnabled || items.isEmpty) {
      return items;
    }
    return items
        .where(
          (item) => ShieldMatcher.match(toCandidate(item), ruleSet).visible,
        )
        .toList();
  }

  static bool isVisible(ShieldCandidate candidate, ShieldRuleSet ruleSet) =>
      ShieldMatcher.match(candidate, ruleSet).visible;

  static List<HotVideoItemModel> filterRecommendationVideos(
    List<HotVideoItemModel> items,
    ShieldRuleSet ruleSet,
  ) => filterList(
    items,
    enabled: ruleSet.recommendationEnabled,
    ruleSet: ruleSet,
    toCandidate: fromRelatedVideo,
  );

  /// Applies related-video shielding to a list of [HotVideoItemModel] items.
  ///
  /// Uses the independent [ShieldRuleSet.relatedVideoEnabled] switch
  /// (not [recommendationEnabled]) and scopes candidates as
  /// [ShieldScope.videoDetail].
  /// The legacy [filterRecommendationVideos] remains unchanged for
  /// homepage and ranking call sites.
  static List<HotVideoItemModel> filterRelatedVideos(
    List<HotVideoItemModel> items,
    ShieldRuleSet ruleSet,
  ) => filterList(
    items,
    enabled: ruleSet.relatedVideoEnabled,
    ruleSet: ruleSet,
    toCandidate: (item) =>
        fromRelatedVideo(item, scope: ShieldScope.videoDetail),
  );

  static List<String> _tags(Map<String, dynamic> json) {
    final raw = json['tag'] ?? json['tags'];
    if (raw is Iterable) {
      return raw.whereType<Object?>().map((e) => e.toString()).toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return raw
          .split(RegExp(r'[,，\s]+'))
          .where((tag) => tag.trim().isNotEmpty)
          .toList();
    }
    return const [];
  }

  static List<String> _tokens(Iterable<String?> values) => values
      .whereType<String>()
      .expand((value) => value.split(RegExp(r'[\s,，。！？!?:：;；]+')))
      .where((value) => value.trim().isNotEmpty)
      .toList();
}

String? _string(Object? value) => value?.toString();

String? _firstString(Iterable<Object?> values) {
  for (final value in values) {
    final string = value?.toString().trim();
    if (string != null && string.isNotEmpty) return string;
  }
  return null;
}

String? _recommendationReason({
  required String? itemReason,
  required Object? jsonReason,
}) {
  final fromItem = itemReason?.trim();
  if (fromItem?.isNotEmpty == true) return fromItem;
  if (jsonReason is Map) {
    return _nonEmpty(_string(jsonReason['content'])?.trim());
  }
  return _nonEmpty(_string(jsonReason)?.trim());
}

String? _nonEmpty(String? value) => value?.isNotEmpty == true ? value : null;

List<String> _staffNames(Object? raw) {
  if (raw is! Iterable) return const [];
  final values = <String>[];
  for (final item in raw) {
    if (item is Map) {
      for (final key in const ['name', 'title']) {
        final value = _nonEmpty(item[key]?.toString().trim());
        if (value != null) values.add(value);
      }
    } else {
      final value = _nonEmpty(item?.toString().trim());
      if (value != null) values.add(value);
    }
  }
  return List.unmodifiable(values);
}
