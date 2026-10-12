import 'package:PiliPlus/features/jev/jev_contract.dart';
import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:PiliPlus/features/jev/jev_settings.dart';

/// One-shot migration from the retired comment-criteria config (issue #122).
///
/// The old comment filtering had its own switch plus a free-text criteria
/// prompt (`comment_enabled` / `comment_criteria`). The merged pipeline
/// replaces both with the typed 判断规则 ([JevRuleStore]) and the per-surface
/// switch of [JevSurface.comment]. This migration runs once per process,
/// lazily, before the merged chain first reads state:
///
/// - non-empty old criteria text (when the old switch was on, or when the
///   user authored custom text different from the retired default) becomes
///   one noul rule so no user-authored standard is lost;
/// - the old switch being on turns on the [JevSurface.comment] surface
///   switch;
/// - both retired keys are deleted only after a successful run, so a crashed
///   attempt retries on the next launch.
///
/// Every failure is swallowed (fail-open): the merged chain simply stays off
/// until the user configures rules.
abstract final class JevCommentCriteriaMigration {
  /// Seeded rule id; the question carries the original criteria text.
  static const String migratedRuleId = 'comment-criteria-migrated';

  /// The retired default prompt, kept verbatim so "switch off + default
  /// text" (never active) can be told apart from authored criteria.
  static const String retiredDefaultCriteria =
      '隐藏明显广告引流、直接辱骂或人身攻击、重复刷屏、明显无关灌水；'
      '保留正常批评和不同意见、相关玩笑、简短但有意义的回复。'
      '不能仅因语气尖锐、观点不同或内容简短就隐藏；信息不足时保留。';

  static bool _done = false;

  /// Tests only: allow re-running the migration in a fresh process state.
  static void resetForTest() => _done = false;

  static Future<void> ensureRun({
    JevSettingsStore? settings,
    JevRuleStore? rules,
  }) async {
    if (_done) return;
    // A failed attempt still counts as done for this process; the retired
    // keys survive so the next launch retries.
    _done = true;
    try {
      final settingsStore = settings ?? JevSettingsStore();
      final rulesStore = rules ?? JevRuleStore(box: settings?.box);
      final box = settingsStore.box;
      final rawSwitch = box.get(JevSettingsStore.commentEnabledKey);
      final rawCriteria = box.get(JevSettingsStore.commentCriteriaKey);
      if (rawSwitch == null && rawCriteria == null) return;
      final oldSwitchOn = rawSwitch is bool && rawSwitch;
      final criteria = rawCriteria is String ? rawCriteria.trim() : '';
      final shouldSeed =
          criteria.isNotEmpty &&
          (oldSwitchOn || criteria != retiredDefaultCriteria);
      var seeded = true;
      if (shouldSeed) {
        final config = await rulesStore.load();
        final existing = config.rules
            .where((rule) => rule.target == JevRuleTarget.comment)
            .toList();
        final alreadySeeded = existing.any(
          (rule) => rule.id == migratedRuleId || rule.question.trim() == criteria,
        );
        if (!alreadySeeded) {
          // A >1000-rune prompt cannot become a rule (JevRule.validate caps
          // the question at 1000) and silently truncating it would change
          // what gets hidden; a full comment target has no free slot either.
          // Both keep the retired keys around so a later launch can retry
          // once the user makes room.
          if (existing.length < JevRule.maxRulesPerTarget &&
              criteria.length <= JevLimits.maxQuestionChars) {
            await rulesStore.save(
              JevRuleConfig(
                rules: [
                  ...config.rules,
                  JevRule(
                    id: migratedRuleId,
                    target: JevRuleTarget.comment,
                    question: criteria,
                    type: JevRuleType.noul,
                    threshold: JevLimits.hideNoulThreshold,
                  ),
                ],
                disabledBuiltins: config.disabledBuiltins,
              ),
            );
          } else {
            seeded = false;
          }
        }
      }
      if (oldSwitchOn) {
        final current = await settingsStore.load();
        if (!current.surfaces.contains(JevSurface.comment)) {
          await settingsStore.save(
            current.withSurface(JevSurface.comment, value: true),
          );
        }
      }
      // The migration is only finished once nothing was dropped on the
      // floor: unseedable criteria retry on the next launch.
      if (seeded) {
        await box.delete(JevSettingsStore.commentEnabledKey);
        await box.delete(JevSettingsStore.commentCriteriaKey);
      }
    } catch (_) {
      // Fail-open: a failed migration never blocks screening.
    }
  }
}
