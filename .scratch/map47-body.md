## Destination

**目的地：在 Jev 筛选设计地图 [#29](https://github.com/CometDash77/PiliAvalon-Worksite/issues/29) 关闭之后，把推荐/筛选管线里重复的上游网络请求剪掉、把过滤模块的耦合拆开、把过滤热路径的重复计算砍掉——在保持现有确定性屏蔽语义不变、现有测试全绿、`gh` 可复跑的前提下，各推荐面的每页上游请求计数有实测下降。**

一句话版本：让过滤这件事只做一遍、上游只查一次、依赖只走一层。

## Notes
- 目标仓库 `CometDash77/PiliAvalon-Worksite`，产品分支 `production`。
- **本图允许改产品源码。** 与 #29 不同，本图是**带执行**的地图：票里直接改代码，票的答案记录「改了什么 + 证据」。
- **顺序**：本图曾整体阻塞于 #29；该门控票已关闭，依赖边保留；若 Jev 实现另立工作包，等它把 Jev 挂进管线上的位置定了，再动「合并双过滤引擎并消灭重复判定」票。
- **量具优先**：基础请求计数/阶段量具已由 [建立可复跑的请求计数与阶段计时](https://github.com/CometDash77/PiliAvalon-Worksite/issues/57) 交付；继续复用默认 no-op 的观察者，先确认测量边界和可复跑条件，再做前后对比。
- 与 #29 的边界：本图不重新决定 Jev 的原子问题、提供方路由、密钥存储、负反馈档案、设置形态；只决定「Jev 门之前的确定性管线」长什么样，并给 Jev 留干净接入点。
- 与 [#36](https://github.com/CometDash77/PiliAvalon-Worksite/issues/36) 的边界：不评估 Jev 门本身的质量/成本，只保证送到门前的候选集更小、判定更省。
- 与 [Live Recommendation 图 #19](https://github.com/CometDash77/PiliAvalon-Worksite/issues/19) 的边界：直播列表行为归它，本图只改跨面共享的获取/缓存/判定层。
- 领域词汇：**过滤** filter（判定可见性，纯函数）；**筛选** screening（含上游取数据）；**屏蔽** shielding（规则集 → 判定）。改动中统一用这三个词。
- 每张票开始前先 `deck_issue_report` 上报；结束时把真实状态写回票的 `## 进度`。
- **证据落盘**：`docs/` 被 `.gitignore:189` 整体忽略，票里指向 `docs/diagnostics/*` 的链接**先 `git add -f` 入库才存在**（本图历史上都没有 `git add -f` 过，因此旧链接全部 404；见 Current status）。证据优先落到一次性 `research/<name>` 分支上，并从票里给指针。

## Decisions so far

<!-- 每关一张票补一行：- [票名](链接) — 一句话结论 -->

- [建立可复跑的请求计数与阶段计时](https://github.com/CometDash77/PiliAvalon-Worksite/issues/57) — 已建立默认关闭的注入式请求/阶段量具，假网络测试与 Android 35 真实推荐列表烟测通过；详细基线见 `docs/diagnostics/recommendation-metrics.md`（该文件从未入库，链接 404；见 Current status）。
- [盘点每页请求放大倍数并建立性能/请求数基线](https://github.com/CometDash77/PiliAvalon-Worksite/issues/48) — 首页 Web/App 冷缓存标签请求按条目放大、评论门按有效 aid 逐项请求；20 条真机样本为 feed 1 + tags 20，详见 [recommendation-request-baseline.md](https://github.com/CometDash77/PiliAvalon-Worksite/blob/production/docs/diagnostics/recommendation-request-baseline.md)（该文件从未入库，链接 404；见 Current status）。

- [统一并去重标签获取路径](https://github.com/CometDash77/PiliAvalon-Worksite/issues/49) — 推荐面与详情页共用 BVID+CID 标签缓存；相同键并发合并，失败/空结果负缓存 30 秒。 **2026-10-06 产物审计：上述产物不在版本库也不在工作树（`lib/features/shielding/shielding_recommend_tag_enricher.dart` 只有 30 分钟 TTL，无并发合并、无负缓存）；结论仍有效，实施按 YG 的决定重做为 [#74](https://github.com/CometDash77/PiliAvalon-Worksite/issues/74)。**

- [评论门请求归并进页内热路径](https://github.com/CometDash77/PiliAvalon-Worksite/issues/50) — 评论门保留在标签之后；同 aid 判定做短期缓存，持续补位的并发池削减批次等待且不增加每页请求。 **2026-10-06 产物审计：产物不在版本库也不在工作树（`lib/features/shielding/home_feed_comment_gate.dart` 只有 `maxConcurrent = 3` 与 3 秒超时，无按 aid 缓存）；已按同一决定重做为 [#75](https://github.com/CometDash77/PiliAvalon-Worksite/issues/75)，并于 2026-10-06 重做入库（`28afe2151`，run 37412617335 三 job 全绿）、并入 production（PR [#78](https://github.com/CometDash77/PiliAvalon-Worksite/pull/78) / `822ba20f1`）。**

- [拆开过滤模块耦合，收敛调用点](https://github.com/CometDash77/PiliAvalon-Worksite/issues/53) — 五面收敛为一条共享管线、每批次注入一次规则/旧配置，纯判定不读存储；本地 500 测试通过，详情及交付边界见票。 **2026-10-06 产物审计：当时那批产物从未入库；已重做成 [#73](https://github.com/CometDash77/PiliAvalon-Worksite/issues/73) 并入库（分支 `codex/issue-73-pipeline-redo`，远程 CI run 37405131412 三 job 全绿、539 测试通过）。**

- [推荐面标签能否内联随推荐接口返回，或按批一次取回](https://github.com/CometDash77/PiliAvalon-Worksite/issues/67) — 结论 **③ 都不行**：两个在用推荐接口的 item 都没有标签字段（web `feed/rcmd`、app `x/v2/feed/index` 实测 `"tag` 命中 0），`/x/web-interface/view/detail/tag` 只认单个 bvid（反向排序对照验证）→ **标签阶段不能删、也不能压成 1 次**，杠杆只能是前置规则命中率与缓存/去重；证据 [recommendation-tag-inline-availability.md](https://github.com/CometDash77/PiliAvalon-Worksite/blob/research/rcmd-tag-availability/docs/diagnostics/recommendation-tag-inline-availability.md)（本图第一份真正入库的证据）。

- [优化 ShieldMatcher 判定热路径](https://github.com/CometDash77/PiliAvalon-Worksite/issues/52) — 判定结果与改动前逐候选逐规则等价（20 候选 × 72 规则 0 mismatch），同负载每页中位耗时 909.6 → 459.4 µs（≈1.98x），完整 shielding 套件 +322 全绿；产品改动 2026-10-06 已入库、远程 CI 全绿（见 [把幸存的 #52 热路径改动入库并取得远程可复跑证据](https://github.com/CometDash77/PiliAvalon-Worksite/issues/71)）；早先落在 research/shieldmatcher-hotpath-bench 的是同一对照装置的另一个变体；2026-10-06 该批改动已 rebase 到 `origin/production` 线并入 `codex/issue-73-pipeline-redo`（`76afd9843` + `6485a9446`），production 线复跑中位 148.7 µs/轮（与 459.4 µs 不是同一量具变体，别混用）。
- [把幸存的 #52 热路径改动入库并取得远程可复跑证据](https://github.com/CometDash77/PiliAvalon-Worksite/issues/71) — 2026-10-06：#52 唯一幸存的那批产品改动（`shielding_matcher.dart`、`shielding_adapters.dart`、`shielding_models.dart` + 新测试 `test/features/shielding/shielding_matcher_cache_test.dart`）以 `c58df090f` 入库，`tool/bench/` 那套量具（README + 冻结参照 `_reference_shield_matcher.dart` + `shield_matcher_bench.dart` + `shield_matcher_equivalence.dart`）以 `f9a19d353` 入库，推在 `codex/issue-52-shield-matcher-hot-path`；远程证据 = `gh workflow run ci.yml --ref codex/issue-52-shield-matcher-hot-path` → run 37397549674（`headSha f9a19d353`）conclusion success：`Flutter verification` 478 passed + analyze 3 issues、Android x86_64 构建、emulator runtime smoke 三 job 全绿。合并目标：2026-10-06 经 YG 决定并入 production —— 该批改动随 [重做 #53](https://github.com/CometDash77/PiliAvalon-Worksite/issues/73) 的分支一起进了 PR [#76](https://github.com/CometDash77/PiliAvalon-Worksite/pull/76)，合并提交 `c24b5aa9b`（2026-10-06T02:59:49Z）。

- [重做 #53：把五面手写筛选管线收敛成一条共享管线](https://github.com/CometDash77/PiliAvalon-Worksite/issues/73) — 2026-10-06：产物重做并入库（4 提交 `76afd9843` / `6485a9446` / `7d84f671c` / `fc3b6c7f5`，基线 = `origin/production` @ `d0820e6c9`）；远程证据 run 37405131412（`headSha fc3b6c7f5`）三 job 全绿（539 tests passed / analyze 3 issues / Android x86_64 / emulator smoke），本机差分夹 100,024 次比较 0 不一致。边界：2026-10-06 经 YG 决定并入 production（PR [#76](https://github.com/CometDash77/PiliAvalon-Worksite/pull/76)，合并提交 `c24b5aa9b`，其树与 CI 验证过的 `fc3b6c7f5` 逐字节相同）；不碰 #51 与 #54。

- [重做 #49：标签获取统一去重、并发合并与负缓存](https://github.com/CometDash77/PiliAvalon-Worksite/issues/74) — 2026-10-06：产物重做并入库（单提交 `c10a00de7`，基线 `origin/production` @ `c24b5aa9b`；新增 `lib/features/shielding/recommendation_tag_store.dart` 235 行、`shielding_recommend_tag_enricher.dart` 退化为薄层并暴露 `fetchSharedTags()`、`lib/pages/common/common_intro_controller.dart:148-155` 由直调 `UserHttp.videoTags` 改走共享入口、两个测试文件）。远程证据 run 37408586817（`headSha c10a00de7`）三 job 全绿（554 tests passed / analyze 3 issues / Android x86_64 / emulator smoke）；请求数上界的证明在 `test/features/shielding/shielding_recommend_tag_enricher_test.dart:674-718`（K=8、24 槽位只有 8 个不同 bvid，`fetchLog` 长度 ≤ 8 且 `toSet()` 恰为 8）。边界：2026-10-06 已并入 production（PR [#77](https://github.com/CometDash77/PiliAvalon-Worksite/pull/77)，合并提交 `cd2cc65db`，其树与 `c10a00de7` 的树逐字节相同）；不碰 #51 与 #54。
- [重做 #50：评论门持续补位 worker、同 aid 合并与成功缓存](https://github.com/CometDash77/PiliAvalon-Worksite/issues/75) — 2026-10-06：产物重做并入库（单提交 `28afe2151`，基线 `origin/production` @ `cd2cc65db`；`lib/features/shielding/home_feed_comment_gate.dart` +264/−28 把固定分批屏障换成持续补位 worker 池 + 同 aid in-flight 合并 + 30 秒 / 256 条成功判定缓存（策略键 = 评论配置 + 屏蔽规则 + ReplyGrpc 过滤开关），失败/超时/`Error` 一律不缓存且条目保留（fail-open）；`lib/features/shielding/recommendation_surfaces.dart` 未动，阶段顺序仍是「标签富集 → 评论门」）。远程证据 run 37412617335（`headSha 28afe2151`）三 job 全绿（569 tests passed / analyze 3 issues / Android x86_64 / emulator smoke）；本次新增 15 条用例且测试文件纯新增（原 5 条用例逐字未动）。边界：2026-10-06 已并入 production（PR [#78](https://github.com/CometDash77/PiliAvalon-Worksite/pull/78)，合并提交 `822ba20f1`，其树与 `28afe2151` 的树逐字节相同）；不碰 #51 与 #54。

## Not yet specified
- 同一候选在连续两页重复出现时的跨页去重范围（#67 未测跨页重复率，收益仍未知）。
- 真机冒烟采集要不要作为每个实现票的固定收尾动作（暂定：只验收票需要）。

## Out of scope
- 重新决定 Jev 的原子问题、提供方路由、密钥存储、负反馈档案、设置形态（归 #29）。
- 评估 Jev 门本身的质量与成本（归 #36）。
- 直播列表面行为与直播卡片快速屏蔽（归 #19 / #45 / #46）。
- 评论、搜索等非推荐面的屏蔽行为。
- DevTools extension、常驻性能面板、第三方 benchmark 包。
- 实时重筛已展示卡片或取消/重启正在执行的批次；本图保留每批次规则快照，实时 UI 刷新另行处理。
- 登录态下的标签内联/批量复核（[带登录凭据复核：推荐响应是否内联标签、标签接口是否解锁批量入参](https://github.com/CometDash77/PiliAvalon-Worksite/issues/68)，2026-10-05 已关闭）——真人决定由自己按需实测，不再占本图的票位。

## Plan
- [x] 建立可复跑的请求计数与阶段计时
- [x] 盘点每页请求放大倍数并建立性能/请求数基线
- [x] 统一并去重标签获取路径（[#74](https://github.com/CometDash77/PiliAvalon-Worksite/issues/74)，2026-10-06 重做并入库：远程 run 37408586817 三 job 全绿；已并入 production，PR [#77](https://github.com/CometDash77/PiliAvalon-Worksite/pull/77) / `cd2cc65db`）
- [x] 评论门请求归并进页内热路径（[#75](https://github.com/CometDash77/PiliAvalon-Worksite/issues/75)，2026-10-06 重做并入库：远程 run 37412617335 三 job 全绿；已并入 production，PR [#78](https://github.com/CometDash77/PiliAvalon-Worksite/pull/78) / `822ba20f1`）
- [ ] 合并双过滤引擎并消灭重复判定
- [x] 优化 ShieldMatcher 判定热路径（[#52](https://github.com/CometDash77/PiliAvalon-Worksite/issues/52)，2026-10-05 关闭：语义等价 + 同负载每页中位耗时 ≈1.98x）
- [x] 把幸存的 #52 热路径改动入库并取得远程可复跑证据（[#71](https://github.com/CometDash77/PiliAvalon-Worksite/issues/71)，2026-10-06 关闭：远程 run 37397549674 三 job 全绿）
- [x] 拆开过滤模块耦合，收敛调用点（[#73](https://github.com/CometDash77/PiliAvalon-Worksite/issues/73)，2026-10-06 重做并入库：远程 run 37405131412 三 job 全绿）
- [ ] 锁定性能/请求数验收基线
- [x] 查清推荐面标签能否内联 / 批量取回（结论 ③ 都不行）
- [x] 带登录凭据复核标签内联与批量能力（[#68](https://github.com/CometDash77/PiliAvalon-Worksite/issues/68)，HITL）— 2026-10-05 关闭：真人决定自行按需实测，本票撤出本图（登录态实测未做）

## Current status

### 2026-10-06 第五轮（重做 #50 → #75 入库并合入 production；「重做」批次闭合）

- **这次推的是哪张票**：[重做 #50：评论门持续补位 worker、同 aid 合并与成功缓存](https://github.com/CometDash77/PiliAvalon-Worksite/issues/75)（`wayfinder:task`，父图 #47）。#72「重做」决议里的第三票，也是最后一张：认领 → 闸门诊断 → 实施 → 验收 → 关闭。
- **闸门诊断**：#50 于 2026-10-02 关闭并声称「固定分批改为 3 个持续补位 worker、同 aid in-flight 合并、30 秒成功缓存上限 256、受控场景 140ms→122ms、279 项通过」，产物从未提交；2026-10-06 实测 `lib/features/shielding/home_feed_comment_gate.dart` 仍是固定 `maxConcurrent` 分批 + 批次屏障，无按 aid 缓存、无 in-flight 合并 → 判定「真实但未入库」，本轮的活是把设计重新实现并入库。
- **改了什么**：单提交 `28afe2151`（基线 `origin/production` @ `cd2cc65db`），2 文件 +736/−28。调度换成 `maxConcurrent` 个持续补位 worker（`:85-113`，按原下标回填、输出顺序不变）；同 aid（同批重复 + 跨页在飞）共享同一 future（`:117-156`，在飞登记早于请求发起，避免 loader 同步抛错留下死键 `:131-136`）；成功判定缓存 30 秒 / 上限 256（`:39-43`），策略键 = 评论配置 + 屏蔽规则（版本 + 4 个开关 + 每条规则 id/type/matchMode/scope/action/pattern/enabled）+ ReplyGrpc 四个过滤开关（`:209-244`，键一变整代作废 `:203-207`）；失败/超时/`Error` 不缓存、条目保留（`:158-197` + `:102-103` fail-open）；`_hasVisibleCheckedComment` / `_checkedCommentsExhausted` / `_isVisible` 与「开关关闭时零请求」的提前返回（`:76-78`）逐字未动。
- **远程证据**：`gh workflow run ci.yml --ref codex/issue-75-commentgate-redo` → run 37412617335（`headSha 28afe2151`，2026-10-06T04:12:39Z → 04:26:32Z）三 job 全绿；决定性日志 `2026-10-06T04:15:08Z 🎉 569 tests passed.`、`2026-10-06T04:15:41Z 3 issues found. (ran in 32.4s)`。
- **本机复跑**：`flutter test --no-pub` = 569 通过（基线 554 + 15 新用例）；`flutter analyze --no-pub --no-fatal-infos` = 14 issues / exit 0（3 条既有 info + 未跟踪 `tool/probe/login_field_probe.dart` 的 11 条，本票改动的两个文件 0 条）。测试文件 diff 纯新增（`git diff` 无删除行），原 5 条用例逐字未动。
- **并入 production**：PR [#78](https://github.com/CometDash77/PiliAvalon-Worksite/pull/78)（2026-10-06T04:27:47Z）合并提交 `822ba20f1`，其树（`8de2180e`）与 CI 验证过的 `28afe2151` 逐字节相同；合并触发的 push run 37413823756 三 job 全绿。
- **「重做」批次至此闭合**：#73（共享管线）、#74（标签缓存）、#75（评论门）三票全部重做、入库并进了 production。Plan 只剩「合并双过滤引擎并消灭重复判定」（#51，被 map 外的 [#65](https://github.com/CometDash77/PiliAvalon-Worksite/issues/65) 闸住）与「锁定性能/请求数验收基线」（#54，被 #51 闸住）两项。
- **如实记录的边界**：① 入库断言用的是放大后的受控场景（1×600ms + 4×200ms、3 槽、断言 < 700ms，固定分批需 800ms）+ 结构性断言（请求数精确列表、并发峰值 = 3）；票面原始尺度（120/20ms、参照 140ms）两侧数字来自实施期间的一次性探针（已删、未入库），本机旧实现 147ms / 新实现 127ms，**出处是本会话报告与提交信息，不能从被跟踪树直接复现**。② 缓存写满 256 后按写入序丢最早条目，反复整页重扫超过 256 条候选时尾部会退化成重发（容量语义的固有行为，不是正确性问题）→ 基线口径归 #54。③ 合并进来的调用方继承发起方那一次请求的超时（上界仍是 3 秒），比改造前「每页各自 3 秒」略紧，未单独验证。

### 2026-10-06 第四轮（重做 #49 → #74 入库并合入 production）

- **这次推的是哪张票**：[重做 #49：标签获取统一去重、并发合并与负缓存](https://github.com/CometDash77/PiliAvalon-Worksite/issues/74)（`wayfinder:task`，父图 #47）。#72 的「重做」决议里的第二票：认领 → 闸门诊断 → 实施 → 验收 → 关闭。
- **闸门诊断**：#49 于 2026-10-02 关闭时明写「代码和报告尚未 commit/push」，产物审计确认树上没有（`RecommendationTagEnricher` 只有 30 分钟 TTL 缓存、无在飞合并、无负缓存）→ 判「真实但未入库，按原 spec 重做」。
- **改了什么**（分支 `codex/issue-74-tagenrich-redo`，基线 `origin/production` @ `c24b5aa9b`，单提交 `c10a00de7`）：新增 `lib/features/shielding/recommendation_tag_store.dart`（键 `bvid|cid`、同键在飞合并、失败与空结果 30 秒负缓存、成功 30 分钟、默认 10MB 上限 50MB 按估算字节旧→新驱逐、只存原始标签不存判定结果）；`shielding_recommend_tag_enricher.dart` 退化为薄层并暴露 `fetchSharedTags()` 作为推荐面与详情页共用的唯一入口（幸存者过滤、并发池默认 5、单调用方 3 秒超时、fail-open 语义不变）；`lib/pages/common/common_intro_controller.dart:148-155` 的 `queryVideoTags()` 由直调 `UserHttp.videoTags` 改走共享入口，详情页因此复用推荐面已取的标签；不做单调用方取消。
- **远程证据**：run 37408586817（`headSha c10a00de75ee9955aff30ddb2551ce94dd283f23`）conclusion success；决定性日志 `2026-10-06T03:23:23Z 🎉 554 tests passed.`、`2026-10-06T03:24:02Z 3 issues found. (ran in 38.3s)`（exit 0）；`Build Android x86_64 artifact` 与 `Android emulator runtime smoke` 均 success。
- **本机复跑**：`flutter test --no-pub` 554 通过（exit 0）、`flutter analyze --no-pub --no-fatal-infos` 14 issues / 0 error（多于 CI 的 3 条 info 来自未跟踪的 `tool/probe/login_field_probe.dart`）。
- **并入 production**：PR [#77](https://github.com/CometDash77/PiliAvalon-Worksite/pull/77)（2026-10-06T03:33:31Z）合并提交 `cd2cc65db`，其树与 CI 验证过的 `c10a00de7` 逐字节相同；push 触发的 `ci.yml` run 37409546588 三 job 全绿（`03:35:58Z 🎉 554 tests passed.` / analyze `3 issues found`）。
- **本轮之后的开口**：#75（重做 #50：评论门持续补位 worker + 同 aid 合并 + 成功缓存）是本图「重做」批次的第三票，尚未开工；三票都排在 production 线上。
- **仍然有效的提醒**：本文件 Decisions so far 里 #49 / #50 / #53 三行的产物在树上并不存在；#53 与 #49 已分别重做入库，读那三行时以三处审计说明为准。

### 2026-10-06 第三轮（重做 #53 → #73 入库；#74 随后落地，见上一节）

- **这次推的是哪张票**：[重做 #53：把五面手写筛选管线收敛成一条共享管线](https://github.com/CometDash77/PiliAvalon-Worksite/issues/73)（`wayfinder:task`，认领 → 闸门诊断 → 实施 → 验收 → 关闭）。#72 的决议是「重做」，本轮先做掉三票里的第一票。
- **落在哪条线上**：整条分支 rebase 到 `origin/production`（`d0820e6c9`）——本地 `production` 引用停在 `aef19ec34` = tag `v2.1.5+5524`，已落后远程两个提交（`df31356a9` live 快速屏蔽 + PR #70 合并）。rebase 时 `lib/features/shielding/shielding_matcher.dart` 撞上真冲突（#52 把 `_valuesForRule` 换成 `_rawValues` 开关，production 在同一处加了 `roomId`），解法 = 取 #52 版，再把 production 的 roomId 搬进新开关（`lib/features/shielding/shielding_matcher.dart:165`）。
- **冻结参照件必须补一行**：`tool/bench/_reference_shield_matcher.dart` 原先只按 main 冻结，枚举多了 `roomId` 后成非穷举开关、编译报 error（会让 CI 的 analyze 直接失败）。补入逐字镜像 production 的两行，其余一字未动；差分夹按 `ShieldRuleType.values` 穷举，sweep 规则数 17,136 → 18,144，反而把 `roomId` 的等价性证明进来了（100,024 次比较 / 0 不一致）。
- **远程证据**：run 37405131412（`headSha fc3b6c7f51646e677ef63d0f34a2337dee284728`）conclusion success；`Flutter verification` → `🎉 539 tests passed.`、analyze `3 issues found`（exit 0）；`Build Android x86_64 artifact`、`Android emulator runtime smoke` 均 success。
- **本机复跑**：`flutter test --no-pub` 539 通过（exit 0）、`flutter analyze --no-pub --no-fatal-infos` 14 issues / 0 error、差分夹 100,024 次比较 / 0 mismatch、bench 每轮中位 148.7 µs。
- **本轮之后的开口**：#74（重做 #49：标签获取去重 + 同键并发合并 + 失败/空负缓存）正在 `codex/issue-74-tagenrich-redo` 上实施；#75（重做 #50：评论门持续补位 worker + 同 aid 合并 + 成功缓存）待开；三票都排在 production 线上。**2026-10-06 已按 YG 的决定并入 production**：PR [#76](https://github.com/CometDash77/PiliAvalon-Worksite/pull/76) 合并提交 `c24b5aa9b`（其树 = `fc3b6c7f5` 的树，逐字节相同），push 触发的 `ci.yml` run 37406851962 三 job 全绿（539 tests passed / analyze 3 issues）。后续顺序仍按他给的：等 map 全部完成、验收通过、stable APK 装到机器上无问题，再走 production → main（方向没反）。
- **仍然有效的提醒**：本文件 Decisions so far 里 #49 / #50 / #53 三行的产物在树上并不存在，本轮只把 #53 这一票重做并入库，读那三行时以本轮与上一轮的两条审计说明为准。

### 2026-10-06（#52 存活产物入库 + 产物审计）

- **这次推的是哪张票**：[把幸存的 #52 热路径改动入库并取得远程可复跑证据](https://github.com/CometDash77/PiliAvalon-Worksite/issues/71)。#52 的验收当时全过，但产品改动只停在本地 git 索引里（未提交、无 ref 指向），从 2026-10-03 16:26 起躺了三天。本次把它和量具一起提交、推分支、再用 `workflow_dispatch` 取了远程证据。结论 gist 见 Decisions so far 的 #71 一行。
- **本图第一次有了可远程复跑的产品产物**：分支 `codex/issue-52-shield-matcher-hot-path` @ `f9a19d353`（基于 `e998665ab`）。远程 `flutter test --no-pub` = 478 passed、`flutter analyze --no-pub --no-fatal-infos` = 3 issues（exit 0）、Android x86_64 构建与 emulator runtime smoke 均 success，整条墙钟约 10 分钟。合并目标（main / production）由 YG 定，本次不合并（后续：同一批改动已随 #73 的分支并入 production，见 Decisions so far 的 #73 一行）。
- **产物审计（重要：读上面的 Decisions so far 前先看这条）**：那三行「统一并去重标签获取路径」「评论门请求归并进页内热路径」「拆开过滤模块耦合，收敛调用点」读起来像现状，但**它们描述的产物在版本库和工作树里都不存在**——`lib/features/shielding/recommendation_pipeline.dart`、`lib/features/shielding/recommendation_filter.dart`、`lib/http/recommendation_screening.dart`、`lib/utils/recommendation_metrics.dart` 对所有 refs、所有 commit、甚至整个 `D:\Documents\vibe` 递归搜索都零命中；`docs/diagnostics/recommendation-{metrics,request-baseline,pipeline-boundaries}.md` 从未进过版本库（库里只有 #67 那份）；树上能看到的 `lib/features/shielding/shielding_recommend_tag_enricher.dart:73` 只有 30 分钟 TTL 缓存、没有并发合并、没有失败/空负缓存，`lib/features/shielding/home_feed_comment_gate.dart:21` 只有 `maxConcurrent = 3` 与 3 秒超时、没有按 aid 缓存。2026-10-05 记录的「35 文件 / +1582 −574 未提交改动」今天也已不在：`git worktree list` 只有一个工作树、`git stash list` 为空、`git rev-list --all --objects` 零命中、`git fsck --no-reflogs` 只有一个 dangling tree 且无 blob。本图至今的产物流失都发生在「验证完了但没提交」这一步，#52 是唯一幸存的一批。
- **这一发现已立票**：[消失的削减：标签缓存、评论门、共享管线的产物不在库里，重做还是划出范围](https://github.com/CometDash77/PiliAvalon-Worksite/issues/72)（HITL / `wayfinder:grilling`，无认领）——要真人定：这三票按「需重做」还是「划出本图范围」记、重开票的形态、以及「先提交、再验证」是否写进 Notes 当硬约束。**在它定下来之前，别把 Decisions so far 里那三行当作树上现状。**
- **frontier**：本次仍无「open ∧ 无认领 ∧ 阻塞已闭」的子票——[合并双过滤引擎并消灭重复判定](https://github.com/CometDash77/PiliAvalon-Worksite/issues/51) 被 map 外的 [Implement Jev-Based Personalized Recommendation Screening](https://github.com/CometDash77/PiliAvalon-Worksite/issues/65) 闸住，[锁定性能/请求数验收基线](https://github.com/CometDash77/PiliAvalon-Worksite/issues/54) 被 #51 闸住。新毕业的 #72 不依赖 #65，是当下唯一可推进的实质决定。
- **本次本机复跑**：`flutter test test/features/shielding --no-pub` = 282 通过；`flutter test --no-pub` = 478 通过；`dart run tool/bench/shield_matcher_equivalence.dart` = sweep 17,136 条规则、100,024 次比较 0 mismatch；`dart run tool/bench/shield_matcher_bench.dart` = 每轮中位 177.0 µs（min 127.0 / max 440.3）。**注意量具变体**：#52 票里的 909.6 → 459.4 µs 与本次入库 README 记的 530.1 → 137.0 µs 出自两个不同的对照变体（另一支是 `_legacy_shielding_matcher.dart`，冻结自 `0d4be712a`），不是同一组数字，别混用；同进程 A/B 的可复跑化留给 #54。

### 2026-10-05 第二轮（#52 收工）

- 关闭 [优化 ShieldMatcher 判定热路径](https://github.com/CometDash77/PiliAvalon-Worksite/issues/52)——这是**解决**不是撤票：验收两半都有可复核证据。语义侧完整 shielding 套件 `+322` 全通过（exit 0；2026-10-02 记的 Material UI 错配、并行 Jev 页面重复 `subtitle` 两个阻塞在本树均不复现）；等价侧自建进程内对照装置（同负载并排跑 HEAD 版与优化版，20 候选 × 72 规则）**0 mismatch**；耗时侧同负载每页中位 legacy 909.6 → optimized 459.4 µs（≈1.98x）。验收中还修掉一处偏差：优化版最初把正则编译挪进 `.any` 闭包，会让「该类型无候选值 + 非法 pattern」的 rule error 消失，已加 `_matchRegex` 急切编译对齐错误面。
- **本图仍未改动任何已入库的产品源码**：本轮的产品改动（`lib/features/shielding/shielding_matcher.dart` 等 3 文件）依旧停在本工作树的未提交状态；本轮唯一新增入库物是对照装置，落在 `research/shieldmatcher-hotpath-bench`（commit `e2fc4983c9c9a2e56c324072f59d9bae244977c5`：`tool/bench/{shield_matcher_bench_test,_legacy_shielding_matcher}.dart` + README）。
- **frontier 仍为空**：剩两张在飞票都不满足「open ∧ 无认领 ∧ 阻塞已闭」——[合并双过滤引擎并消灭重复判定](https://github.com/CometDash77/PiliAvalon-Worksite/issues/51) 被 open 的 [Implement Jev-Based Personalized Recommendation Screening](https://github.com/CometDash77/PiliAvalon-Worksite/issues/65) 阻塞，[锁定性能/请求数验收基线](https://github.com/CometDash77/PiliAvalon-Worksite/issues/54) 被 #51 阻塞（不再被 #52 阻塞）。本图当前的闸门确实是 #65：与 Notes 里「等 Jev 把挂进管线上的位置定了，再动 #51」一致。

### 2026-10-05（本 session，只记录可复核事实）

- 子票共 10 张。本 session **未改任何产品源码**；做了一件事并按其结论撤票：关闭 [带登录凭据复核：推荐响应是否内联标签、标签接口是否解锁批量入参](https://github.com/CometDash77/PiliAvalon-Worksite/issues/68)（真人决定：自己按需实测，不占本图票位）。
- **#68 是「撤票」不是「解决」**：匿名基线在本 checkout 复现，登录态三组**未做** → #67 的结论 ③ 仍只经匿名态验证；本票对应的 fog 尾巴已随之撤出本图。
- **frontier 现在为空**：三张在飞票没有一张同时满足「open ∧ 无认领 ∧ 阻塞已闭」——[优化 ShieldMatcher 判定热路径](https://github.com/CometDash77/PiliAvalon-Worksite/issues/52) 仍被认领（assignee=CometDash77），[合并双过滤引擎并消灭重复判定](https://github.com/CometDash77/PiliAvalon-Worksite/issues/51) 仍被 open 的 [活着的 Jev 票](https://github.com/CometDash77/PiliAvalon-Worksite/issues/65) 阻塞，[锁定性能/请求数验收基线](https://github.com/CometDash77/PiliAvalon-Worksite/issues/54) 仍被 #52/#51 阻塞。**要往前推，必须先让 #52 收工，或由真人解除它的认领。**（2026-10-05 第二轮已按此执行：#52 已关闭，见上节。）
- **对 2026-10-03 那轮 Current status 的更正（重要）**：本工作树（branch `codex/task55-temp-quiet-rewrite`，HEAD `0d4be712a`）**确实含有**本图已关票的产物，但**全是未提交改动/未跟踪文件**：`lib/features/shielding/recommendation_pipeline.dart`、`lib/features/shielding/recommendation_filter.dart`、`lib/http/recommendation_screening.dart`、`lib/utils/recommendation_metrics.dart`、`lib/utils/recommend_filter.dart`（±199 行）、`lib/features/shielding/shielding_matcher.dart`（Expando 预编译缓存）、`docs/diagnostics/recommendation-{metrics,request-baseline,pipeline-boundaries}.md`（仍被 `.gitignore:189:docs/` 忽略）。`git diff --stat` = 35 文件 / +1582 −574。这与历史记录不冲突：**产物存在，但从未入库，checkout 一重建就丢**——destination 里「gh 可复跑的实测下降」这一半依然没有落地物。
- **同一 checkout 上有并发 session 在写**：`lib/pages/live/controller.dart`、`lib/pages/live/view.dart`、`lib/features/shielding/live_shielding.dart`、`lib/pages/live/widgets/{live_item_app,live_shield_button}.dart` 等在 2026-10-05 20:57–21:42 被改动（属直播屏蔽那一摊）；`shielding_matcher.dart`/`shielding_models.dart` 也在 20:57–20:58 被改。本 session 一律没碰。
- 探针复现（本 session 实测，Dart 3.13.2，匿名态）：G1 web rcmd 20 条、`"tag` 命中 0；G2 app feed 8 条、`"tag` 命中 0、`"tname` 命中 8（只有分区名）；G3 `/x/web-interface/view/detail/tag` 重复 `bvid` **先发者胜**、逗号与 `%2C` 拼接均 `code=-400`。取回方式：`git fetch origin "+refs/heads/research/*:refs/remotes/origin/research/*"` + `git --work-tree=.wf47 checkout origin/research/rcmd-tag-availability -- tool/probe/login_field_probe.dart`（`.wf47/` 未入库，可删）。

### 历史记录（2026-10-03 那轮，保留；仍然生效的坑）

- `docs/` 被 `.gitignore:189` 整体忽略且从未 `git add -f`，所以旧证据从未入库、票里 `blob/production/docs/diagnostics/*` 链接全部 404。**后续所有票的产物一律 `git add -f` 后再给链接。**
- 本图第一份真正入库的证据：`research/rcmd-tag-availability`，commit `c0e3eff5a` → `414cb2619`，blob `805f646c91fac86a77afe7718ec8c81a2dcf3a7e`。
- 仓库无 git user.name/email → `git commit-tree` 报 `Author identity unknown`；只对单次提交设 `GIT_AUTHOR_NAME/EMAIL`、`GIT_COMMITTER_NAME/EMAIL`（`CometDash77` / `anastasiiaprinling@gmail.com`），别改仓库配置；推证据不搅动工作树时用临时索引 `GIT_INDEX_FILE=.git/dsh-research-index`。
- 测重复 query 参数不能用 `Uri.replace(queryParameters: Map)`（会折叠成单参数、产出假证据），要直发原始 query；pwsh 里 URL 与 regex 一律用单引号包（`&` 会解析失败）。
- #52 进度里「Material UI 包/API 错配导致 `test/features/shielding/*` 无法编译」在 2026-10-03 那轮本树**未复现**（`flutter pub get` 成功，`material_ui` 解析到 `1.1.1`）；该票保持 OPEN，等验证补齐。
- #67 给 #54 的硬约束：目标式不许写「标签请求 ≤ 常数 1」，应写「feed 1 次/页」+「标签请求 = 本页幸存候选去重后未命中缓存的条数/页」；已在 #54 留评论记录（追加式，未改其正文）。



