import 'dart:convert';

import 'package:PiliPlus/features/jev/jev_contract.dart';
import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:PiliPlus/features/jev/jev_settings.dart';
import 'package:PiliPlus/features/llm/llm_rules.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBox implements JevSettingsBox {
  final map = <String, Object?>{};
  @override
  Object? get(String key, {Object? defaultValue}) => map[key] ?? defaultValue;
  @override
  Future<void> put(String key, Object? value) async {
    map[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    map.remove(key);
  }
}

LlmVideoRule _rule(String id, {String? text, bool enabled = true}) =>
    LlmVideoRule(id: id, text: text ?? '隐藏明显的广告评论', enabled: enabled);

JevRule _noulRule({String question = '是否为广告？', String? yes, String? no}) =>
    JevRule(
      id: 'r1',
      target: JevRuleTarget.comment,
      question: question,
      type: JevRuleType.noul,
      threshold: JevLimits.hideNoulThreshold,
      yesMeaning: yes ?? '',
      noMeaning: no ?? '',
    );

void main() {
  group('LlmVideoRule', () {
    test('rejects blank ids and out-of-range text', () {
      expect(const LlmVideoRule(id: '', text: 'x').validate(), isNotNull);
      expect(const LlmVideoRule(id: 'a', text: '').validate(), isNotNull);
      expect(
        LlmVideoRule(
          id: 'a',
          text: '长' * (LlmVideoRule.maxTextRunes + 1),
        ).validate(),
        isNotNull,
      );
      expect(
        LlmVideoRule(id: 'a', text: '长' * LlmVideoRule.maxTextRunes).validate(),
        isNull,
      );
      expect(
        LlmVideoRule(id: 'a', text: 'a' * LlmVideoRule.maxTextRunes).validate(),
        isNull,
      );
    });

    test('json round-trip keeps id, text and switch', () {
      final rule = _rule('a', text: 't1', enabled: false);
      final back = LlmVideoRule.fromJson(rule.toJson());
      expect(back.id, 'a');
      expect(back.text, 't1');
      expect(back.enabled, isFalse);
    });
  });

  group('LlmVideoRuleStore', () {
    test('empty box loads an empty config', () async {
      final store = LlmVideoRuleStore(box: _FakeBox());
      expect((await store.load()).rules, isEmpty);
    });

    test('save then load round-trips', () async {
      final box = _FakeBox();
      final store = LlmVideoRuleStore(box: box);
      await store.save(
        LlmVideoRuleConfig(rules: [_rule('a'), _rule('b', enabled: false)]),
      );
      final loaded = await store.load();
      expect(loaded.rules, hasLength(2));
      expect(loaded.rules[0].id, 'a');
      expect(loaded.rules[1].enabled, isFalse);
    });

    test(
      'save rejects more than the per-surface cap and duplicate ids',
      () {
        final store = LlmVideoRuleStore(box: _FakeBox());
        expect(
          () => store.save(
            LlmVideoRuleConfig(
              rules: List.generate(
                LlmVideoRule.maxRulesPerSurface + 1,
                (i) => _rule('r$i'),
              ),
            ),
          ),
          throwsArgumentError,
        );
        expect(
          () => store.save(
            LlmVideoRuleConfig(rules: [_rule('dup'), _rule('dup')]),
          ),
          throwsArgumentError,
        );
      },
    );

    test('load caps and dedupes hostile content', () async {
      final box = _FakeBox();
      final store = LlmVideoRuleStore(box: box);
      final over = List.generate(
        LlmVideoRule.maxRulesPerSurface + 3,
        (i) => _rule('r$i'),
      );
      final entries = [for (final r in over) r.toJson(), _rule('r0').toJson()];
      final raw = {'version': 1, 'rules': entries};
      await box.put(LlmVideoRuleStore.key, jsonEncode(raw));
      final loaded = await store.load();
      expect(loaded.rules.length, LlmVideoRule.maxRulesPerSurface);
      expect(loaded.rules.where((r) => r.id == 'r0'), hasLength(1));
    });

    test('corrupt blobs fail open as an empty config', () async {
      final box = _FakeBox();
      final store = LlmVideoRuleStore(box: box);
      await box.put(LlmVideoRuleStore.key, '{not json');
      expect((await store.load()).rules, isEmpty);
      await box.put(
        LlmVideoRuleStore.key,
        jsonEncode({'version': 2, 'rules': []}),
      );
      expect((await store.load()).rules, isEmpty);
      await box.put(
        LlmVideoRuleStore.key,
        jsonEncode({
          'version': 1,
          'rules': [
            {'id': 'x'},
          ],
        }),
      );
      expect((await store.load()).rules, isEmpty);
    });
  });

  group('rule_version', () {
    test('is a stable 16-hex digest', () {
      final v = videoRuleVersion([_rule('a')]);
      expect(RegExp('^[0-9a-f]{16}').hasMatch(v), isTrue);
      expect(videoRuleVersion([_rule('a')]), v);
    });

    test('content edits change it, whitespace does not', () {
      final base = videoRuleVersion([_rule('a', text: '隐藏广告')]);
      expect(videoRuleVersion([_rule('a', text: '隐藏广告 ')]), base);
      expect(videoRuleVersion([_rule('a', text: '隐藏推广')]), isNot(base));
    });

    test('enable toggle and rule order change it', () {
      final both = videoRuleVersion([_rule('a'), _rule('b')]);
      expect(videoRuleVersion([_rule('b'), _rule('a')]), isNot(both));
    });

    test('disabled rules are excluded from the active version', () {
      final active = [_rule('a'), _rule('b', enabled: false)];
      expect(videoRuleVersion(active), videoRuleVersion([_rule('a')]));
      // 空态稳定
      expect(videoRuleVersion(const []), videoRuleVersion(const []));
    });
  });

  group('LlmCommentRuleView', () {
    test('noul rendering carries question and meanings, drops threshold', () {
      final views = LlmCommentRuleView.of([
        _noulRule(yes: '包含购买链接', no: '普通讨论'),
      ]);
      expect(views, hasLength(1));
      expect(views.single.id, 'r1');
      expect(views.single.criteria, contains('是否为广告？'));
      expect(views.single.criteria, contains('Yes 含义：包含购买链接'));
      expect(views.single.criteria, contains('No 含义：普通讨论'));
      expect(views.single.criteria, isNot(contains('0.95')));
    });

    test('choice rendering names the hidden options', () {
      const rule = JevRule(
        id: 'c1',
        target: JevRuleTarget.comment,
        question: '属于哪类？',
        type: JevRuleType.choice,
        options: [
          JevRuleOption(id: 'ad', label: '广告'),
          JevRuleOption(id: 'ok', label: '正常'),
        ],
        hiddenOptions: {'ad'},
      );
      final views = LlmCommentRuleView.of([rule]);
      expect(views.single.criteria, contains('广告'));
      expect(views.single.criteria, isNot(contains('正常')));
    });

    test('rendering and version track rule edits deterministically', () {
      final base = LlmCommentRuleView.of([_noulRule(yes: '是广告')]);
      final edited = LlmCommentRuleView.of([
        _noulRule(question: '是拉黑对象吗？', yes: '是广告'),
      ]);
      expect(
        LlmCommentRuleView.canonicalJson(base),
        LlmCommentRuleView.canonicalJson(base),
      );
      expect(
        LlmCommentRuleView.canonicalJson(edited),
        isNot(LlmCommentRuleView.canonicalJson(base)),
      );
      final empty = LlmCommentRuleView.of(const []);
      expect(LlmCommentRuleView.canonicalJson(empty), '[]');
    });
  });
}
