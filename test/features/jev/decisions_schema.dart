import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Independent fixture for the published Decisions/System One HTTP contract.
/// Deliberately uses literal wire names rather than production constants.
/// Checks the subset emitted by this app, including explicit yes/no criteria.
bool acceptsDecisionsRequest(Object? value) {
  if (value is! Map || value['model'] is! String || value['state'] is! Map) {
    return false;
  }
  final questions = value['questions'];
  if (questions is! Map || questions.isEmpty) return false;
  for (final entry in questions.entries) {
    final question = entry.value;
    if (entry.key is! String || question is! Map) return false;
    if (question.keys.toSet().difference({
          'type',
          'instructions',
          'criteria',
        }).isNotEmpty ||
        question['type'] != 'noul' ||
        question['instructions'] is! String ||
        (question['instructions'] as String).isEmpty) {
      return false;
    }
    final criteria = question['criteria'];
    if (criteria is! Map ||
        criteria['true'] is! String ||
        criteria['false'] is! String) {
      return false;
    }
  }
  return true;
}

/// Rejects invalid outgoing requests before supplying realistic typed answers.
class DecisionsSchemaAdapter implements HttpClientAdapter {
  DecisionsSchemaAdapter(this.reply);

  final Object? Function(int index) reply;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final index = requests.length;
    requests.add(options);
    final valid = acceptsDecisionsRequest(options.data);
    return ResponseBody.fromString(
      jsonEncode(
        valid
            ? reply(index)
            : {
                'error': {'message': 'Invalid Decisions request schema'},
              },
      ),
      valid ? 200 : 400,
      headers: const {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
