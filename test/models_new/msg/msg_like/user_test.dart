import 'package:PiliPlus/models_new/msg/msg_like/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('message-like user', () {
    test('reads the member id used by the profile link', () {
      final user = User.fromJson({
        'mid': 12345,
        'nickname': 'Example',
        'avatar': 'https://example.com/avatar.png',
      });

      expect(user.mid, 12345);
      expect(user.nickname, 'Example');
      expect(user.avatar, 'https://example.com/avatar.png');
    });

    test('keeps the member id optional for older payloads', () {
      final user = User.fromJson({'nickname': 'Example'});

      expect(user.mid, isNull);
    });
  });
}
