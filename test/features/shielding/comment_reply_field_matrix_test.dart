import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Comment ReplyInfo field matrix', () {
    test('proves all configured comment-side fields are accessible and typed', () {
      final reply = ReplyInfo(
        mid: Int64(42),
        like: Int64(128),
        content: Content(
          message: '这是一条带图片和[doge]的评论',
          pictures: [
            Picture(
              imgSrc: 'https://i0.hdslb.com/comment/image.jpg',
              imgWidth: 640,
              imgHeight: 360,
            ),
          ],
          emotes: [
            MapEntry(
              '[doge]',
              Emote(
                id: Int64(1),
                packageId: Int64(2),
                text: '[doge]',
                url: 'https://i0.hdslb.com/emote/doge.png',
                size: Int64(1),
              ),
            ),
          ],
        ),
        member: Member(
          mid: Int64(42),
          name: '评论者',
          sex: '男',
          level: Int64(6),
          vipType: Int64(2),
          vipStatus: Int64(1),
          garbPendantImage: 'https://i0.hdslb.com/pendant.png',
          garbCardNumber: 'NO.0001',
        ),
        replyControl: ReplyControl(location: 'IP属地：广东'),
        memberV2: MemberV2(
          basic: MemberV2_Basic(
            mid: Int64(42),
            name: '评论者V2',
            sex: '男',
            level: Int64(6),
          ),
          vip: MemberV2_Vip(
            type: Int64(2),
            status: Int64(1),
            labelText: '年度大会员',
          ),
          garb: MemberV2_Garb(
            pendantImage: 'https://i0.hdslb.com/v2-pendant.png',
            cardImage: 'https://i0.hdslb.com/card.png',
            cardNumber: 'NO.0002',
            cardIsFan: true,
          ),
        ),
      );

      expect(reply.content.message, isA<String>());
      expect(reply.content.message, '这是一条带图片和[doge]的评论');
      expect(reply.member.name, isA<String>());
      expect(reply.member.name, '评论者');
      expect(reply.mid, isA<Int64>());
      expect(reply.mid.toInt(), 42);
      expect(reply.member.mid, isA<Int64>());
      expect(reply.member.mid.toInt(), 42);
      expect(reply.member.level, isA<Int64>());
      expect(reply.member.level.toInt(), 6);
      expect(reply.member.sex, isA<String>());
      expect(reply.member.sex, '男');
      expect(reply.member.vipType, isA<Int64>());
      expect(reply.member.vipType.toInt(), 2);
      expect(reply.member.vipStatus, isA<Int64>());
      expect(reply.member.vipStatus.toInt(), 1);
      expect(reply.replyControl.location, isA<String>());
      expect(reply.replyControl.location, 'IP属地：广东');
      expect(reply.member.garbPendantImage, isA<String>());
      expect(reply.member.garbPendantImage, contains('pendant.png'));
      expect(reply.member.garbCardNumber, isA<String>());
      expect(reply.member.garbCardNumber, 'NO.0001');
      expect(reply.memberV2.garb.pendantImage, isA<String>());
      expect(reply.memberV2.garb.pendantImage, contains('v2-pendant.png'));
      expect(reply.memberV2.garb.cardNumber, isA<String>());
      expect(reply.memberV2.garb.cardNumber, 'NO.0002');
      expect(reply.content.message.length, isA<int>());
      expect(reply.content.message.length, 17);
      expect(reply.like, isA<Int64>());
      expect(reply.like.toInt(), 128);
      expect(reply.content.pictures, isA<List<Picture>>());
      expect(reply.content.pictures, hasLength(1));
      expect(reply.content.pictures.first.imgSrc, contains('image.jpg'));
      expect(reply.content.emotes, isA<Map<String, Emote>>());
      expect(reply.content.emotes, contains('[doge]'));
      expect(reply.content.emotes['[doge]']!.text, '[doge]');
    });

    test('documents protobuf default and presence behavior for missing fields', () {
      final reply = ReplyInfo();

      expect(reply.hasContent(), isFalse);
      expect(reply.content.message, '');
      expect(reply.content.hasMessage(), isFalse);
      expect(reply.content.pictures, isEmpty);
      expect(reply.content.emotes, isEmpty);
      expect(reply.hasMember(), isFalse);
      expect(reply.member.name, '');
      expect(reply.member.hasName(), isFalse);
      expect(reply.member.mid.toInt(), 0);
      expect(reply.member.hasMid(), isFalse);
      expect(reply.member.level.toInt(), 0);
      expect(reply.member.hasLevel(), isFalse);
      expect(reply.member.sex, '');
      expect(reply.member.hasSex(), isFalse);
      expect(reply.member.vipType.toInt(), 0);
      expect(reply.member.hasVipType(), isFalse);
      expect(reply.member.vipStatus.toInt(), 0);
      expect(reply.member.hasVipStatus(), isFalse);
      expect(reply.hasReplyControl(), isFalse);
      expect(reply.replyControl.location, '');
      expect(reply.replyControl.hasLocation(), isFalse);
      expect(reply.member.garbPendantImage, '');
      expect(reply.member.hasGarbPendantImage(), isFalse);
      expect(reply.member.garbCardNumber, '');
      expect(reply.member.hasGarbCardNumber(), isFalse);
      expect(reply.hasMemberV2(), isFalse);
      expect(reply.memberV2.hasGarb(), isFalse);
      expect(reply.memberV2.garb.pendantImage, '');
      expect(reply.memberV2.garb.hasPendantImage(), isFalse);
      expect(reply.like.toInt(), 0);
      expect(reply.hasLike(), isFalse);
    });

    test('proves known membership numeric encodings remain raw values', () {
      final nonVip = Member(vipType: Int64(0), vipStatus: Int64(0));
      final monthlyVip = Member(vipType: Int64(1), vipStatus: Int64(1));
      final annualVip = Member(vipType: Int64(2), vipStatus: Int64(1));
      final expiredAnnualVip = Member(vipType: Int64(2), vipStatus: Int64(0));

      expect(
        [nonVip, monthlyVip, annualVip, expiredAnnualVip]
            .map((member) => (member.vipType.toInt(), member.vipStatus.toInt()))
            .toList(),
        [(0, 0), (1, 1), (2, 1), (2, 0)],
      );
    });
  });
}
