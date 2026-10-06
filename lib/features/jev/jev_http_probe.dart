import 'package:PiliPlus/features/jev/jev_contract.dart';
import 'package:dio/dio.dart';

/// Result of one credential probe against a selected provider.
enum JevProbeOutcome {
  /// The selected provider accepted the key.
  ok,

  /// The provider rejected the credential (401/403).
  invalidKey,

  /// The provider asked us to slow down (429/529).
  rateLimited,

  /// The provider rejected the request shape (400/422) - not a key verdict.
  rejectedRequest,

  /// The provider failed on its side.
  serverError,

  /// No response inside [JevLimits.requestTimeout].
  timeout,

  /// The request never reached the provider.
  networkError,

  /// A 2xx answer that could not be parsed.
  malformedResponse,
}

class JevProbeResult {
  const JevProbeResult(this.outcome, {this.detail});

  final JevProbeOutcome outcome;

  final String? detail;

  bool get succeeded => outcome == JevProbeOutcome.ok;
}

typedef JevProbe = Future<JevProbeResult> Function({
  required JevProvider provider,
  required String apiKey,
});

/// Single-shot credential probe behind the settings page (gap G-20).
///
/// The probe deliberately uses its own [Dio] rather than the app's shared HTTP
/// client, so no cookie, account identifier, or device header can travel to the
/// provider. It sends one synthetic, candidate-free question: the only purpose
/// is to prove that the key is accepted by the *selected* provider.
class JevHttpProbe {
  JevHttpProbe({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<JevProbeResult> call({
    required JevProvider provider,
    required String apiKey,
  }) async {
    try {
      final response = await _dio.post<Object?>(
        provider.endpoint,
        data: JevRequest.body(
          model: provider.model,
          state: const <String, Object?>{},
          questions: <Map<String, Object?>>[JevRequest.question('probe_1')],
        ),
        options: Options(
          headers: <String, String>{
            'authorization': 'Bearer $apiKey',
            'content-type': 'application/json',
          },
          sendTimeout: JevLimits.requestTimeout,
          receiveTimeout: JevLimits.requestTimeout,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        return JevProbeResult(_outcomeForStatus(status));
      }
      if (response.data is! Map) {
        return const JevProbeResult(JevProbeOutcome.malformedResponse);
      }
      return const JevProbeResult(JevProbeOutcome.ok);
    } on DioException catch (error) {
      return JevProbeResult(_outcomeForError(error));
    }
  }

  static JevProbeOutcome _outcomeForStatus(int status) {
    if (status == 401 || status == 403) return JevProbeOutcome.invalidKey;
    if (status == 429 || status == 529) return JevProbeOutcome.rateLimited;
    if (status == 400 || status == 422) return JevProbeOutcome.rejectedRequest;
    return JevProbeOutcome.serverError;
  }

  static JevProbeOutcome _outcomeForError(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => JevProbeOutcome.timeout,
      DioExceptionType.badResponse => _outcomeForStatus(
        error.response?.statusCode ?? 0,
      ),
      _ => JevProbeOutcome.networkError,
    };
  }
}
