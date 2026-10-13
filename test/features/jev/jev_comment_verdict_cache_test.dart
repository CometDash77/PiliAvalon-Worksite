import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:PiliPlus/features/jev/jev_comment_migration.dart';
import 'package:PiliPlus/features/jev/jev_comment_screening.dart';
import 'package:PiliPlus/features/jev/jev.dart';
import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:PiliPlus/features/jev/jev_screen_log.dart';
import 'package:PiliPlus/features/jev/jev_verdict_cache.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/utils/storage_key.dart';

import 'jev_comment_screening_test.dart'
    show Credentials, MemoryBox, answer, commentRule, decisions, videoRule;

ReplyInfo reply(String text, {int id = 987654, int oid = 100}) => ReplyInfo(
  id: Int64(id),
  oid: Int64(oid),
  mid: Int64(12345),
  content: Content(message: text),
);

const settings = JevSettings(
  enabled: true,
  provider: JevProvider.openRouter,
  providerConfirmed: true,
  surfaces: {JevSurface.comment},
  modelOverrides: {JevProvider.openRouter: '~typesafe/test-model'},
);

void main() {
  late MemoryBox box;
  late JevSettingsStore store;
  late JevRuleStore rulesStore;
  late Credentials credentials;

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
    JevVerdictCache? verdictCache,
  }) => JevCommentScreening(
    settings: store,
    rules: rulesStore,
    credentials: credentials,
    transport: transport,
    verdictCache: verdictCache,
  );

  /// Counting transport: one call per upstream request; verdict keyed by
  /// candidate position so callers map outcomes to inputs.
  JevTransport counting(
    void Function(int) calls, {
    required Object? Function(String candidateKey) verdict,
    List<int>? batchSizes,
    Object? Function(String candidateKey)? context,
  }) {
    var n = 0;
    return ({required provider, required apiKey, required body}) async {
      calls(n + 1);
      n++;
      final candidates = (body['state'] as Map)['candidates'] as Map;
      batchSizes?.add(candidates.length);
      return {
        'answers': decisions(
          candidates.keys.cast<String>(),
          context: context?.call('') ?? answer(.98),
          verdict: verdict,
        ),
      };
    };
  }

  List<String> visibleTexts(JevCommentResult result) =>
      result.replies.map((r) => r.content.message).toList();

  test('首次筛选发送上游请求，重进同一列表零请求且结果一致（AC1）', () async {
    var calls = 0;
    final input = [
      reply('广告加群', id: 1),
      reply('正常发言', id: 2),
      reply('也好啊', id: 3),
    ];
    final transport = counting(
      (v) => calls = v,
      verdict: (key) => key == 'candidate_1' ? answer(1) : answer(0),
    );
    final first = await service(transport: transport).filter(input);
    expect(calls, 1);
    expect(visibleTexts(first), ['正常发言', '也好啊']);
    final second = await service(transport: transport).filter(input);
    expect(calls, 1, reason: '重进列表应零新增上游请求');
    expect(visibleTexts(second), ['正常发言', '也好啊'], reason: '结果与首次一致');
    expect(second.cacheable, isTrue);
  });

  test('同一评论跨评论场景（主楼列表/楼中楼列表）第二次命中缓存（AC2）', () async {
    var calls = 0;
    final transport = counting(
      (v) => calls = v,
      verdict: (_) => answer(1),
    );
    await service(
      transport: transport,
    ).filter([reply('同一评论', id: 7)]);
    expect(calls, 1);
    // 另一个入口（楼中楼）重建的列表实例：结构不同（带父上下文、不同 oid
    // 无关紧要——身份只看 oid+rpid），同 oid+rpid 直接吃缓存。
    final again = await service(
      transport: transport,
    ).filter([reply('同一评论', id: 7)], parents: ['父评论为什么这么长']);
    expect(calls, 1);
    expect(again.replies, isEmpty);
  });

  test('编辑评论规则使全部评论判定缓存失效并重发（AC3）', () async {
    var calls = 0;
    final input = [reply('灌水内容', id: 1)];
    final transport = counting((v) => calls = v, verdict: (_) => answer(0));
    await service(transport: transport).filter(input);
    expect(calls, 1);
    await rulesStore.save(
      JevRuleConfig(rules: [commentRule(question: '换一个问题?')]),
    );
    await service(transport: transport).filter(input);
    expect(calls, 2, reason: '规则编辑后必须重发');
  });

  test('编辑视频面规则不失效评论判定缓存（AC3）', () async {
    var calls = 0;
    final input = [reply('不变判定', id: 1)];
    final transport = counting((v) => calls = v, verdict: (_) => answer(0));
    await service(transport: transport).filter(input);
    expect(calls, 1);
    await rulesStore.save(
      JevRuleConfig(rules: [commentRule(), videoRule]),
    );
    final second = await service(transport: transport).filter(input);
    expect(calls, 1, reason: '视频面规则编辑不应重发评论面');
    expect(second.replies, isNotEmpty);
  });

  test('视频面写入不驱逐评论面，评论面写入不驱逐视频面（AC3 face 隔离）', () async {
    var calls = 0;
    final videoCache = JevVerdictCache(box: box, face: 'video');
    videoCache.put('video-gen', 'video-id', hide: true);
    final transport = counting((v) => calls = v, verdict: (_) => answer(1));
    final svc = service(transport: transport);
    await svc.filter([reply('主楼内容', id: 1)]);
    expect(calls, 1);
    // 评论面 put 换代不触碰视频面条目。
    expect(videoCache.lookup('video-gen', 'video-id'), isTrue);
    // 视频面 put 换代不触碰评论面条目。
    videoCache.put('other-video-gen', 'video-id', hide: false);
    final second = await svc.filter([reply('主楼内容', id: 1)]);
    expect(calls, 1, reason: '评论面缓存仍在');
    expect(second.replies, isEmpty);
  });

  test('主开关关闭回到全量重发且不写入缓存（AC4）', () async {
    box.values[SettingBoxKey.jevVerdictCacheEnabled] = false;
    var calls = 0;
    final input = [reply('每次都问', id: 1)];
    final transport = counting((v) => calls = v, verdict: (_) => answer(0));
    await service(transport: transport).filter(input);
    await service(transport: transport).filter(input);
    expect(calls, 2);
    expect(JevVerdictCache.cachedEntryCount, 0);
  });

  test('mid-band keep 判定不缓存，下次重发（AC5）', () async {
    var calls = 0;
    final input = [reply('拿不准', id: 1)];
    final transport = counting((v) => calls = v, verdict: (_) => answer(.5));
    final first = await service(transport: transport).filter(input);
    expect(visibleTexts(first), ['拿不准']);
    expect(first.cacheable, isFalse);
    await service(transport: transport).filter(input);
    expect(calls, 2, reason: 'mid-band 判定不入缓存');
  });

  test('畸形答案不缓存，下次重发（AC5）', () async {
    for (final bad in [answer(double.nan), answer(1, type: 'choice'), null]) {
      JevVerdictCache.resetCache();
      var calls = 0;
      final input = [reply('畸形', id: 1)];
      final transport = counting((v) => calls = v, verdict: (_) => bad);
      await service(transport: transport).filter(input);
      await service(transport: transport).filter(input);
      expect(calls, 2, reason: 'bad=$bad');
    }
  });

  test('上游失败不缓存，恢复后重发（AC5）', () async {
    var attempts = 0;
    var fail = true;
    final input = [reply('失败重试', id: 1)];
    Future<Object?> flaky({
      required provider,
      required apiKey,
      required body,
    }) async {
      attempts++;
      if (fail) throw Exception('upstream down');
      return {
        'answers': decisions(['candidate_1'], verdict: (_) => answer(0)),
      };
    }
    final first = await service(transport: flaky).filter(input);
    expect(first.replies, isNotEmpty, reason: '失败保持可见');
    expect(first.cacheable, isFalse);
    fail = false;
    await service(transport: flaky).filter(input);
    expect(attempts, 2, reason: '失败路径不入缓存，恢复后必须重发');
  });

  test('混合批次：确定项入库，不确定项下次单独重发（AC5）', () async {
    var calls = 0;
    final batchSizes = <int>[];
    final input = [reply('拿不准', id: 1), reply('垃圾', id: 2)];
    final transport = counting(
      (v) => calls = v,
      batchSizes: batchSizes,
      verdict: (key) => key == 'candidate_1' ? answer(.5) : answer(1),
    );
    final first = await service(transport: transport).filter(input);
    expect(visibleTexts(first), ['拿不准']);
    expect(batchSizes, [2]);
    final second = await service(transport: transport).filter(input);
    expect(calls, 2);
    expect(batchSizes, [2, 1], reason: '只有不确定的那条重发');
    expect(visibleTexts(second), ['拿不准']);
  });

  test('TTL 过期后重发（AC6/AC8）', () async {
    var now = DateTime(2026, 1, 1);
    box.values[SettingBoxKey.jevVerdictCacheTtlMinutes] = 1;
    var calls = 0;
    final input = [reply('过期重发', id: 1)];
    final transport = counting((v) => calls = v, verdict: (_) => answer(0));
    final svc = service(
      transport: transport,
      verdictCache: JevVerdictCache(
        box: box,
        clock: () => now,
        face: 'comment',
      ),
    );
    await svc.filter(input);
    expect(calls, 1);
    now = now.add(const Duration(minutes: 2));
    await svc.filter(input);
    expect(calls, 2, reason: 'TTL 过期必须重发');
  });

  test('容量驱逐后重发（AC6/AC8）', () async {
    box.values[SettingBoxKey.jevVerdictCacheMaxEntries] = 1;
    var calls = 0;
    final input = [reply('第一条', id: 1), reply('第二条', id: 2)];
    final transport = counting((v) => calls = v, verdict: (_) => answer(0));
    final svc = service(transport: transport);
    await svc.filter(input);
    expect(calls, 1);
    expect(JevVerdictCache.cachedEntryCount, 1);
    await svc.filter(input);
    expect(calls, 2, reason: '被驱逐的条目必须重发');
  });

  test('相同文本不同 id/父上下文各自独立，互不串扰（AC7）', () async {
    var calls = 0;
    final input = [
      reply('相同文本', id: 1, oid: 100),
      reply('相同文本', id: 2, oid: 200),
    ];
    final transport = counting(
      (v) => calls = v,
      verdict: (key) => key == 'candidate_1' ? answer(1) : answer(0),
    );
    final first = await service(transport: transport).filter(input);
    expect(visibleTexts(first), ['相同文本'], reason: '只有第一条被隐藏');
    expect(calls, 1);
    final second = await service(transport: transport).filter(input);
    expect(calls, 1, reason: '两条各自命中自己的缓存');
    expect(visibleTexts(second), ['相同文本'], reason: '判定不串扰');
  });

  test('并发筛选同一评论合并为单次上游请求', () async {
    final gate = Completer<void>();
    var calls = 0;
    JevTransport transport =
        ({required provider, required apiKey, required body}) async {
          calls++;
          await gate.future;
          return {
            'answers': decisions(['candidate_1'], verdict: (_) => answer(1)),
          };
        };
    final first = service(transport: transport).filter([reply('并发', id: 1)]);
    final second = service(
      transport: transport,
    ).filter([reply('并发', id: 1)]);
    gate.complete();
    final results = await Future.wait([first, second]);
    expect(calls, 1);
    expect(results[0].replies, isEmpty);
    expect(results[1].replies, isEmpty);
  });

  test('缓存命中的隐藏判定同样进入筛选日志（ruleId 为空）', () async {
    var calls = 0;
    final input = [reply('日志可见', id: 1)];
    final transport = counting((v) => calls = v, verdict: (_) => answer(1));
    await service(transport: transport).filter(input);
    expect(JevScreenLog.instance.load().single.ruleId, 'r1');
    await service(transport: transport).filter(input);
    final entries = JevScreenLog.instance.load();
    expect(entries, hasLength(2));
    expect(entries.first.ruleId, isNull, reason: '缓存命中没有规则来源');
  });

  test('上游载荷保持不含评论身份', () async {
    var encoded = '';
    JevTransport transport =
        ({required provider, required apiKey, required body}) async {
          encoded = jsonEncode(body);
          return {
            'answers': decisions(['candidate_1'], verdict: (_) => answer(0)),
          };
        };
    await service(transport: transport).filter([reply('身份检查', id: 987654)]);
    expect(encoded, isNot(contains('987654')));
    expect(encoded, isNot(contains('12345')));
  });
}
