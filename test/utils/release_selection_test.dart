import 'package:PiliPlus/utils/release_selection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('skips drafts and prereleases before selecting a stable release', () {
    final stable = <String, dynamic>{
      'tag_name': 'v2.0.9+5218',
      'draft': false,
      'prerelease': false,
    };
    expect(
      latestStableRelease([
        {'draft': true, 'prerelease': false},
        {'draft': false, 'prerelease': true},
        stable,
        {'tag_name': 'older', 'draft': false, 'prerelease': false},
      ]),
      same(stable),
    );
  });

  test('returns no release for an empty response or only test builds', () {
    expect(latestStableRelease([]), isNull);
    expect(
      latestStableRelease([
        {'draft': true, 'prerelease': false},
        {'draft': false, 'prerelease': true},
      ]),
      isNull,
    );
  });

  test('does not treat malformed entries as a published stable release', () {
    expect(latestStableRelease([null, 'invalid', {}, {'draft': false}]), isNull);
  });
}
