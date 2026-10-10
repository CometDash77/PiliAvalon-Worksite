import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:PiliPlus/features/jev/jev.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryBox implements JevSettingsBox {
  final values = <String, Object?>{};
  @override
  Object? get(String key, {Object? defaultValue}) =>
      values[key] ?? defaultValue;
  @override
  Future<void> put(String key, Object? value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class Credentials implements JevCredentialStore {
  @override
  Future<String?> read() async => 'test-secret';
  @override
  Future<void> delete() async {}
  @override
  Future<void> write(String key) async {}
  @override
  Future<JevKeyStoreStatus> status() async => JevKeyStoreStatus.available;
}

JevRule rule({JevRuleTarget target = JevRuleTarget.video, bool yes = true}) =>
    JevRule(
      id: 'local-id',
      target: target,
      question: '是否包含剧透？',
      hideOnYes: yes,
    );

void main() {
  test(
    'Choice wire criteria and partial rule failures preserve OR decisions',
    () async {
      final box = MemoryBox();
      final settings = JevSettingsStore(box: box);
      await settings.save(
        const JevSettings(
          enabled: true,
          provider: JevProvider.typeSafe,
          providerConfirmed: true,
          surfaces: {JevSurface.live},
        ),
      );
      final store = JevRuleStore(box: box);
      await store.save(
        const JevRuleConfig(
          disabledBuiltins: {JevRuleTarget.live},
          rules: [
            JevRule(
              id: 'live',
              target: JevRuleTarget.live,
              question: '内容类型？',
              type: JevRuleType.choice,
              options: [
                JevRuleOption(id: 'ad', label: '广告', description: '推广商品'),
                JevRuleOption(id: 'other', label: '其他'),
              ],
              hiddenOptions: {'ad'},
            ),
            JevRule(
              id: 'failed',
              target: JevRuleTarget.live,
              question: '是否剧透？',
            ),
          ],
        ),
      );
      var malformed = false;
      final evaluator = JevEvaluator(
        settings: settings,
        rules: store,
        credentials: Credentials(),
        transport: ({required provider, required apiKey, required body}) async {
          final question =
              (body['questions'] as Map)['candidate_1_rule_1'] as Map;
          expect(question['type'], 'choice');
          expect(question['criteria'], {'ad': '广告：推广商品', 'other': '其他'});
          expect(body.toString(), isNot(contains('test-secret')));
          return {
            'answers': {
              'candidate_1_rule_1': {
                'type': 'choice',
                'choice': 'ad',
                'confidence': malformed ? 2 : .99,
                'probabilities': {'ad': .99, 'other': .01},
              },
              'candidate_1_rule_1_context': {'type': 'noul', 'noul': .99},
              // The other rule has no answer: it cannot override a valid hide.
            },
          };
        },
      );
      const input = [JevCandidate(title: '广告：优惠商品')];
      expect((await evaluator.screen(input, surface: JevSurface.live)).hidden, [
        true,
      ]);
      malformed = true;
      expect((await evaluator.screen(input, surface: JevSurface.live)).hidden, [
        false,
      ]);
    },
  );
  test(
    'restart preserves independent targets, No trigger and builtin switches',
    () async {
      final box = MemoryBox();
      final store = JevRuleStore(box: box);
      expect((await store.load()).builtinEnabled(JevRuleTarget.video), isTrue);
      expect(
        (await store.load()).builtinEnabled(JevRuleTarget.comment),
        isFalse,
      );
      await store.save(
        JevRuleConfig(
          rules: [
            rule(yes: false),
            const JevRule(
              id: 'comment',
              target: JevRuleTarget.comment,
              question: '是否辱骂？',
            ),
          ],
          disabledBuiltins: {JevRuleTarget.live},
        ),
      );
      final restarted = await JevRuleStore(box: box).load();
      expect(restarted.rules.first.hideOnYes, isFalse);
      expect(
        restarted.activeFor(JevRuleTarget.comment).single.question,
        '是否辱骂？',
      );
      expect(restarted.builtinEnabled(JevRuleTarget.live), isFalse);
      expect(restarted.builtinEnabled(JevRuleTarget.video), isTrue);
      box.values[JevRuleStore.key] = 'broken';
      final corrupt = await store.load();
      expect(corrupt.rules, isEmpty);
      expect(corrupt.builtinEnabled(JevRuleTarget.video), isFalse);
    },
  );

  test(
    'choice hides only selected valid top answer with sufficient confidence',
    () {
      const choice = JevRule(
        id: 'choice',
        target: JevRuleTarget.video,
        question: '内容属于什么？',
        type: JevRuleType.choice,
        options: [
          JevRuleOption(id: 'tutorial', label: '教程'),
          JevRuleOption(id: 'ad', label: '广告'),
          JevRuleOption(id: 'fun', label: '娱乐'),
        ],
        hiddenOptions: {'ad', 'fun'},
      );
      Map<String, Object?> answer(String pick, double confidence) => {
        'type': 'choice',
        'choice': pick,
        'confidence': confidence,
        'probabilities': {
          'tutorial': .01,
          'ad': pick == 'ad' ? .98 : .01,
          'fun': pick == 'fun' ? .98 : .01,
        },
      };
      expect(choice.hides(answer('ad', .95)), isTrue);
      expect(choice.hides(answer('fun', .96)), isTrue);
      expect(choice.hides(answer('ad', .94)), isFalse);
      expect(choice.hides({...answer('ad', .96), 'type': 'noul'}), isFalse);
      expect(
        choice.hides({...answer('ad', .96), 'choice': 'unknown'}),
        isFalse,
      );
      expect(
        choice.hides({...answer('ad', .96), 'confidence': double.nan}),
        isFalse,
      );
      expect(
        choice.hides({
          ...answer('ad', .96),
          'probabilities': {'ad': .98},
        }),
        isFalse,
      );
    },
  );

  test('No threshold is inverted; malformed values never hide', () {
    final no = rule(yes: false);
    expect(no.hides({'type': 'noul', 'noul': .01}), isTrue);
    expect(no.hides({'type': 'noul', 'noul': .06}), isFalse);
    for (final value in [double.nan, double.infinity, -.1, 1.1, '0']) {
      expect(no.hides({'type': 'noul', 'noul': value}), isFalse);
    }
    expect(no.hides({'noul': 0}), isFalse);
    expect(
      no.copyWith(enabled: false).hides({'type': 'noul', 'noul': 0}),
      isFalse,
    );
  });

  test('evaluator compiles custom questions, isolates targets and keeps missing context', () async {
    final box = MemoryBox();
    final settings = JevSettingsStore(box: box);
    await settings.save(
      const JevSettings(
        enabled: true,
        provider: JevProvider.openRouter,
        providerConfirmed: true,
        surfaces: {JevSurface.homeWeb, JevSurface.comment},
        modelOverrides: {JevProvider.openRouter: '~typesafe/jev-latest'},
      ),
    );
    final store = JevRuleStore(box: box);
    await store.save(
      JevRuleConfig(
        rules: [
          rule(yes: false),
          const JevRule(
            id: 'other',
            target: JevRuleTarget.comment,
            question: '是否辱骂？',
          ),
        ],
        disabledBuiltins: {JevRuleTarget.video},
      ),
    );
    var sufficient = true;
    var calls = 0;
    final evaluator = JevEvaluator(
      settings: settings,
      credentials: Credentials(),
      rules: store,
      transport: ({required provider, required apiKey, required body}) async {
        calls++;
        expect(body['model'], '~typesafe/jev-latest');
        final questions = body['questions'] as Map;
        expect(questions.length, 2);
        expect((questions['candidate_1_rule_1'] as Map)['type'], 'noul');
        expect(
          (questions['candidate_1_rule_1'] as Map)['instructions'],
          contains('是否包含剧透？'),
        );
        expect(body.toString(), isNot(contains('是否辱骂？')));
        expect((body['state'] as Map).containsKey('themes'), isFalse);
        return {
          'answers': {
            'candidate_1_rule_1': {'type': 'noul', 'noul': .01},
            if (sufficient)
              'candidate_1_rule_1_context': {'type': 'noul', 'noul': .99},
          },
        };
      },
    );
    const candidates = [JevCandidate(title: '结局解析')];
    expect(
      (await evaluator.screen(candidates, surface: JevSurface.homeWeb)).hidden,
      [true],
    );
    sufficient = false;
    expect(
      (await evaluator.screen(candidates, surface: JevSurface.homeWeb)).hidden,
      [false],
    );
    expect(calls, 2);
  });
}
