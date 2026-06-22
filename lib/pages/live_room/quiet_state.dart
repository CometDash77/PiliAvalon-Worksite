import 'package:PiliPlus/models/common/super_chat_type.dart';

bool effectiveShowLiveDanmaku({
  required bool globalShow,
  required bool temporaryHide,
}) => globalShow && !temporaryHide;

bool effectiveShowLiveSuperChat({
  required SuperChatType globalType,
  required bool temporaryHide,
}) => globalType != SuperChatType.disable && !temporaryHide;
