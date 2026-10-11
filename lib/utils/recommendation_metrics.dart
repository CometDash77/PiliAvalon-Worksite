import 'package:dio/dio.dart';

/// Phases measured while preparing a recommendation page.
enum RecommendationPhase {
  filtering,
  tagEnrichment,
  commentGate,
  firstScreenVisible,
}

/// Optional observer for recommendation request counts and phase timings.
///
/// The default observer is a const no-op. Install an observer only while
/// collecting diagnostics; production requests and filtering then avoid
/// timers, allocations, and log output.
abstract interface class RecommendationMetricsObserver {
  void onHttpRequest(Uri uri);

  void onGrpcRequest(String method);

  void onPhaseCompleted(
    RecommendationPhase phase,
    Duration elapsed, {
    required int inputCount,
    required int outputCount,
  });
}

class _NoopRecommendationMetricsObserver
    implements RecommendationMetricsObserver {
  const _NoopRecommendationMetricsObserver();

  @override
  void onGrpcRequest(String method) {}

  @override
  void onHttpRequest(Uri uri) {}

  @override
  void onPhaseCompleted(
    RecommendationPhase phase,
    Duration elapsed, {
    required int inputCount,
    required int outputCount,
  }) {}
}

/// Mutable only so a diagnostic session can opt in and then restore no-op.
abstract final class RecommendationMetrics {
  static const _noop = _NoopRecommendationMetricsObserver();
  static RecommendationMetricsObserver _observer = _noop;

  static RecommendationMetricsObserver get observer => _observer;

  static set observer(RecommendationMetricsObserver value) {
    _observer = value;
  }

  static void disable() => _observer = _noop;

  static bool get enabled => !identical(_observer, _noop);

  static void recordHttpRequest(Uri uri) {
    if (enabled) _observer.onHttpRequest(uri);
  }

  static void recordGrpcRequest(String method) {
    if (enabled) _observer.onGrpcRequest(method);
  }

  static RecommendationPhaseMeasurement? startPhase(
    RecommendationPhase phase, {
    required int inputCount,
  }) {
    if (!enabled) return null;
    return RecommendationPhaseMeasurement._(phase, inputCount);
  }

  static void finishPhase(
    RecommendationPhaseMeasurement? measurement, {
    required int outputCount,
  }) {
    if (measurement == null) return;
    measurement.stopwatch.stop();
    _observer.onPhaseCompleted(
      measurement.phase,
      measurement.stopwatch.elapsed,
      inputCount: measurement.inputCount,
      outputCount: outputCount,
    );
  }
}

class RecommendationPhaseMeasurement {
  RecommendationPhaseMeasurement._(this.phase, this.inputCount)
    : stopwatch = Stopwatch()..start();

  final RecommendationPhase phase;
  final int inputCount;
  final Stopwatch stopwatch;
}

/// Counts physical HTTP attempts at Dio's shared interceptor boundary.
class RecommendationMetricsInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    RecommendationMetrics.recordHttpRequest(options.uri);
    handler.next(options);
  }
}

/// In-memory collector suitable for a repeatable test or an opt-in smoke run.
class RecommendationMetricsRecorder implements RecommendationMetricsObserver {
  RecommendationMetricsRecorder({this.onRecord});

  final void Function(String line)? onRecord;
  final Map<String, int> httpRequests = {};
  final Map<String, int> grpcRequests = {};
  final Map<RecommendationPhase, List<RecommendationPhaseSample>> phases = {};

  @override
  void onHttpRequest(Uri uri) {
    final key = '${uri.host}${uri.path}';
    final count = httpRequests.update(
      key,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    onRecord?.call('http $key=$count');
  }

  @override
  void onGrpcRequest(String method) {
    final count = grpcRequests.update(
      method,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    onRecord?.call('grpc $method=$count');
  }

  @override
  void onPhaseCompleted(
    RecommendationPhase phase,
    Duration elapsed, {
    required int inputCount,
    required int outputCount,
  }) {
    final sample = RecommendationPhaseSample(
      elapsed: elapsed,
      inputCount: inputCount,
      outputCount: outputCount,
    );
    phases
        .putIfAbsent(phase, () => <RecommendationPhaseSample>[])
        .add(sample);
    onRecord?.call(
      'phase ${phase.name}=${elapsed.inMicroseconds}us '
      'items=$inputCount->$outputCount',
    );
  }

  /// A compact, stable text record that can be copied from a test/smoke run.
  String format() {
    final lines = <String>['Recommendation metrics'];
    for (final key in httpRequests.keys.toList()..sort()) {
      lines.add('http $key=${httpRequests[key]}');
    }
    for (final key in grpcRequests.keys.toList()..sort()) {
      lines.add('grpc $key=${grpcRequests[key]}');
    }
    for (final phase in RecommendationPhase.values) {
      final samples = phases[phase];
      if (samples == null) continue;
      for (final sample in samples) {
        lines.add(
          'phase ${phase.name}=${sample.elapsed.inMicroseconds}us '
          'items=${sample.inputCount}->${sample.outputCount}',
        );
      }
    }
    return lines.join('\n');
  }
}

class RecommendationPhaseSample {
  const RecommendationPhaseSample({
    required this.elapsed,
    required this.inputCount,
    required this.outputCount,
  });

  final Duration elapsed;
  final int inputCount;
  final int outputCount;
}
