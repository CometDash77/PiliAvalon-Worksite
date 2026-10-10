import 'package:dio/dio.dart';

import 'package:PiliPlus/features/jev/jev_contract.dart';

class JevModelCatalogResult {
  const JevModelCatalogResult(this.models, {this.error});
  final List<String> models;
  final String? error;
}

/// Catalog entries are candidates, never a successful Decisions verification.
class JevModelCatalog {
  JevModelCatalog({Dio? dio}) : _dio = dio ?? Dio();
  final Dio _dio;

  Future<JevModelCatalogResult> load({
    required JevProvider provider,
    required String apiKey,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        provider == JevProvider.openRouter
            ? 'https://openrouter.ai/api/v1/models?output_modalities=decisions'
            : 'https://api.typesafe.ai/v1/models',
        options: Options(
          followRedirects: false,
          headers: {if (apiKey.isNotEmpty) 'authorization': 'Bearer $apiKey'},
          sendTimeout: JevLimits.requestTimeout,
          receiveTimeout: JevLimits.requestTimeout,
        ),
      );
      if ((response.statusCode ?? 0) < 200 ||
          (response.statusCode ?? 0) >= 300) {
        return JevModelCatalogResult(
          const [],
          error: '目录请求失败（HTTP ${response.statusCode}），可重试或手动填写',
        );
      }
      final data = response.data;
      final rows = data is Map
          ? data[provider == JevProvider.openRouter ? 'data' : 'models']
          : null;
      if (rows is! List) {
        return const JevModelCatalogResult([], error: '目录响应无法解析，可重试或手动填写');
      }
      final models = <String>{};
      for (final row in rows) {
        final key = provider == JevProvider.openRouter ? 'id' : 'name';
        if (row is! Map || row[key] is! String) continue;
        if (provider == JevProvider.openRouter) {
          final architecture = row['architecture'];
          final outputs = architecture is Map
              ? architecture['output_modalities']
              : null;
          if (outputs is! List || !outputs.contains('decisions')) continue;
        }
        final id = (row[key] as String).trim();
        if (id.isNotEmpty) models.add(id);
      }
      return JevModelCatalogResult(models.toList()..sort());
    } catch (_) {
      // Do not expose request exceptions containing authorization headers.
      return const JevModelCatalogResult([], error: '目录获取失败，可重试或手动填写；现有配置已保留');
    }
  }
}
