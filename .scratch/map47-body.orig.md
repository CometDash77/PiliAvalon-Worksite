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

- [统一并去重标签获取路径](https://github.com/CometDash77/PiliAvalon-Worksite/issues/49) — 推荐面与详情页共用 BVID+CID 标签缓存；相同键并发合并，失败/空结果负缓存 30 秒。

- [评论门请求归并进页内热路径](https://github.com/CometDash77/PiliAvalon-Worksite/issues/50) — 评论门保留在标签之后；同 aid 判定做短期缓存，持续补位的并发池削减批次等待且不增加每页请求。

- [拆开过滤模块耦合，收敛调用点](https://github.com/CometDash77/PiliAvalon-Worksite/issues/53) — 五面收敛为一条共享管线、每批次注入一次规则/旧配置，纯判定不读存储；本地 500 测试通过，详情及交付边界见票。

- [推荐面标签能否内联随推荐接口返回，或按批一次取回](https://github.com/CometDash77/PiliAvalon-Worksite/issues/67) — 结论 **③ 都不行**：两个在用推荐接口的 item 都没有标签字段（web `feed/rcmd`、app `x/v2/feed/index` 实测 `"tag` 命中 0），`/x/web-interface/view/detail/tag` 只认单个 bvid（反向排序对照验证）→ **标签阶段不能删、也不能压成 1 次**，杠杆只能是前置规则命中率与缓存/去重；证据 [recommendation-tag-inline-availability.md](https://github.com/CometDash77/PiliAvalon-Worksite/blob/research/rcmd-tag-availability/docs/diagnostics/recommendation-tag-inline-availability.md)（本图第一份真正入库的证据）。

- [优化 ShieldMatcher 判定热路径](https://github.com/CometDash77/PiliAvalon-Worksite/issues/52) — 判定结果与改动前逐候选逐规则等价（20 候选 × 72 规则 0 mismatch），同负载每页中位耗时 909.6 → 459.4 µs（≈1.98x），完整 shielding 套件 +322 全绿；产品改动仍未入库，对照装置落在 research/shieldmatcher-hotpath-bench。

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
- [x] 统一并去重标签获取路径
- [x] 评论门请求归并进页内热路径
- [ ] 合并双过滤引擎并消灭重复判定
- [x] 优化 ShieldMatcher 判定热路径（[#52](https://github.com/CometDash77/PiliAvalon-Worksite/issues/52)，2026-10-05 关闭：语义等价 + 同负载每页中位耗时 ≈1.98x）
- [x] 拆开过滤模块耦合，收敛调用点
- [ ] 锁定性能/请求数验收基线
- [x] 查清推荐面标签能否内联 / 批量取回（结论 ③ 都不行）
- [x] 带登录凭据复核标签内联与批量能力（[#68](https://github.com/CometDash77/PiliAvalon-Worksite/issues/68)，HITL）— 2026-10-05 关闭：真人决定自行按需实测，本票撤出本图（登录态实测未做）

## Current status

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
