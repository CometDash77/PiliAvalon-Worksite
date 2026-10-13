import 'package:PiliPlus/features/llm/llm_contract.dart';
import 'package:PiliPlus/features/llm/llm_response.dart';
import 'package:PiliPlus/features/llm/llm_settings.dart';
import 'package:dio/dio.dart';

// Result of one credential probe against the configured generic service.
enum LlmProbeOutcome {
  // The service accepted the key and answered a chat request.
  ok,

  // The service rejected the credential (401/403).
  invalidKey,

  // The service asked us to slow down (429/529).
  rateLimited,

  // The service rejected the request shape (400/422) - not a key verdict.
  rejectedRequest,

  // The requested model was explicitly reported missing.
  modelNotFound,

  // The service failed on its side.
  serverError,

  // No response inside [LlmLimits.requestTimeout].
  timeout,

  // The request never reached the service.
  networkError,

  // A 2xx answer that carried no extractable text.
  malformedResponse,
}

class LlmProbeResult {
  const LlmProbeResult(this.outcome, {this.detail});

  // Null when no request left the device because the configuration is
  // structurally incomplete; [detail] then carries the blocking reason.
  final LlmProbeOutcome? outcome;

  // Short upstream summary (HTTP status plus excerpt), capped to
  // [LlmLimits.maxDetailRunes]; null for outcomes without an HTTP response.
  final String? detail;

  bool get succeeded => outcome == LlmProbeOutcome.ok;
}

// Single-shot credential probe for the generic line (spec 1).
//
// Uses its own [Dio], never the app's shared HTTP client, so no cookie,
// account identifier, or device header can travel to the service. It sends one
// synthetic, candidate-free question whose only purpose is to prove the service
// is callable with the stored key and model choice. Redirects are disabled so
// authentication headers are never forwarded elsewhere.
class LlmHttpProbe {
  LlmHttpProbe({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const String _probePrompt = 'Respond with OK.';

  Future<LlmProbeResult> call({
    required LlmProviderConfig config,
    required String apiKey,
    String? model,
  }) async {
    final blocking = config.issues;
    if (blocking.isNotEmpty) {
      return LlmProbeResult(null, detail: blocking.first.message);
    }
    final protocol = config.protocol!;
    final effectiveModel = model ?? config.model;
    try {
      final response = await _dio.post<Object?>(
        config.chatEndpoint!,
        data: switch (protocol) {
          LlmProtocol.openAICompatible => <String, Object?>{
            'model': effectiveModel,
            'messages': const <Map<String, String>>[
              {'role': 'user', 'content': _probePrompt},
            ],
            'max_tokens': 16,
            'stream': false,
          },
          LlmProtocol.anthropicCompatible => <String, Object?>{
            'model': effectiveModel,
            'max_tokens': 16,
            'messages': const <Map<String, String>>[
              {'role': 'user', 'content': _probePrompt},
            ],
          },
        },
        options: Options(
          followRedirects: false,
          headers: <String, String>{
            'content-type': 'application/json',
            if (apiKey.isNotEmpty) ...protocol.authHeaders(apiKey),
          },
          sendTimeout: LlmLimits.requestTimeout,
          receiveTimeout: LlmLimits.requestTimeout,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        return LlmProbeResult(
          _outcomeForResponse(status, response.data),
          detail: _describeResponse(status, response.data),
        );
      }
      if (LlmResponseText.extract(protocol, response.data) == null) {
        return LlmProbeResult(
          LlmProbeOutcome.malformedResponse,
          detail: _describeResponse(status, response.data),
        );
      }
      return const LlmProbeResult(LlmProbeOutcome.ok);
    } on DioException catch (error) {
      return LlmProbeResult(
        _outcomeForError(error),
        detail: _describeResponse(
          error.response?.statusCode,
          error.response?.data,
        ),
      );
    }
  }

  static LlmProbeOutcome _outcomeForResponse(int status, Object? data) {
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
      return LlmProbeOutcome.modelNotFound;
    }
    return _outcomeForStatus(status);
  }

  static LlmProbeOutcome _outcomeForStatus(int status) {
    if (status == 401 || status == 403) return LlmProbeOutcome.invalidKey;
    if (status == 429 || status == 529) return LlmProbeOutcome.rateLimited;
    if (status == 400 || status == 422) return LlmProbeOutcome.rejectedRequest;
    return LlmProbeOutcome.serverError;
  }

  // Both protocols answer errors with error.message; generic compatible
  // services often use message / detail / error at the top level.
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

  static String? _describeResponse(int? status, Object? data) {
    final message = switch (data) {
      final Map body => _messageIn(body),
      final String text => text.trim(),
      _ => null,
    };
    final summary = (message == null || message.isEmpty)
        ? null
        : _shorten(message);
    if (summary == null) {
      return status == null ? null : 'HTTP $status';
    }
    if (status == null) return summary;
    return 'HTTP $status：$summary';
  }

  static String _shorten(String text) {
    final runes = text.runes.toList();
    if (runes.length <= LlmLimits.maxDetailRunes) return text;
    return '${String.fromCharCodes(runes.take(LlmLimits.maxDetailRunes))}…';
  }

  static LlmProbeOutcome _outcomeForError(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => LlmProbeOutcome.timeout,
      DioExceptionType.badResponse => _outcomeForResponse(
        error.response?.statusCode ?? 0,
        error.response?.data,
      ),
      _ => LlmProbeOutcome.networkError,
    };
  }
}
