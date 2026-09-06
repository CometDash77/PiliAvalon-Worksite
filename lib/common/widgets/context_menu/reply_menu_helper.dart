part of 'package:PiliPlus/pages/video/reply/widgets/reply_item_grpc.dart';

void showReplyCopyDialog(
  BuildContext context,
  String message,
  Map<String, Emote> emotes, {
  ShieldSettingsStore? shieldSettingsStore,
}) {
  bool showEmote = false;
  showDialog(
    context: context,
    builder: (context) => Dialog(
      constraints: const BoxConstraints.tightFor(width: 380),
      child: Padding(
        padding: const .symmetric(horizontal: 20, vertical: 16),
        child: SelectionArea(
          contextMenuBuilder: (_, state) {
            final buttonItems = state.contextMenuButtonItems;
            if (emotes.isNotEmpty) {
              buttonItems.insertOrAdd(
                3,
                ContextMenuButtonItem(
                  label: showEmote ? '文本' : '表情',
                  onPressed: () {
                    state.hideAndClear();
                    showEmote = !showEmote;
                    (context as Element).markNeedsBuild();
                  },
                ),
              );
            }
            state.addLaunchMenuIfNeeded(buttonItems, index: 4);
            if (state.isUncollapsed) {
              buttonItems.add(
                ContextMenuButtonItem(
                  onPressed: () {
                    final selectedText = state.selectedText;
                    if (selectedText == null || selectedText.trim().isEmpty) {
                      return;
                    }
                    state.hideAndClear();
                    showConfirmDialog(
                      context: context,
                      title: const Text('是否加入评论屏蔽规则：'),
                      content: Text('屏蔽评论关键词「$selectedText」'),
                      onConfirm: () async {
                        await ReplyItemGrpc._addCommentQuickActionRule(
                          type: ShieldRuleType.keyword,
                          pattern: selectedText,
                          targetLabel: '屏蔽评论关键词「$selectedText」',
                          store: shieldSettingsStore,
                        );
                      },
                    );
                  },
                  label: '加入过滤',
                ),
              );
            }
            return AdaptiveTextSelectionToolbar.buttonItems(
              buttonItems: buttonItems,
              anchors: state.contextMenuAnchors,
            );
          },
          child: SingleChildScrollView(
            child: Text.rich(
              showEmote
                  ? TextSpan(
                      children: emotes.entries.mapIndexed(
                        (i, e) {
                          final emote = e.value;
                          final size = emote.size.toInt() * 25.0;
                          return TextSpan(
                            children: [
                              if (i != 0) const TextSpan(text: '\n\n'),
                              WidgetSpan(
                                child: NetworkImgLayer(
                                  src: emote.url,
                                  type: .emote,
                                  width: size,
                                  height: size,
                                ),
                              ),
                              TextSpan(text: '\n${e.key}\n${emote.url}'),
                            ],
                          );
                        },
                      ).toList(),
                    )
                  : TextSpan(text: message),
              style: const TextStyle(fontSize: 15, height: 1.7),
            ),
          ),
        ),
      ),
    ),
  );
}
