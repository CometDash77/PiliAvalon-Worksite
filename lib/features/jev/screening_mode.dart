import 'package:PiliPlus/features/jev/jev_settings.dart';
import 'package:PiliPlus/utils/storage.dart';

enum ScreeningEngineMode {
  off('关闭'),
  decision('Decision'),
  llm('LLM');

  const ScreeningEngineMode(this.label);
  final String label;
}

/// One persisted route for every semantic entry point. No credentials live here.
class ScreeningModeStore {
  ScreeningModeStore({JevSettingsBox? box}) : _injectedBox = box;

  final JevSettingsBox? _injectedBox;
  JevSettingsBox? _lazyBox;
  JevSettingsBox get _box =>
      _lazyBox ??= _injectedBox ?? HiveJevSettingsBox(GStorage.setting);

  static const key = 'piliavalon.screening.v1.mode';
  static const _choiceRequired = 'choice_required';
  static int _generation = 0;
  static int _pendingWrites = 0;
  // ponytail: serialize rare settings writes globally; use per-box queues if needed.
  static Future<void> _writes = Future<void>.value();

  ScreeningEngineMode get _mode => switch (_box.get(key)) {
    'decision' => ScreeningEngineMode.decision,
    'llm' => ScreeningEngineMode.llm,
    _ => ScreeningEngineMode.off,
  };

  bool get needsChoice => !ScreeningEngineMode.values.any(
    (mode) => mode.name == _box.get(key),
  );

  Future<ScreeningModeSnapshot> load() async {
    try {
      return await _load();
    } catch (_) {
      return ScreeningModeSnapshot._(this, ScreeningEngineMode.off, -1);
    }
  }

  Future<ScreeningModeSnapshot> _load() async {
    await _writes;
    if (_box.get(key) == null) {
      await _write(() async {
        if (_box.get(key) != null) return;
        // A saved LLM configuration used to run independently of the Jev switch.
        // Do not guess which backend its owner intended, or erase either config.
        final legacyLlm = [
          'piliavalon.llm.v1.protocol',
          'piliavalon.llm.v1.base_url',
          'piliavalon.llm.v1.model',
          'piliavalon.llm.v1.video_rules.v1',
          'piliavalon.llm.v2.accounts',
          'piliavalon.llm.v2.active_provider',
        ].any((key) {
          final value = _box.get(key);
          return value != null && value != '' &&
              !(value is List && value.isEmpty);
        });
        final enabled = _box.get(JevSettingsStore.enabledKey);
        await _box.put(key, legacyLlm
            ? _choiceRequired
            : enabled == null || enabled == true ? 'decision' : 'off');
      });
    }
    return ScreeningModeSnapshot._(this, _mode, _generation);
  }

  Future<void> save(ScreeningEngineMode mode) => _write(() async {
    await _box.put(key, mode.name);
  });

  Future<void> _write(Future<void> Function() action) {
    _generation++;
    _pendingWrites++;
    final result = _writes.then((_) => action()).whenComplete(() {
      _generation++;
      _pendingWrites--;
    });
    // A failed save must reach its caller without poisoning subsequent writes.
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
}

class ScreeningModeSnapshot {
  ScreeningModeSnapshot._(this._store, this.mode, this.generation);

  final ScreeningModeStore _store;
  final ScreeningEngineMode mode;
  final int generation;

  bool get isCurrent {
    try {
      return ScreeningModeStore._pendingWrites == 0 &&
          generation == ScreeningModeStore._generation && mode == _store._mode;
    } catch (_) {
      return false;
    }
  }
}
