import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/features/shielding/shielding_matcher.dart' as current;
import 'package:PiliPlus/features/shielding/shielding_models.dart';
import '_legacy_shielding_matcher.dart' as legacy;

// map #47 / issue #52 acceptance harness: same process, same workload,
// legacy (HEAD) matcher vs optimized matcher.

const _docs = [
  ['原神攻略：枫丹版本角色培养全解析与圣遗物搭配思路', '恰饭广告 抽奖 恰饭推广', '带货', '游戏'],
  ['【4K】赛博朋克边缘行者全剧集剪辑合集', '剪辑 混剪 mv', '转载', '影视'],
  ['关于我在深夜食堂点了一份奇怪套餐这件事', 'vlog 日常 记录', '原创', '生活'],
  ['从零开始学算法：动态规划入门到放弃', '算法 编程 教程', '原创', '科技'],
  ['今日股市复盘：几个值得关注的方向', '财经 股市 投资', '转载', '财经'],
  ['手机拆解：这台旗舰的散热到底行不行', '数码 拆机 评测', '原创', '数码'],
  ['十分钟看懂量子纠缠的五个常见误解', '科普 物理 量子', '原创', '知识'],
  ['深夜放毒：自制麻辣香锅全流程', '美食 烹饪 家常菜', '原创', '美食'],
  ['旅行vlog：一个人去大理看洱海的第七天', '旅行 vlog 大理', '原创', '生活'],
  ['电竞选手第一视角训练复盘', '电竞 游戏 训练', '转载', '游戏'],
  ['吐槽一下最近排位的匹配机制', '吐槽 排位 游戏', '原创', '游戏'],
  ['音乐会现场：肖邦夜曲全集演奏', '音乐 钢琴 古典', '原创', '音乐'],
  ['健身打卡第 100 天：从 90kg 到 70kg', '健身 减脂 打卡', '原创', '体育'],
  ['宠物日常：橘猫的一天到底有多忙', '宠物 猫 日常', '原创', '动物'],
  ['手办开箱：这个价格值不值', '开箱 手办 二次元', '原创', '动画'],
  ['汽车保养避坑指南：这些项目其实不用做', '汽车 保养 避坑', '原创', '汽车'],
  ['纪录片推荐：五部值得反复观看的作品', '纪录片 推荐 影视', '转载', '影视'],
  ['深夜电台：那些年我们听过的老歌', '电台 音乐 怀旧', '原创', '音乐'],
  ['摄影后期：一张照片的完整调色流程', '摄影 调色 教程', '原创', '摄影'],
  ['职场经验分享：如何优雅地拒绝需求', '职场 职场经验 分享', '原创', '职场'],
];

const _authors = [
  '深夜食堂官方', '科技美学', '老张说游戏', '小破站音乐君', '测评小分队',
  '不定期更新的UP', '知识区搬运工', '带货警告', '旅行的小王', '健身教练老李',
];

List<ShieldRule> _buildRules() {
  final types = <ShieldRuleType>[
    ShieldRuleType.keyword,
    ShieldRuleType.userKeyword,
    ShieldRuleType.reasonKeyword,
    ShieldRuleType.uid,
    ShieldRuleType.category,
    ShieldRuleType.tag,
    ShieldRuleType.avatarPendant,
    ShieldRuleType.garb,
    ShieldRuleType.duration,
    ShieldRuleType.playbackCount,
    ShieldRuleType.danmakuCount,
    ShieldRuleType.commentMemberSex,
    ShieldRuleType.commentMemberLevel,
    ShieldRuleType.descriptionKeyword,
    ShieldRuleType.publishTime,
    ShieldRuleType.isUpowerExclusive,
    ShieldRuleType.staffKeyword,
  ];
  const modes = <ShieldMatchMode>[
    ShieldMatchMode.exact,
    ShieldMatchMode.contains,
    ShieldMatchMode.regex,
    ShieldMatchMode.contains,
    ShieldMatchMode.regex,
    ShieldMatchMode.exact,
  ];
  const patterns = <String>[
    '恰饭', '广告', '带货', '抽奖', '代购', '推广', '福利',
    '深夜食堂', '科技美学', '老张说游戏', '小破站音乐君',
    '转载', '搬运', '剪辑', '混剪',
    r'^第\s*\d+\s*集', r'(?i)spoiler|剧透', r'^\d{4}年', r'拼团|团购',
    '比特币', '炒币', '赌', '麻将', '棋牌',
    '1-1000', '0-60', '100000-9999999', '2020-2024',
    'male', 'true', '原创',
  ];
  final rules = <ShieldRule>[];
  for (var i = 0; i < 72; i++) {
    final type = types[i % types.length];
    ShieldMatchMode mode;
    switch (type) {
      case ShieldRuleType.duration:
      case ShieldRuleType.playbackCount:
      case ShieldRuleType.danmakuCount:
      case ShieldRuleType.publishTime:
        mode = ShieldMatchMode.range;
        break;
      case ShieldRuleType.commentMemberSex:
      case ShieldRuleType.isUpowerExclusive:
        mode = ShieldMatchMode.enumValue;
        break;
      case ShieldRuleType.commentMemberLevel:
        mode = i.isEven ? ShieldMatchMode.range : ShieldMatchMode.exact;
        break;
      case ShieldRuleType.roomId:
        mode = ShieldMatchMode.exact;
        break;
      default:
        mode = i % 13 == 0
            ? ShieldMatchMode.token
            : modes[i % modes.length];
    }
    final numericType =
        type == ShieldRuleType.duration ||
        type == ShieldRuleType.playbackCount ||
        type == ShieldRuleType.danmakuCount ||
        type == ShieldRuleType.commentMemberLevel ||
        type == ShieldRuleType.publishTime;
    final raw = numericType
        ? const ['1-1000', '0-60', '100000-9999999', '2020-2024'][i % 4]
        : patterns[i % patterns.length];
    rules.add(
      ShieldRule(
        id: 'rule-${i}',
        type: type,
        matchMode: mode,
        scope: i % 9 == 0 ? ShieldScope.both : ShieldScope.recommendation,
        action: i % 5 == 0 ? ShieldAction.allow : ShieldAction.block,
        pattern: raw,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000 + i),
      ),
    );
  }
  return rules;
}

List<ShieldCandidate> _buildCandidates() {
  final candidates = <ShieldCandidate>[];
  for (var i = 0; i < 20; i++) {
    final doc = _docs[i % _docs.length];
    final tags = doc[1].split(' ');
    final tokens = <String>[
      ...doc[0].split(RegExp(r'[\s,，。！？!?:：;；_\-]+')),
      ...doc[1].split(RegExp(r'[\s,，。！？!?:：;；_\-]+')),
    ].where((value) => value.trim().isNotEmpty).toList();
    candidates.add(
      ShieldCandidate(
        scope: ShieldScope.recommendation,
        title: doc[0],
        body: doc[0],
        reason: doc[2],
        uid: '${1000000 + i * 37}',
        authorName: _authors[i % _authors.length],
        authorTokens: _authors[i % _authors.length].split(', '),
        category: doc[3],
        tags: tags,
        tokens: tokens,
        avatarPendantValues: i % 4 == 0 ? const ['恰饭'] : const [],
        garbValues: i % 6 == 0 ? const ['福利'] : const [],
        durationSeconds: 30 + i * 17,
        playbackCount: 1000 + i * 313,
        danmakuCount: 10 + i * 7,
        commentMemberSex: i.isEven ? 'male' : 'female',
        commentMemberLevel: 6,
        description: doc[0],
        pubdate: 1700000000 + i * 86400,
        staffNames: i % 5 == 0 ? const ['深夜食堂官方'] : const [],
        isUpowerExclusive: i % 3 == 0,
      ),
    );
  }
  return candidates;
}

String _describe(ShieldMatchResult r) =>
    'visible=${r.visible} block=${r.blockedBy?.id} allow=${r.allowedBy?.id} '
    'err=${r.errors.length}';

void main() {
  test('map#47 / issue#52: legacy vs optimized ShieldMatcher', () {
    final ruleSet = ShieldRuleSet(rules: _buildRules());
    final candidates = _buildCandidates();

    var mismatches = 0;
    for (final candidate in candidates) {
      final a = legacy.ShieldMatcher.match(candidate, ruleSet);
      final b = current.ShieldMatcher.match(candidate, ruleSet);
      final same =
          a.visible == b.visible &&
          a.blockedBy?.id == b.blockedBy?.id &&
          a.allowedBy?.id == b.allowedBy?.id &&
          a.errors.length == b.errors.length;
      if (!same) {
        mismatches++;
        final legacyErrs = a.errors.map((e) => e.rule.id).toSet();
        final currentErrs = b.errors.map((e) => e.rule.id).toSet();
        final onlyLegacy = legacyErrs.difference(currentErrs);
        final onlyCurrent = currentErrs.difference(legacyErrs);
        print('MISMATCH: legacy(${_describe(a)}) vs optimized(${_describe(b)})');
        print('  only-legacy-errors=${onlyLegacy} only-optimized-errors=${onlyCurrent}');
        for (final e in a.errors) {
          if (onlyLegacy.contains(e.rule.id)) {
            print('  probe rule: id=${e.rule.id} type=${e.rule.type} '
                'mode=${e.rule.matchMode} pattern=${e.rule.pattern}');
            print('  probe msg: ${e.message}');
          }
        }
      }
    }
    print('equivalence: ${mismatches} mismatch(es) over ${candidates.length} candidates');
    expect(mismatches, 0);

    void page(bool useLegacy) {
      for (final candidate in candidates) {
        if (useLegacy) {
          legacy.ShieldMatcher.match(candidate, ruleSet);
        } else {
          current.ShieldMatcher.match(candidate, ruleSet);
        }
      }
    }

    double medianMicrosPerPage(
      bool useLegacy, {
      int iterations = 100,
      int samples = 7,
    }) {
      for (var i = 0; i < 30; i++) {
        page(useLegacy);
      }
      final results = <double>[];
      for (var s = 0; s < samples; s++) {
        final sw = Stopwatch()..start();
        for (var i = 0; i < iterations; i++) {
          page(useLegacy);
        }
        sw.stop();
        results.add(sw.elapsedMicroseconds / iterations);
      }
      results.sort();
      return results[results.length ~/ 2];
    }

    final legacyFirst = medianMicrosPerPage(true);
    final currentFirst = medianMicrosPerPage(false);
    final legacySecond = medianMicrosPerPage(true);
    final currentSecond = medianMicrosPerPage(false);

    print('legacy    us/page: ${legacyFirst.toStringAsFixed(1)} / ${legacySecond.toStringAsFixed(1)}');
    print('optimized us/page: ${currentFirst.toStringAsFixed(1)} / ${currentSecond.toStringAsFixed(1)}');
    print(
      'speedup: ${(legacyFirst / currentFirst).toStringAsFixed(2)}x / '
      '${(legacySecond / currentSecond).toStringAsFixed(2)}x',
    );
  });
}
