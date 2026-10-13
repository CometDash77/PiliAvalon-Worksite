import 'package:PiliPlus/common/widgets/flutter/list_tile.dart' as custom;
import 'package:PiliPlus/features/jev/jev.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;

String _surfaceLabel(String id) {
  for (final surface in JevSurface.values) {
    if (surface.id == id) return surface.label;
  }
  return id;
}

String _fmtTime(int epochMs) {
  final t = DateTime.fromMillisecondsSinceEpoch(epochMs);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.month}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

String _fmtScore(double? value) => value == null ? '—' : value.toStringAsFixed(2);

/// 最近 5 条真实 Jev 筛除记录(issue #105)。只展示真实推荐列表被
/// 筛除的候选;判定数值缺失(命中本地判定缓存)时如实说明。
class JevFilterLogSection extends StatefulWidget {
  const JevFilterLogSection({super.key, this.log});

  final JevFilterLog? log;

  @override
  State<JevFilterLogSection> createState() => _JevFilterLogSectionState();
}

class _JevFilterLogSectionState extends State<JevFilterLogSection> {
  late final JevFilterLog _log = widget.log ?? JevFilterLog.instance;
  List<JevFilterLogEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _reload();
    JevFilterLog.revision.addListener(_onRevision);
  }

  @override
  void dispose() {
    JevFilterLog.revision.removeListener(_onRevision);
    super.dispose();
  }

  void _onRevision() {
    if (mounted) _reload();
  }

  void _reload() {
    setState(() => _entries = _log.load());
  }

  List<String> _lines(JevFilterLogEntry e) => [
    '${_surfaceLabel(e.surface)} · ${_fmtTime(e.time)}',
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
      '本次数值未记录（命中本地判定缓存）',
    e.ruleId == null
        ? '达到筛除阈值；上游未提供具体原因'
        : '命中规则「${e.ruleId}」；上游未提供具体原因',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            '最近 Jev 筛除（真实推荐过滤，最新 5 条）',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (_entries.isEmpty)
          const custom.ListTile(
            title: Text('暂无真实过滤记录'),
            subtitle: Text(
              '只有真实推荐列表被 Jev 筛除时才产生记录；连接验证与测试不会写入。',
            ),
          )
        else
          for (final entry in _entries)
            custom.ListTile(
              title: Text(
                entry.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _lines(entry).join('\n'),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Text(
            '记录只保存在本机设置存储，不含账号信息；重启后保留最新 5 条。',
          ),
        ),
      ],
    );
  }
}