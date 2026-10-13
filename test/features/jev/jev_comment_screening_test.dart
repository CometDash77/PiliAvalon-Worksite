import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:PiliPlus/features/jev/jev.dart';
import 'package:PiliPlus/features/jev/jev_comment_screening.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnum/fixnum.dart';

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
        'answers': {'candidate_1': answer(1)},
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
void main() {
  late JevSettingsStore store;
  late Credentials credentials;
  const settings = JevSettings(
    enabled: true,
    commentEnabled: true,
    provider: JevProvider.openRouter,
    providerConfirmed: true,
    modelOverrides: {JevProvider.openRouter: '~typesafe/test-model'},
  );
  setUp(() async {
    store = JevSettingsStore(box: MemoryBox());
    credentials = Credentials();
    await store.save(settings);
  });
  test(
    'official request applies decisions in order, text only, no child mutation',
    () async {
      final replies = [reply('广告加群'), reply('我不同意'), reply('相关玩笑')];
      replies[1].replies.add(reply('nested stays untouched'));
      final service = JevCommentScreening(
        settings: store,
        credentials: credentials,
        transport: ({required provider, required apiKey, required body}) async {
          expect(provider, JevProvider.openRouter);
          expect(apiKey, 'secret');
          expect(body['model'], '~typesafe/test-model');
          expect(acceptsDecisionsRequest(body), isTrue);
          final encoded = jsonEncode(body);
          expect(encoded, isNot(contains('987654')));
          expect(encoded, isNot(contains('12345')));
          expect(encoded, isNot(contains('nested stays untouched')));
          final state = body['state'] as Map;
          expect(state['criteria'], JevSettings.defaultCommentCriteria);
          expect((state['candidates'] as Map)['candidate_1'], {'text': '广告加群'});
          expect(
            ((body['questions'] as Map)['candidate_1'] as Map)['instructions'],
            contains('state.candidates.candidate_1.text'),
          );
          return {
            'answers': {
              'candidate_1': answer(.95),
              'candidate_2': answer(.01),
              'candidate_3': answer(.05),
            },
          };
        },
      );
      final result = await service.filter(replies);
      expect(result.replies, [replies[1], replies[2]]);
      expect(result.cacheable, isTrue);
      expect(replies[1].replies, hasLength(1));
    },
  );
  test('disabled, master disabled, blank criterion skip network', () async {
    for (final config in [
      settings.copyWith(commentEnabled: false),
      settings.copyWith(enabled: false),
      settings.copyWith(commentCriteria: '  '),
    ]) {
      await store.save(config);
      final service = JevCommentScreening(
        settings: store,
        credentials: credentials,
        transport: ({
          required provider,
          required apiKey,
          required body,
        }) async => fail('must not call'),
      );
      final input = [reply('text')];
      final result = await service.filter(input);
      expect(result.replies, input);
      expect(result.cacheable, isTrue);
      expect(await service.isEnabled(), isFalse);
    }
  });
  test(
    'missing key, unconfirmed provider and provider errors fail open',
    () async {
      for (var i = 0; i < 3; i++) {
        await store.save(settings.copyWith(providerConfirmed: i != 1));
        credentials.key = i == 0 ? null : 'secret';
        final input = [reply('text')];
        final result = await JevCommentScreening(
          settings: store,
          credentials: credentials,
          transport: ({
            required provider,
            required apiKey,
            required body,
          }) async => throw StateError('provider'),
        ).filter(input);
        expect(result.replies, input);
        expect(result.cacheable, isFalse);
      }
    },
  );
  test('invalid/missing/uncertain answers retain affected candidates and partial hides', () async {
    for (final value in [
      answer(double.nan),
      answer(double.infinity),
      answer(-1),
      answer(1.1),
      answer('1'),
      answer(1, type: 'choice'),
      {'noul': 1},
      answer(.5),
      null,
    ]) {
      final input = [reply('hide'), reply('retain')];
      final result = await JevCommentScreening(
        settings: store,
        credentials: credentials,
        transport:
            ({required provider, required apiKey, required body}) async => {
              'answers': {'candidate_1': answer(1), 'candidate_2': value},
            },
      ).filter(input);
      expect(result.replies, [input[1]]);
      expect(result.cacheable, isFalse);
    }
  });
  test(
    'whole pass deadline keeps pending comments and starts no late batches',
    () async {
      final complete = Completer<Object?>();
      var calls = 0;
      final input = List.generate(9, (i) => reply('comment $i'));
      final result = await JevCommentScreening(
        settings: store,
        credentials: credentials,
        passTimeout: const Duration(milliseconds: 20),
        transport: ({required provider, required apiKey, required body}) {
          calls++;
          return complete.future;
        },
      ).filter(input);
      expect(result.replies, input);
      expect(result.cacheable, isFalse);
      complete.complete({
        'answers': {
          'candidate_1': answer(1),
          'candidate_2': answer(1),
          'candidate_3': answer(1),
        },
      });
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(calls, 1);
      expect(result.replies, input);
    },
  );
  test(
    'custom criterion persistence, preset restore and policy fingerprint',
    () async {
      final service = JevCommentScreening(
        settings: store,
        credentials: credentials,
      );
      final old = await service.policyKey();
      await store.save(settings.copyWith(commentCriteria: '隐藏剧透'));
      expect((await store.load()).commentCriteria, '隐藏剧透');
      expect(await service.policyKey(), isNot(old));
      expect((await store.load()).withoutProvider().commentEnabled, isTrue);
      await store.save(
        settings.copyWith(commentCriteria: JevSettings.defaultCommentCriteria),
      );
      expect(await service.policyKey(), old);
      expect(JevSettings.disabled.commentEnabled, isFalse);
    },
  );
  test(
    'bounded batch and oversized comment retain without truncation',
    () async {
      var calls = 0;
      final input = [
        reply('x' * 2001),
        ...List.generate(7, (i) => reply('text $i')),
      ];
      final result = await JevCommentScreening(
        settings: store,
        credentials: credentials,
        transport: ({required provider, required apiKey, required body}) async {
          calls++;
          final questions = body['questions'] as Map;
          expect(questions.length, lessThanOrEqualTo(3));
          return {
            'answers': {for (final key in questions.keys) key: answer(0)},
          };
        },
      ).filter(input);
      expect(calls, 3);
      expect(result.replies, input);
      expect(result.cacheable, isFalse);
    },
  );
  test('repeat evidence crosses batches without identities', () async {
    final input = [
      reply('repeat'),
      reply('unique 1'),
      reply('unique 2'),
      reply(' repeat '),
    ];
    final counts = <Object?>[];
    await JevCommentScreening(
      settings: store,
      credentials: credentials,
      transport: ({required provider, required apiKey, required body}) async {
        final candidates = (body['state'] as Map)['candidates'] as Map;
        for (final candidate in candidates.values) {
          if ((candidate as Map)['text'].toString().trim() == 'repeat') {
            counts.add(candidate['repeat_count']);
          }
        }
        return {
          'answers': {for (final key in candidates.keys) key: answer(0)},
        };
      },
    ).filter(input);
    expect(counts, [2, 2]);
  });
  test('changed policy cannot apply an in-flight old decision', () async {
    final input = [reply('text')];
    final result = await JevCommentScreening(
      settings: store,
      credentials: credentials,
      transport: ({required provider, required apiKey, required body}) async {
        await store.save(settings.copyWith(commentEnabled: false));
        return {
          'answers': {'candidate_1': answer(1)},
        };
      },
    ).filter(input);
    expect(result.replies, input);
    expect(result.cacheable, isFalse);
  });
  test(
    'production HTTP transport routes only selected provider with private body',
    () async {
      for (final provider in JevProvider.values) {
        await store.save(settings.copyWith(provider: provider));
        final adapter = Adapter();
        final dio = Dio()..httpClientAdapter = adapter;
        final result = await JevCommentScreening(
          settings: store,
          credentials: credentials,
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
