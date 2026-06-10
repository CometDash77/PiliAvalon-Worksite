import 'package:PiliPlus/models/common/super_chat_type.dart';
import 'package:PiliPlus/pages/live_room/quiet_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('effectiveShowLiveDanmaku', () {
    test('global on and temporary visible shows danmaku', () {
      expect(
        effectiveShowLiveDanmaku(globalShow: true, temporaryHide: false),
        isTrue,
      );
    });

    test('temporary hide blocks danmaku when global is on', () {
      expect(
        effectiveShowLiveDanmaku(globalShow: true, temporaryHide: true),
        isFalse,
      );
    });

    test('global off is a hard gate', () {
      expect(
        effectiveShowLiveDanmaku(globalShow: false, temporaryHide: false),
        isFalse,
      );
      expect(
        effectiveShowLiveDanmaku(globalShow: false, temporaryHide: true),
        isFalse,
      );
    });
  });

  group('effectiveShowLiveSuperChat', () {
    test('enabled global types show SC when temporary visible', () {
      for (final type in SuperChatType.values) {
        if (type == SuperChatType.disable) continue;
        expect(
          effectiveShowLiveSuperChat(
            globalType: type,
            temporaryHide: false,
          ),
          isTrue,
          reason: type.name,
        );
      }
    });

    test('temporary hide blocks SC for every global type', () {
      for (final type in SuperChatType.values) {
        expect(
          effectiveShowLiveSuperChat(globalType: type, temporaryHide: true),
          isFalse,
          reason: type.name,
        );
      }
    });

    test('global disable is a hard gate', () {
      expect(
        effectiveShowLiveSuperChat(
          globalType: SuperChatType.disable,
          temporaryHide: false,
        ),
        isFalse,
      );
    });
  });
}
