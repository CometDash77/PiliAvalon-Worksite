import 'package:PiliPlus/pages/video/quiet_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('effectiveShowContent', () {
    test('visible when global on, persistent off, temporary off', () {
      expect(
        effectiveShowContent(
          globalShow: true,
          persistentRuleHide: false,
          temporaryHide: false,
          zenMode: false,
        ),
        isTrue,
      );
    });

    test('hidden when global on, persistent on, temporary off', () {
      expect(
        effectiveShowContent(
          globalShow: true,
          persistentRuleHide: true,
          temporaryHide: false,
          zenMode: false,
        ),
        isFalse,
      );
    });

    test('hidden when global on, persistent off, temporary on', () {
      expect(
        effectiveShowContent(
          globalShow: true,
          persistentRuleHide: false,
          temporaryHide: true,
          zenMode: false,
        ),
        isFalse,
      );
    });

    test('hidden when global on, persistent on, temporary on', () {
      expect(
        effectiveShowContent(
          globalShow: true,
          persistentRuleHide: true,
          temporaryHide: true,
          zenMode: false,
        ),
        isFalse,
      );
    });

    test('hidden when global off regardless of persistent/temporary', () {
      expect(
        effectiveShowContent(
          globalShow: false,
          persistentRuleHide: false,
          temporaryHide: false,
          zenMode: false,
        ),
        isFalse,
      );
      expect(
        effectiveShowContent(
          globalShow: false,
          persistentRuleHide: false,
          temporaryHide: true,
          zenMode: false,
        ),
        isFalse,
      );
      expect(
        effectiveShowContent(
          globalShow: false,
          persistentRuleHide: true,
          temporaryHide: true,
          zenMode: false,
        ),
        isFalse,
      );
    });

    test('16-row truth table: only the fully-open row is visible', () {
      for (var mask = 0; mask < 16; mask++) {
        final globalShow = mask & 1 != 0;
        final persistentRuleHide = mask & 2 != 0;
        final temporaryHide = mask & 4 != 0;
        final zenMode = mask & 8 != 0;
        expect(
          effectiveShowContent(
            globalShow: globalShow,
            persistentRuleHide: persistentRuleHide,
            temporaryHide: temporaryHide,
            zenMode: zenMode,
          ),
          globalShow && !persistentRuleHide && !temporaryHide && !zenMode,
          reason:
              'mask=$mask globalShow=$globalShow '
              'persistentRuleHide=$persistentRuleHide '
              'temporaryHide=$temporaryHide zenMode=$zenMode',
        );
      }
    });

    test('zen hides even when the user gates are wide open', () {
      expect(
        effectiveShowContent(
          globalShow: true,
          persistentRuleHide: false,
          temporaryHide: false,
          zenMode: true,
        ),
        isFalse,
        reason: 'R19: zen is an AND term layered on top, never an override',
      );
    });
  });

  group('comment gate: persistent hideComments hides reply', () {
    test('hidden when channel rule hideComments is true', () {
      expect(
        effectiveShowContent(
          globalShow: true,
          persistentRuleHide: true,
          temporaryHide: false,
          zenMode: false,
        ),
        isFalse,
      );
    });

    test(
      'visible when channel rule only has hideDanmaku (not hideComments)',
      () {
        expect(
          effectiveShowContent(
            globalShow: true,
            persistentRuleHide: false,
            temporaryHide: false,
            zenMode: false,
          ),
          isTrue,
        );
      },
    );

    test('visible when no channel rule matches (persistentRuleHide false)', () {
      expect(
        effectiveShowContent(
          globalShow: true,
          persistentRuleHide: false,
          temporaryHide: false,
          zenMode: false,
        ),
        isTrue,
      );
    });

    test(
      'hard gate: global off overrides everything even with channel rule',
      () {
        expect(
          effectiveShowContent(
            globalShow: false,
            persistentRuleHide: true,
            temporaryHide: false,
            zenMode: false,
          ),
          isFalse,
        );
        expect(
          effectiveShowContent(
            globalShow: false,
            persistentRuleHide: false,
            temporaryHide: false,
            zenMode: false,
          ),
          isFalse,
        );
      },
    );
  });

  group('danmaku gate: persistent hideDanmaku hides danmaku', () {
    test('hidden when channel rule hideDanmaku is true', () {
      expect(
        effectiveShowContent(
          globalShow: true,
          persistentRuleHide: true,
          temporaryHide: false,
          zenMode: false,
        ),
        isFalse,
      );
    });

    test(
      'visible when channel rule only has hideComments (not hideDanmaku)',
      () {
        expect(
          effectiveShowContent(
            globalShow: true,
            persistentRuleHide: false,
            temporaryHide: false,
            zenMode: false,
          ),
          isTrue,
        );
      },
    );

    test('visible when no channel rule matches (persistentRuleHide false)', () {
      expect(
        effectiveShowContent(
          globalShow: true,
          persistentRuleHide: false,
          temporaryHide: false,
          zenMode: false,
        ),
        isTrue,
      );
    });

    test('hard gate: global off overrides everything even with '
        'channel hideDanmaku rule', () {
      expect(
        effectiveShowContent(
          globalShow: false,
          persistentRuleHide: true,
          temporaryHide: false,
          zenMode: false,
        ),
        isFalse,
      );
      expect(
        effectiveShowContent(
          globalShow: false,
          persistentRuleHide: false,
          temporaryHide: false,
          zenMode: false,
        ),
        isFalse,
      );
    });
  });

  group('effectiveShowTemporaryContent', () {
    test('keeps the global gate authoritative', () {
      expect(
        effectiveShowTemporaryContent(
          globalShow: true,
          temporaryHide: false,
        ),
        isTrue,
      );
      expect(
        effectiveShowTemporaryContent(globalShow: true, temporaryHide: true),
        isFalse,
      );
      expect(
        effectiveShowTemporaryContent(globalShow: false, temporaryHide: false),
        isFalse,
      );
      expect(
        effectiveShowTemporaryContent(globalShow: false, temporaryHide: true),
        isFalse,
      );
    });
  });

  group('quietControlsEffectiveTabIndex', () {
    test('moves off the selected comments tab when comments are hidden', () {
      expect(
        quietControlsEffectiveTabIndex(
          currentIndex: 1,
          previousLength: 3,
          nextLength: 2,
          previousHadReply: true,
          nextHasReply: false,
          showIntro: true,
        ),
        0,
      );
    });

    test('shifts playlist index left when comments are hidden before it', () {
      expect(
        quietControlsEffectiveTabIndex(
          currentIndex: 2,
          previousLength: 3,
          nextLength: 2,
          previousHadReply: true,
          nextHasReply: false,
          showIntro: true,
        ),
        1,
      );
    });

    test(
      'shifts playlist index right when comments are restored before it',
      () {
        expect(
          quietControlsEffectiveTabIndex(
            currentIndex: 1,
            previousLength: 2,
            nextLength: 3,
            previousHadReply: false,
            nextHasReply: true,
            showIntro: true,
          ),
          2,
        );
      },
    );

    test('keeps a valid index when comments are the first tab', () {
      expect(
        quietControlsEffectiveTabIndex(
          currentIndex: 0,
          previousLength: 2,
          nextLength: 1,
          previousHadReply: true,
          nextHasReply: false,
          showIntro: false,
        ),
        0,
      );
    });
  });
}
