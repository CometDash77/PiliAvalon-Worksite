import 'dart:async';
import 'dart:io';

import 'package:PiliPlus/features/shielding/recommendation_tag_store.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/video/video_tag/data.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// A hand-cranked clock: the cache TTLs are 30 min / 30 s, so tests advance
/// time instead of waiting for it.
class _TestClock {
  DateTime now = DateTime.fromMillisecondsSinceEpoch(1767225600000);

  DateTime call() => now;

  void advance(Duration delta) => now = now.add(delta);
}

List<VideoTagItem> _tags(List<String> names) =>
    names.map((n) => VideoTagItem(tagName: n)).toList();

void main() {
  setUpAll(() async {
    try {
      final dir = Directory.systemTemp.createTempSync('hive_test_');
      Hive.init(dir.path);
      GStorage.setting = await Hive.openBox('setting');
    } catch (_) {
      // Already initialized by another test file in the same isolate.
    }
  });

  group('RecommendationTagStore', () {
    test('cache TTLs match the spec', () {
      expect(tagCacheTtl, const Duration(minutes: 30));
      expect(negativeTagCacheTtl, const Duration(seconds: 30));
    });

    test('the cache key is bvid + cid', () {
      expect(RecommendationTagStore.cacheKey('BV1', null), 'BV1|');
      expect(RecommendationTagStore.cacheKey('BV1', 111), 'BV1|111');
      expect(
        RecommendationTagStore.cacheKey('BV1', '111'),
        RecommendationTagStore.cacheKey('BV1', 111),
      );
      expect(
        RecommendationTagStore.cacheKey('BV1', 111),
        isNot(RecommendationTagStore.cacheKey('BV1', 222)),
      );
    });

    test('a cached success is served without touching the transport', () async {
      final store = RecommendationTagStore();
      var calls = 0;
      Future<LoadingState<List<VideoTagItem>?>> stub(
        String bvid,
        Object? cid,
      ) async {
        calls++;
        return Success(_tags(['tag-$calls']));
      }

      final first = await store.fetch('BV1', null, fetcher: stub);
      final second = await store.fetch('BV1', null, fetcher: stub);

      expect(first!.map((t) => t.tagName).toList(), ['tag-1']);
      expect(second!.map((t) => t.tagName).toList(), ['tag-1']);
      expect(calls, 1, reason: 'a cache hit must not issue a request');
      expect(store.entryCount, 1);
    });

    test(
      'concurrent fetches of the same key are merged into one request',
      () async {
        final store = RecommendationTagStore();
        var calls = 0;
        Future<LoadingState<List<VideoTagItem>?>> stub(
          String bvid,
          Object? cid,
        ) async {
          calls++;
          await Future.delayed(const Duration(milliseconds: 20));
          return Success(_tags(['tag']));
        }

        // Three surfaces ask for the same video part while the first request is
        // still in flight.
        final results = await Future.wait([
          store.fetch('BV1', '9', fetcher: stub),
          store.fetch('BV1', '9', fetcher: stub),
          store.fetch('BV1', '9', fetcher: stub),
        ]);

        expect(
          calls,
          1,
          reason: 'in-flight requests must be shared, not repeated',
        );
        for (final result in results) {
          expect(result!.map((t) => t.tagName).toList(), ['tag']);
        }
      },
    );

    test('a caller that gives up does not cancel the shared request', () async {
      final store = RecommendationTagStore();
      var calls = 0;
      Future<LoadingState<List<VideoTagItem>?>> stub(
        String bvid,
        Object? cid,
      ) async {
        calls++;
        await Future.delayed(const Duration(milliseconds: 40));
        return Success(_tags(['late']));
      }

      // The page leaves: the caller stops waiting almost immediately.
      await expectLater(
        store
            .fetch('BV1', null, fetcher: stub)
            .timeout(const Duration(milliseconds: 5)),
        throwsA(isA<TimeoutException>()),
      );

      // The shared request keeps running and still lands in the cache.
      await Future.delayed(const Duration(milliseconds: 100));
      expect(store.entryCount, 1);
      expect(
        (await store.fetch('BV1', null, fetcher: stub))!.single.tagName,
        'late',
      );
      expect(calls, 1, reason: 'the abandoned request completed exactly once');
    });

    test('clear() empties the cache but not an in-flight request', () async {
      final store = RecommendationTagStore();
      var calls = 0;
      Future<LoadingState<List<VideoTagItem>?>> stub(
        String bvid,
        Object? cid,
      ) async {
        calls++;
        await Future.delayed(const Duration(milliseconds: 20));
        return Success(_tags(['late']));
      }

      final pending = store.fetch('BV1', null, fetcher: stub);
      store.clear();
      await pending;

      expect(
        store.entryCount,
        1,
        reason: 'the in-flight request still wrote its result back',
      );
      expect(
        (await store.fetch('BV1', null, fetcher: stub))!.single.tagName,
        'late',
      );
      expect(calls, 1);
    });

    test(
      'failed and empty results are negative-cached, not stored as success',
      () async {
        final store = RecommendationTagStore();
        var mode = 'empty';
        Future<LoadingState<List<VideoTagItem>?>> stub(
          String bvid,
          Object? cid,
        ) async => switch (mode) {
          'empty' => const Success([]),
          'error' => const Error('upstream down'),
          _ => Success(_tags(['good'])),
        };

        expect(await store.fetch('BV1', null, fetcher: stub), isNull);
        expect(
          store.entryCount,
          0,
          reason: 'an empty payload is not a cache entry',
        );
        expect(store.estimatedBytes, 0);

        mode = 'error';
        expect(await store.fetch('BV2', null, fetcher: stub), isNull);
        expect(store.entryCount, 0, reason: 'a failure is not a cache entry');
        expect(store.estimatedBytes, 0);

        // A healthy key still caches normally right after those failures.
        mode = 'good';
        expect(
          (await store.fetch(
            'BV3',
            null,
            fetcher: stub,
          ))!.map((t) => t.tagName).toList(),
          ['good'],
        );
        expect(store.entryCount, 1);
        expect(store.estimatedBytes, greaterThan(0));
      },
    );

    test(
      'the negative cache holds a failure for 30s and then expires',
      () async {
        final clock = _TestClock();
        final store = RecommendationTagStore(clock: clock.call);
        var calls = 0;
        Future<LoadingState<List<VideoTagItem>?>> stub(
          String bvid,
          Object? cid,
        ) async {
          calls++;
          return calls == 1
              ? const Error('upstream down')
              : Success(_tags(['recovered']));
        }

        expect(await store.fetch('BV1', null, fetcher: stub), isNull);
        expect(calls, 1);

        clock.advance(const Duration(seconds: 29));
        expect(await store.fetch('BV1', null, fetcher: stub), isNull);
        expect(
          calls,
          1,
          reason: 'a fresh failure must not be retried right away',
        );

        clock.advance(const Duration(seconds: 2));
        expect(
          (await store.fetch(
            'BV1',
            null,
            fetcher: stub,
          ))!.map((t) => t.tagName).toList(),
          ['recovered'],
        );
        expect(calls, 2);
      },
    );

    test('a cached success expires after 30 minutes', () async {
      final clock = _TestClock();
      final store = RecommendationTagStore(clock: clock.call);
      var calls = 0;
      Future<LoadingState<List<VideoTagItem>?>> stub(
        String bvid,
        Object? cid,
      ) async {
        calls++;
        return Success(_tags(['tag-$calls']));
      }

      expect(
        (await store.fetch('BV1', null, fetcher: stub))!.single.tagName,
        'tag-1',
      );

      clock.advance(const Duration(minutes: 29));
      expect(
        (await store.fetch('BV1', null, fetcher: stub))!.single.tagName,
        'tag-1',
      );
      expect(calls, 1);

      clock.advance(const Duration(minutes: 2));
      expect(
        (await store.fetch('BV1', null, fetcher: stub))!.single.tagName,
        'tag-2',
      );
      expect(calls, 2);
    });

    test('the byte budget evicts the oldest entries first', () async {
      GStorage.setting.put(SettingBoxKey.tagEnrichCacheMaxMb, 1);
      addTearDown(
        () => GStorage.setting.delete(SettingBoxKey.tagEnrichCacheMaxMb),
      );

      final store = RecommendationTagStore();
      var calls = 0;
      Future<LoadingState<List<VideoTagItem>?>> stub(
        String bvid,
        Object? cid,
      ) async {
        calls++;
        // ~390 KB of estimated tag bytes per entry, so a 1 MB budget keeps
        // two of them and drops the rest oldest-first.
        return Success(_tags([List.filled(130000, 'x').join()]));
      }

      for (int i = 1; i <= 5; i++) {
        await store.fetch('BV$i', null, fetcher: stub);
      }

      expect(
        store.estimatedBytes,
        lessThanOrEqualTo(tagEnrichCacheMaxBytes),
      );
      expect(
        store.entryCount,
        lessThan(5),
        reason: 'entries had to be dropped',
      );

      final before = calls;
      await store.fetch('BV5', null, fetcher: stub);
      expect(calls, before, reason: 'the newest entry is still cached');
      await store.fetch('BV1', null, fetcher: stub);
      expect(calls, before + 1, reason: 'the oldest entry was evicted');
    });

    test('a synchronously throwing fetcher negative-caches, not poisons, the '
        'key', () async {
      final clock = _TestClock();
      final store = RecommendationTagStore(clock: clock.call);

      // This fetcher throws *before* its first await. An async load body runs
      // synchronously up to that await, so a store that registers its in-flight
      // slot only after starting the load would publish an already-completed,
      // never-released future and silently stop fetching this key forever.
      await store.fetch(
        'BV1',
        null,
        fetcher: (bvid, cid) {
          throw Exception('synchronous boom');
        },
      );

      var calls = 0;
      Future<LoadingState<List<VideoTagItem>?>> stub(
        String bvid,
        Object? cid,
      ) async {
        calls++;
        return Success(_tags(['t']));
      }

      // Inside the window the retry is suppressed by the negative cache.
      await store.fetch('BV1', null, fetcher: stub);
      expect(calls, 0);

      clock.advance(negativeTagCacheTtl + const Duration(seconds: 1));
      expect(
        (await store.fetch('BV1', null, fetcher: stub))!.single.tagName,
        't',
      );
      expect(calls, 1, reason: 'the key is still fetchable after the TTL');
    });
  });
}
