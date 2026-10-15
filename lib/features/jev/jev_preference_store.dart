import 'package:PiliPlus/features/jev/jev_contract.dart';
import 'package:PiliPlus/features/jev/jev_preference_profile.dart';
import 'package:PiliPlus/features/jev/jev_settings.dart';
import 'package:PiliPlus/utils/storage.dart';

/// Reads and writes the local explicit negative profile (issue #33).
///
/// The profile lives in the non-secret settings box: it holds themes and
/// approximate counts, so it may travel with a settings export — which is
/// exactly why no credential and no per-video row may ever reach it.
class JevPreferenceStore {
  JevPreferenceStore({
    JevSettingsBox? box,
    JevSettingsStore? settings,
    DateTime Function()? clock,
  }) : _box = box ?? HiveJevSettingsBox(GStorage.setting),
       _settings = settings ?? JevSettingsStore(box: box),
       _clock = clock ?? DateTime.now {
    if (box != null) {
      _cache = null;
    }
  }

  static const String profileKey = '${JevSettingsStore.namespace}.profile';

  final JevSettingsBox _box;
  final JevSettingsStore _settings;
  final DateTime Function() _clock;

  static JevPreferenceProfile? _cache;

  /// Last loaded profile, or the empty default before any load.
  static JevPreferenceProfile get snapshot =>
      _cache ?? JevPreferenceProfile.empty;

  /// Drops the cached snapshot (used when a settings export is restored).
  static void resetCache() => _cache = null;

  /// Reads the profile, dropping the themes that expired since the last write.
  Future<JevPreferenceProfile> load() async {
    final profile = JevPreferenceProfile.decode(
      _box.get(profileKey),
    ).settled(_clock());
    _cache = profile;
    return profile;
  }

  /// Records one explicit recommendation-card dislike. Returns true when a
  /// theme was written.
  ///
  /// The gate is deliberately not the caller's business: nothing is collected
  /// unless the master switch and the switch of the surface the card belongs to
  /// are both on, because a surface the user switched off must not silently feed
  /// the profile that screens the others (gap G-16). Turning Jev off pauses
  /// collection only — the profile and its expiry timers stay, so the next [load]
  /// still drops expired themes. A card that yields no usable theme
  /// ([JevDislikeSignal.summarize] is null) writes nothing at all.
  Future<bool> record(
    JevDislikeSignal signal, {
    required JevSurface surface,
  }) async {
    final settings = await _settings.load();
    if (!settings.isSurfaceEnabled(surface)) return false;
    final theme = signal.summarize();
    if (theme == null) return false;
    await _write((await load()).recordTheme(theme, now: _clock()));
    return true;
  }

  /// Deletes one theme. The only decrement path there is: the platform 「撤销」
  /// action never calls it (issue #33).
  Future<void> deleteTheme(String theme) async =>
      _write((await load()).withoutTheme(theme));

  /// Clears the entire profile: the key is removed, not emptied.
  Future<void> clear() => _write(JevPreferenceProfile.empty);

  Future<void> _write(JevPreferenceProfile profile) async {
    if (profile.isEmpty) {
      await _box.delete(profileKey);
    } else {
      await _box.put(profileKey, profile.encode());
    }
    _cache = profile;
  }
}
