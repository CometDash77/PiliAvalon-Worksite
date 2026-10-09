import 'package:PiliPlus/features/jev/jev.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sends one request to the selected provider', () async {
    final calls = <JevProvider>[];
    final validator = JevKeyValidator(
      probe:
          ({
            required JevProvider provider,
            required String apiKey,
          }) async {
            calls.add(provider);
            return const JevProbeResult(JevProbeOutcome.ok);
          },
    );
    final state = const JevSelectionState(
      keyText: 'sk-or-v1-abc',
    ).withProvider(JevProvider.openRouter);

    final result = await validator.validate(
      selection: state,
      apiKey: 'sk-or-v1-abc',
    );

    expect(calls, <JevProvider>[JevProvider.openRouter]);
    expect(result.provider, JevProvider.openRouter);
    expect(result.attempted, isTrue);
    expect(result.validated, isTrue);
    expect(result.blockedBy, isEmpty);
  });

  test('a rejection is never retried against the other provider', () async {
    final calls = <JevProvider>[];
    final validator = JevKeyValidator(
      probe:
          ({
            required JevProvider provider,
            required String apiKey,
          }) async {
            calls.add(provider);
            return const JevProbeResult(JevProbeOutcome.invalidKey);
          },
    );
    final state = const JevSelectionState(
      keyText: 'plain-key',
    ).withProvider(JevProvider.typeSafe);

    final first = await validator.validate(
      selection: state,
      apiKey: 'plain-key',
    );
    final second = await validator.validate(
      selection: state,
      apiKey: 'plain-key',
    );

    expect(calls, <JevProvider>[JevProvider.typeSafe, JevProvider.typeSafe]);
    expect(first.validated, isFalse);
    expect(first.outcome, JevProbeOutcome.invalidKey);
    expect(second.outcome, JevProbeOutcome.invalidKey);
  });

  test('a blocked selection sends nothing at all', () async {
    var calls = 0;
    final validator = JevKeyValidator(
      probe:
          ({
            required JevProvider provider,
            required String apiKey,
          }) async {
            calls++;
            return const JevProbeResult(JevProbeOutcome.ok);
          },
    );
    final state = const JevSelectionState(
      keyText: 'sk-or-v1-abc',
    ).withProvider(JevProvider.typeSafe);

    final result = await validator.validate(
      selection: state,
      apiKey: 'sk-or-v1-abc',
    );

    expect(calls, 0);
    expect(result.attempted, isFalse);
    expect(result.validated, isFalse);
    expect(result.outcome, isNull);
    expect(result.provider, JevProvider.typeSafe);
    expect(result.blockedBy, contains(JevSelectionIssue.providerMismatch));
  });

  test('no provider selected means no request', () async {
    var calls = 0;
    final validator = JevKeyValidator(
      probe:
          ({
            required JevProvider provider,
            required String apiKey,
          }) async {
            calls++;
            return const JevProbeResult(JevProbeOutcome.ok);
          },
    );

    final result = await validator.validate(
      selection: const JevSelectionState(keyText: 'sk-or-v1-abc'),
      apiKey: 'sk-or-v1-abc',
    );

    expect(calls, 0);
    expect(result.provider, isNull);
    expect(result.blockedBy, contains(JevSelectionIssue.missingProvider));
  });

  test('probe detail rides along and stays null when absent (issue #101)', () async {
    var reply = const JevProbeResult(
      JevProbeOutcome.rejectedRequest,
      detail: 'HTTP 400：No endpoint found.',
    );
    final validator = JevKeyValidator(
      probe:
          ({
            required JevProvider provider,
            required String apiKey,
          }) async => reply,
    );
    final state = const JevSelectionState(
      keyText: 'plain-key',
    ).withProvider(JevProvider.typeSafe);

    final withDetail = await validator.validate(
      selection: state,
      apiKey: 'plain-key',
    );
    expect(withDetail.outcome, JevProbeOutcome.rejectedRequest);
    expect(withDetail.detail, 'HTTP 400：No endpoint found.');

    reply = const JevProbeResult(JevProbeOutcome.rejectedRequest);
    final withoutDetail = await validator.validate(
      selection: state,
      apiKey: 'plain-key',
    );
    expect(withoutDetail.detail, isNull);
  });
}
