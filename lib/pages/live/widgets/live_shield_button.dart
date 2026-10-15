import 'package:PiliPlus/features/shielding/live_shielding.dart';
import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/models_new/live/live_feed_index/card_data_list_item.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

/// Shield entry shown on every card of the standalone live recommendation page.
///
/// It stays separate from the room entry tap and from the long press cover
/// save: one tap offers the two stable identities of the card, and picking one
/// saves the rule directly, with no confirmation step.
class LiveShieldButton extends StatelessWidget {
  const LiveShieldButton({
    super.key,
    required this.item,
    this.store,
    this.onRuleChanged,
  });

  final CardLiveItem item;

  /// Injectable store, used by tests; production saves through the default one.
  final ShieldSettingsStore? store;

  /// Called after a save that must drop the newly matching cards from the
  /// already loaded page. Duplicate rules still report, so the card goes away.
  final VoidCallback? onRuleChanged;

  @override
  Widget build(BuildContext context) {
    final targets = LiveShielding.targetsFor(item);
    if (targets.isEmpty) return const SizedBox.shrink();
    return Material(
      color: Colors.black38,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _selectTarget(context, targets),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.block, size: 14, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _selectTarget(
    BuildContext context,
    List<LiveShieldTarget> targets,
  ) async {
    final selected = await showModalBottomSheet<LiveShieldTarget>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final target in targets)
              ListTile(
                dense: true,
                leading: Icon(_targetIcon(target)),
                title: Text('屏蔽${LiveShielding.targetLabel(target)}'),
                subtitle: Text(LiveShielding.labelFor(item, target)),
                onTap: () => Navigator.of(sheetContext).pop(target),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    final result = await LiveShielding.applyQuickAction(
      card: item,
      target: selected,
      store: store,
    );
    SmartDialog.showToast(result.message);
    if (result.refiltersCurrentPage) onRuleChanged?.call();
  }

  IconData _targetIcon(LiveShieldTarget target) => switch (target) {
    LiveShieldTarget.host => Icons.person_off_outlined,
    LiveShieldTarget.room => Icons.meeting_room_outlined,
  };
}
