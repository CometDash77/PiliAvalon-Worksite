import 'package:PiliPlus/common/widgets/flutter/list_tile.dart' as custom;
import 'package:PiliPlus/features/jev/jev_contract.dart';
import 'package:PiliPlus/features/jev/jev_screen_log.dart';
import 'package:PiliPlus/utils/share_utils.dart';
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
  return '${t.month}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}:${two(
    t.second,
  )}';
}

/// 被屏蔽条目的本地诊断视图,分「视频」「评论」两个题头展示。
class JevScreenLogPage extends StatefulWidget {
  const JevScreenLogPage({super.key, this.log});

  final JevScreenLog? log;

  @override
  State<JevScreenLogPage> createState() => _JevScreenLogPageState();
}

class _JevScreenLogPageState extends State<JevScreenLogPage> {
  late final JevScreenLog _log = widget.log ?? JevScreenLog.instance;
  List<JevScreenLogEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _entries = _log.load());
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空筛选日志'),
        content: const Text('将删除全部被屏蔽记录,不影响任何筛选设置。'),
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

  List<Widget> _section(String title, List<JevScreenLogEntry> items) => [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    ),
    if (items.isEmpty)
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text('暂无记录。开箱后没有条目被屏蔽,或筛选开关/凭据尚未生效。'),
      ),
    for (final entry in items)
      custom.ListTile(
        title: Text(
          entry.title.isEmpty ? '通用线失败' : entry.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            '${_surfaceLabel(entry.surface)} · ${_fmtTime(entry.time)}',
            if (entry.snippet != null && entry.snippet!.isNotEmpty)
              '上下文:${entry.snippet!}',
            if (entry.modelId != null) '模型:${entry.modelId!}',
            if (entry.reason != null && entry.reason!.isNotEmpty)
              '理由:${entry.reason!}',
            if (entry.failure != null) '失败:${entry.failure!}',
            if (entry.llmInputTokens != null ||
                entry.llmCacheHitTokens != null ||
                entry.llmCacheMissTokens != null)
              'Tokens:输入 ${entry.llmInputTokens ?? '-'} · '
                  '缓存命中 ${entry.llmCacheHitTokens ?? '-'} · '
                  '未命中 ${entry.llmCacheMissTokens ?? '-'}',
          ].join('\n'),
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
        ),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final videos = [
      for (final entry in _entries)
        if (entry.kind == JevScreenLogKind.video) entry,
    ];
    final comments = [
      for (final entry in _entries)
        if (entry.kind == JevScreenLogKind.comment) entry,
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jev 筛选日志'),
        actions: [
          IconButton(
            tooltip: '导出 JSON',
            onPressed: _entries.isEmpty
                ? null
                : () => ShareUtils.shareText(JevScreenLog.exportJson(_entries)),
            icon: const Icon(Icons.ios_share),
          ),
          IconButton(
            tooltip: '清空',
            onPressed: _entries.isEmpty ? null : _confirmClear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        children: [
          ..._section('被屏蔽的视频', videos),
          const Divider(height: 1),
          ..._section('被屏蔽的评论', comments),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
