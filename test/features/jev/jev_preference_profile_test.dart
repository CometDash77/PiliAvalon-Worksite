import 'dart:convert';

import 'package:PiliPlus/features/jev/jev.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 6, 12);

  group('summarize', () {
    test('strips bracketed decoration and noise from the card title', () {
      expect(
        const JevDislikeSignal.card(title: '【4K修复】某纪录片的真相').summarize(),
        '某纪录片的真相',
      );
      expect(
        const JevDislikeSignal.card(title: '(上) 某主题 解析').summarize(),
        '某主题 解析',
      );
    });

    test('the title wins and the reasons are fallbacks', () {
      expect(
        const JevDislikeSignal.card(
          title: '',
          displayedReason: '因为你看过',
          selectedReason: '已看过',
        ).summarize(),
        '因为你看过',
      );
      expect(
        const JevDislikeSignal.card(
          title: '   ',
          selectedReason: '已看过',
        ).summarize(),
        '已看过',
      );
    });

    test('a card with no usable topical phrase stores nothing', () {
      expect(const JevDislikeSignal.card(title: '!!!').summarize(), isNull);
      expect(const JevDislikeSignal.card(title: 'A').summarize(), isNull);
      expect(const JevDislikeSignal.card(title: '').summarize(), isNull);
    });

    test('links and video ids never survive into a theme', () {
      expect(
        const JevDislikeSignal.card(
          title: 'https://www.bilibili.com/video/BV1xx411c7mD 某主题解析',
        ).summarize(),
        '某主题解析',
      );
      expect(
        const JevDislikeSignal.card(title: 'av170001 某主题').summarize(),
        '某主题',
      );
    });

    test('a theme is capped at the contract length', () {
      const long = '一二三四五六七八九十一二三四五六七八九十';
      final theme = const JevDislikeSignal.card(title: long).summarize();
      expect(theme, long.substring(0, JevLimits.maxThemeChars));
    });
  });

  group('profile', () {
    test('merges the same theme into one row and refreshes its time', () {
      var profile = JevPreferenceProfile.empty.recordTheme('某主题', now: now);
      profile = profile.recordTheme(
        '某 主题',
        now: now.add(const Duration(days: 1)),
      );
      expect(profile.length, 1);
      expect(profile.themes.single.count, 2);
      expect(
        profile.themes.single.lastFeedbackAt,
        now.add(const Duration(days: 1)),
      );
    });

    test('saturates the approximate count', () {
      var profile = JevPreferenceProfile.empty;
      for (var i = 0; i < JevLimits.maxThemeCount + 5; i++) {
        profile = profile.recordTheme('某主题', now: now);
      }
      expect(profile.themes.single.count, JevLimits.maxThemeCount);
    });

    test('keeps at most 20 themes and evicts the oldest feedback first', () {
      var profile = JevPreferenceProfile.empty;
      for (var i = 0; i < JevLimits.maxProfileThemes; i++) {
        profile = profile.recordTheme(
          '主题$i',
          now: now.subtract(Duration(days: 30 - i)),
        );
      }
      expect(profile.length, JevLimits.maxProfileThemes);

      profile = profile.recordTheme('新主题', now: now);
      expect(profile.length, JevLimits.maxProfileThemes);
      expect(profile.themes.map((item) => item.theme), isNot(contains('主题0')));
      expect(profile.themes.map((item) => item.theme), contains('新主题'));
      expect(profile.themes.first.theme, '新主题');
    });

    test('drops a theme only after six months without new feedback', () {
      final profile = JevPreferenceProfile.empty.recordTheme('某主题', now: now);
      expect(profile.settled(now.add(const Duration(days: 182))).length, 1);
      expect(profile.settled(now.add(JevLimits.themeTtl)).isEmpty, isTrue);
    });

    test('deletes a single theme, case- and space-insensitively', () {
      final profile = JevPreferenceProfile.empty
          .recordTheme('甲主题', now: now)
          .recordTheme('乙主题', now: now);
      expect(
        profile.withoutTheme('甲 主题').themes.map((item) => item.theme),
        <String>['乙主题'],
      );
    });

    test('round-trips through its stored form, newest first', () {
      final profile = JevPreferenceProfile.empty
          .recordTheme('甲主题', now: now)
          .recordTheme('乙主题', now: now.add(const Duration(days: 1)));
      final decoded = JevPreferenceProfile.decode(profile.encode());
      expect(decoded, profile);
      expect(
        decoded.themes.map((item) => item.theme),
        <String>['乙主题', '甲主题'],
      );
    });

    test('garbage reads as an empty profile instead of throwing', () {
      final garbage = <Object?>[
        null,
        '',
        'not json',
        '[]',
        '{}',
        '{"themes":7}',
        42,
      ];
      for (final raw in garbage) {
        expect(
          JevPreferenceProfile.decode(raw).isEmpty,
          isTrue,
          reason: 'raw: $raw',
        );
      }
    });

    test('one unusable entry is skipped, not the whole profile', () {
      final epoch = now.millisecondsSinceEpoch;
      final raw =
          '{"themes":[{"theme":"甲主题","count":2,"last":$epoch},{"theme":7},{"count":1},7]}';
      final profile = JevPreferenceProfile.decode(raw);
      expect(profile.themes.map((item) => item.theme), <String>['甲主题']);
      expect(profile.themes.single.count, 2);
    });

    test('an absurd stored count is clamped', () {
      final epoch = now.millisecondsSinceEpoch;
      final raw = '{"themes":[{"theme":"甲主题","count":-5,"last":$epoch}]}';
      expect(JevPreferenceProfile.decode(raw).themes.single.count, 1);
    });

    test('the state payload carries themes and counts only', () {
      final profile = JevPreferenceProfile.empty.recordTheme('甲主题', now: now);
      final payload = profile.statePayload();
      expect(payload.keys, <String>[
        JevPreferenceProfile.themesField,
      ]);
      final entries =
          payload[JevPreferenceProfile.themesField]! as List<Object?>;
      expect(
        (entries.single! as Map).keys.toSet(),
        <String>{
          JevPreferenceProfile.themeField,
          JevPreferenceProfile.countField,
        },
      );
    });

    test('the worst-case state payload fits the contract byte budget', () {
      const base = '一二三四五六七八九十一二三四五';
      const tails = '甲乙丙丁戊己庚辛壬癸子丑寅卯辰巳午未申酉';
      var profile = JevPreferenceProfile.empty;
      for (var i = 0; i < JevLimits.maxProfileThemes; i++) {
        profile = profile.recordTheme(base + tails[i], now: now);
      }
      expect(profile.length, JevLimits.maxProfileThemes);
      expect(
        profile.themes.first.theme.runes.length,
        JevLimits.maxThemeChars,
      );
      final bytes = utf8.encode(jsonEncode(profile.statePayload())).length;
      expect(bytes, lessThanOrEqualTo(JevLimits.maxStateBytes));
    });
  });
}
