import 'dart:io';
import 'dart:typed_data';

import 'package:PiliPlus/features/shielding/comment_shielding_config.dart';
import 'package:PiliPlus/features/shielding/home_feed_comment_gate.dart';
import 'package:PiliPlus/features/shielding/shielding_models.dart';
import 'package:PiliPlus/features/shielding/shielding_recommend_tag_enricher.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/grpc/bilibili/pagination.pb.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models_new/video/video_tag/data.dart';
import 'package:PiliPlus/utils/recommendation_metrics.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

class _FakeHttpAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('{}', 200);

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  late RecommendationMetricsRecorder recorder;

  setUpAll(() async {
    try {
      final dir = Directory.systemTemp.createTempSync('hive_metrics_test_');
      Hive.init(dir.path);
      GStorage.setting = await Hive.openBox('setting');
    } catch (_) {
      // Another test file may have initialized Hive in this isolate.
    }
  });

  setUp(() {
    RecommendationTagEnricher.resetCache();
    recorder = RecommendationMetricsRecorder();
    RecommendationMetrics.observer = recorder;
    dio = Dio(BaseOptions(baseUrl: 'https://api.bilibili.com'))
      ..httpClientAdapter = _FakeHttpAdapter()
      ..interceptors.add(RecommendationMetricsInterceptor());
  });

  tearDown(() {
    dio.close(force: true);
    RecommendationMetrics.disable();
  });

  test(
    'records HTTP, gRPC, and recommendation phases with repeatable counts',
    () async {
      final enriched =
          await RecommendationTagEnricher(
            fetchTags: (bvid, _) async {
              await dio.get<void>(
                '/x/web-interface/view/detail/tag',
                queryParameters: {'bvid': bvid},
              );
              return const Success<List<VideoTagItem>?>(null);
            },
          ).enrichAndFilter<int>(
            [1, 2],
            ShieldRuleSet(),
            getBvid: (item) => 'BV$item',
            getCid: (_) => null,
          );
      final gated = await HomeFeedCommentGate.filter<int>(
        enriched,
        config: const CommentShieldingConfig(
          hideHomeFeedItemsWithoutVisibleComments: true,
        ),
        ruleSet: ShieldRuleSet(),
        getAid: (item) => item,
        loader:
            ({
              required oid,
              required type,
              required mode,
              required offset,
              required cursorNext,
            }) async => Success(
              MainListReply(
                paginationReply: FeedPaginationReply(nextOffset: 'more'),
              ),
            ),
      );

      final filtering = RecommendationMetrics.startPhase(
        RecommendationPhase.filtering,
        inputCount: 4,
      );
      RecommendationMetrics.finishPhase(
        filtering,
        outputCount: enriched.length,
      );
      final firstScreen = RecommendationMetrics.startPhase(
        RecommendationPhase.firstScreenVisible,
        inputCount: 0,
      );
      RecommendationMetrics.finishPhase(firstScreen, outputCount: gated.length);

      expect(gated, [1, 2]);
      expect(
        recorder
            .httpRequests['api.bilibili.com/x/web-interface/view/detail/tag'],
        2,
      );
      expect(recorder.grpcRequests['ReplyGrpc.mainList'], 2);
      expect(recorder.phases[RecommendationPhase.filtering], hasLength(1));
      expect(recorder.phases[RecommendationPhase.tagEnrichment], hasLength(1));
      expect(recorder.phases[RecommendationPhase.commentGate], hasLength(1));
      expect(
        recorder.phases[RecommendationPhase.firstScreenVisible],
        hasLength(1),
      );
      expect(
        recorder.format(),
        contains('http api.bilibili.com/x/web-interface/view/detail/tag=2'),
      );
      for (final phase in RecommendationPhase.values) {
        expect(recorder.format(), contains('phase ${phase.name}='));
      }
    },
  );
}
