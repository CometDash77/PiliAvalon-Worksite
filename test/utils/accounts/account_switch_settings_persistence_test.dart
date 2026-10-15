import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/features/shielding/shielding.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/pages/video/channel_quiet/channel_quiet_rule.dart';
import 'package:PiliPlus/pages/video/channel_quiet/channel_quiet_store.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

LoginAccount _account(String mid) => LoginAccount(
  BiliCookieJar.fromJson({'DedeUserID': mid, 'bili_jct': 'csrf-$mid'}),
  'access-key-$mid',
  'refresh-token-$mid',
)..activated = true;

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'piliplus-account-settings-test-',
    );
    appSupportDirPath = tempDir.path;
    await GStorage.init();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('account changes and box reopen preserve app-wide settings', () async {
    for (final account in Accounts.accountMode) {
      account.activated = true;
    }
    final now = DateTime.utc(2026, 10, 1);
    final quietRule = ChannelQuietRule(
      key: ChannelQuietRule.ugcKey(42),
      channelUid: '42',
      channelName: 'Example channel',
      hideComments: true,
      hideDanmaku: true,
      createdAt: now,
      updatedAt: now,
    );
    final quietRules = jsonEncode([quietRule.toJson()]);

    final shieldRules = jsonEncode(
      ShieldRuleSet(
        rules: [
          ShieldRule(
            id: 'persisted-rule',
            type: ShieldRuleType.uid,
            matchMode: ShieldMatchMode.exact,
            scope: ShieldScope.comment,
            action: ShieldAction.block,
            pattern: '42',
            updatedAt: now,
          ),
        ],
      ).toJson(),
    );
    await GStorage.setting.put(ShieldBoxKey.rules, shieldRules);
    await GStorage.setting.put(ShieldBoxKey.globalEnabled, true);
    await GStorage.setting.put(
      SettingBoxKey.minInteractionRateForRecommend,
      0.04,
    );
    await GStorage.setting.put(SettingBoxKey.repeatExposureFilterEnabled, true);
    await GStorage.setting.put(SettingBoxKey.repeatExposureWindowDays, 9);
    await GStorage.setting.put(ChannelQuietStore.rulesKey, quietRules);
    await GStorage.video.put(VideoBoxKey.playSpeedDefault, 1.75);
    expect(GStorage.setting.name, 'setting');
    expect(GStorage.video.name, 'video');

    final accountA = _account('1001');
    final accountB = _account('1002');
    await Accounts.set(AccountType.video, accountA);
    expect(Accounts.video, same(accountA));
    await Accounts.set(AccountType.video, accountB);
    expect(Accounts.video, same(accountB));

    final anonymous = AnonymousAccount()..activated = true;
    await Accounts.set(AccountType.video, anonymous);
    expect(Accounts.video, same(anonymous));
    await Accounts.set(AccountType.video, accountB);
    expect(Accounts.video, same(accountB));

    expect(GStorage.setting.get(ShieldBoxKey.rules), shieldRules);
    expect(GStorage.setting.get(ShieldBoxKey.globalEnabled), isTrue);
    expect(
      GStorage.setting.get(SettingBoxKey.minInteractionRateForRecommend),
      0.04,
    );
    expect(
      GStorage.setting.get(SettingBoxKey.repeatExposureFilterEnabled),
      isTrue,
    );
    expect(GStorage.setting.get(SettingBoxKey.repeatExposureWindowDays), 9);
    expect(GStorage.setting.get(ChannelQuietStore.rulesKey), quietRules);
    expect(GStorage.video.get(VideoBoxKey.playSpeedDefault), 1.75);

    Accounts.accountMode[AccountType.video.index] = AnonymousAccount()
      ..activated = true;
    await Accounts.refresh();
    expect(Accounts.video, same(accountB));

    await GStorage.setting.close();
    await GStorage.video.close();
    await Accounts.account.close();
    final reopenedSetting = await Hive.openBox<dynamic>('setting');
    final reopenedVideo = await Hive.openBox<dynamic>('video');
    final reopenedAccounts = await Hive.openBox<LoginAccount>('account');

    expect(
      reopenedAccounts.get('1002')?.type,
      contains(AccountType.video),
    );
    expect(reopenedAccounts.containsKey('1001'), isTrue);
    expect(
      reopenedAccounts.get('1001')!.type.contains(AccountType.video),
      isFalse,
    );
    expect(reopenedSetting.name, 'setting');
    expect(reopenedVideo.name, 'video');
    expect(reopenedSetting.get(ShieldBoxKey.rules), shieldRules);
    expect(reopenedSetting.get(ShieldBoxKey.globalEnabled), isTrue);
    expect(
      reopenedSetting.get(SettingBoxKey.minInteractionRateForRecommend),
      0.04,
    );
    expect(
      reopenedSetting.get(SettingBoxKey.repeatExposureFilterEnabled),
      isTrue,
    );
    expect(reopenedSetting.get(SettingBoxKey.repeatExposureWindowDays), 9);
    expect(reopenedSetting.get(ChannelQuietStore.rulesKey), quietRules);
    expect(reopenedVideo.get(VideoBoxKey.playSpeedDefault), 1.75);
  });
}
