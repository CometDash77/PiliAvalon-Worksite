import 'package:PiliPlus/features/jev/jev_feedback_profile.dart';
import 'package:PiliPlus/features/jev/jev_settings_store.dart';
import 'package:PiliPlus/utils/storage.dart';

class JevHiveProfileBox implements JevProfileBox {
  const JevHiveProfileBox();
  @override
  Object? get(String key) => GStorage.localCache.get(key);
  @override
  Future<void> put(String key, Object? value) async => GStorage.localCache.put(key, value);
  @override
  Future<void> delete(String key) async => GStorage.localCache.delete(key);
}

JevSettingsStore createJevSettingsStore() => JevSettingsStore();
JevFeedbackProfile createJevFeedbackProfile() => JevFeedbackProfile(const JevHiveProfileBox());
