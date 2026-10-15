## 这是什么

map [#47](https://github.com/CometDash77/PiliAvalon-Worksite/issues/47) 的一轮落地：把推荐/筛选管线收敛成一条共享管线（票 [#73](https://github.com/CometDash77/PiliAvalon-Worksite/issues/73)，重做已关闭的 #53），并把唯一幸存的 ShieldMatcher 热路径改动（票 [#52](https://github.com/CometDash77/PiliAvalon-Worksite/issues/52) / [#71](https://github.com/CometDash77/PiliAvalon-Worksite/issues/71)）一并带上。基线就是 `production` 当前尖端 `d0820e6c9`，所以这是一个纯线性叠加、内容确定的合并。

## 提交

| 提交 | 内容 |
| --- | --- |
| `76afd9843` | `perf(shielding): cache compiled rule/rule-set/candidate work in ShieldMatcher (#52)` — `shielding_matcher.dart` / `shielding_adapters.dart` / `shielding_models.dart` + 新测试 `test/features/shielding/shielding_matcher_cache_test.dart` |
| `6485a9446` | `test(bench): add ShieldMatcher hot-path harness and frozen pre-change reference (#52)` — `tool/bench/README.md`、`_reference_shield_matcher.dart`、`shield_matcher_bench.dart`、`shield_matcher_equivalence.dart` |
| `7d84f671c` | `refactor(recommendation): route five recommendation surfaces through one shared filter pipeline (#73)` — 13 文件 +1579/−305 |
| `fc3b6c7f5` | `test(bench): keep the frozen reference exhaustive on the production line (#73)` — 冻结参照件补 `ShieldRuleType.roomId` 分支（`production` 新增该枚举值后原参照件成了非穷举开关，会让 CI 的 analyze 直接报 error） |

## 改了什么

- 新增 `lib/features/shielding/recommendation_filter.dart`（无 IO 纯判定）、`recommendation_filter_config.dart`（`@immutable` 配置）、`recommendation_pipeline.dart`（`RecommendationBatch` + 固定 6 步 `supplyBatch → candidateSource → judge → enrichTags → gateComments → recordExposure`）、`recommendation_surfaces.dart`（`homeFeed` / `hotAndRanking` / `relatedVideos` 三个面）、`shielding_runtime.dart`（单一注入点 + 每批次只读一次规则与 Pref）。
- `lib/http/video.dart` 五个调用点收敛到这条管线：首页 Web、首页 App、热门、相关视频、排行。
- `lib/utils/recommend_filter.dart` 旧静态入口保留为转发 shim（判定表达式全部搬到纯层，shim 只保留旧的短路顺序，原因写在文件内注释）。
- 新增 `test/features/shielding/recommendation_pipeline_test.dart`（674 行，覆盖每批单次快照、阶段顺序固定、后续阶段只见存活候选、空列表走完全程、面未提供阶段不被调用、各面作用域与总开关短路、注入点优先级等）。

## 证据

- 远程：`gh workflow run ci.yml --ref codex/issue-73-pipeline-redo` → run **37405131412**（`headSha fc3b6c7f51646e677ef63d0f34a2337dee284728`）conclusion **success**：`Flutter verification`（`539 tests passed`、analyze `3 issues found` exit 0）、`Build Android x86_64 artifact`、`Android emulator runtime smoke` 三 job 全绿。
- 本机：`flutter test --no-pub` 539 通过；`flutter analyze --no-pub --no-fatal-infos` 0 error；差分夹 18,144 条规则 × 100,024 次比较 **0 mismatch**；`tool/bench/shield_matcher_bench.dart` 每轮中位 148.7 µs。
- 语义不变性：五面的屏蔽语义与改造前逐位一致——旧守卫 `!enabled || !ruleSet.globalEnabled || items.isEmpty` 原样返回，等价于 `ShieldMatcher` 内部的 `isScopeEnabled`（其第一行就是 `if (!globalEnabled) return false;`）；相关视频旧路径本来就没有 `filterTitle`，新实现保持一致；热门/排行的候选源顺序（blackMids → filterTitle → filterLikeRatio → zone）未变。

## 合入与后续

- base = `production`。由于 `production` 尖端就是本分支的基线，合并后树内容与 CI 验证过的 `fc3b6c7f5` 完全一致；合入后推 `production` 会再触发一次 `ci.yml`（`push` 分支含 `production`）。
- PR 目标为 `production` 时不会自动跑 CI（`ci.yml` 的 `pull_request.branches` 只有 `main`），所以上面的 run 是用 `workflow_dispatch` 在同一个 sha 上跑的。因此**合并前**的 CI 证据以那次 run 为准。
- 不含：`#51`（合并双过滤引擎）、`#54`（锁定性能/请求数验收基线）——两者仍被 map 外的 [#65](https://github.com/CometDash77/PiliAvalon-Worksite/issues/65) 闸住，本 PR 不碰。
- 与本 PR 同源的另外两批产物（`#74` 标签获取去重/并发合并/负缓存、`#75` 评论门 worker/缓存）在另外的分支上，将各自单独提 PR。
