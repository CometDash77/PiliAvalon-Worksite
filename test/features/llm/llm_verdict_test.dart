import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/features/llm/llm.dart';

void main() {
  const known = {'r1', 'r2'};

  LlmVerdict parse(String? text) => LlmVerdictParser.parse(text, known);

  test('non-JSON payloads are invalid', () {
    for (final text in [null, '', 'no braces here', '{"hits":[]', '{oops}']) {
      expect(parse(text).valid, isFalse, reason: 'text: $text');
    }
  });

  test('the top level must be exactly one hits field', () {
    expect(parse('{"hits":[],"x":1}').valid, isFalse);
    expect(parse('{"result":[]}').valid, isFalse);
    expect(parse('{"hits":{}}').valid, isFalse);
    expect(parse('[]').valid, isFalse);
  });

  test('hit entries must be exactly rule_id + reason strings', () {
    final ok = parse('{"hits":[{"rule_id":"r1","reason":"ok"}]}');
    expect(ok.valid, isTrue);
    expect(ok.hits.single.ruleId, 'r1');
    expect(ok.hits.single.reason, 'ok');

    expect(
      parse('{"hits":[{"rule_id":"r1","reason":"ok","extra":1}]}').valid,
      isFalse,
    );
    expect(parse('{"hits":[{"rule_id":"r1"}]}').valid, isFalse);
    expect(parse('{"hits":[{"rule_id":"r1","reason":1}]}').valid, isFalse);
    expect(parse('{"hits":["not a map"]}').valid, isFalse);
  });

  test('unknown ids and blank reasons invalidate the whole response', () {
    for (final payload in [
      '{"hits":[{"rule_id":"ghost","reason":"x"},{"rule_id":"r1","reason":"ok"}]}',
      '{"hits":[{"rule_id":"r1","reason":"  "}]}',
    ]) {
      final v = parse(payload);
      expect(v.valid, isFalse, reason: payload);
      expect(v.hits, isEmpty);
    }
  });

  test('duplicate rule ids invalidate the response', () {
    final v = parse(
      '{"hits":[{"rule_id":"r1","reason":"a"},{"rule_id":"r1","reason":"b"}]}',
    );
    expect(v.valid, isFalse);
    expect(v.hits, isEmpty);
  });

  test('a kept reason is preserved verbatim', () {
    final v = parse('{"hits":[{"rule_id":"r1","reason":" ok "}]}');
    expect(v.valid, isTrue);
    expect(v.hits.single.reason, ' ok ');
  });

  test('reasons are rune-truncated but stay valid', () {
    final reason = '长' * 300;
    final v = parse('{"hits":[{"rule_id":"r1","reason":"$reason"}]}');
    expect(v.valid, isTrue);
    expect(v.hits.single.reason.runes.length, LlmLimits.maxReasonRunes);
  });

  test('prose around JSON is invalid', () {
    expect(parse('判定如下 {"hits":[]}').valid, isFalse);
    expect(parse('{"hits":[]} 以上').valid, isFalse);
  });

  test('multiple hits keep their order', () {
    final v = parse(
      '{"hits":[{"rule_id":"r2","reason":"b"},{"rule_id":"r1","reason":"a"}]}',
    );
    expect(v.hits.map((h) => h.ruleId).toList(), ['r2', 'r1']);
  });

  test('canonical verdict requires a valid qualitative band', () {
    final ok = LlmVerdictParser.parseCanonical(
      '{"hits":[{"rule_id":"r1","reason":"ok","band":"high"}]}',
      known,
    );
    expect(ok.valid, isTrue);
    expect(ok.hits.single.band, LlmConfidenceBand.high);
    expect(
      LlmVerdictParser.parseCanonical(
        '{"hits":[{"rule_id":"r1","reason":"ok"}]}',
        known,
      ).valid,
      isFalse,
    );
  });

  test('an empty hits list is valid and means keep everything', () {
    final v = parse('{"hits":[]}');
    expect(v.valid, isTrue);
    expect(v.hits, isEmpty);
  });
}
