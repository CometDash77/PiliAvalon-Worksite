// Micro-benchmark for the ShieldMatcher hot path.
//
// Reproduces the "candidates x rules" shape used by the recommendation pages:
// one rule set, many candidates, repeated page passes. Run with:
//   dart run tool/bench/shield_matcher_bench.dart
import 'dart:math' as math;

// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings
import 'package:PiliPlus/features/shielding/shielding_matcher.dart';
import 'package:PiliPlus/features/shielding/shielding_models.dart';

const _candidateCount = 20;
const _iterations = 100;
const _samples = 7;

ShieldRule _rule({
  required int id,
  required ShieldRuleType type,
  ShieldMatchMode mode = ShieldMatchMode.contains,
  required String pattern,
  ShieldScope scope = ShieldScope.recommendation,
  ShieldAction action = ShieldAction.block,
  bool enabled = true,
}) => ShieldRule(
  id: 'rule-' + id.toString(),
  type: type,
  matchMode: mode,
  scope: scope,
  action: action,
  pattern: pattern,
  enabled: enabled,
  updatedAt: _ruleEpoch,
);

final DateTime _ruleEpoch = DateTime.utc(2025, 10, 3);

ShieldRuleSet _ruleSet() {
  final rules = <ShieldRule>[];
  var id = 0;

  // 20 keyword rules: contains/exact/regex leave plenty of work per candidate.
  for (var i = 0; i < 20; i++) {
    final mode = ShieldMatchMode.values[i % 3];
    final pattern = mode == ShieldMatchMode.regex
        ? '关键词' + i.toString() + '+'
        : '关键词' + i.toString();
    rules.add(
      _rule(
        id: ++id,
        type: ShieldRuleType.keyword,
        mode: mode,
        pattern: pattern,
      ),
    );
  }

  // 12 user keyword rules split between token and regex modes.
  for (var i = 0; i < 12; i++) {
    final token = i.isEven;
    rules.add(
      _rule(
        id: ++id,
        type: ShieldRuleType.userKeyword,
        mode: token ? ShieldMatchMode.token : ShieldMatchMode.regex,
        pattern: token ? 'UP' + i.toString() : 'UP(' + i.toString() + '|主)',
      ),
    );
  }

  // 10 reason keyword rules.
  for (var i = 0; i < 10; i++) {
    rules.add(
      _rule(
        id: ++id,
        type: ShieldRuleType.reasonKeyword,
        mode: ShieldMatchMode.contains,
        pattern: '因为你看过' + i.toString(),
      ),
    );
  }

  // 8 tag token rules.
  for (var i = 0; i < 8; i++) {
    rules.add(
      _rule(
        id: ++id,
        type: ShieldRuleType.tag,
        mode: ShieldMatchMode.token,
        pattern: '标签' + i.toString(),
      ),
    );
  }

  // 8 numeric range rules (duration/playback/danmaku/comment level).
  const numericTypes = [
    ShieldRuleType.duration,
    ShieldRuleType.playbackCount,
    ShieldRuleType.danmakuCount,
    ShieldRuleType.commentMemberLevel,
  ];
  for (var i = 0; i < 8; i++) {
    rules.add(
      _rule(
        id: ++id,
        type: numericTypes[i % numericTypes.length],
        mode: ShieldMatchMode.range,
        pattern: i.toString() + '..' + (i + 100000).toString(),
      ),
    );
  }

  // 8 enum rules + 2 exact uid rules + 2 disabled + 2 comment-scope rules.
  for (var i = 0; i < 8; i++) {
    rules.add(
      _rule(
        id: ++id,
        type: ShieldRuleType.category,
        mode: ShieldMatchMode.enumValue,
        pattern: '分区_' + i.toString(),
      ),
    );
  }
  rules.add(
    _rule(
      id: ++id,
      type: ShieldRuleType.uid,
      mode: ShieldMatchMode.exact,
      pattern: '90001',
    ),
  );
  rules.add(
    _rule(
      id: ++id,
      type: ShieldRuleType.uid,
      mode: ShieldMatchMode.exact,
      pattern: '90002',
    ),
  );
  rules.add(
    _rule(
      id: ++id,
      type: ShieldRuleType.keyword,
      mode: ShieldMatchMode.contains,
      pattern: '禁用规则',
      enabled: false,
    ),
  );
  rules.add(
    _rule(
      id: ++id,
      type: ShieldRuleType.keyword,
      mode: ShieldMatchMode.regex,
      pattern: '禁用正则.*',
      enabled: false,
    ),
  );
  rules.add(
    _rule(
      id: ++id,
      type: ShieldRuleType.keyword,
      mode: ShieldMatchMode.contains,
      pattern: '评论专用',
      scope: ShieldScope.comment,
    ),
  );
  rules.add(
    _rule(
      id: ++id,
      type: ShieldRuleType.keyword,
      mode: ShieldMatchMode.contains,
      pattern: '评论置顶',
      scope: ShieldScope.comment,
    ),
  );

  if (rules.length != 72) {
    throw StateError('expected 72 rules, got ' + rules.length.toString());
  }
  return ShieldRuleSet(rules: rules);
}

List<ShieldCandidate> _candidates() {
  final random = math.Random(20251003);
  return List.generate(_candidateCount, (index) {
    final tags = List.generate(6, (tagIndex) => '标签' + tagIndex.toString() + '-' + index.toString());
    final words = List.generate(8, (wordIndex) => '词' + wordIndex.toString()).join(' ');
    final author = 'UP' + (index % 12).toString() + '主 ' + index.toString();
    return ShieldCandidate(
      scope: index.isEven ? ShieldScope.recommendation : ShieldScope.comment,
      title: '普通标题 ' + index.toString() + ' ' + words,
      body: '评论正文 ' + index.toString() + ' ' + words,
      reason: '因为你看过UP' + (index % 12).toString(),
      uid: (90000 + index).toString(),
      authorName: author,
      authorTokens: const ['UP0', 'UP1'],
      category: '分区_' + (index % 8).toString(),
      tags: tags,
      tokens: [tags.first, 'UP' + (index % 12).toString()],
      durationSeconds: 60 + index,
      playbackCount: 1000 + index,
      danmakuCount: 20 + index,
      commentMemberLevel: index % 6,
      description: '简介 ' + index.toString(),
      pubdate: 1700000000 + index,
      staffNames: const ['staff-a', 'staff-b'],
      isUpowerExclusive: random.nextBool(),
    );
  });
}

void main() {
  final ruleSet = _ruleSet();
  final candidates = _candidates();

  var warmupMatches = 0;
  for (var warmup = 0; warmup < 20; warmup++) {
    for (final candidate in candidates) {
      if (ShieldMatcher.match(candidate, ruleSet).visible) warmupMatches++;
    }
  }

  final samples = <double>[];
  for (var sample = 0; sample < _samples; sample++) {
    final watch = Stopwatch()..start();
    for (var iteration = 0; iteration < _iterations; iteration++) {
      for (final candidate in candidates) {
        ShieldMatcher.match(candidate, ruleSet);
      }
    }
    watch.stop();
    samples.add(watch.elapsedMicroseconds / _iterations);
  }
  samples.sort();
  final median = samples[samples.length ~/ 2];

  print(
    'rules=' +
        ruleSet.rules.length.toString() +
        ' candidates=' +
        candidates.length.toString() +
        ' iterations=' +
        _iterations.toString() +
        ' samples=' +
        samples.length.toString(),
  );
  print(
    'per-pass median=' +
        median.toStringAsFixed(1) +
        'us min=' +
        samples.first.toStringAsFixed(1) +
        'us max=' +
        samples.last.toStringAsFixed(1) +
        'us',
  );
  print(
    'per-match median=' +
        (median / _candidateCount).toStringAsFixed(2) +
        'us warmupMatches=' +
        warmupMatches.toString(),
  );
}
