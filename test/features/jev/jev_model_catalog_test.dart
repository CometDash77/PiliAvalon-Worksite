import 'dart:convert';
import 'dart:typed_data';

import 'package:PiliPlus/features/jev/jev.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class CatalogAdapter implements HttpClientAdapter {
  CatalogAdapter(this.body, {this.status = 200});
  Object body;
  int status;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('OpenRouter requests Decisions and filters mixed directory', () async {
    final adapter = CatalogAdapter({
      'data': [
        {
          'id': '~vendor/decision',
          'architecture': {
            'output_modalities': ['decisions'],
          },
        },
        {
          'id': 'vendor/text',
          'architecture': {
            'output_modalities': ['text'],
          },
        },
        {'id': 'vendor/unknown'},
      ],
    });
    final result = await JevModelCatalog(
      dio: Dio()..httpClientAdapter = adapter,
    ).load(provider: JevProvider.openRouter, apiKey: 'synthetic');
    expect(result.models, ['~vendor/decision']);
    expect(
      adapter.requests.single.uri.queryParameters['output_modalities'],
      'decisions',
    );
    expect(adapter.requests.single.uri.host, 'openrouter.ai');
  });
  test(
    'TypeSafe parses its documented models/name response on its own host',
    () async {
      final adapter = CatalogAdapter({
        'models': [
          {'name': 'jev-latest'},
          {'name': 'jev-preview'},
        ],
      });
      final result = await JevModelCatalog(
        dio: Dio()..httpClientAdapter = adapter,
      ).load(provider: JevProvider.typeSafe, apiKey: 'synthetic');
      expect(result.models, ['jev-latest', 'jev-preview']);
      expect(
        adapter.requests.single.uri.toString(),
        'https://api.typesafe.ai/v1/models',
      );
    },
  );
  test(
    'empty, malformed and error catalogs permit retry without exceptions',
    () async {
      final adapter = CatalogAdapter({'data': []});
      final catalog = JevModelCatalog(dio: Dio()..httpClientAdapter = adapter);
      expect(
        (await catalog.load(
          provider: JevProvider.openRouter,
          apiKey: '',
        )).models,
        isEmpty,
      );
      adapter.body = {'unexpected': []};
      expect(
        (await catalog.load(
          provider: JevProvider.openRouter,
          apiKey: '',
        )).error,
        isNotNull,
      );
      adapter.status = 401;
      expect(
        (await catalog.load(
          provider: JevProvider.openRouter,
          apiKey: 'secret',
        )).error,
        isNotNull,
      );
      adapter.status = 200;
      adapter.body = {
        'data': [
          {
            'id': 'recovered',
            'architecture': {
              'output_modalities': ['decisions'],
            },
          },
        ],
      };
      expect(
        (await catalog.load(
          provider: JevProvider.openRouter,
          apiKey: '',
        )).models,
        ['recovered'],
      );
    },
  );
}
