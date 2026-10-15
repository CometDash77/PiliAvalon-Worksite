重做 [评论门请求归并进页内热路径](https://github.com/CometDash77/PiliAvalon-Worksite/issues/50)，收尾 map [#47](https://github.com/CometDash77/PiliAvalon-Worksite/issues/47) 的「重做」批次第三票 [#75](https://github.com/CometDash77/PiliAvalon-Worksite/issues/75)。

## 改了什么

`lib/features/shielding/home_feed_comment_gate.dart`（+264/−28）：把一个**固定分批 + 批次屏障**的调度换成**持续补位 worker 池**，并补上判定缓存。

- 调度：`maxConcurrent` 个 worker 从队首取下标，谁空谁补（`home_feed_comment_gate.dart:85-113`）；判定按原下标回填，输出顺序不变（`:110-113`）。并发与超时维持默认 3 / 3 秒（`:36-37`）。
- 同 aid 合并：同批重复 aid、以及还在飞的同一个 aid，共享同一个 future（`:117-156`）；在飞登记**早于**请求发起，避免 loader 同步抛错留下死键（`:131-136`）。
- 成功判定缓存：30 秒、上限 256 条（`:39-43`）；策略键 = 评论配置 + 屏蔽规则（版本、4 个开关、每条规则的 id/type/matchMode/scope/action/pattern/enabled）+ ReplyGrpc 的 4 个过滤开关（`:209-244`），键一变整代作废（`:203-207`）。
- 失败/超时/`Error` 一律不缓存，条目保留（fail-open，`:158-197` + `:102-103`）；总开关关闭时仍在任何调度之前提前返回，零请求（`:76-78`）。

`_hasVisibleCheckedComment` / `_checkedCommentsExhausted` / `_isVisible` / `_defaultLoader` / `filter` 签名与 `lib/features/shielding/recommendation_surfaces.dart` 的「标签富集 → 评论门」阶段顺序均未改动（`git diff production` 中为 context 行）。

## 测试

`test/features/shielding/home_feed_comment_gate_test.dart` **纯新增** 500 行（`git diff` 无删除行，原 5 条用例逐字未动），新增 15 条用例：worker 补位、受控场景（1×600ms + 4×200ms、3 槽、断言 < 700ms，固定分批需 800ms）、请求数精确列表、并发峰值 = 3、同 aid 同批与跨页在飞合并、缓存命中 / TTL / 溢出 FIFO / 键隔离（评论配置、新增规则、ReplyGrpc 开关）、开关关闭零请求、耗尽与 fail-open。

本机：`flutter test --no-pub` → **569 tests passed**（基线 554 + 15）；`flutter analyze --no-pub --no-fatal-infos` → 14 issues、exit 0、0 error / 0 warning（3 条既有 info + 未跟踪 `tool/probe/login_field_probe.dart` 的 11 条，均不在本 PR 改动的文件上）。

远程：`gh workflow run ci.yml --ref codex/issue-75-commentgate-redo` → run **37412617335**（`headSha 28afe2151`）conclusion **success**，`Flutter verification` / `Build Android x86_64 artifact` / `Android emulator runtime smoke` 三 job 全绿。

## 边界

不碰 [#51](https://github.com/CometDash77/PiliAvalon-Worksite/issues/51)（被 map 外的 [#65](https://github.com/CometDash77/PiliAvalon-Worksite/issues/65) 闸住）与 [#54](https://github.com/CometDash77/PiliAvalon-Worksite/issues/54)。缓存写满 256 后按写入序丢最早条目，反复整页重扫超过 256 条候选时尾部会退化成重发——这是容量语义的固有行为，不是正确性问题，基线/验收口径归 #54。

回退：`git revert -m 1 <merge commit>`。
