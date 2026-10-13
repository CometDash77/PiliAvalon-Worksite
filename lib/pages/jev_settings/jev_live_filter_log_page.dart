import 'package:PiliPlus/common/widgets/flutter/list_tile.dart' as custom;
import 'package:PiliPlus/features/jev/jev.dart';
import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;

String _fmtTime(int epochMs) {
  final t = DateTime.fromMillisecondsSinceEpoch(epochMs);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.month}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}:${two(
    t.second,
  )}';
}

String _fmtScore(double? value) => value == null ? '—' : value.toStringAsFixed(2);

/// 直播 Jev 筛除记录页（issue #115）：本机最近 500 条真实直播筛除，
/// 可清空。数值/规则缺失时如实说明，不编造。
class JevLiveFilterLogPage extends StatefulWidget {
  const JevLiveFilterLogPage({super.key, this.log});

  final JevFilterLog? log;

  @override
  State<JevLiveFilterLogPage> createState() => _JevLiveFilterLogPageState();
}

class _JevLiveFilterLogPageState extends State<JevLiveFilterLogPage> {
  late final JevFilterLog _log = widget.log ?? JevFilterLog.live;
  List<JevFilterLogEntry> _entries = const [];
  Map<String, String> _ruleQuestions = const {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _entries = _log.load());
    _loadRuleQuestions();
  }

  Future<void> _loadRuleQuestions() async {
    try {
      final config = await JevRuleStore().load();
      final questions = <String, String>{
        for (final rule in config.rules) rule.id: rule.question,
      };
      if (mounted) setState(() => _ruleQuestions = questions);
    } catch (_) {
      // 规则读取失败时只显示规则标识本身。
    }
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空直播筛除记录'),
        content: const Text('将删除全部直播筛除记录，不影响任何筛选设置。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _log.clear();
      if (mounted) _reload();
    }
  }

  List<String> _lines(JevFilterLogEntry e) => [
    '时间：${_fmtTime(e.time)}',
    if (e.snippet != null && e.snippet!.isNotEmpty)
      '主题：${e.snippet!}'
    else if (e.tags.isNotEmpty)
      '主题：${e.tags.join('、')}'
    else
      '主题：候选未提供',
    if (e.noul != null || e.confidence != null || e.threshold != null)
      [
        if (e.noul != null) 'noul=${_fmtScore(e.noul)}',
        if (e.confidence != null) '置信度=${_fmtScore(e.confidence)}',
        if (e.threshold != null) '阈值=${_fmtScore(e.threshold)}',
      ].join('·'),
    if (e.noul == null && e.confidence == null && e.threshold == null)
      '本次数值未记录（命中本地判定缓存或为复合判定）',
    if (e.ruleId != null)
      '规则：${_ruleQuestions[e.ruleId] ?? e.ruleId}',
    if (e.ruleId == null && e.reason == null) '内置阈值筛除',
    if (e.reason != null) '原因：${e.reason!}',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('直播筛除记录'),
        actions: [
          IconButton(
            tooltip: '清空',
            onPressed: _entries.isEmpty ? null : _confirmClear,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: _entries.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                '暂无真实直播筛除记录。只有直播推荐列表被 Jev 筛除时才产生记录；'
                '连接验证与测试不会写入。',
              ),
            )
          : ListView(
              children: [
                for (final entry in _entries)
                  custom.ListTile(
                    title: Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _lines(entry).join('\n'),
                      maxLines: 7,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Text(
                    '记录只保存在本机设置存储，不含账号信息与密钥；'
                    '重启后保留最新 500 条。',
                  ),
                ),
              ],
            ),
    );
  }
}
