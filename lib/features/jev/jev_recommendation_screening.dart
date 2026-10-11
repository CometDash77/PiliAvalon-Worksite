import 'package:PiliPlus/features/jev/jev_evaluator.dart';
import 'package:PiliPlus/features/jev/jev_feedback_profile.dart';
import 'package:PiliPlus/features/jev/jev_models.dart';
import 'package:PiliPlus/features/jev/jev_secure_key_store.dart';
import 'package:PiliPlus/features/jev/jev_settings_store.dart';
import 'package:PiliPlus/features/jev/jev_storage.dart';

/// Shared Jev decision point for recommendation adapters. Adapter-owned
/// deterministic filters run first; provider and secure-store failures keep
/// every remaining candidate visible.
class JevRecommendationScreening {
  JevRecommendationScreening({
    required this.settingsStore,
    required this.profile,
    required this.credentials,
    required this.pipeline,
  });

  factory JevRecommendationScreening.create() {
    final credentials = JevCredentialStore(FlutterJevSecretStorage());
    final profile = createJevFeedbackProfile();
    return JevRecommendationScreening(
      settingsStore: createJevSettingsStore(),
      profile: profile,
      credentials: credentials,
      pipeline: JevRecommendationPipeline(
        evaluator: JevHttpEvaluator(),
        loadKey: credentials.read,
      ),
    );
  }

  final JevSettingsStore settingsStore;
  final JevFeedbackProfile profile;
  final JevCredentialStore credentials;
  final JevRecommendationPipeline pipeline;

  Future<List<T>> filter<T>({
    required List<T> candidates,
    required JevSurface surface,
    required JevCandidate Function(T item) toCandidate,
    required List<T> Function(List<T> input) runLowerCostFilters,
  }) async {
    await profile.pruneExpired();
    return pipeline.filter<T>(
      candidates: candidates,
      settings: settingsStore.load(),
      surface: surface,
      negativeThemes: profile.providerSummary(),
      toJevCandidate: toCandidate,
      runLowerCostFilters: runLowerCostFilters,
    );
  }

  Future<void> recordExplicitDislike({
    String? displayedReason,
    String? selectedReason,
  }) async {
    final settings = settingsStore.load();
    final provider = settings.provider;
    final isReady = settings.enabled && provider != null &&
        await credentials.read(provider) != null;
    await profile.recordExplicitDislike(
      jevEnabled: isReady,
      displayedReason: displayedReason,
      selectedReason: selectedReason,
    );
  }
}
