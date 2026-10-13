// ISSUE #68 probe: does a logged-in request surface tag data that the
// anonymous one does not?
//
// Pure Dart (no Flutter imports) so it runs against this checkout without
// building an APK, an emulator, or a proxy with a pinned cert:
//
//   dart run tool/probe/login_field_probe.dart                    # anonymous baseline
//   dart run tool/probe/login_field_probe.dart --sessdata=XXXX     # web groups
//   dart run tool/probe/login_field_probe.dart --cookie="SESSDATA=X; bili_jct=Y"
//   dart run tool/probe/login_field_probe.dart --sessdata=X --access-key=Z --app-sign
//
// Secrets are never printed: only a masked prefix and a length.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

// Mirrors lib/utils/app_sign.dart + lib/common/constants.dart (Android HD appkey).
const String _appKey = 'dfca71928277209b';
const String _appSec = 'b5475a8825547a4fc26c7d518eaaa02e';

// Mirrors lib/common/constants.dart userAgent / statistics.
const String _userAgent =
    'Mozilla/5.0 BiliDroid/2.0.1 (bbcallen@gmail.com) os/android model/android_hd '
    'mobi_app/android_hd build/2001100 channel/master innerVer/2001100 osVer/15 network/2';
const String _statistics =
    '{"appId":5,"platform":3,"version":"2.0.1","abtest":""}';

// Mirrors lib/utils/wbi_sign.dart _mixinKeyEncTab.
const List<int> _mixinKeyEncTab = <int>[
  46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49,
  33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13,
];

const String _webBase = 'https://api.bilibili.com';
const String _appBase = 'https://app.bilibili.com';

Map<String, String> _args = const {};

String mask(String? value) {
  if (value == null || value.isEmpty) return '<absent>';
  final String head = value.length <= 4 ? '****' : value.substring(0, 4);
  return '$head****(len=${value.length})';
}

String getMixinKey(String orig) {
  final List<int> units = orig.codeUnits;
  return String.fromCharCodes(_mixinKeyEncTab.map((int i) => units[i]));
}

void encWbi(Map<String, Object> params, String mixinKey) {
  params['wts'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final List<String> keys = params.keys.toList()..sort();
  final String queryStr = keys
      .map(
        (String i) =>
            '${Uri.encodeComponent(i)}=${Uri.encodeComponent(params[i].toString().replaceAll(RegExp(r"[!'\(\)\*]"), ''))}',
      )
      .join('&');
  params['w_rid'] = md5.convert(utf8.encode(queryStr + mixinKey)).toString();
}

void appSign(Map<String, Object> params) {
  params['appkey'] = _appKey;
  params['ts'] = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
  final List<MapEntry<String, Object>> sorted = params.entries.toList()
    ..sort((MapEntry<String, Object> a, MapEntry<String, Object> b) =>
        a.key.compareTo(b.key));
  final String query = sorted
      .map((MapEntry<String, Object> e) =>
          '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
      .join('&');
  params['sign'] = md5.convert(utf8.encode(query + _appSec)).toString();
}

class Probe {
  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20);

  static Future<Map<String, dynamic>> get(
    String url,
    Map<String, String> query, {
    Map<String, String>? headers,
  }) =>
      getRaw(Uri.parse(url).replace(queryParameters: query).toString(),
          headers: headers);

  // Raw variant: a Map<String,String> cannot carry a repeated parameter, and the
  // whole point of G3 is to send `bvid=A&bvid=B` verbatim.
  static Future<Map<String, dynamic>> getRaw(
    String rawUrl, {
    Map<String, String>? headers,
  }) async {
    final Uri uri = Uri.parse(rawUrl);
    final HttpClientRequest req = await _client.getUrl(uri);
    req.headers.set(HttpHeaders.userAgentHeader, _userAgent);
    headers?.forEach(req.headers.set);
    final HttpClientResponse res = await req.close();
    final String body = await res.transform(utf8.decoder).join();
    Map<String, dynamic> json;
    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      json = <String, dynamic>{'code': 'non-json', 'raw': body.length};
    }
    return <String, dynamic>{
      'status': res.statusCode,
      'bytes': body.length,
      'json': json,
    };
  }
}

List<String> itemKeys(Object? item) {
  if (item is Map) return item.keys.map((Object? k) => '$k').toList();
  return const <String>[];
}

int countOf(String haystack, String needle) =>
    needle.allMatches(haystack).length;

void reportFields(String label, Map<String, dynamic> res) {
  final Map<String, dynamic> json = res['json'] as Map<String, dynamic>;
  final String raw = jsonEncode(json);
  stdout.writeln('$label.status=${res['status']} bytes=${res['bytes']} '
      'code=${json['code']}');
  stdout.writeln('$label.hits: "tag=${countOf(raw, '"tag')} '
      '"tags=${countOf(raw, '"tags')} '
      '"tname=${countOf(raw, '"tname')} '
      '"tag_name=${countOf(raw, '"tag_name')}');
}

List<Object?> itemsOf(Map<String, dynamic> json) {
  final Object? data = json['data'];
  if (data is Map) {
    final Object? items = data['items'];
    if (items is List) return items as List<Object?>;
    // anonymous web rcmd answers with a single `item`
    final Object? item = data['item'];
    if (item is Map) return <Object?>[item];
    if (item is List) return item as List<Object?>;
  }
  return const <Object?>[];
}

// Web items carry bvid directly; app items only carry args.aid, so resolve it.
Future<String?> bvidOf(Object? item, String? cookie) async {
  if (item is! Map) return null;
  final Object? direct = item['bvid'];
  if (direct is String && direct.isNotEmpty) return direct;
  final Object? args = item['args'];
  final Object? aid = args is Map ? args['aid'] : null;
  if (aid == null) return null;
  final Map<String, dynamic> res = await Probe.get(
    '$_webBase/x/web-interface/view',
    <String, String>{'aid': '$aid'},
    headers: cookie == null ? null : <String, String>{'Cookie': cookie},
  );
  final Map<String, dynamic> json = res['json'] as Map<String, dynamic>;
  final Object? data = json['data'];
  final Object? bvid = data is Map ? data['bvid'] : null;
  return bvid is String ? bvid : null;
}

Future<List<String>> tagsOf(String bvid, String? cookie) async {
  final Map<String, dynamic> res = await Probe.get(
    '$_webBase/x/web-interface/view/detail/tag',
    <String, String>{'bvid': bvid},
    headers: cookie == null ? null : <String, String>{'Cookie': cookie},
  );
  final Map<String, dynamic> json = res['json'] as Map<String, dynamic>;
  final Object? data = json['data'];
  if (json['code'] == 0 && data is List) {
    return data
        .map((Object? e) =>
            e is Map ? '${e['tag_name']}' : '$e')
        .toList()
      ..sort();
  }
  return <String>['<code=${json['code']}>'];
}

Future<void> main(List<String> argv) async {
  _args = <String, String>{};
  for (final String a in argv) {
    if (!a.startsWith('--')) continue;
    final int eq = a.indexOf('=');
    if (eq < 0) {
      _args[a.substring(2)] = 'true';
    } else {
      _args[a.substring(2, eq)] = a.substring(eq + 1);
    }
  }

  final String? sessdata = _args['sessdata'];
  final String? accessKey = _args['access-key'];
  final bool wantAppSign = _args.containsKey('app-sign');
  final String? cookie = _args['cookie'] ??
      (sessdata == null ? null : 'SESSDATA=$sessdata');

  stdout.writeln('== login_field_probe (issue #68) ==');
  stdout.writeln('cookie=${cookie == null ? '<absent: anonymous run>' : mask(cookie)}');
  stdout.writeln('access_key=${mask(accessKey)} app_sign=$wantAppSign');
  stdout.writeln('');

  // ---- group 0: identity + wbi keys -------------------------------------
  stdout.writeln('-- G0 nav (identity / wbi keys) --');
  final Map<String, dynamic> nav = await Probe.get(
    '$_webBase/x/web-interface/nav',
    const <String, String>{},
    headers: cookie == null ? null : <String, String>{'Cookie': cookie},
  );
  final Map<String, dynamic> navJson = nav['json'] as Map<String, dynamic>;
  final Object? navData = navJson['data'];
  String? mixinKey;
  stdout.writeln('nav.code=${navJson['code']} bytes=${nav['bytes']}');
  if (navData is Map) {
    stdout.writeln('nav.isLogin=${navData['isLogin']} '
        'uname=${mask(navData['uname'] as String?)}');
    final Object? wbi = navData['wbi_img'];
    if (wbi is Map && wbi['img_url'] != null && wbi['sub_url'] != null) {
      String stem(Object? url) =>
          Uri.parse('$url').pathSegments.last.split('.').first;
      mixinKey = getMixinKey('${stem(wbi['img_url'])}${stem(wbi['sub_url'])}');
      stdout.writeln('nav.wbi_img=present mixin_key=${mask(mixinKey)}');
    } else {
      stdout.writeln('nav.wbi_img=<absent>');
    }
  }
  stdout.writeln('');

  // ---- group 1: web rcmd -------------------------------------------------
  stdout.writeln('-- G1 web rcmd (/x/web-interface/wbi/index/top/feed/rcmd) --');
  final Map<String, Object> webParams = <String, Object>{
    // mirrors lib/http/video.dart:63-71 (rcmdVideoList)
    'version': 1,
    'feed_version': 'V8',
    'homepage_ver': 1,
    'ps': 20,
    'fresh_idx': 1,
    'brush': 1,
    'fresh_type': 4,
  };
  final bool signed = mixinKey != null;
  if (signed) encWbi(webParams, mixinKey);
  stdout.writeln('G1.wbi_signed=$signed');
  final Map<String, dynamic> g1 = await Probe.get(
    '$_webBase/x/web-interface/wbi/index/top/feed/rcmd',
    webParams.map((String k, Object v) =>
        MapEntry<String, String>(k, v.toString())),
    headers: cookie == null ? null : <String, String>{'Cookie': cookie},
  );
  reportFields('G1', g1);
  final List<Object?> g1Items = itemsOf(g1['json'] as Map<String, dynamic>);
  stdout.writeln('G1.items=${g1Items.length} '
      'keys=${itemKeys(g1Items.isEmpty ? null : g1Items.first)}');
  if (g1Items.isEmpty) {
    final Object? data = (g1['json'] as Map<String, dynamic>)['data'];
    stdout.writeln('G1.data_keys='
        '${data is Map ? data.keys.toList() : '<${data.runtimeType}>'}');
  }
  stdout.writeln('');

  // ---- group 2: app feed -------------------------------------------------
  stdout.writeln('-- G2 app feed (/x/v2/feed/index) --');
  final Map<String, Object> appParams = <String, Object>{
    'build': 2001100,
    'c_locale': 'zh_CN',
    'channel': 'master',
    'column': 4,
    'device': 'pad',
    'device_name': 'android',
    'device_type': 0,
    'disable_rcmd': 0,
    'flush': 5,
    'fnval': 976,
    'fnver': 0,
    'force_host': 2,
    'fourk': 1,
    'guidance': 0,
    'https_url_req': 0,
    'idx': 0,
    'mobi_app': 'android_hd',
    'network': 'wifi',
    'platform': 'android',
    'player_net': 1,
    'pull': 'true',
    'qn': 32,
    'recsys_mode': 0,
    's_locale': 'zh_CN',
    'splash_id': '',
    'statistics': _statistics,
    'voice_balance': 0,
  };
  if (accessKey != null) appParams['access_key'] = accessKey;
  if (wantAppSign) appSign(appParams);
  final Map<String, String> appHeaders = <String, String>{
    'app-key': 'android_hd',
    'env': 'prod',
    'bili-http-engine': 'cronet',
    if (cookie != null) 'Cookie': cookie,
  };
  final Map<String, dynamic> g2 = await Probe.get(
    '$_appBase/x/v2/feed/index',
    appParams.map((String k, Object v) =>
        MapEntry<String, String>(k, v.toString())),
    headers: appHeaders,
  );
  reportFields('G2', g2);
  final List<Object?> g2Items = itemsOf(g2['json'] as Map<String, dynamic>);
  stdout.writeln('G2.items=${g2Items.length} '
      'keys=${itemKeys(g2Items.isEmpty ? null : g2Items.first)}');
  if (g2Items.isNotEmpty && g2Items.first is Map) {
    final Object? args = (g2Items.first as Map)['args'];
    if (args is Map) stdout.writeln('G2.item0.args.keys=${args.keys.toList()}');
  }
  stdout.writeln('');

  // ---- group 3: tag endpoint batch behaviour ----------------------------
  stdout.writeln('-- G3 tag endpoint batch behaviour (/x/web-interface/view/detail/tag) --');
  String? bvidA = _args['a'];
  String? bvidB = _args['b'];
  for (final List<Object?> items in <List<Object?>>[g1Items, g2Items]) {
    for (final Object? item in items) {
      final String? bvid = await bvidOf(item, cookie);
      if (bvid == null) continue;
      bvidA ??= bvid;
      if (bvidA != bvid && bvidB == null) bvidB = bvid;
    }
    if (bvidA != null && bvidB != null) break;
  }
  if (bvidA == null || bvidB == null) {
    stdout.writeln('G3.skipped=<need two bvids: pass --a= --b= or reach the feed>');
    stdout.writeln('');
  } else {
    stdout.writeln('G3.bvidA=$bvidA bvidB=$bvidB');
    final List<String> setA = await tagsOf(bvidA, cookie);
    final List<String> setB = await tagsOf(bvidB, cookie);
    stdout.writeln('G3.single(A).n=${setA.length} tags=$setA');
    stdout.writeln('G3.single(B).n=${setB.length} tags=$setB');
    final List<List<String>> variants = <List<String>>[
      <String>['A,B (raw repeat param, A first)', '$_webBase/x/web-interface/view/detail/tag?bvid=$bvidA&bvid=$bvidB', 'bvidA'],
      <String>['B,A (raw repeat param, reversed)', '$_webBase/x/web-interface/view/detail/tag?bvid=$bvidB&bvid=$bvidA', 'bvidB'],
      <String>['A,B (comma joined, raw)', '$_webBase/x/web-interface/view/detail/tag?bvid=$bvidA,$bvidB', '?'],
      <String>['A,B (comma joined, %2C)', '$_webBase/x/web-interface/view/detail/tag?bvid=$bvidA%2C$bvidB', '?'],
    ];
    for (final List<String> v in variants) {
      final Map<String, dynamic> res =
          await Probe.getRaw(v[1], headers: cookie == null ? null : <String, String>{'Cookie': cookie});
      final Map<String, dynamic> json = res['json'] as Map<String, dynamic>;
      final Object? data = json['data'];
      final List<String> got = json['code'] == 0 && data is List
          ? (data
              .map((Object? e) => e is Map ? '${e['tag_name']}' : '$e')
              .toList()
            ..sort())
          : <String>['<code=${json['code']}>'];
      String match = 'other';
      if (_listEq(got, setA)) {
        match = 'A';
      } else if (_listEq(got, setB)) {
        match = 'B';
      }
      stdout.writeln('G3[${v[0]}] -> code=${json['code']} n=${got.length} '
          'match=$match tags=$got');
      stdout.writeln('G3[${v[0]}].url=${v[1]}');
    }
    final Map<String, dynamic> detail = await Probe.get(
      '$_webBase/x/web-interface/view/detail',
      <String, String>{'bvid': bvidA},
      headers: cookie == null ? null : <String, String>{'Cookie': cookie},
    );
    final Map<String, dynamic> detailJson = detail['json'] as Map<String, dynamic>;
    final Object? detailData = detailJson['data'];
    Object? detailTags;
    if (detailData is Map) detailTags = detailData['Tags'];
    stdout.writeln('G3[view/detail bvidA] -> code=${detailJson['code']} '
        'Tags=${detailTags is List ? 'n=${detailTags.length}' : '<absent>'}');
    stdout.writeln('');
  }

  stdout.writeln('-- verdict inputs (paste into the issue) --');
  stdout.writeln('login_state=${navData is Map ? navData['isLogin'] : '<unknown>'}');
  stdout.writeln('G1_tag_hits=${countOf(jsonEncode(g1['json']), '"tag')}');
  stdout.writeln('G2_tag_hits=${countOf(jsonEncode(g2['json']), '"tag')}');
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
