import 'package:PiliPlus/features/jev/jev_credential_store.dart'
    show JevCredentialException;
import 'package:PiliPlus/features/llm/llm_contract.dart';
import 'package:PiliPlus/features/llm/llm_credential_store.dart';
import 'package:PiliPlus/features/llm/llm_response.dart';
import 'package:PiliPlus/features/llm/llm_settings.dart';
import 'package:dio/dio.dart';

// Why one generic-line chat call could not produce a usable verdict (spec 4).
// Every kind fails open upstream: affected content stays visible and
// no failed verdict enters the cache or triggers another backend.
enum LlmChatFailureKind {
  config, // provider config incomplete or not confirmed
  credential, // key missing or the OS credential store failed
  httpStatus, // non-2xx answer (429/5xx included; never retried)
  network, // connection failures and malformed transports
  timeout, // send/receive timeout, or the page-budget wrapper fired
  cancelled, // caller cancelled the page
  truncation, // finish_reason length / stop_reason max_tokens
  refusal, // provider refused or content-filtered the call
  emptyOutput, // 2xx but no extractable text
}

class LlmChatOutcome {
  const LlmChatOutcome.ok(this.text, {this.usage})
    : failure = null,
      detail = null;

  const LlmChatOutcome.failed(this.failure, this.detail) : text = null, usage = null;

  final String? text;
  final LlmChatFailureKind? failure;

  /// Human-readable summary, at most [LlmLimits.maxDetailRunes] runes,
  /// built only from server error envelopes - never from request headers.
  final String? detail;

  /// 上游 usage 观测（#176）：ok 且上游返回 usage 时非空；解析失败为 null。
  final LlmUpstreamUsage? usage;

  bool get ok => text != null;
}

// The raw HTTP seam of [LlmChatClient]: endpoint, headers, body, timeout in -
// decoded response body out. Throws [DioException] on transport/HTTP errors;
// any other throw is classified as a network failure.
typedef LlmChatTransport = Future<Object?> Function({
  required String endpoint,
  required Map<String, String> headers,
  required Map<String, Object?> body,
  required Duration timeout,
});

/// One generic-line chat call (spec 1/4): fixed built-in prompt in, JSON
/// text out. Production transport runs its own [Dio] - no app interceptors,
/// no cookies, no account headers (issue #32 precedent) - and refuses
/// redirects so the auth header can never follow a 3xx to another host
/// (issue #101 probe precedent).
class LlmChatClient {
  LlmChatClient({
    LlmChatTransport? transport,
    LlmCredentialStore? credentials,
    LlmSettingsStore? settings,
  }) : _transport = transport ?? _dioTransport,
       _credentials = credentials ?? SecureLlmCredentialStore(),
       _settings = settings ?? LlmSettingsStore();

  final LlmChatTransport _transport;
  final LlmCredentialStore _credentials;
  final LlmSettingsStore _settings;

  Future<LlmChatOutcome> call({
    required String system,
    required String user,
    Duration? timeout,
    bool Function()? isCurrent,
    Map<String, Object?>? thinkingFields,
  }) async {
    final config = await _settings.load();
    if (config.issues.isNotEmpty ||
        !config.confirmed ||
        config.protocol == null) {
      return const LlmChatOutcome.failed(LlmChatFailureKind.config, null);
    }
    final protocol = config.protocol!;
    final String? apiKey;
    try {
      apiKey = await _credentials.read(protocol);
    } on JevCredentialException {
      return const LlmChatOutcome.failed(LlmChatFailureKind.credential, null);
    }
    if (apiKey == null || apiKey.isEmpty) {
      return const LlmChatOutcome.failed(LlmChatFailureKind.credential, null);
    }
    try {
      if (isCurrent != null && !isCurrent()) {
        return const LlmChatOutcome.failed(LlmChatFailureKind.cancelled, null);
      }
      final data = await _transport(
        endpoint: config.chatEndpoint!,
        headers: <String, String>{
          ...config.authHeaders(apiKey),
          'content-type': 'application/json',
        },
        body: requestBody(
          protocol,
          model: config.model,
          system: system,
          user: user,
          thinkingFields: thinkingFields,
        ),
        timeout: timeout ?? LlmLimits.requestTimeout,
      );
      return fromBody(protocol, data);
    } on DioException catch (error) {
      return fromDioError(protocol, error);
    } catch (_) {
      return const LlmChatOutcome.failed(LlmChatFailureKind.network, null);
    }
  }

  /// Per-protocol request wire shape (issue #114, sections 2-3): OpenAI
  /// compatible = messages array; Anthropic compatible = native /v1/messages
  /// with a top-level system field and required max_tokens.
  static Map<String, Object?> requestBody(
    LlmProtocol protocol, {
    required String model,
    required String system,
    required String user,
    Map<String, Object?>? thinkingFields,
  }) => switch (protocol) {
    LlmProtocol.openAICompatible => <String, Object?>{
      'model': model,
      'messages': <Object?>[
        <String, Object?>{'role': 'system', 'content': system},
        <String, Object?>{'role': 'user', 'content': user},
      ],
      'max_tokens': LlmLimits.maxCompletionTokens,
      'stream': false,
      ...?thinkingFields,
    },
    LlmProtocol.anthropicCompatible => <String, Object?>{
      'model': model,
      'max_tokens': LlmLimits.maxCompletionTokens,
      'system': system,
      'messages': <Object?>[
        <String, Object?>{'role': 'user', 'content': user},
      ],
      ...?thinkingFields,
    },
  };

  /// 2xx body -> verdict text, with the stop marker checked first: a
  /// truncated or refused answer is invalid even when some text is present
  /// (spec 4 fail-open list).
  static LlmChatOutcome fromBody(LlmProtocol protocol, Object? data) {
    if (data is! Map) {
      return const LlmChatOutcome.failed(LlmChatFailureKind.emptyOutput, null);
    }
    final stop = stopReason(protocol, data);
    if (stop == 'length' || stop == 'max_tokens') {
      return const LlmChatOutcome.failed(LlmChatFailureKind.truncation, null);
    }
    if (stop == 'refusal' || stop == 'content_filter') {
      return const LlmChatOutcome.failed(LlmChatFailureKind.refusal, null);
    }
    final text = LlmResponseText.extract(protocol, data);
    if (text == null || text.trim().isEmpty) {
      return const LlmChatOutcome.failed(LlmChatFailureKind.emptyOutput, null);
    }
    return LlmChatOutcome.ok(
      text,
      usage: LlmUpstreamUsage.fromBody(protocol, data),
    );
  }

  /// OpenAI finish_reason / Anthropic stop_reason; null when absent.
  static String? stopReason(LlmProtocol protocol, Map data) {
    final raw = switch (protocol) {
      LlmProtocol.openAICompatible => () {
        final choices = data['choices'];
        if (choices is! List || choices.isEmpty || choices.first is! Map) {
          return null;
        }
        return (choices.first as Map)['finish_reason'];
      }(),
      LlmProtocol.anthropicCompatible => data['stop_reason'],
    };
    return raw is String ? raw : null;
  }

  static LlmChatOutcome fromDioError(LlmProtocol protocol, DioException error) {
    final response = error.response;
    if (response == null) {
      final kind = switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => LlmChatFailureKind.timeout,
        DioExceptionType.cancel => LlmChatFailureKind.cancelled,
        _ => LlmChatFailureKind.network,
      };
      return LlmChatOutcome.failed(kind, null);
    }
    return LlmChatOutcome.failed(
      LlmChatFailureKind.httpStatus,
      describeError(protocol, response.statusCode, response.data),
    );
  }

  /// `'HTTP <status>: <message>'` from one error envelope. Both contracts
  /// carry the human-readable text at error.message (issue #114 sections
  /// 2-3): OpenAI {error:{type,code,message,param}}, Anthropic
  /// {type:'error',error:{type,message},request_id}.
  static String? describeError(
    LlmProtocol protocol,
    int? status,
    Object? body,
  ) {
    var message = '';
    if (body is Map && body['error'] is Map) {
      final raw = (body['error'] as Map)['message'];
      if (raw is String) message = raw;
    }
    final detail =
        'HTTP ${status ?? '-'}${message.isEmpty ? '' : ': $message'}';
    return limitRunes(detail, LlmLimits.maxDetailRunes);
  }

  static String limitRunes(String text, int limit) =>
      String.fromCharCodes(text.runes.take(limit));

  static final Dio _dio = Dio();

  static Future<Object?> _dioTransport({
    required String endpoint,
    required Map<String, String> headers,
    required Map<String, Object?> body,
    required Duration timeout,
  }) async {
    final response = await _dio.post<Object?>(
      endpoint,
      data: body,
      options: Options(
        headers: headers,
        sendTimeout: timeout,
        receiveTimeout: timeout,
        followRedirects: false,
        validateStatus: (code) => code != null && code >= 200 && code < 300,
      ),
    );
    return response.data;
  }
}
