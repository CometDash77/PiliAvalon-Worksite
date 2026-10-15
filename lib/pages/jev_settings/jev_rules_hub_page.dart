import 'package:PiliPlus/features/jev/jev_rules.dart';
import 'package:PiliPlus/pages/jev_settings/jev_rules_page.dart';
import 'package:PiliPlus/pages/jev_settings/llm_video_rules_page.dart';
import 'package:material_ui/material_ui.dart';

/// Single settings entry for all screening rules; scene-specific editors stay
/// separate so each editor can keep its existing validation and storage flow.
class JevRulesHubPage extends StatelessWidget {
  const JevRulesHubPage({super.key, this.store});

  final JevRuleStore? store;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('判断规则')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('按场景管理同一份筛选规则；规则保存在本机，编辑不会发起模型请求。'),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.tune_outlined),
              title: const Text('场景判断规则'),
              subtitle: const Text('视频、评论、直播间的结构化问题、答案和阈值'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => JevRulesPage(store: store),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: const Text('视频文本规则'),
              subtitle: const Text('通用模型按自然语言描述筛选视频，命中即屏蔽'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => LlmVideoRulesPage(store: store),
                ),
              ),
            ),
          ],
        ),
      );
}
