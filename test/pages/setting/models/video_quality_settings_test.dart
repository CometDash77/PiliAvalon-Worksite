import 'package:PiliPlus/models/common/video/video_quality.dart';
import 'package:PiliPlus/pages/setting/models/video_settings.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

/// Synchronous in-memory [Box] backing every test in this file.
///
/// GStorage.setting is a late final field, so it can only be assigned once;
/// the stub is installed exactly once in setUpAll and cleared between tests.
/// Real Hive storage cannot be used inside testWidgets: Hive disk writes rely
/// on timers that the FakeAsync zone intercepts, so a bare
/// `await GStorage.setting.put(...)` never completes there.
class _MemBox implements Box<dynamic> {
  _MemBox([Map<dynamic, dynamic>? initial])
    : _map = Map.of(initial ?? const {});

  final Map<dynamic, dynamic> _map;

  @override
  String get name => 'setting';
  @override
  bool get isOpen => true;
  @override
  String? get path => null;
  @override
  bool get lazy => false;
  @override
  Iterable<dynamic> get keys => _map.keys;
  @override
  int get length => _map.length;
  @override
  bool get isEmpty => _map.isEmpty;
  @override
  bool get isNotEmpty => _map.isNotEmpty;
  @override
  Iterable<dynamic> get values => _map.values;
  @override
  dynamic keyAt(int index) => _map.keys.elementAt(index);
  @override
  dynamic getAt(int index) => _map.values.elementAt(index);
  @override
  Iterable<dynamic> valuesBetween({dynamic startKey, dynamic endKey}) =>
      _map.values;
  @override
  Stream<BoxEvent> watch({dynamic key}) => const Stream.empty();
  @override
  bool containsKey(dynamic key) => _map.containsKey(key);
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) => _map[key] ?? defaultValue;
  @override
  Map<dynamic, dynamic> toMap() => Map.of(_map);
  @override
  Future<void> put(dynamic key, dynamic value) async {
    _map[key] = value;
  }

  @override
  Future<void> putAt(int index, dynamic value) async {
    _map[_map.keys.elementAt(index)] = value;
  }

  @override
  Future<void> putAll(Map<dynamic, dynamic> entries) async {
    _map.addAll(entries);
  }

  @override
  Future<int> add(dynamic value) async {
    final key = _map.length;
    _map[key] = value;
    return key;
  }

  @override
  Future<Iterable<int>> addAll(Iterable<dynamic> values) async => [
    for (final value in values) await add(value),
  ];

  @override
  Future<void> delete(dynamic key) async {
    _map.remove(key);
  }

  @override
  Future<void> deleteAt(int index) async {
    _map.remove(_map.keys.elementAt(index));
  }

  @override
  Future<void> deleteAll(Iterable<dynamic> keys) async {
    for (final key in keys) {
      _map.remove(key);
    }
  }

  @override
  Future<void> compact() async {}

  @override
  Future<int> clear() async {
    final count = _map.length;
    _map.clear();
    return count;
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> deleteFromDisk() async {}

  @override
  Future<void> flush() async {}
}

void main() {
  late BuildContext dialogContext;

  setUpAll(() {
    GStorage.setting = _MemBox();
  });

  setUp(() async {
    await GStorage.setting.clear();
  });

  Future<void> pumpDialogHost(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: Builder(
          builder: (context) {
            dialogContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  /// Fixed pumps instead of pumpAndSettle: the forked Material dialog is
  /// fully interactive after a few 150 ms ticks, without waiting on
  /// potentially endless animation pumps.
  Future<void> pumpTicks(WidgetTester tester, [int count = 6]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  group('half-screen quality preference storage', () {
    test('missing and -1 normalize to follow fullscreen', () async {
      expect(Pref.defaultVideoQaHalfScreen, isNull);

      await GStorage.setting.put(SettingBoxKey.defaultVideoQaHalfScreen, -1);

      expect(Pref.defaultVideoQaHalfScreen, isNull);
    });

    test(
      'explicit half-screen quality is returned without changing old keys',
      () async {
        await GStorage.setting.putAll({
          SettingBoxKey.defaultVideoQa: VideoQuality.high1080.code,
          SettingBoxKey.defaultVideoQaCellular: VideoQuality.high720.code,
          SettingBoxKey.defaultVideoQaHalfScreen: VideoQuality.hdr.code,
        });

        expect(Pref.defaultVideoQaHalfScreen, VideoQuality.hdr.code);
        expect(Pref.defaultVideoQa, VideoQuality.high1080.code);
        expect(Pref.defaultVideoQaCellular, VideoQuality.high720.code);
      },
    );
  });

  group('half-screen quality dialog', () {
    testWidgets('cancel leaves the stored preference untouched', (
      tester,
    ) async {
      await GStorage.setting.put(
        SettingBoxKey.defaultVideoQaHalfScreen,
        VideoQuality.high1080.code,
      );
      await pumpDialogHost(tester);

      final future = showVideoQaHalfScreenDialog(dialogContext, () {});
      await pumpTicks(tester);
      expect(find.text('跟随全屏画质'), findsOneWidget);

      Navigator.of(dialogContext).pop();
      await tester.pump();
      await future;
      await pumpTicks(tester, 3);

      expect(
        GStorage.setting.get(SettingBoxKey.defaultVideoQaHalfScreen),
        VideoQuality.high1080.code,
      );
    });

    testWidgets('follow selection persists -1 and exposes normalized getter', (
      tester,
    ) async {
      await GStorage.setting.put(
        SettingBoxKey.defaultVideoQaHalfScreen,
        VideoQuality.high1080.code,
      );
      await pumpDialogHost(tester);

      final future = showVideoQaHalfScreenDialog(dialogContext, () {});
      await pumpTicks(tester);
      expect(find.text('跟随全屏画质'), findsOneWidget);

      await tester.tap(find.text('跟随全屏画质'));
      await tester.pump();
      await future;
      await pumpTicks(tester, 3);

      expect(GStorage.setting.get(SettingBoxKey.defaultVideoQaHalfScreen), -1);
      expect(Pref.defaultVideoQaHalfScreen, isNull);
    });

    testWidgets('explicit selection persists the selected quality', (
      tester,
    ) async {
      await pumpDialogHost(tester);

      final future = showVideoQaHalfScreenDialog(dialogContext, () {});
      await pumpTicks(tester);
      expect(find.text(VideoQuality.hdr.desc), findsOneWidget);

      await tester.tap(find.text(VideoQuality.hdr.desc));
      await tester.pump();
      await future;
      await pumpTicks(tester, 3);

      expect(
        GStorage.setting.get(SettingBoxKey.defaultVideoQaHalfScreen),
        VideoQuality.hdr.code,
      );
      expect(Pref.defaultVideoQaHalfScreen, VideoQuality.hdr.code);
    });
  });
}
