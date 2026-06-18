import 'package:PiliPlus/features/shielding/comment_shielding_config.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Helper to build a minimal reply with level, gender, vip, IP, content, likes,
  /// pictures, and emotes.
  ReplyInfo replyFixture({
    int level = 6,
    String sex = '男',
    int vipType = 2,
    int vipStatus = 1,
    String location = 'IP属地：广东',
    String message = '这是一条测试评论',
    int like = 100,
    List<Picture> pictures = const [],
    Iterable<MapEntry<String, Emote>> emotes = const [],
  }) => ReplyInfo(
    mid: Int64(1),
    like: Int64(like),
    content: Content(
      message: message,
      pictures: pictures,
      emotes: emotes,
    ),
    member: Member(
      mid: Int64(1),
      name: '用户',
      sex: sex,
      level: Int64(level),
      vipType: Int64(vipType),
      vipStatus: Int64(vipStatus),
    ),
    replyControl: ReplyControl(location: location),
  );

  group('CommentShieldMatcher', () {
    group('level threshold', () {
      test('hides lower-level users', () {
        final reply = replyFixture(level: 2);
        const config = CommentShieldingConfig(levelThreshold: 5);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isFalse);
        expect(result.blockedBy, 'levelThreshold');
      });

      test('keeps equal level visible', () {
        final reply = replyFixture(level: 5);
        const config = CommentShieldingConfig(levelThreshold: 5);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isTrue);
        expect(result.blockedBy, isNull);
      });

      test('keeps higher level visible', () {
        final reply = replyFixture(level: 6);
        const config = CommentShieldingConfig(levelThreshold: 5);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isTrue);
      });

      test('null threshold means no filter', () {
        final reply = replyFixture(level: 0);
        const config = CommentShieldingConfig();

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isTrue);
      });

      test('0 threshold means no filter', () {
        final reply = replyFixture(level: 0);
        const config = CommentShieldingConfig(levelThreshold: 0);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isTrue);
      });
    });

    group('gender filter', () {
      test('blocks selected raw sex value', () {
        final reply = replyFixture(sex: '男');
        const config = CommentShieldingConfig(genderFilter: ['男']);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isFalse);
        expect(result.blockedBy, 'genderFilter');
      });

      test('does not block unselected values', () {
        final reply = replyFixture(sex: '女');
        const config = CommentShieldingConfig(genderFilter: ['男']);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isTrue);
      });

      test('empty gender filter means no filter', () {
        final reply = replyFixture(sex: '保密');
        const config = CommentShieldingConfig();

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isTrue);
      });

      test('blocks when sex is empty string and empty is in filter', () {
        final reply = replyFixture(sex: '');
        const config = CommentShieldingConfig(genderFilter: ['']);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isFalse);
        expect(result.blockedBy, 'genderFilter');
      });
    });

    group('member filter', () {
      test('blocks exact vip:type:status key', () {
        final reply = replyFixture(vipType: 2, vipStatus: 1);
        const config = CommentShieldingConfig(memberFilter: ['vip:2:1']);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isFalse);
        expect(result.blockedBy, 'memberFilter');
      });

      test('keeps non-matching vip pair visible', () {
        final reply = replyFixture(vipType: 2, vipStatus: 0);
        const config = CommentShieldingConfig(memberFilter: ['vip:2:1']);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isTrue);
      });

      test('empty member filter means no filter', () {
        final reply = replyFixture(vipType: 2, vipStatus: 1);
        const config = CommentShieldingConfig();

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isTrue);
      });
    });

    group('ip location filter', () {
      test('strips Bilibili IP属地 prefix before matching', () {
        final reply = replyFixture(location: 'IP属地：广东');
        const config = CommentShieldingConfig(ipLocationFilter: ['广东']);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isFalse);
        expect(result.blockedBy, 'ipLocationFilter');
      });

      test('matches raw location without prefix', () {
        final reply = replyFixture(location: '广东');
        const config = CommentShieldingConfig(ipLocationFilter: ['广东']);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isFalse);
        expect(result.blockedBy, 'ipLocationFilter');
      });

      test('does not block unmatched location', () {
        final reply = replyFixture(location: 'IP属地：北京');
        const config = CommentShieldingConfig(ipLocationFilter: ['广东']);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isTrue);
      });

      test('empty location is not blocked', () {
        final reply = replyFixture(location: '');
        const config = CommentShieldingConfig(ipLocationFilter: ['广东']);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isTrue);
      });
    });

    group('min char count', () {
      test('hides short comments', () {
        final reply = replyFixture(message: '短');
        const config = CommentShieldingConfig(minCharCount: 3);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isFalse);
        expect(result.blockedBy, 'minCharCount');
      });

      test('keeps comments at the boundary visible', () {
        final reply = replyFixture(message: '刚好三字');
        const config = CommentShieldingConfig(minCharCount: 3);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isTrue);
      });

      test('null min char count means no filter', () {
        final reply = replyFixture(message: '');
        const config = CommentShieldingConfig();

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isTrue);
      });
    });

    group('max char count', () {
      test('hides long comments', () {
        final reply = replyFixture(message: '超过五个字');
        const config = CommentShieldingConfig(maxCharCount: 4);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isFalse);
        expect(result.blockedBy, 'maxCharCount');
      });

      test('keeps comments at the boundary visible', () {
        final reply = replyFixture(message: '四个字');
        const config = CommentShieldingConfig(maxCharCount: 4);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isTrue);
      });

      test('null max char count means no filter', () {
        final reply = replyFixture(message: '很长的评论文字' * 100);
        const config = CommentShieldingConfig();

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isTrue);
      });
    });

    group('like threshold', () {
      test('hides replies below threshold', () {
        final reply = replyFixture(like: 5);
        const config = CommentShieldingConfig(likeThreshold: 10);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isFalse);
        expect(result.blockedBy, 'likeThreshold');
      });

      test('keeps equal like visible', () {
        final reply = replyFixture(like: 10);
        const config = CommentShieldingConfig(likeThreshold: 10);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isTrue);
      });

      test('null like threshold means no filter', () {
        final reply = replyFixture(like: 0);
        const config = CommentShieldingConfig();

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isTrue);
      });

      test('0 like threshold means no filter', () {
        final reply = replyFixture(like: 0);
        const config = CommentShieldingConfig(likeThreshold: 0);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isTrue);
      });
    });

    group('picture toggle', () {
      test('hides replies with content pictures when toggle is on', () {
        final reply = replyFixture(
          pictures: [
            Picture(
              imgSrc: 'https://example.com/pic.jpg',
              imgWidth: 100,
              imgHeight: 100,
            ),
          ],
        );
        const config = CommentShieldingConfig(blockWithPicture: true);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isFalse);
        expect(result.blockedBy, 'blockWithPicture');
      });

      test('keeps replies with pictures visible when toggle is off', () {
        final reply = replyFixture(
          pictures: [
            Picture(
              imgSrc: 'https://example.com/pic.jpg',
              imgWidth: 100,
              imgHeight: 100,
            ),
          ],
        );
        const config = CommentShieldingConfig(blockWithPicture: false);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isTrue);
      });

      test('keeps replies without pictures visible', () {
        final reply = replyFixture();
        const config = CommentShieldingConfig(blockWithPicture: true);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isTrue);
      });
    });

    group('emote toggle', () {
      test('hides replies with content emotes when toggle is on', () {
        final reply = replyFixture(
          emotes: [
            MapEntry(
              '[doge]',
              Emote(
                id: Int64(1),
                packageId: Int64(1),
                text: '[doge]',
                url: 'https://example.com/doge.png',
              ),
            ),
          ],
        );
        const config = CommentShieldingConfig(blockWithEmote: true);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isFalse);
        expect(result.blockedBy, 'blockWithEmote');
      });

      test('keeps replies with emotes visible when toggle is off', () {
        final reply = replyFixture(
          emotes: [
            MapEntry(
              '[doge]',
              Emote(
                id: Int64(1),
                packageId: Int64(1),
                text: '[doge]',
                url: 'https://example.com/doge.png',
              ),
            ),
          ],
        );
        const config = CommentShieldingConfig(blockWithEmote: false);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isTrue);
      });

      test('keeps replies without emotes visible', () {
        final reply = replyFixture();
        const config = CommentShieldingConfig(blockWithEmote: true);

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isTrue);
      });
    });

    group('default config', () {
      test('keeps missing protobuf fields visible', () {
        final reply = ReplyInfo();
        const config = CommentShieldingConfig();

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.visible, isTrue);
        expect(result.blockedBy, isNull);
      });
    });

    group('multiple blocked returns first', () {
      test('returns first blocked reason in settings page order', () {
        final reply = replyFixture(level: 2, sex: '男');
        const config = CommentShieldingConfig(
          levelThreshold: 5,
          genderFilter: ['男'],
        );

        final result = CommentShieldMatcher.match(reply, config);

        expect(result.blockedBy, 'levelThreshold');
      });
    });

    group('vipKey', () {
      test('formats vip:type:status', () {
        expect(vipKey(2, 1), 'vip:2:1');
        expect(vipKey(0, 0), 'vip:0:0');
        expect(vipKey(1, 1), 'vip:1:1');
        expect(vipKey(2, 0), 'vip:2:0');
      });
    });

    group('canonicalIpLocation', () {
      test('strips Chinese colon prefix', () {
        expect(canonicalIpLocation('IP属地：广东'), '广东');
      });

      test('strips English colon prefix', () {
        expect(canonicalIpLocation('IP属地:广东'), '广东');
      });

      test('preserves raw location without prefix', () {
        expect(canonicalIpLocation('广东'), '广东');
      });

      test('handles whitespace around prefix', () {
        expect(canonicalIpLocation('  IP属地：  广东 '), '广东');
      });

      test('handles overseas value', () {
        expect(canonicalIpLocation('IP属地：海外'), '海外');
      });

      test('returns empty for empty input', () {
        expect(canonicalIpLocation(''), '');
      });
    });
  });
}
