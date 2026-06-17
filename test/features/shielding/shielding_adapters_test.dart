// ignore_for_file: unnecessary_lambdas

import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/models/model_hot_video_item.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/pages/video/reply_reply/controller.dart';
import 'package:PiliPlus/utils/recommend_filter.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShieldingAdapters', () {
    test(
      'maps web recommendation title, owner, category, tags, and reason',
      () {
        final item = RcmdVideoItemModel.fromJson({
          'id': 1,
          'bvid': 'BV1',
          'cid': 2,
          'goto': 'av',
          'uri': '',
          'pic': '',
          'title': '猫咪睡觉合集',
          'duration': 60,
          'pubdate': 1,
          'owner': {'mid': 42, 'name': 'UP主'},
          'stat': {'view': 1, 'like': 1, 'danmaku': 1},
          'tname': '动物',
          'tag': ['萌宠'],
          'rcmd_reason': {'content': '因为你看过萌宠'},
        });

        final candidate = ShieldingAdapters.fromRecommendationJson(
          item,
          {
            'owner': {'mid': 42, 'name': 'UP主'},
            'tname': '动物',
            'tag': ['萌宠'],
            'rcmd_reason': {'content': '因为你看过萌宠'},
          },
        );

        expect(candidate.title, '猫咪睡觉合集');
        expect(candidate.uid, '42');
        expect(candidate.authorName, 'UP主');
        expect(candidate.reason, '因为你看过萌宠');
        expect(candidate.category, '动物');
        expect(candidate.tags, contains('萌宠'));
      },
    );

    test('maps app recommendation args fields', () {
      final item = RcmdVideoItemAppModel.fromJson({
        'player_args': {'aid': 1, 'cid': 2, 'duration': 60},
        'bvid': 'BV1',
        'cover': '',
        'cover_left_text_1': '1',
        'cover_left_text_2': '1',
        'title': '游戏攻略',
        'args': {'up_id': 88, 'up_name': '玩家', 'tname': '游戏'},
        'rcmd_reason': '',
        'goto': 'av',
        'param': '1',
        'uri': '',
      });

      final candidate = ShieldingAdapters.fromRecommendationJson(
        item,
        {
          'args': {'up_id': 88, 'up_name': '玩家', 'tname': '游戏'},
        },
      );

      expect(candidate.title, '游戏攻略');
      expect(candidate.uid, '88');
      expect(candidate.authorName, '玩家');
      expect(candidate.category, '游戏');
      expect(candidate.reason, isNull);
    });

    test('web recommendation UP regex blocks owner name substring', () {
      final item = RcmdVideoItemModel.fromJson({
        'id': 1,
        'bvid': 'BV1',
        'cid': 2,
        'goto': 'av',
        'uri': '',
        'pic': '',
        'title': '影视推荐',
        'duration': 60,
        'pubdate': 1,
        'owner': {'mid': 1, 'name': 'xx说电影'},
        'stat': {'view': 1, 'like': 1, 'danmaku': 1},
        'tname': '影视',
      });
      final ruleSet = _userRegexRuleSet('电影');

      final candidate = ShieldingAdapters.fromRecommendationJson(
        item,
        {
          'owner': {'mid': 1, 'name': 'xx说电影'},
          'tname': '影视',
        },
      );

      expect(candidate.authorName, 'xx说电影');
      expect(ShieldMatcher.match(candidate, ruleSet).visible, isFalse);
    });

    test('app recommendation UP regex blocks args up_name substring', () {
      final item = RcmdVideoItemAppModel.fromJson({
        'player_args': {'aid': 1, 'cid': 2, 'duration': 60},
        'bvid': 'BV1',
        'cover': '',
        'cover_left_text_1': '1',
        'cover_left_text_2': '1',
        'title': '影视推荐',
        'args': {'up_id': 1, 'up_name': 'xx说电影', 'tname': '影视'},
        'rcmd_reason': '',
        'goto': 'av',
        'param': '1',
        'uri': '',
      });
      final ruleSet = _userRegexRuleSet('电影');

      final candidate = ShieldingAdapters.fromRecommendationJson(
        item,
        {
          'args': {'up_id': 1, 'up_name': 'xx说电影', 'tname': '影视'},
        },
      );

      expect(candidate.authorName, 'xx说电影');
      expect(ShieldMatcher.match(candidate, ruleSet).visible, isFalse);
    });

    test('app recommendation UP name falls back to args uname', () {
      final item = RcmdVideoItemAppModel.fromJson({
        'player_args': {'aid': 1, 'cid': 2, 'duration': 60},
        'bvid': 'BV1',
        'cover': '',
        'cover_left_text_1': '1',
        'cover_left_text_2': '1',
        'title': '影视推荐',
        'args': {'up_id': 1, 'tname': '影视'},
        'rcmd_reason': '',
        'goto': 'av',
        'param': '1',
        'uri': '',
      });

      final candidate = ShieldingAdapters.fromRecommendationJson(
        item,
        {
          'args': {'up_id': 1, 'uname': 'xx说电影', 'tname': '影视'},
        },
      );

      expect(candidate.authorName, 'xx说电影');
    });

    test('web recommendation UP name falls back to owner_name', () {
      final item = RcmdVideoItemModel.fromJson({
        'id': 1,
        'bvid': 'BV1',
        'cid': 2,
        'goto': 'av',
        'uri': '',
        'pic': '',
        'title': '影视推荐',
        'duration': 60,
        'pubdate': 1,
        'owner': {'mid': 1, 'name': ''},
        'stat': {'view': 1, 'like': 1, 'danmaku': 1},
        'tname': '影视',
      });

      final candidate = ShieldingAdapters.fromRecommendationJson(
        item,
        {'owner_name': 'xx说电影', 'tname': '影视'},
      );

      expect(candidate.authorName, 'xx说电影');
    });

    test('reason keyword filters recommendation json reason only', () {
      final item = RcmdVideoItemAppModel.fromJson({
        'player_args': {'aid': 1, 'cid': 2, 'duration': 60},
        'bvid': 'BV1',
        'cover': '',
        'cover_left_text_1': '1',
        'cover_left_text_2': '1',
        'title': '正常标题',
        'args': {'up_id': 88, 'up_name': '玩家', 'tname': '游戏'},
        'rcmd_reason': '因为你看过相似内容',
        'goto': 'av',
        'param': '1',
        'uri': '',
      });

      final candidate = ShieldingAdapters.fromRecommendationJson(
        item,
        {
          'args': {'up_id': 88, 'up_name': '玩家', 'tname': '游戏'},
        },
      );

      final rules = ShieldRuleSet(
        rules: [
          ShieldRule(
            id: 'reason',
            type: ShieldRuleType.reasonKeyword,
            matchMode: ShieldMatchMode.contains,
            scope: ShieldScope.recommendation,
            action: ShieldAction.block,
            pattern: '相似内容',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
      );

      expect(candidate.reason, '因为你看过相似内容');
      expect(ShieldingAdapters.isVisible(candidate, rules), isFalse);
    });

    test('maps comment content and member fields', () {
      final reply = ReplyInfo(
        mid: Int64(42),
        content: Content(message: '这是一条评论'),
        member: Member(mid: Int64(42), name: '评论者'),
      );

      final candidate = ShieldingAdapters.fromReplyInfo(reply);

      expect(candidate.scope, ShieldScope.comment);
      expect(candidate.body, '这是一条评论');
      expect(candidate.uid, '42');
      expect(candidate.authorName, '评论者');
    });

    test('maps related video title owner and category fields', () {
      final video = HotVideoItemModel.fromJson({
        'aid': 1,
        'cid': 2,
        'bvid': 'BV1',
        'videos': 1,
        'tid': 17,
        'tname': '单机游戏',
        'copyright': 1,
        'pic': '',
        'title': '硬核攻略',
        'pubdate': 1,
        'ctime': 1,
        'desc': '',
        'duration': 60,
        'owner': {'mid': 42, 'name': '玩家UP'},
        'stat': {'view': 1, 'like': 1, 'danmaku': 1},
      });

      final candidate = ShieldingAdapters.fromRelatedVideo(video);

      expect(candidate.scope, ShieldScope.recommendation);
      expect(candidate.title, '硬核攻略');
      expect(candidate.uid, '42');
      expect(candidate.authorName, '玩家UP');
      expect(candidate.category, '单机游戏');
      expect(candidate.tags, isEmpty);
    });

    test(
      'filterList handles all-blocked list without requesting more data',
      () {
        final visible = ShieldingAdapters.filterList(
          [1, 2, 3],
          enabled: true,
          toCandidate: (item) => ShieldCandidate(
            scope: ShieldScope.recommendation,
            title: 'blocked-$item',
          ),
          ruleSet: ShieldRuleSet(
            rules: [
              ShieldRule(
                id: 'all',
                type: ShieldRuleType.keyword,
                matchMode: ShieldMatchMode.regex,
                scope: ShieldScope.recommendation,
                action: ShieldAction.block,
                pattern: r'blocked-\d',
                updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
              ),
            ],
          ),
        );

        expect(visible, isEmpty);
      },
    );

    test(
      'filterList preserves original list when total switch is disabled',
      () {
        final items = [1, 2, 3];
        final visible = ShieldingAdapters.filterList(
          items,
          enabled: true,
          toCandidate: (item) => ShieldCandidate(
            scope: ShieldScope.recommendation,
            title: 'blocked-$item',
          ),
          ruleSet: ShieldRuleSet(
            globalEnabled: false,
            rules: [
              ShieldRule(
                id: 'all',
                type: ShieldRuleType.keyword,
                matchMode: ShieldMatchMode.regex,
                scope: ShieldScope.recommendation,
                action: ShieldAction.block,
                pattern: r'blocked-\d',
                updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
              ),
            ],
          ),
        );

        expect(identical(visible, items), isTrue);
        expect(visible, items);
      },
    );

    test('filterList applies comment-scoped rules to reply info lists', () {
      final visibleReply = ReplyInfo(
        mid: Int64(1),
        content: Content(message: '正常评论'),
        member: Member(mid: Int64(1), name: '用户A'),
      );
      final blockedReply = ReplyInfo(
        mid: Int64(2),
        content: Content(message: '这是一条剧透评论'),
        member: Member(mid: Int64(2), name: '用户B'),
      );

      final visible = ShieldingAdapters.filterList(
        [visibleReply, blockedReply],
        enabled: true,
        ruleSet: ShieldRuleSet(
          rules: [
            ShieldRule(
              id: 'spoiler',
              type: ShieldRuleType.keyword,
              matchMode: ShieldMatchMode.regex,
              scope: ShieldScope.comment,
              action: ShieldAction.block,
              pattern: '剧透',
              updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
            ),
          ],
        ),
        toCandidate: ShieldingAdapters.fromReplyInfo,
      );

      expect(visible, [visibleReply]);
    });

    test('raw recommendation tags stay distinct from category', () {
      final item = RcmdVideoItemModel.fromJson({
        'id': 1,
        'bvid': 'BV1',
        'cid': 2,
        'goto': 'av',
        'uri': '',
        'pic': '',
        'title': '猫咪睡觉合集',
        'duration': 60,
        'pubdate': 1,
        'owner': {'mid': 42, 'name': 'UP主'},
        'stat': {'view': 1, 'like': 1, 'danmaku': 1},
        'tname': '动物',
      });

      final candidate = ShieldingAdapters.fromRecommendationJson(
        item,
        {
          'owner': {'mid': 42, 'name': 'UP主'},
          'tname': '动物',
          'tag': ['萌宠'],
        },
      );

      final rules = ShieldRuleSet(
        rules: [
          ShieldRule(
            id: 'tag-pet',
            type: ShieldRuleType.tag,
            matchMode: ShieldMatchMode.exact,
            scope: ShieldScope.recommendation,
            action: ShieldAction.block,
            pattern: '萌宠',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
      );

      expect(candidate.category, '动物');
      expect(candidate.tags, ['萌宠']);
      expect(ShieldingAdapters.isVisible(candidate, rules), isFalse);
    });

    test(
      'filterRecommendationVideos applies category rules to video lists',
      () {
        final visibleVideo = HotVideoItemModel.fromJson({
          'aid': 1,
          'cid': 2,
          'bvid': 'BV1',
          'videos': 1,
          'tid': 17,
          'tname': '音乐',
          'copyright': 1,
          'pic': '',
          'title': '现场合集',
          'pubdate': 1,
          'ctime': 1,
          'desc': '',
          'duration': 60,
          'owner': {'mid': 42, 'name': '音乐UP'},
          'stat': {'view': 1, 'like': 1, 'danmaku': 1},
        });
        final blockedVideo = HotVideoItemModel.fromJson({
          'aid': 2,
          'cid': 3,
          'bvid': 'BV2',
          'videos': 1,
          'tid': 18,
          'tname': '游戏',
          'copyright': 1,
          'pic': '',
          'title': '攻略合集',
          'pubdate': 1,
          'ctime': 1,
          'desc': '',
          'duration': 60,
          'owner': {'mid': 88, 'name': '游戏UP'},
          'stat': {'view': 1, 'like': 1, 'danmaku': 1},
        });

        final visible = ShieldingAdapters.filterRecommendationVideos(
          [visibleVideo, blockedVideo],
          ShieldRuleSet(
            rules: [
              ShieldRule(
                id: 'tag-game',
                type: ShieldRuleType.category,
                matchMode: ShieldMatchMode.exact,
                scope: ShieldScope.recommendation,
                action: ShieldAction.block,
                pattern: '游戏',
                updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
              ),
            ],
          ),
        );

        expect(visible, [visibleVideo]);
      },
    );

    test(
      'filterRecommendationVideos bypasses rules when recommendation is off',
      () {
        final items = [
          HotVideoItemModel.fromJson({
            'aid': 1,
            'cid': 2,
            'bvid': 'BV1',
            'videos': 1,
            'tid': 17,
            'tname': '游戏',
            'copyright': 1,
            'pic': '',
            'title': '攻略合集',
            'pubdate': 1,
            'ctime': 1,
            'desc': '',
            'duration': 60,
            'owner': {'mid': 42, 'name': '游戏UP'},
            'stat': {'view': 1, 'like': 1, 'danmaku': 1},
          }),
        ];

        final visible = ShieldingAdapters.filterRecommendationVideos(
          items,
          ShieldRuleSet(
            recommendationEnabled: false,
            rules: [
              ShieldRule(
                id: 'tag-game',
                type: ShieldRuleType.category,
                matchMode: ShieldMatchMode.exact,
                scope: ShieldScope.recommendation,
                action: ShieldAction.block,
                pattern: '游戏',
                updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
              ),
            ],
          ),
        );

        expect(identical(visible, items), isTrue);
      },
    );

    test('legacy recommendation filters obey recommendation scene switch', () {
      addTearDown(() {
        RecommendFilter.minDurationForRcmd = 0;
        RecommendFilter.minPlayForRcmd = 0;
        RecommendFilter.minLikeRatioForRecommend = 0;
        RecommendFilter.exemptFilterForFollowed = false;
        RecommendFilter.applyFilterToRelatedVideos = false;
        RecommendFilter.rcmdRegExp = RegExp('', caseSensitive: false);
        RecommendFilter.enableFilter = false;
        RecommendFilter.useLegacyTextFilter = false;
        RecommendFilter.shieldRuleSetProvider = null;
      });

      RecommendFilter.minDurationForRcmd = 120;
      RecommendFilter.minPlayForRcmd = 1000;
      RecommendFilter.minLikeRatioForRecommend = 10;
      RecommendFilter.rcmdRegExp = RegExp('剧透', caseSensitive: false);
      RecommendFilter.enableFilter = true;
      RecommendFilter.useLegacyTextFilter = true;
      RecommendFilter.shieldRuleSetProvider = () => ShieldRuleSet(
        recommendationEnabled: false,
        rules: [
          ShieldRule(
            id: 'legacy-title',
            type: ShieldRuleType.keyword,
            matchMode: ShieldMatchMode.contains,
            scope: ShieldScope.recommendation,
            action: ShieldAction.block,
            pattern: '剧透',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
      );

      final item = HotVideoItemModel.fromJson({
        'aid': 1,
        'cid': 2,
        'bvid': 'BV1',
        'videos': 1,
        'tid': 17,
        'tname': '游戏',
        'copyright': 1,
        'pic': '',
        'title': '剧透短视频',
        'pubdate': 1,
        'ctime': 1,
        'desc': '',
        'duration': 60,
        'owner': {'mid': 42, 'name': '游戏UP'},
        'stat': {'view': 10, 'like': 0, 'danmaku': 1},
      });

      expect(RecommendFilter.filter(item), isFalse);
      expect(RecommendFilter.filterTitle(item.title), isFalse);
      expect(RecommendFilter.filterLikeRatio(0, 10), isFalse);
    });

    test(
      'legacy title keyword path is disabled after merge into shielding',
      () {
        addTearDown(() {
          RecommendFilter.rcmdRegExp = RegExp('', caseSensitive: false);
          RecommendFilter.enableFilter = false;
          RecommendFilter.useLegacyTextFilter = false;
          RecommendFilter.shieldRuleSetProvider = null;
        });

        RecommendFilter.rcmdRegExp = RegExp('剧透', caseSensitive: false);
        RecommendFilter.enableFilter = true;
        RecommendFilter.shieldRuleSetProvider = () => ShieldRuleSet();

        expect(RecommendFilter.filterTitle('剧透短视频'), isFalse);
      },
    );

    test('legacy numeric recommendation filters stay active', () {
      addTearDown(() {
        RecommendFilter.minDurationForRcmd = 0;
        RecommendFilter.minPlayForRcmd = 0;
        RecommendFilter.minLikeRatioForRecommend = 0;
        RecommendFilter.exemptFilterForFollowed = false;
        RecommendFilter.applyFilterToRelatedVideos = false;
        RecommendFilter.shieldRuleSetProvider = null;
      });

      RecommendFilter.minDurationForRcmd = 120;
      RecommendFilter.minPlayForRcmd = 1000;
      RecommendFilter.minLikeRatioForRecommend = 10;
      RecommendFilter.shieldRuleSetProvider = () => ShieldRuleSet();

      final item = HotVideoItemModel.fromJson({
        'aid': 1,
        'cid': 2,
        'bvid': 'BV1',
        'videos': 1,
        'tid': 17,
        'tname': '游戏',
        'copyright': 1,
        'pic': '',
        'title': '正常短视频',
        'pubdate': 1,
        'ctime': 1,
        'desc': '',
        'duration': 60,
        'owner': {'mid': 42, 'name': '游戏UP'},
        'stat': {'view': 10, 'like': 0, 'danmaku': 1},
      });

      expect(RecommendFilter.filter(item), isTrue);
    });

    test('direct reply target lookup runs before comment shielding', () {
      final controller = _TargetLookupController(targetId: 42);
      final replies = [
        ReplyInfo(
          id: Int64(1),
          mid: Int64(1),
          content: Content(message: '正常评论'),
          member: Member(mid: Int64(1), name: '用户A'),
        ),
        ReplyInfo(
          id: Int64(42),
          mid: Int64(2),
          content: Content(message: '这是一条剧透评论'),
          member: Member(mid: Int64(2), name: '用户B'),
        ),
      ];

      controller.handleListResponse(replies);

      expect(controller.index.value, 1);
      expect(replies.map((reply) => reply.id.toInt()), [1]);
    });

    // task-065: Direct structured fields on homepage recommendation.

    test(
      'web recommendation populates durationSeconds, playbackCount, danmakuCount from direct stat fields',
      () {
        final item = RcmdVideoItemModel.fromJson({
          'id': 1,
          'bvid': 'BV1',
          'cid': 2,
          'goto': 'av',
          'uri': '',
          'pic': '',
          'title': '游戏攻略',
          'duration': 600,
          'pubdate': 1,
          'owner': {'mid': 42, 'name': 'UP主'},
          'stat': {'view': 50000, 'like': 1200, 'danmaku': 300},
          'tname': '游戏',
          'rcmd_reason': {'content': '推荐'},
        });

        final candidate = ShieldingAdapters.fromRecommendationJson(
          item,
          {
            'owner': {'mid': 42, 'name': 'UP主'},
            'tname': '游戏',
            'rcmd_reason': {'content': '推荐'},
          },
        );

        expect(candidate.durationSeconds, 600);
        expect(candidate.playbackCount, 50000);
        expect(candidate.danmakuCount, 300);
      },
    );

    test(
      'web recommendation leaves durationSeconds null when duration is default -1',
      () {
        final item = RcmdVideoItemModel.fromJson({
          'id': 1,
          'bvid': 'BV1',
          'cid': 2,
          'goto': 'av',
          'uri': '',
          'pic': '',
          'title': '无时长',
          'duration': -1,
          'pubdate': 1,
          'owner': {'mid': 42, 'name': 'UP主'},
          'stat': {'view': 100, 'like': 10, 'danmaku': 5},
          'tname': '其他',
        });

        final candidate = ShieldingAdapters.fromRecommendationJson(
          item,
          {
            'owner': {'mid': 42, 'name': 'UP主'},
            'tname': '其他',
          },
        );

        expect(candidate.durationSeconds, isNull);
      },
    );

    test(
      'app recommendation populates durationSeconds, playbackCount, danmakuCount',
      () {
        final item = RcmdVideoItemAppModel.fromJson({
          'player_args': {'aid': 1, 'cid': 2, 'duration': 840},
          'bvid': 'BV1',
          'cover': '',
          'cover_left_text_1': '1.2万',
          'cover_left_text_2': '450',
          'title': 'App视频',
          'args': {'up_id': 88, 'up_name': '玩家', 'tname': '游戏'},
          'rcmd_reason': '',
          'goto': 'av',
          'param': '1',
          'uri': '',
        });

        final candidate = ShieldingAdapters.fromRecommendationJson(
          item,
          {
            'args': {'up_id': 88, 'up_name': '玩家', 'tname': '游戏'},
          },
        );

        // duration is a direct integer from player_args
        expect(candidate.durationSeconds, 840);
        // App stat: RcmdStat parses cover_left_text_1/2 into view/danmu.
        // '1.2万' → 12000, '450' → 450
        expect(candidate.playbackCount, 12000);
        expect(candidate.danmakuCount, 450);
      },
    );

    test(
      'web recommendation direct fields survive existing string-field mapping',
      () {
        final item = RcmdVideoItemModel.fromJson({
          'id': 1,
          'bvid': 'BV1',
          'cid': 2,
          'goto': 'av',
          'uri': '',
          'pic': '',
          'title': '综合测试',
          'duration': 300,
          'pubdate': 1,
          'owner': {'mid': 99, 'name': '测试君'},
          'stat': {'view': 9999, 'like': 500, 'danmaku': 200},
          'tname': '综合',
          'tag': ['标签1', '标签2'],
        });

        final candidate = ShieldingAdapters.fromRecommendationJson(
          item,
          {
            'owner': {'mid': 99, 'name': '测试君'},
            'tname': '综合',
            'tag': ['标签1', '标签2'],
          },
        );

        // Existing string fields still present
        expect(candidate.title, '综合测试');
        expect(candidate.uid, '99');
        expect(candidate.authorName, '测试君');
        expect(candidate.category, '综合');
        expect(candidate.tags, ['标签1', '标签2']);

        // New direct numeric fields populated
        expect(candidate.durationSeconds, 300);
        expect(candidate.playbackCount, 9999);
        expect(candidate.danmakuCount, 200);
      },
    );

    test(
      'duration range rule blocks web recommendation by durationSeconds',
      () {
        final item = RcmdVideoItemModel.fromJson({
          'id': 1,
          'bvid': 'BV1',
          'cid': 2,
          'goto': 'av',
          'uri': '',
          'pic': '',
          'title': '长视频',
          'duration': 6000,
          'pubdate': 1,
          'owner': {'mid': 42, 'name': 'UP主'},
          'stat': {'view': 100, 'like': 10, 'danmaku': 5},
          'tname': '其他',
        });

        final ruleSet = ShieldRuleSet(
          rules: [
            ShieldRule(
              id: 'dur',
              type: ShieldRuleType.duration,
              matchMode: ShieldMatchMode.range,
              scope: ShieldScope.recommendation,
              action: ShieldAction.block,
              pattern: '3000..99999',
              updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
            ),
          ],
        );

        final candidate = ShieldingAdapters.fromRecommendationJson(
          item,
          {
            'owner': {'mid': 42, 'name': 'UP主'},
            'tname': '其他',
          },
        );

        expect(ShieldingAdapters.isVisible(candidate, ruleSet), isFalse);
      },
    );

    test(
      'playbackCount range rule blocks web recommendation by stat view',
      () {
        final item = RcmdVideoItemModel.fromJson({
          'id': 1,
          'bvid': 'BV1',
          'cid': 2,
          'goto': 'av',
          'uri': '',
          'pic': '',
          'title': '高播放',
          'duration': 300,
          'pubdate': 1,
          'owner': {'mid': 42, 'name': 'UP主'},
          'stat': {'view': 999999, 'like': 10, 'danmaku': 5},
          'tname': '其他',
        });

        final ruleSet = ShieldRuleSet(
          rules: [
            ShieldRule(
              id: 'play',
              type: ShieldRuleType.playbackCount,
              matchMode: ShieldMatchMode.range,
              scope: ShieldScope.recommendation,
              action: ShieldAction.block,
              pattern: '100000..999999999',
              updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
            ),
          ],
        );

        final candidate = ShieldingAdapters.fromRecommendationJson(
          item,
          {
            'owner': {'mid': 42, 'name': 'UP主'},
            'tname': '其他',
          },
        );

        expect(ShieldingAdapters.isVisible(candidate, ruleSet), isFalse);
      },
    );

    test(
      'playbackCount range rule blocks app recommendation by stat view from cover_left_text_1',
      () {
        final item = RcmdVideoItemAppModel.fromJson({
          'player_args': {'aid': 1, 'cid': 2, 'duration': 120},
          'bvid': 'BV1',
          'cover': '',
          'cover_left_text_1': '999999',
          'cover_left_text_2': '50',
          'title': '高播放APP',
          'args': {'up_id': 88, 'up_name': '玩家', 'tname': '游戏'},
          'rcmd_reason': '',
          'goto': 'av',
          'param': '1',
          'uri': '',
        });

        final ruleSet = ShieldRuleSet(
          rules: [
            ShieldRule(
              id: 'play-app',
              type: ShieldRuleType.playbackCount,
              matchMode: ShieldMatchMode.range,
              scope: ShieldScope.recommendation,
              action: ShieldAction.block,
              pattern: '100000..999999999',
              updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
            ),
          ],
        );

        final candidate = ShieldingAdapters.fromRecommendationJson(
          item,
          {
            'args': {'up_id': 88, 'up_name': '玩家', 'tname': '游戏'},
          },
        );

        // playbackCount is populated from RcmdStat parsing of cover_left_text_1.
        expect(candidate.playbackCount, 999999);
        // 999999 falls within range 100000..999999999, so candidate is blocked.
        expect(ShieldingAdapters.isVisible(candidate, ruleSet), isFalse);
      },
    );

    test(
      'danmakuCount range rule blocks app recommendation when danmakuCount is populated from cover_left_text_2',
      () {
        final item = RcmdVideoItemAppModel.fromJson({
          'player_args': {'aid': 1, 'cid': 2, 'duration': 120},
          'bvid': 'BV1',
          'cover': '',
          'cover_left_text_1': '100',
          'cover_left_text_2': '50',
          'title': '弹幕测试',
          'args': {'up_id': 88, 'up_name': '玩家', 'tname': '游戏'},
          'rcmd_reason': '',
          'goto': 'av',
          'param': '1',
          'uri': '',
        });

        final ruleSet = ShieldRuleSet(
          rules: [
            ShieldRule(
              id: 'dan',
              type: ShieldRuleType.danmakuCount,
              matchMode: ShieldMatchMode.range,
              scope: ShieldScope.recommendation,
              action: ShieldAction.block,
              pattern: '0..100',
              updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
            ),
          ],
        );

        final candidate = ShieldingAdapters.fromRecommendationJson(
          item,
          {
            'args': {'up_id': 88, 'up_name': '玩家', 'tname': '游戏'},
          },
        );

        // danmakuCount is now populated from RcmdStat's parsing of cover_left_text_2.
        expect(candidate.danmakuCount, 50);
        // 50 falls within range 0..100, so the candidate is blocked.
        expect(ShieldingAdapters.isVisible(candidate, ruleSet), isFalse);
      },
    );

    test(
      'web recommendation durationSeconds, playbackCount, danmakuCount leave fromRelatedVideo unchanged',
      () {
        final video = HotVideoItemModel.fromJson({
          'aid': 1,
          'cid': 2,
          'bvid': 'BV1',
          'videos': 1,
          'tid': 17,
          'tname': '游戏',
          'copyright': 1,
          'pic': '',
          'title': '相关视频',
          'pubdate': 1,
          'ctime': 1,
          'desc': '',
          'duration': 300,
          'owner': {'mid': 42, 'name': '玩家UP'},
          'stat': {'view': 5000, 'like': 100, 'danmaku': 50},
        });

        final candidate = ShieldingAdapters.fromRelatedVideo(video);

        // fromRelatedVideo does not populate numeric candidate fields
        expect(candidate.durationSeconds, isNull);
        expect(candidate.playbackCount, isNull);
        expect(candidate.danmakuCount, isNull);
      },
    );
  });

  group('task-066 detail-introduction candidate fields', () {
    test('fromRelatedVideo populates description, pubdate, isUpowerExclusive', () {
      final video = HotVideoItemModel.fromJson({
        'aid': 1,
        'cid': 2,
        'bvid': 'BV1',
        'videos': 1,
        'tid': 17,
        'tname': '游戏',
        'copyright': 1,
        'pic': '',
        'title': '简介测试视频',
        'pubdate': 1718000000,
        'ctime': 1718000000,
        'desc': '这是一段视频简介文字',
        'duration': 300,
        'owner': {'mid': 42, 'name': '玩家UP'},
        'stat': {'view': 5000, 'like': 100, 'danmaku': 50},
        'charging_pay': {'level': 1},
      });

      final candidate = ShieldingAdapters.fromRelatedVideo(video);

      expect(candidate.description, '这是一段视频简介文字');
      expect(candidate.pubdate, 1718000000);
      expect(candidate.isUpowerExclusive, isTrue);
    });

    test('fromRelatedVideo isUpowerExclusive is false for non-charging badge', () {
      final video = HotVideoItemModel.fromJson({
        'aid': 2,
        'cid': 3,
        'bvid': 'BV2',
        'videos': 1,
        'tid': 17,
        'tname': '合作视频',
        'copyright': 1,
        'pic': '',
        'title': '合作视频',
        'pubdate': 1,
        'ctime': 1,
        'desc': '',
        'duration': 300,
        'owner': {'mid': 42, 'name': 'UP'},
        'stat': {'view': 5000, 'like': 100, 'danmaku': 50},
        'rights': {'is_cooperation': 1},
      });

      final candidate = ShieldingAdapters.fromRelatedVideo(video);

      expect(candidate.isUpowerExclusive, isFalse);
    });

    test('fromRelatedVideo isUpowerExclusive is null when badge is null', () {
      final video = HotVideoItemModel.fromJson({
        'aid': 3,
        'cid': 4,
        'bvid': 'BV3',
        'videos': 1,
        'tid': 17,
        'tname': '普通视频',
        'copyright': 1,
        'pic': '',
        'title': '普通视频',
        'pubdate': 1,
        'ctime': 1,
        'desc': '',
        'duration': 300,
        'owner': {'mid': 42, 'name': 'UP'},
        'stat': {'view': 5000, 'like': 100, 'danmaku': 50},
      });

      final candidate = ShieldingAdapters.fromRelatedVideo(video);

      expect(candidate.isUpowerExclusive, isNull);
    });

    test('fromRelatedVideo staffNames is empty', () {
      final video = HotVideoItemModel.fromJson({
        'aid': 4,
        'cid': 5,
        'bvid': 'BV4',
        'videos': 1,
        'tid': 17,
        'tname': '测试',
        'copyright': 1,
        'pic': '',
        'title': '测试',
        'pubdate': 1,
        'ctime': 1,
        'desc': '',
        'duration': 300,
        'owner': {'mid': 42, 'name': 'UP'},
        'stat': {'view': 5000, 'like': 100, 'danmaku': 50},
      });

      final candidate = ShieldingAdapters.fromRelatedVideo(video);

      expect(candidate.staffNames, isEmpty);
    });

    test('fromRecommendationJson populates description and pubdate from web model', () {
      final item = RcmdVideoItemModel.fromJson({
        'id': 1,
        'bvid': 'BV1',
        'cid': 2,
        'pic': '',
        'title': '测试标题',
        'duration': 120,
        'pubdate': 1718000000,
        'owner': {'mid': 42, 'name': 'UP主'},
        'stat': {'view': 5000, 'like': 100, 'danmaku': 50},
        'is_followed': 0,
        'rcmd_reason': {'content': '热门推荐'},
      });

      final candidate = ShieldingAdapters.fromRecommendationJson(item, {
        'owner': {'mid': 42, 'name': 'UP主'},
        'desc': '测试视频简介',
      });

      // Web model: pubdate comes from item.pubdate.
      expect(candidate.pubdate, 1718000000);
      // desc comes from JSON since web RcmdVideoItemModel doesn't set desc.
      expect(candidate.description, '测试视频简介');
      // Not available from homepage recommendation.
      expect(candidate.staffNames, isEmpty);
      expect(candidate.isUpowerExclusive, isNull);
    });

    test('fromRecommendationJson populates description from app model item.desc', () {
      final item = RcmdVideoItemAppModel.fromJson({
        'player_args': {'aid': 1, 'cid': 2, 'duration': 120},
        'bvid': 'BV1',
        'cover': '',
        'cover_left_text_1': '100',
        'cover_left_text_2': '50',
        'title': 'app测试',
        'args': {'up_id': 88, 'up_name': '玩家', 'tname': '游戏'},
        'rcmd_reason': '',
        'goto': 'av',
        'param': '1',
        'uri': '',
        'desc': 'app端简介',
      });

      final candidate = ShieldingAdapters.fromRecommendationJson(item, {
        'args': {'up_id': 88, 'up_name': '玩家', 'tname': '游戏'},
      });

      // App model sets desc from json['desc'] in its constructor.
      expect(candidate.description, 'app端简介');
      expect(candidate.pubdate, isNull);
    });

    test('fromRecommendationJson isUpowerExclusive from charging_pay', () {
      final item = RcmdVideoItemModel.fromJson({
        'id': 1,
        'bvid': 'BV1',
        'cid': 2,
        'pic': '',
        'title': '充电视频',
        'duration': 120,
        'pubdate': 1,
        'owner': {'mid': 42, 'name': 'UP主'},
        'stat': {'view': 100, 'like': 10, 'danmaku': 5},
        'is_followed': 0,
      });

      final candidate = ShieldingAdapters.fromRecommendationJson(item, {
        'owner': {'mid': 42, 'name': 'UP主'},
        'charging_pay': {'level': 1},
      });

      expect(candidate.isUpowerExclusive, isTrue);
    });
  });

  group('task-066 filterRelatedVideos independent switch', () {
    test('filterRelatedVideos uses relatedVideoEnabled, not recommendationEnabled', () {
      final video = HotVideoItemModel.fromJson({
        'aid': 1,
        'cid': 2,
        'bvid': 'BV1',
        'videos': 1,
        'tid': 17,
        'tname': '游戏',
        'copyright': 1,
        'pic': '',
        'title': '被屏蔽视频',
        'pubdate': 1,
        'ctime': 1,
        'desc': '',
        'duration': 300,
        'owner': {'mid': 42, 'name': '玩家UP'},
        'stat': {'view': 100, 'like': 10, 'danmaku': 5},
      });

      final blockRule = ShieldRuleSet(
        globalEnabled: true,
        recommendationEnabled: true,
        relatedVideoEnabled: false,
        rules: [
          ShieldRule(
            id: 'block-all',
            type: ShieldRuleType.userKeyword,
            matchMode: ShieldMatchMode.contains,
            scope: ShieldScope.videoDetail,
            action: ShieldAction.block,
            pattern: '玩家',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
      );

      // relatedVideoEnabled = false → filterRelatedVideos should be no-op.
      final result = ShieldingAdapters.filterRelatedVideos([video], blockRule);
      expect(result.length, 1); // Not filtered — switch is off.
    });

    test('filterRelatedVideos blocks when relatedVideoEnabled is true', () {
      final video = HotVideoItemModel.fromJson({
        'aid': 1,
        'cid': 2,
        'bvid': 'BV1',
        'videos': 1,
        'tid': 17,
        'tname': '游戏',
        'copyright': 1,
        'pic': '',
        'title': '被屏蔽视频',
        'pubdate': 1,
        'ctime': 1,
        'desc': '',
        'duration': 300,
        'owner': {'mid': 42, 'name': '玩家UP'},
        'stat': {'view': 100, 'like': 10, 'danmaku': 5},
      });

      final blockRule = ShieldRuleSet(
        globalEnabled: true,
        recommendationEnabled: false,
        relatedVideoEnabled: true,
        rules: [
          ShieldRule(
            id: 'block-all',
            type: ShieldRuleType.userKeyword,
            matchMode: ShieldMatchMode.contains,
            scope: ShieldScope.videoDetail,
            action: ShieldAction.block,
            pattern: '玩家',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
      );

      // relatedVideoEnabled = true → filterRelatedVideos should block.
      final result = ShieldingAdapters.filterRelatedVideos([video], blockRule);
      expect(result, isEmpty);
    });

    test('filterRecommendationVideos still uses recommendationEnabled (unchanged)', () {
      final video = HotVideoItemModel.fromJson({
        'aid': 1,
        'cid': 2,
        'bvid': 'BV1',
        'videos': 1,
        'tid': 17,
        'tname': '游戏',
        'copyright': 1,
        'pic': '',
        'title': '测试视频',
        'pubdate': 1,
        'ctime': 1,
        'desc': '',
        'duration': 300,
        'owner': {'mid': 42, 'name': '玩家UP'},
        'stat': {'view': 100, 'like': 10, 'danmaku': 5},
      });

      // recommendationEnabled = false → filterRecommendationVideos no-op.
      final offRuleSet = ShieldRuleSet(
        globalEnabled: true,
        recommendationEnabled: false,
        relatedVideoEnabled: true,
        rules: [
          ShieldRule(
            id: 'block-all',
            type: ShieldRuleType.userKeyword,
            matchMode: ShieldMatchMode.contains,
            scope: ShieldScope.recommendation,
            action: ShieldAction.block,
            pattern: '玩家',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
      );

      final result =
          ShieldingAdapters.filterRecommendationVideos([video], offRuleSet);
      expect(result.length, 1); // Not filtered — recommendationEnabled is off.
    });
  });

  group('task-066 new rule type matching', () {
    test('descriptionKeyword blocks when description contains keyword', () {
      final candidate = ShieldCandidate(
        scope: ShieldScope.recommendation,
        title: '测试',
        description: '这是一个搬运视频，原视频来自YouTube',
      );

      final ruleSet = ShieldRuleSet(
        rules: [
          ShieldRule(
            id: 'desc-kw',
            type: ShieldRuleType.descriptionKeyword,
            matchMode: ShieldMatchMode.contains,
            scope: ShieldScope.recommendation,
            action: ShieldAction.block,
            pattern: '搬运',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
      );

      expect(ShieldingAdapters.isVisible(candidate, ruleSet), isFalse);
    });

    test('descriptionKeyword allows when description does not contain keyword', () {
      final candidate = ShieldCandidate(
        scope: ShieldScope.recommendation,
        title: '测试',
        description: '这是一个原创视频',
      );

      final ruleSet = ShieldRuleSet(
        rules: [
          ShieldRule(
            id: 'desc-kw',
            type: ShieldRuleType.descriptionKeyword,
            matchMode: ShieldMatchMode.contains,
            scope: ShieldScope.recommendation,
            action: ShieldAction.block,
            pattern: '搬运',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
      );

      expect(ShieldingAdapters.isVisible(candidate, ruleSet), isTrue);
    });

    test('publishTime range blocks candidate within range', () {
      final candidate = ShieldCandidate(
        scope: ShieldScope.recommendation,
        title: '旧视频',
        pubdate: 1600000000, // Before 2021
      );

      final ruleSet = ShieldRuleSet(
        rules: [
          ShieldRule(
            id: 'old-video',
            type: ShieldRuleType.publishTime,
            matchMode: ShieldMatchMode.range,
            scope: ShieldScope.recommendation,
            action: ShieldAction.block,
            pattern: '..1640995200', // Before 2022-01-01
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
      );

      expect(ShieldingAdapters.isVisible(candidate, ruleSet), isFalse);
    });

    test('publishTime allows candidate outside range', () {
      final candidate = ShieldCandidate(
        scope: ShieldScope.recommendation,
        title: '新视频',
        pubdate: 1700000000, // After 2023
      );

      final ruleSet = ShieldRuleSet(
        rules: [
          ShieldRule(
            id: 'old-video',
            type: ShieldRuleType.publishTime,
            matchMode: ShieldMatchMode.range,
            scope: ShieldScope.recommendation,
            action: ShieldAction.block,
            pattern: '..1640995200',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
      );

      expect(ShieldingAdapters.isVisible(candidate, ruleSet), isTrue);
    });

    test('isUpowerExclusive enum blocks charged videos', () {
      final candidate = ShieldCandidate(
        scope: ShieldScope.recommendation,
        title: '充电视频',
        isUpowerExclusive: true,
      );

      final ruleSet = ShieldRuleSet(
        rules: [
          ShieldRule(
            id: 'no-charge',
            type: ShieldRuleType.isUpowerExclusive,
            matchMode: ShieldMatchMode.enumValue,
            scope: ShieldScope.recommendation,
            action: ShieldAction.block,
            pattern: 'true',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
      );

      expect(ShieldingAdapters.isVisible(candidate, ruleSet), isFalse);
    });

    test('isUpowerExclusive enum allows non-charged videos', () {
      final candidate = ShieldCandidate(
        scope: ShieldScope.recommendation,
        title: '免费视频',
        isUpowerExclusive: false,
      );

      final ruleSet = ShieldRuleSet(
        rules: [
          ShieldRule(
            id: 'no-charge',
            type: ShieldRuleType.isUpowerExclusive,
            matchMode: ShieldMatchMode.enumValue,
            scope: ShieldScope.recommendation,
            action: ShieldAction.block,
            pattern: 'true',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
      );

      expect(ShieldingAdapters.isVisible(candidate, ruleSet), isTrue);
    });

    test('staffKeyword blocks when staffName matches', () {
      final candidate = ShieldCandidate(
        scope: ShieldScope.recommendation,
        title: '测试',
        staffNames: ['张三', '李四'],
      );

      final ruleSet = ShieldRuleSet(
        rules: [
          ShieldRule(
            id: 'staff-zs',
            type: ShieldRuleType.staffKeyword,
            matchMode: ShieldMatchMode.contains,
            scope: ShieldScope.recommendation,
            action: ShieldAction.block,
            pattern: '张三',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
      );

      expect(ShieldingAdapters.isVisible(candidate, ruleSet), isFalse);
    });

    test('staffKeyword allows when no staffName matches', () {
      final candidate = ShieldCandidate(
        scope: ShieldScope.recommendation,
        title: '测试',
        staffNames: ['张三', '李四'],
      );

      final ruleSet = ShieldRuleSet(
        rules: [
          ShieldRule(
            id: 'staff-wang',
            type: ShieldRuleType.staffKeyword,
            matchMode: ShieldMatchMode.contains,
            scope: ShieldScope.recommendation,
            action: ShieldAction.block,
            pattern: '王五',
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
          ),
        ],
      );

      expect(ShieldingAdapters.isVisible(candidate, ruleSet), isTrue);
    });
  });
}

ShieldRuleSet _userRegexRuleSet(String pattern) => ShieldRuleSet(
  rules: [
    ShieldRule(
      id: 'up-regex-$pattern',
      type: ShieldRuleType.userKeyword,
      matchMode: ShieldMatchMode.regex,
      scope: ShieldScope.recommendation,
      action: ShieldAction.block,
      pattern: pattern,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
    ),
  ],
);

class _TargetLookupController extends VideoReplyReplyController {
  _TargetLookupController({required int targetId})
    : super(
        hasRoot: false,
        id: targetId,
        oid: 1,
        rpid: 1,
        dialog: null,
        replyType: 1,
      );

  @override
  List<ReplyInfo> applyShielding(List<ReplyInfo> replies) =>
      replies.where((reply) => !reply.content.message.contains('剧透')).toList();

  @override
  void jumpToItem(int index) {}
}
