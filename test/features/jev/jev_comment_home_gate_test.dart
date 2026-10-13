import 'dart:async';
import 'dart:io';

import 'package:PiliPlus/features/jev/jev_comment_screening.dart';
import 'package:PiliPlus/features/jev/jev_contract.dart';
import 'package:PiliPlus/features/jev/jev_credential_store.dart';
import 'package:PiliPlus/features/jev/jev_evaluator.dart';
import 'package:PiliPlus/features/jev/jev_settings.dart';
import 'package:PiliPlus/features/shielding/home_feed_comment_gate.dart';
import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

class _Box implements JevSettingsBox {
  final values = <String, Object?>{};
  @override
  Object? get(String key, {Object? defaultValue}) =>
      values[key] ?? defaultValue;
  @override
  Future<void> put(String key, Object? value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _Key implements JevCredentialStore {
  @override
  Future<JevKeyStoreStatus> status() async => JevKeyStoreStatus.available;
  @override
  Future<String?> read() async => 'test-key';
  @override
  Future<void> write(String apiKey) async {}
  @override
  Future<void> delete() async {}
}

ReplyInfo _reply(String text) => ReplyInfo(content: Content(message: text));

void main() {
  late Directory directory;
  late JevSettingsStore settings;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('jev_comment_gate_');
    Hive.init(directory.path);
    GStorage.setting = await Hive.openBox('setting');
    GStorage.localCache = await Hive.openBox('localCache');
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  setUp(() async {
    HomeFeedCommentGate.resetDecisionCache();
    settings = JevSettingsStore(box: _Box());
    await settings.save(
      const JevSettings(
        enabled: true,
        provider: JevProvider.openRouter,
        providerConfirmed: true,
        commentEnabled: true,
      ),
    );
  });

  Future<List<int>> run(
    JevTransport transport, {
    List<int> items = const [1],
    List<ReplyInfo>? replies,
    bool exhausted = true,
    void Function()? onLoad,
    ReplyInfo? pinned,
    Duration loaderDelay = Duration.zero,
    Duration passTimeout = JevLimits.requestTimeout,
  }) => HomeFeedCommentGate.filter(
    items,
    config: const CommentShieldingConfig(
      hideHomeFeedItemsWithoutVisibleComments: true,
      minCharCount: 3,
    ),
    ruleSet: ShieldRuleSet(),
    getAid: (item) => item,
    commentScreening: JevCommentScreening(
      settings: settings,
      credentials: _Key(),
      transport: transport,
      passTimeout: passTimeout,
    ),
    loader:
        ({
          required oid,
          required type,
          required mode,
          required offset,
          required cursorNext,
        }) async {
          onLoad?.call();
          if (loaderDelay > Duration.zero) {
            await Future<void>.delayed(loaderDelay);
          }
          return Success(
            MainListReply(
              replies: replies ?? [_reply('明显广告引流')],
              cursor: CursorReply(isEnd: exhausted),
              upTop: pinned,
            ),
          );
        },
  );

  Object answers(double value) => {
    'answers': {
      'candidate_1': {'type': 'noul', 'noul': value},
    },
  };

  test(
    'slow loader cannot start paid work after the shared aid deadline',
    () async {
      var calls = 0;
      expect(
        await run(
          ({required provider, required apiKey, required body}) async {
            calls++;
            return answers(1);
          },
          loaderDelay: const Duration(milliseconds: 30),
          passTimeout: const Duration(milliseconds: 10),
        ),
        [1],
      );
      expect(calls, 0);
      expect(HomeFeedCommentGate.decisionCacheEntryCount, 0);
    },
  );

  test(
    'real comment text reaches provider after cheap rules; hide removes card',
    () async {
      Map<String, Object?>? request;
      final result = await run(
        ({required provider, required apiKey, required body}) async {
          request = body;
          expect(provider, JevProvider.openRouter);
          return answers(0.99);
        },
        replies: [_reply('短'), _reply('明显广告引流')],
      );
      expect(result, isEmpty);
      expect((request!['state'] as Map)['candidates'], {
        'candidate_1': {'text': '明显广告引流'},
      });
    },
  );

  test('gate awaits semantic answer and merges duplicate aid', () async {
    final pending = Completer<Object?>();
    var requests = 0;
    var loads = 0;
    var finished = false;
    final result =
        run(
          ({required provider, required apiKey, required body}) {
            requests++;
            return pending.future;
          },
          items: [1, 1],
          onLoad: () => loads++,
        ).then((value) {
          finished = true;
          return value;
        });
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(finished, isFalse);
    expect(requests, 1);
    expect(loads, 1);
    pending.complete(answers(0.99));
    expect(await result, isEmpty);
  });

  test('remaining source page prevents false no-comments decision', () async {
    expect(
      await run(
        ({required provider, required apiKey, required body}) async =>
            answers(0.99),
        exhausted: false,
      ),
      [1],
    );
  });

  test(
    'provider failure preserves card and retries instead of caching',
    () async {
      var calls = 0;
      Future<Object?> transport({
        required JevProvider provider,
        required String apiKey,
        required Map<String, Object?> body,
      }) async {
        calls++;
        if (calls == 1) throw StateError('offline');
        return answers(0.99);
      }

      expect(await run(transport), [1]);
      expect(HomeFeedCommentGate.decisionCacheEntryCount, 0);
      expect(await run(transport), isEmpty);
      expect(calls, 2);
    },
  );

  test(
    'criteria edit, disabled and blank policies take effect on same aid',
    () async {
      var calls = 0;
      Future<Object?> transport({
        required JevProvider provider,
        required String apiKey,
        required Map<String, Object?> body,
      }) async {
        calls++;
        final criteria = (body['state'] as Map)['criteria'];
        return answers(criteria == '保留全部' ? 0 : 1);
      }

      expect(await run(transport), isEmpty);
      await settings.save(
        (await settings.load()).copyWith(commentCriteria: '保留全部'),
      );
      expect(await run(transport), [1]);
      await settings.save(
        (await settings.load()).copyWith(commentEnabled: false),
      );
      expect(await run(transport), [1]);
      await settings.save(
        (await settings.load()).copyWith(
          commentEnabled: true,
          commentCriteria: '',
        ),
      );
      expect(await run(transport), [1]);
      expect(calls, 2);
    },
  );

  test(
    'visible pinned comment keeps card after ordinary comments hide',
    () async {
      expect(
        await run(
          ({required provider, required apiKey, required body}) async => {
            'answers': {
              'candidate_1': {'type': 'noul', 'noul': 0.01},
              'candidate_2': {'type': 'noul', 'noul': 0.99},
            },
          },
          pinned: _reply('正常讨论'),
        ),
        [1],
      );
    },
  );
}
