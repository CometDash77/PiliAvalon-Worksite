import 'package:PiliPlus/features/shielding/comment_shielding_config.dart';
import 'package:PiliPlus/features/shielding/shielding_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommentShieldingConfig', () {
    test('defaults mean no filtering', () {
      const config = CommentShieldingConfig();

      expect(config.levelThreshold, isNull);
      expect(config.genderFilter, isEmpty);
      expect(config.memberFilter, isEmpty);
      expect(config.ipLocationFilter, isEmpty);
      expect(config.minCharCount, isNull);
      expect(config.maxCharCount, isNull);
      expect(config.likeThreshold, isNull);
      expect(config.blockWithPicture, isFalse);
      expect(config.blockWithEmote, isFalse);
      expect(config.version, 1);
    });

    test('round trips JSON', () {
      const config = CommentShieldingConfig(
        levelThreshold: 5,
        genderFilter: ['男'],
        memberFilter: ['vip:2:1'],
        ipLocationFilter: ['广东'],
        minCharCount: 3,
        maxCharCount: 80,
        likeThreshold: 10,
        blockWithPicture: true,
        blockWithEmote: true,
        version: 1,
      );

      final decoded = CommentShieldingConfig.fromJson(config.toJson());

      expect(decoded.levelThreshold, 5);
      expect(decoded.genderFilter, ['男']);
      expect(decoded.memberFilter, ['vip:2:1']);
      expect(decoded.ipLocationFilter, ['广东']);
      expect(decoded.minCharCount, 3);
      expect(decoded.maxCharCount, 80);
      expect(decoded.likeThreshold, 10);
      expect(decoded.blockWithPicture, isTrue);
      expect(decoded.blockWithEmote, isTrue);
      expect(decoded.version, 1);
    });

    test('damaged config payload falls back safely', () {
      final decoded = CommentShieldingConfig.tryFromJson({
        'version': 'broken',
        'level_threshold': 'not an int',
      });

      expect(decoded.levelThreshold, isNull);
      expect(decoded.genderFilter, isEmpty);
      expect(decoded.version, 1);
    });

    test('invalid numeric values from persisted JSON are ignored', () {
      final decoded = CommentShieldingConfig.fromJson({
        'level_threshold': 7,
        'min_char_count': -1,
        'max_char_count': -2,
        'like_threshold': -3,
      });

      expect(decoded.levelThreshold, isNull);
      expect(decoded.minCharCount, isNull);
      expect(decoded.maxCharCount, isNull);
      expect(decoded.likeThreshold, isNull);
    });

    test('persisted min greater than max clears both char bounds', () {
      final decoded = CommentShieldingConfig.fromJson({
        'min_char_count': 12,
        'max_char_count': 6,
      });

      expect(decoded.minCharCount, isNull);
      expect(decoded.maxCharCount, isNull);
    });

    test('null fields round trip as null', () {
      const config = CommentShieldingConfig();

      final decoded = CommentShieldingConfig.fromJson(config.toJson());

      expect(decoded.levelThreshold, isNull);
      expect(decoded.minCharCount, isNull);
      expect(decoded.maxCharCount, isNull);
      expect(decoded.likeThreshold, isNull);
    });

    test('all list fields round trip with empty lists', () {
      const config = CommentShieldingConfig(
        genderFilter: [],
        memberFilter: [],
        ipLocationFilter: [],
      );

      final decoded = CommentShieldingConfig.fromJson(config.toJson());

      expect(decoded.genderFilter, isEmpty);
      expect(decoded.memberFilter, isEmpty);
      expect(decoded.ipLocationFilter, isEmpty);
    });

    test('copyWith creates updated instance', () {
      const config = CommentShieldingConfig(levelThreshold: 3);

      final updated = config.copyWith(levelThreshold: 5);

      expect(updated.levelThreshold, 5);
      expect(config.levelThreshold, 3);
    });

    test('equality is value-based', () {
      const a = CommentShieldingConfig(
        levelThreshold: 3,
        genderFilter: ['男'],
      );
      const b = CommentShieldingConfig(
        levelThreshold: 3,
        genderFilter: ['男'],
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('CommentShieldingStore', () {
    test('defaults to no-op config', () {
      final box = _MemoryBox();
      final store = CommentShieldingStore(box: box);

      final config = store.snapshot();

      expect(config.levelThreshold, isNull);
      expect(config.genderFilter, isEmpty);
      expect(config.memberFilter, isEmpty);
      expect(config.ipLocationFilter, isEmpty);
      expect(config.minCharCount, isNull);
      expect(config.maxCharCount, isNull);
      expect(config.likeThreshold, isNull);
      expect(config.blockWithPicture, isFalse);
      expect(config.blockWithEmote, isFalse);
    });

    test('save and load round trips', () async {
      final box = _MemoryBox();
      final store = CommentShieldingStore(box: box);

      const config = CommentShieldingConfig(
        levelThreshold: 5,
        genderFilter: ['男'],
        memberFilter: ['vip:2:1'],
        ipLocationFilter: ['广东'],
        minCharCount: 3,
        maxCharCount: 80,
        likeThreshold: 10,
        blockWithPicture: true,
        blockWithEmote: true,
      );

      await store.save(config);
      final loaded = store.snapshot();

      expect(loaded.levelThreshold, 5);
      expect(loaded.genderFilter, ['男']);
      expect(loaded.memberFilter, ['vip:2:1']);
      expect(loaded.ipLocationFilter, ['广东']);
      expect(loaded.minCharCount, 3);
      expect(loaded.maxCharCount, 80);
      expect(loaded.likeThreshold, 10);
      expect(loaded.blockWithPicture, isTrue);
      expect(loaded.blockWithEmote, isTrue);
    });

    test('damaged payload falls back to default config', () {
      final box = _MemoryBox({
        CommentShieldingStore.configKey: 'not-valid-json',
      });
      final store = CommentShieldingStore(box: box);

      final config = store.snapshot();

      expect(config.levelThreshold, isNull);
      expect(config.genderFilter, isEmpty);
      expect(config.version, 1);
    });

    test('snapshot caches and updates after save', () async {
      final box = _MemoryBox();
      final store = CommentShieldingStore(box: box);

      const config = CommentShieldingConfig(levelThreshold: 3);
      await store.save(config);

      final first = store.snapshot();
      final second = store.snapshot();

      expect(identical(first, second), isTrue);
    });

    test('uses separate namespace key from ShieldSettingsStore', () {
      expect(
        CommentShieldingStore.configKey,
        isNot(ShieldSettingsStore.rulesKey),
      );
    });
  });
}

class _MemoryBox implements ShieldSettingsBox {
  _MemoryBox([Map<String, Object?>? values]) : values = values ?? {};

  final Map<String, Object?> values;

  @override
  Object? get(String key, {Object? defaultValue}) =>
      values.containsKey(key) ? values[key] : defaultValue;

  @override
  Future<void> put(String key, Object? value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
