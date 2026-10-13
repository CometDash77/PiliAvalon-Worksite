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

  /// The requested model was explicitly reported missing.
  modelNotFound,

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
  String? model,
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
    String? model,
  }) async {
    try {
      final response = await _dio.post<Object?>(
        provider.endpoint,
        data: JevRequest.body(
          model: model ?? provider.model,
          state: const <String, Object?>{},
          questions: <String, Map<String, Object?>>{
            'probe_1': JevRequest.question(),
          },
        ),
        options: Options(
          followRedirects: false,
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
        return JevProbeResult(
          _outcomeForResponse(status, response.data),
          detail: _describeResponse(status, response.data),
        );
      }
      final data = response.data;
      final answers = data is Map ? data['answers'] : null;
      final answer = answers is Map ? answers['probe_1'] : null;
      final noul = answer is Map ? answer['noul'] : null;
      if (answer is! Map ||
          answer['type'] != 'noul' ||
          noul is! num ||
          !noul.isFinite ||
          noul < 0 ||
          noul > 1) {
        return JevProbeResult(
          JevProbeOutcome.malformedResponse,
          detail: _describeResponse(status, response.data),
        );
      }
      return const JevProbeResult(JevProbeOutcome.ok);
    } on DioException catch (error) {
      return JevProbeResult(
        _outcomeForError(error),
        detail: _describeResponse(
          error.response?.statusCode,
          error.response?.data,
        ),
      );
    }
  }

  static JevProbeOutcome _outcomeForResponse(int status, Object? data) {
    final text =
        (data is Map
                ? _messageIn(data)
                : data is String
                ? data
                : null)
            ?.toLowerCase() ??
        '';
    if ((status == 400 || status == 404 || status == 422) &&
        text.contains('model') &&
        (text.contains('does not exist') ||
            text.contains('not found') ||
            text.contains('unknown model'))) {
      return JevProbeOutcome.modelNotFound;
    }
    return _outcomeForStatus(status);
  }

  static JevProbeOutcome _outcomeForStatus(int status) {
    if (status == 401 || status == 403) return JevProbeOutcome.invalidKey;
    if (status == 429 || status == 529) return JevProbeOutcome.rateLimited;
    if (status == 400 || status == 422) return JevProbeOutcome.rejectedRequest;
    return JevProbeOutcome.serverError;
  }

  /// Short upstream summary (status + message) carried on the probe result so
  /// the settings page can explain *why* a request was rejected (issue #101).
  /// Returns null for outcomes without an HTTP response, keeping the existing
  /// user-facing copy as the fallback.
  static String? _describeResponse(int? status, Object? data) {
    final message = switch (data) {
      final Map body => _messageIn(body),
      final String text => text.trim(),
      _ => null,
    };
    final summary = (message == null || message.isEmpty)
        ? null
        : _shorten(message);
    if (summary == null) return status == null ? null : 'HTTP $status';
    return status == null ? summary : 'HTTP $status：$summary';
  }

  static String? _messageIn(Map body) {
    final error = body['error'];
    if (error is Map) {
      final message = error['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    for (final key in const ['message', 'detail', 'error']) {
      final value = body[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static String _shorten(String text) {
    final runes = text.runes.toList();
    if (runes.length <= 200) return text;
    return '${String.fromCharCodes(runes.take(200))}…';
  }

  static JevProbeOutcome _outcomeForError(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => JevProbeOutcome.timeout,
      DioExceptionType.badResponse => _outcomeForResponse(
        error.response?.statusCode ?? 0,
        error.response?.data,
      ),
      _ => JevProbeOutcome.networkError,
    };
  }
}
