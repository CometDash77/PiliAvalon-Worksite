import 'package:PiliPlus/features/llm/llm_contract.dart';
import 'package:PiliPlus/features/llm/llm_settings.dart';
import 'package:dio/dio.dart';

class LlmModelCatalogResult {
  const LlmModelCatalogResult(this.models, {this.error});
  final List<String> models;
  final String? error;
}

// Model catalog for the generic line (spec 1).
//
// Entries are candidates, never proof of a callable service: catalog success
// does not imply callable, and callable does not imply filtering.
// OpenAI-compatible services answer one page of data[].id; Anthropic-compatible
// services paginate with has_more / first_id / last_id and the loop is capped.
class LlmModelCatalog {
  LlmModelCatalog({Dio? dio}) : _dio = dio ?? Dio();
  final Dio _dio;

  Future<LlmModelCatalogResult> load({
    required LlmProviderConfig config,
    required String apiKey,
  }) async {
    // The catalog does not need a model choice; every other structural gap
    // blocks the request before it leaves the device.
    for (final issue in config.issues) {
      if (issue != LlmConfigIssue.missingModel) {
        return LlmModelCatalogResult(const [], error: issue.message);
      }
    }
    final protocol = config.protocol!;
    try {
      if (protocol == LlmProtocol.anthropicCompatible) {
        return await _loadAnthropic(config: config, apiKey: apiKey);
      }
      final response = await _dio.get<Object?>(
        config.catalogEndpoint!,
        options: _options(protocol, apiKey),
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        return LlmModelCatalogResult(
          const [],
          error: '目录请求失败（HTTP $status），可重试或手动填写',
        );
      }
      final models = _parseIds(response.data);
      if (models == null) {
        return const LlmModelCatalogResult(
          [],
          error: '目录响应无法解析，可重试或手动填写',
        );
      }
      return LlmModelCatalogResult(models);
    } catch (_) {
      // Do not expose request exceptions containing authorization headers.
      return const LlmModelCatalogResult(
        [],
        error: '目录获取失败，可重试或手动填写；现有配置已保留',
      );
    }
  }

  Future<LlmModelCatalogResult> _loadAnthropic({
    required LlmProviderConfig config,
    required String apiKey,
  }) async {
    final models = <String>{};
    String? after;
    while (models.length < LlmLimits.maxCatalogModels) {
      final response = await _dio.get<Object?>(
        config.catalogEndpoint!,
        queryParameters: <String, Object?>{
          'limit': LlmLimits.maxCatalogModels,
          'after': ?after,
        },
        options: _options(config.protocol!, apiKey),
      );
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        return LlmModelCatalogResult(
          const [],
          error: '目录请求失败（HTTP $status），可重试或手动填写',
        );
      }
      final data = response.data;
      if (data is! Map) {
        return const LlmModelCatalogResult(
          [],
          error: '目录响应无法解析，可重试或手动填写',
        );
      }
      final page = _parseIds(data);
      if (page == null) {
        return const LlmModelCatalogResult(
          [],
          error: '目录响应无法解析，可重试或手动填写',
        );
      }
      models.addAll(page);
      if (data['has_more'] != true) break;
      final lastId = data['last_id'];
      if (lastId is! String || lastId.isEmpty) break;
      after = lastId;
    }
    return LlmModelCatalogResult(models.toList()..sort());
  }

  Options _options(LlmProtocol protocol, String apiKey) => Options(
    followRedirects: false,
    headers: <String, String>{
      if (apiKey.isNotEmpty) ...protocol.authHeaders(apiKey),
    },
    sendTimeout: LlmLimits.requestTimeout,
    receiveTimeout: LlmLimits.requestTimeout,
  );

  // Accepts data (documented by both protocols) and models (seen on sloppy
  // compatible servers); anything else is unparseable.
  static List<String>? _parseIds(Object? data) {
    if (data is! Map) return null;
    final rows = data['data'] ?? data['models'];
    if (rows is! List) return null;
    final models = <String>{};
    for (final row in rows) {
      if (row is! Map) continue;
      final id = row['id'];
      if (id is! String) continue;
      final trimmed = id.trim();
      if (trimmed.isNotEmpty) models.add(trimmed);
    }
    return models.toList()..sort();
  }
}
