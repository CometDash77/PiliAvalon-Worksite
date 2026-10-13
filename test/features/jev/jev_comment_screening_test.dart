import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:PiliPlus/features/jev/jev_comment_migration.dart';
import 'package:PiliPlus/features/jev/jev_comment_screening.dart';
import 'package:PiliPlus/features/jev/jev.dart';
import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:PiliPlus/features/jev/jev_screen_log.dart';
import 'package:PiliPlus/features/jev/jev_verdict_cache.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';

import 'decisions_schema.dart';

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
  String? key = 'secret';
  @override
  Future<String?> read() async => key;
  @override
  Future<void> write(String value) async {
    key = value;
  }

  @override
  Future<void> delete() async {
    key = null;
  }

  @override
  Future<JevKeyStoreStatus> status() async => JevKeyStoreStatus.available;
}

class Adapter implements HttpClientAdapter {
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    expect(acceptsDecisionsRequest(options.data), isTrue);
    return ResponseBody.fromString(
      jsonEncode({
        'answers': {
          'candidate_1_rule_1_context': answer(.98),
          'candidate_1_rule_1': answer(1),
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ReplyInfo reply(String text) => ReplyInfo(
  id: Int64(987654),
  mid: Int64(12345),
  content: Content(message: text),
);
Map<String, Object?> answer(Object? value, {String type = 'noul'}) => {
  'type': type,
  'noul': value,
};

const ruleQuestion = '这条评论是否在灌水?';

JevRule commentRule({
  String id = 'r1',
  String question = ruleQuestion,
  bool enabled = true,
  JevRuleType type = JevRuleType.noul,
  List<JevRuleOption> options = const [],
  Set<String> hiddenOptions = const {},
}) => JevRule(
  id: id,
  target: JevRuleTarget.comment,
  question: question,
  enabled: enabled,
  type: type,
  options: options,
  hiddenOptions: hiddenOptions,
);

const videoRule = JevRule(
  id: 'v1',
  target: JevRuleTarget.video,
  question: '这个视频是否值得推荐?',
);

/// Verdicts for rule r1 over the given candidate keys, each with a
/// sufficient context answer unless [context] overrides it.
Map<String, Object?> decisions(
  Iterable<String> candidateKeys, {
  Object? context,
  required Object? Function(String candidateKey) verdict,
}) => {
  for (final key in candidateKeys) ...{
    key + '_rule_1_context': context ?? answer(.98),
    key + '_rule_1': verdict(key),
  },
};

void main() {
  late MemoryBox box;
  late JevSettingsStore store;
  late JevRuleStore rulesStore;
  late Credentials credentials;
  const settings = JevSettings(
    enabled: true,
    provider: JevProvider.openRouter,
    providerConfirmed: true,
    surfaces: {JevSurface.comment},
    modelOverrides: {JevProvider.openRouter: '~typesafe/test-model'},
  );

  setUp(() async {
    box = MemoryBox();
    store = JevSettingsStore(box: box);
    rulesStore = JevRuleStore(box: box);
    credentials = Credentials();
    await store.save(settings);
    await rulesStore.save(JevRuleConfig(rules: [commentRule()]));
    JevCommentCriteriaMigration.resetForTest();
    JevVerdictCache.resetCache();
    JevScreenLog.instance = JevScreenLog(box: MemoryBox());
  });

  JevCommentScreening service({
    JevTransport? transport,
    Duration passTimeout = JevLimits.requestTimeout,
  }) => JevCommentScreening(
    settings: store,
    rules: rulesStore,
    credentials: credentials,
    transport: transport,
    passTimeout: passTimeout,
  );

  test('enabled pipeline reports itself', () async {
    final svc = service();
    expect(await svc.isEnabled(), isTrue);
    expect(await svc.policyKey(), isNotEmpty);
  });

  test('official request compiles comment rules, text only, no child mutation',
      () async {
    final replies = [reply('广告加群'), reply('我不同意'), reply('相关玩笑')];
    replies[1].replies.add(reply('nested stays untouched'));
    final result = await service(
      transport: ({required provider, required apiKey, required body}) async {
        expect(provider, JevProvider.openRouter);
        expect(apiKey, 'secret');
        expect(body['model'], '~typesafe/test-model');
        expect(acceptsDecisionsRequest(body), isTrue);
        final encoded = jsonEncode(body);
        expect(encoded, isNot(contains('987654')));
        expect(encoded, isNot(contains('12345')));
        expect(encoded, isNot(contains('nested stays untouched')));
        final candidates = (body['state'] as Map)['candidates'] as Map;
        expect(candidates['candidate_1'], {'text': '广告加群'});
        final questions = body['questions'] as Map;
        expect(questions.keys.toSet(), {
          'candidate_1_rule_1',
          'candidate_1_rule_1_context',
          'candidate_2_rule_1',
          'candidate_2_rule_1_context',
          'candidate_3_rule_1',
          'candidate_3_rule_1_context',
        });
        final verdict = questions['candidate_1_rule_1'] as Map;
        expect(
          verdict['instructions'],
          contains('state.candidates.candidate_1'),
        );
        expect(verdict['instructions'], contains(ruleQuestion));
        expect((verdict['criteria'] as Map)['true'], '问题的回答为 Yes。');
        final context = questions['candidate_1_rule_1_context'] as Map;
        expect(context['instructions'], contains(ruleQuestion));
        expect(context['type'], 'noul');
        return {
          'answers': decisions(
            ['candidate_1', 'candidate_2', 'candidate_3'],
            verdict: (key) => switch (key) {
              'candidate_1' => answer(.95),
              'candidate_2' => answer(.01),
              _ => answer(.05),
            },
          ),
        };
      },
    ).filter(replies);
    expect(result.replies, [replies[1], replies[2]]);
    expect(result.cacheable, isTrue);
    expect(replies[1].replies, hasLength(1));
  });

  test('master off, surface off, no comment rules skip network', () async {
    for (final (config, rules) in [
      (
        settings.copyWith(enabled: false),
        JevRuleConfig(rules: [commentRule()]),
      ),
      (
        settings.copyWith(surfaces: {}),
        JevRuleConfig(rules: [commentRule()]),
      ),
      (settings, const JevRuleConfig()),
      (settings, JevRuleConfig(rules: [videoRule])),
    ]) {
      await store.save(config);
      await rulesStore.save(rules);
      final svc = service(
        transport:
            ({
              required provider,
              required apiKey,
              required body,
            }) async => fail('must not call'),
      );
      final input = [reply('text')];
      final result = await svc.filter(input);
      expect(result.replies, input);
      expect(result.cacheable, isTrue);
      expect(await svc.isEnabled(), isFalse);
    }
  });

  test('missing key, unconfirmed provider, provider errors and malformed '
      'payloads fail open', () async {
    for (var i = 0; i < 3; i++) {
      await store.save(settings.copyWith(providerConfirmed: i != 1));
      credentials.key = i == 0 ? null : 'secret';
      final input = [reply('text')];
      final result = await service(
        transport:
            ({required provider, required apiKey, required body}) async =>
                throw StateError('provider'),
      ).filter(input);
      expect(result.replies, input);
      expect(result.cacheable, isFalse, reason: 'case ' + i.toString());
    }
    for (final payload in [
      'garbage',
      <String, Object?>{},
      {'answers': 'nope'},
    ]) {
      final input = [reply('text')];
      final result = await service(
        transport:
            ({required provider, required apiKey, required body}) async =>
                payload,
      ).filter(input);
      expect(result.replies, input);
      expect(result.cacheable, isFalse, reason: 'payload ' + payload.toString());
    }
  });

  test('invalid/missing answers retain affected candidates and partial hides',
      () async {
    for (final value in [
      answer(double.nan),
      answer(double.infinity),
      answer(-1),
      answer(1.1),
      answer('1'),
      answer(1, type: 'choice'),
      {'noul': 1},
      null,
    ]) {
      // 每轮清空判定缓存：candidate_1 每轮产生确定 hide 判定并入库，下一轮
      // lookup 命中会缩水批次，让 mock 的按位置映射失真。
      JevVerdictCache.resetCache();
      final input = [reply('hide'), reply('retain')];
      final result = await service(
        transport:
            ({required provider, required apiKey, required body}) async => {
              'answers': decisions(
                ['candidate_1', 'candidate_2'],
                verdict: (key) => key == 'candidate_1' ? answer(1) : value,
              ),
            },
      ).filter(input);
      expect(result.replies, [input[1]]);
      expect(result.cacheable, isFalse);
    }
  });

  test('mid-band keep verdicts are not cached', () async {
    for (final value in [.5, .9, .06]) {
      JevVerdictCache.resetCache();
      final input = [reply('hide'), reply('mid')];
      final result = await service(
        transport:
            ({required provider, required apiKey, required body}) async => {
              'answers': decisions(
                ['candidate_1', 'candidate_2'],
                verdict: (key) =>
                    key == 'candidate_1' ? answer(1) : answer(value),
              ),
            },
      ).filter(input);
      expect(result.replies, [input[1]]);
      expect(result.cacheable, isFalse, reason: 'value ' + value.toString());
    }
    // Band boundaries stay cacheable: certain keeps and certain hides.
    for (final value in [0.0, .05]) {
      JevVerdictCache.resetCache();
      final input = [reply('a'), reply('b')];
      final result = await service(
        transport:
            ({required provider, required apiKey, required body}) async => {
              'answers': decisions(
                ['candidate_1', 'candidate_2'],
                verdict: (_) => answer(value),
              ),
            },
      ).filter(input);
      expect(result.replies, input, reason: 'value ' + value.toString());
      expect(result.cacheable, isTrue, reason: 'value ' + value.toString());
    }
    for (final value in [.95, 1.0]) {
      JevVerdictCache.resetCache();
      final input = [reply('a'), reply('b')];
      final result = await service(
        transport:
            ({required provider, required apiKey, required body}) async => {
              'answers': decisions(
                ['candidate_1', 'candidate_2'],
                verdict: (_) => answer(value),
              ),
            },
      ).filter(input);
      expect(result.replies, isEmpty, reason: 'value ' + value.toString());
      expect(result.cacheable, isTrue, reason: 'value ' + value.toString());
    }
  });

  test('insufficient context keeps the candidate and poisons the cache',
      () async {
    for (final context in [
      answer(.5),
      answer(.9499),
      null,
      'yes',
      answer(1, type: 'choice'),
    ]) {
      final input = [reply('unsure'), reply('clear spam')];
      final result = await service(
        transport:
            ({required provider, required apiKey, required body}) async => {
              'answers': {
                'candidate_1_rule_1_context': context,
                'candidate_1_rule_1': answer(1),
                ...decisions(['candidate_2'], verdict: (_) => answer(1)),
              },
            },
      ).filter(input);
      expect(result.replies, [input[0]], reason: 'context ' + context.toString());
      expect(result.cacheable, isFalse, reason: 'context ' + context.toString());
    }
  });

  test('whole pass deadline keeps pending comments and starts no late batches',
      () async {
    final complete = Completer<Object?>();
    var calls = 0;
    final input = List.generate(9, (i) => reply('comment ' + i.toString()));
    final result = await service(
      passTimeout: const Duration(milliseconds: 20),
      transport: ({required provider, required apiKey, required body}) {
        calls++;
        return complete.future;
      },
    ).filter(input);
    expect(result.replies, input);
    expect(result.cacheable, isFalse);
    complete.complete({
      'answers': decisions(
        ['candidate_1', 'candidate_2', 'candidate_3'],
        verdict: (_) => answer(1),
      ),
    });
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(calls, 1);
    expect(result.replies, input);
  });

  test('comment rule edits move the fingerprint; video rules do not',
      () async {
    final svc = service();
    final base = await svc.policyKey();
    await rulesStore.save(
      JevRuleConfig(rules: [commentRule(question: '隐藏剧透')]),
    );
    final edited = await svc.policyKey();
    expect(edited, isNot(base));
    expect((await rulesStore.load()).rules.single.question, '隐藏剧透');
    await rulesStore.save(
      JevRuleConfig(rules: [commentRule(question: '隐藏剧透'), videoRule]),
    );
    expect(await svc.policyKey(), edited);
    await rulesStore.save(
      JevRuleConfig(
        rules: [commentRule(question: '隐藏剧透', enabled: false), videoRule],
      ),
    );
    expect(await svc.isEnabled(), isFalse);
    expect(await svc.policyKey(), isNot(edited));
    await rulesStore.save(
      JevRuleConfig(rules: [commentRule(question: '隐藏剧透'), videoRule]),
    );
    expect(await svc.policyKey(), edited);
    await store.save(settings.copyWith(surfaces: {}));
    expect(await svc.policyKey(), isNot(edited));
    await store.save(settings.copyWith(enabled: false));
    expect(await svc.policyKey(), isNot(edited));
    await store.save(settings.copyWith(providerConfirmed: false));
    expect(await svc.policyKey(), isNot(edited));
    await store.save(settings.copyWith(provider: JevProvider.typeSafe));
    expect(await svc.policyKey(), isNot(edited));
    await store.save(settings);
    expect(await svc.policyKey(), edited);
  });

  test('bounded batch and oversized comment retain without truncation',
      () async {
    var calls = 0;
    final input = [
      reply('x' * 2001),
      ...List.generate(7, (i) => reply('text ' + i.toString())),
    ];
    final result = await service(
      transport: ({required provider, required apiKey, required body}) async {
        calls++;
        final questions = body['questions'] as Map;
        // 3 candidates x (1 verdict + 1 context) per batch at most.
        expect(questions.length, lessThanOrEqualTo(6));
        return {
          'answers': {
            for (final key in questions.keys)
              key:
                  (key as String).endsWith('_context') ? answer(.98) : answer(0),
          },
        };
      },
    ).filter(input);
    expect(calls, 3);
    expect(result.replies, input);
    expect(result.cacheable, isFalse);
  });

  test('repeat evidence crosses batches without identities', () async {
    final input = [
      reply('repeat'),
      reply('unique 1'),
      reply('unique 2'),
      reply(' repeat '),
    ];
    final counts = <Object?>[];
    await service(
      transport: ({required provider, required apiKey, required body}) async {
        final candidates = (body['state'] as Map)['candidates'] as Map;
        for (final candidate in candidates.values) {
          if ((candidate as Map)['text'].toString().trim() == 'repeat') {
            counts.add(candidate['repeat_count']);
          }
        }
        return {
          'answers': {
            for (final key in candidates.keys)
              ...decisions([key as String], verdict: (_) => answer(0)),
          },
        };
      },
    ).filter(input);
    expect(counts, [2, 2]);
  });

  test('changed policy cannot apply an in-flight old decision', () async {
    final input = [reply('text')];
    final result = await service(
      transport: ({required provider, required apiKey, required body}) async {
        await rulesStore.save(
          JevRuleConfig(rules: [commentRule(question: '换了规则')]),
        );
        return {
          'answers': decisions(['candidate_1'], verdict: (_) => answer(1)),
        };
      },
    ).filter(input);
    expect(result.replies, input);
    expect(result.cacheable, isFalse);
  });

  test('parent context rides along, clipped, and feeds the screen log',
      () async {
    final longParent = '父' * 1000;
    final input = [reply('灌水'), reply('正常'), reply('空父')];
    final candidatesSeen = <Map<Object?, Object?>>[];
    final result = await service(
      transport: ({required provider, required apiKey, required body}) async {
        candidatesSeen.add((body['state'] as Map)['candidates'] as Map);
        return {
          'answers': decisions(
            ['candidate_1', 'candidate_2', 'candidate_3'],
            verdict: (key) => switch (key) {
              'candidate_1' => answer(1),
              'candidate_2' => answer(0),
              _ => answer(.95),
            },
          ),
        };
      },
    ).filter(input, parents: [longParent, null, '   ']);
    expect(result.replies, [input[1]]);
    expect(result.cacheable, isTrue);
    final candidates = candidatesSeen.single;
    final first = candidates['candidate_1'] as Map;
    expect(first['text'], '灌水');
    expect(
      (first['snippet'] as String).runes.length,
      JevCommentScreening.maxSnippetChars,
    );
    expect(candidates['candidate_2'], {'text': '正常'});
    expect(candidates['candidate_3'], {'text': '空父'});
    final log = await JevScreenLog.instance.load();
    expect(log, hasLength(2));
    expect(log[0].title, '空父');
    expect(log[0].snippet, isNull);
    expect(log[0].ruleId, 'r1');
    expect(log[0].kind, JevScreenLogKind.comment);
    expect(log[0].surface, 'video_comments');
    expect(log[1].title, '灌水');
    expect(log[1].snippet, isNotNull);
    // The log clips stored text to its own bound.
    expect(log[1].snippet!.runes.length, JevScreenLog.maxTextLength);
    expect(log[1].ruleId, 'r1');
  });

  test('choice rules hide on hidden options and poison malformed answers',
      () async {
    const choiceRule = JevRule(
      id: 'r1',
      target: JevRuleTarget.comment,
      question: '这条评论属于哪一类?',
      type: JevRuleType.choice,
      options: [
        JevRuleOption(id: 'opt1', label: '无关'),
        JevRuleOption(id: 'opt2', label: '灌水'),
        JevRuleOption(id: 'opt3', label: '剧透'),
      ],
      hiddenOptions: {'opt2', 'opt3'},
    );
    await rulesStore.save(JevRuleConfig(rules: [choiceRule]));
    final input = [reply('a'), reply('b'), reply('c')];
    final result = await service(
      transport:
          ({required provider, required apiKey, required body}) async => {
            'answers': {
              'candidate_1_rule_1_context': const {
                'type': 'noul',
                'noul': 0.98,
              },
              'candidate_2_rule_1_context': const {
                'type': 'noul',
                'noul': 0.98,
              },
              'candidate_3_rule_1_context': const {
                'type': 'noul',
                'noul': 0.98,
              },
              'candidate_1_rule_1': {
                'type': 'choice',
                'choice': 'opt2',
                'confidence': .97,
                'probabilities': {'opt1': .02, 'opt2': .97, 'opt3': .01},
              },
              'candidate_2_rule_1': {
                'type': 'choice',
                'choice': 'opt1',
                'confidence': .9,
                'probabilities': {'opt1': .9, 'opt2': .06, 'opt3': .04},
              },
              'candidate_3_rule_1': {
                'type': 'choice',
                'choice': 'opt2',
                'confidence': .97,
                'probabilities': {'opt1': .5, 'opt2': .47, 'opt3': .03},
              },
            },
          },
    ).filter(input);
    // candidate_3's verdict is malformed (top probability opt1 != choice
    // opt2), so its reply stays visible and the pass is poisoned.
    expect(result.replies, [input[1], input[2]]);
    expect(result.cacheable, isFalse);
  });

  test(
    'production HTTP transport routes only selected provider with private body',
    () async {
      for (final provider in JevProvider.values) {
        await store.save(settings.copyWith(provider: provider));
        final adapter = Adapter();
        final dio = Dio()..httpClientAdapter = adapter;
        final result = await service(
          transport: JevHttpTransport(dio: dio).call,
        ).filter([reply('advertisement')]);
        expect(result.replies, isEmpty);
        expect(adapter.request!.uri.toString(), provider.endpoint);
        expect(adapter.request!.headers['authorization'], 'Bearer secret');
        expect(
          adapter.request!.headers.keys.map((key) => key.toLowerCase()),
          isNot(contains('cookie')),
        );
        expect(jsonEncode(adapter.request!.data), isNot(contains('secret')));
        expect(jsonEncode(adapter.request!.data), isNot(contains('987654')));
        expect(
          (adapter.request!.data as Map)['model'],
          settings.modelFor(provider),
        );
        dio.close();
      }
    },
  );
}

