import 'package:PiliPlus/http/api.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/utils/accounts/api_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live user moderation lookup uses the heartbeat account', () {
    expect(
      ApiType.apiTypeSet[AccountType.heartbeat],
      contains(Api.getLiveInfoByUser),
    );
  });
}
