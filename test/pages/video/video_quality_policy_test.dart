import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('video quality default policy', () {
    test(
      'caps independent half-screen quality by fullscreen network quality',
      () {
        expect(
          effectiveVideoQuality(
            isFullScreen: false,
            fullscreenQuality: 80,
            halfScreenQuality: 64,
          ),
          64,
        );
        expect(
          effectiveVideoQuality(
            isFullScreen: false,
            fullscreenQuality: 64,
            halfScreenQuality: 64,
          ),
          64,
        );
        expect(
          effectiveVideoQuality(
            isFullScreen: false,
            fullscreenQuality: 64,
            halfScreenQuality: 80,
          ),
          64,
        );
      },
    );

    test(
      'follow and fullscreen use the current network fullscreen quality',
      () {
        expect(
          effectiveVideoQuality(
            isFullScreen: false,
            fullscreenQuality: 80,
            halfScreenQuality: null,
          ),
          80,
        );
        expect(
          effectiveVideoQuality(
            isFullScreen: true,
            fullscreenQuality: 80,
            halfScreenQuality: 64,
          ),
          80,
        );
      },
    );
  });

  group('video quality persistence policy', () {
    test('routes desktop to fullscreen default', () {
      expect(
        videoQualityPreferenceKey(
          isMobile: false,
          isFullScreen: false,
          hasIndependentHalfScreen: true,
          isWiFi: false,
        ),
        SettingBoxKey.defaultVideoQa,
      );
    });

    test('routes independent mobile half-screen to half-screen key', () {
      expect(
        videoQualityPreferenceKey(
          isMobile: true,
          isFullScreen: false,
          hasIndependentHalfScreen: true,
          isWiFi: true,
        ),
        SettingBoxKey.defaultVideoQaHalfScreen,
      );
    });

    test('routes fullscreen and follow to current network fullscreen key', () {
      expect(
        videoQualityPreferenceKey(
          isMobile: true,
          isFullScreen: true,
          hasIndependentHalfScreen: true,
          isWiFi: true,
        ),
        SettingBoxKey.defaultVideoQa,
      );
      expect(
        videoQualityPreferenceKey(
          isMobile: true,
          isFullScreen: false,
          hasIndependentHalfScreen: false,
          isWiFi: false,
        ),
        SettingBoxKey.defaultVideoQaCellular,
      );
    });
  });

  group('fullscreen quality transition policy', () {
    test('upgrades only when target exceeds actual playback quality', () {
      expect(
        shouldUpgradeVideoQuality(targetQuality: 80, actualQuality: 64),
        isTrue,
      );
      expect(
        shouldUpgradeVideoQuality(targetQuality: 80, actualQuality: 80),
        isFalse,
      );
      expect(
        shouldUpgradeVideoQuality(targetQuality: 64, actualQuality: 80),
        isFalse,
      );
    });
  });
}
