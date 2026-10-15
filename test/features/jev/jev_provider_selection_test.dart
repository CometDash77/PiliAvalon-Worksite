import 'package:PiliPlus/features/jev/jev.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JevKeyFormat', () {
    test('classifies key shapes without ever deciding a provider', () {
      expect(JevKeyFormat.hintFor(''), JevKeyHint.empty);
      expect(JevKeyFormat.hintFor('   '), JevKeyHint.empty);
      expect(
        JevKeyFormat.hintFor('sk-or-v1-abc123'),
        JevKeyHint.openRouterSuggested,
      );
      expect(JevKeyFormat.hintFor('plain-key'), JevKeyHint.unrecognized);
    });
  });

  group('JevSelectionState', () {
    test('an OpenRouter-shaped key alone still asks for a provider', () {
      const state = JevSelectionState(keyText: 'sk-or-v1-abc');
      expect(state.canValidate, isFalse);
      expect(state.routableProvider, isNull);
      expect(state.issues, contains(JevSelectionIssue.missingProvider));
      expect(state.issues, contains(JevSelectionIssue.openRouterSuggestion));
    });

    test('never routes an OpenRouter-shaped key to TypeSafe', () {
      final state = const JevSelectionState(
        keyText: 'sk-or-v1-abc',
      ).withProvider(JevProvider.typeSafe);
      expect(state.isBlockedByMismatch, isTrue);
      expect(state.canValidate, isFalse);
      expect(state.routableProvider, isNull);
      expect(state.issues, contains(JevSelectionIssue.providerMismatch));
    });

    test('an explicit confirmation unblocks the selected provider only', () {
      final state = const JevSelectionState(keyText: 'sk-or-v1-abc')
          .withProvider(JevProvider.typeSafe)
          .acknowledgeMismatch();
      expect(state.canValidate, isTrue);
      expect(state.routableProvider, JevProvider.typeSafe);
      expect(state.issues, isEmpty);
    });

    test('editing the key drops the earlier confirmation', () {
      final state = const JevSelectionState(keyText: 'sk-or-v1-abc')
          .withProvider(JevProvider.typeSafe)
          .acknowledgeMismatch()
          .withKey('sk-or-v1-xyz');
      expect(state.mismatchAcknowledged, isFalse);
      expect(state.canValidate, isFalse);
    });

    test('switching provider drops the earlier confirmation', () {
      final state = const JevSelectionState(keyText: 'sk-or-v1-abc')
          .withProvider(JevProvider.typeSafe)
          .acknowledgeMismatch()
          .withProvider(JevProvider.typeSafe);
      expect(state.mismatchAcknowledged, isFalse);
      expect(state.canValidate, isFalse);
    });

    test('an unrecognized key validates after a manual choice', () {
      const noProvider = JevSelectionState(keyText: 'plain-key');
      expect(noProvider.canValidate, isFalse);
      expect(noProvider.issues, contains(JevSelectionIssue.missingProvider));
      expect(noProvider.hasKey, isTrue);
      final manual = noProvider.withProvider(JevProvider.openRouter);
      expect(manual.issues, isEmpty);
      expect(manual.routableProvider, JevProvider.openRouter);
    });

    test('a matching suggestion needs no confirmation step', () {
      final state = const JevSelectionState(
        keyText: 'sk-or-v1-abc',
      ).withProvider(JevProvider.openRouter);
      expect(state.isBlockedByMismatch, isFalse);
      expect(state.canValidate, isTrue);
      expect(state.routableProvider, JevProvider.openRouter);
    });

    test('blank keys never become validatable', () {
      final state = const JevSelectionState(
        keyText: '   ',
      ).withProvider(JevProvider.openRouter);
      expect(state.hasKey, isFalse);
      expect(state.canValidate, isFalse);
      expect(state.issues, contains(JevSelectionIssue.missingKey));
    });
  });
}
