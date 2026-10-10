import 'package:material_ui/material_ui.dart';

/// A hidden source page is not the end of the thread.
class FilteredCommentsContinuation extends StatefulWidget {
  const FilteredCommentsContinuation({super.key, required this.onLoadMore});
  final Future<void> Function() onLoadMore;
  @override
  State<FilteredCommentsContinuation> createState() =>
      _FilteredCommentsContinuationState();
}

class _FilteredCommentsContinuationState
    extends State<FilteredCommentsContinuation> {
  bool _loading = false;
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await widget.onLoadMore();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const Text('当前页没有可见评论，后面可能还有评论。'),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _loading ? null : _load,
          child: Text(_loading ? '加载中…' : '加载下一页'),
        ),
      ],
    ),
  );
}
