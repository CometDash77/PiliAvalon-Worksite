import 'package:PiliPlus/features/llm/llm_contract.dart';
import 'package:PiliPlus/features/llm/llm_provider_presets.dart';
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
        options: _options(config, apiKey),
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
        options: _options(config, apiKey),
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

  /// Issue #145: 按提供方预设的目录形态获取模型目录。
  ///
  /// openaiData = 单页 data[].id（复用 [_parseIds]）；dashscopePages = 按
  /// page_no 翻页直至 total 覆盖或页面无新条目，同样受
  /// [LlmLimits.maxCatalogModels] 上限约束；none 形态不发请求，直接给出
  /// catalogUnavailable 提示。鉴权头按 [resolved.authHeaders] 发送，与探活
  /// 完全一致；请求路线只影响鉴权头，不影响目录端点。
  Future<LlmModelCatalogResult> loadResolved({
    required LlmResolvedProvider resolved,
    required String apiKey,
  }) async {
    final preset = resolved.preset;
    if (!preset.hasCatalog) {
      return const LlmModelCatalogResult(
        [],
        error: '该提供方没有可用的模型目录，请手动填写模型或改用其 OpenAI 兼容地址',
      );
    }
    final endpoint = resolved.catalogEndpoint;
    if (endpoint == null) {
      return const LlmModelCatalogResult(
        [],
        error: '目录地址无效，请检查服务地址',
      );
    }
    final options = Options(
      followRedirects: false,
      headers: <String, String>{
        if (apiKey.isNotEmpty) ...resolved.authHeaders(apiKey),
      },
      sendTimeout: LlmLimits.requestTimeout,
      receiveTimeout: LlmLimits.requestTimeout,
    );
    try {
      switch (preset.catalogShape) {
        case LlmCatalogShape.openaiData:
          final response = await _dio.get<Object?>(endpoint, options: options);
          final status = response.statusCode ?? 0;
          if (status < 200 || status >= 300) {
            return LlmModelCatalogResult(
              const [],
              error: '目录请求失败（HTTP $status），可重试或手动填写',
            );
          }
          return _pageResult(response.data);
        case LlmCatalogShape.dashscopePages:
          final models = <String>{};
          var pageNo = 1;
          while (models.length < LlmLimits.maxCatalogModels) {
            final response = await _dio.get<Object?>(
              endpoint,
              queryParameters: <String, Object?>{
                'page_no': pageNo,
                'page_size': 100,
              },
              options: options,
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
            final before = models.length;
            models.addAll(page);
            final total = data['total'];
            if (page.isEmpty ||
                models.length == before ||
                (total is num && models.length >= total)) {
              break;
            }
            pageNo++;
          }
          return LlmModelCatalogResult(models.toList()..sort());
        case LlmCatalogShape.none:
          return const LlmModelCatalogResult(
            [],
            error: '该提供方没有可用的模型目录，请手动填写模型或改用其 OpenAI 兼容地址',
          );
      }
    } catch (_) {
      // Do not expose request exceptions containing authorization headers.
      return const LlmModelCatalogResult(
        [],
        error: '目录获取失败，可重试或手动填写；现有配置已保留',
      );
    }
  }

  LlmModelCatalogResult _pageResult(Object? data) {
    final models = _parseIds(data);
    if (models == null) {
      return const LlmModelCatalogResult(
        [],
        error: '目录响应无法解析，可重试或手动填写',
      );
    }
    return LlmModelCatalogResult(models);
  }

  Options _options(LlmProviderConfig config, String apiKey) => Options(
    followRedirects: false,
    headers: <String, String>{
      if (apiKey.isNotEmpty) ...config.authHeaders(apiKey),
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
