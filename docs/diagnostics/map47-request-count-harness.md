# map #47 量具：#79 每页上游请求数实测（复建 #57 量具 + 跨页去重采样）

票：#79 「实测每页上游请求数：复建请求量具 + 跨页去重采样」（父图 #47）
量具：test/features/shielding/recommendation_request_count_test.dart
基线参照：#48 记录的历史基线（列表 1 次/页 + 标签 20 次/页，20 条候选一页）

## 这份证据回答什么

`#74`（标签去重 / 在飞合并）与 `#75`（评论判定合并 + 30s 判定缓存）落地后，推荐面
**每页上游请求数**相对「每页各自取数」的口径下降多少，以及下降随页间重复率怎么变。

## 量具边界（口径诚实声明）

只在**传输端点**换成计数假件，判定与调度全部走已入库产品类：

- 走产品代码：`RecommendationPipeline.run()`（列表 → judge → 标签 → 评论 → 曝光 的固定阶段顺序）、
  `RecommendationSurfaces.homeFeed()` 的 `judge` 与 `gateComments` 闭包、
  `RecommendationTagEnricher` + `RecommendationTagStore`、`HomeFeedCommentGate`。
- 被替换的只有两处传输端点：`fetchTags`（产品装配用 `defaultVideoTagFetch`）与
  `loader`（产品装配用 `_defaultLoader`）——两者在 lib/features/shielding/recommendation_surfaces.dart:42/:48
  处是真实网络调用，单测里必须注入。
- **列表请求（取这一页的候选）按常数 1 次/页计，不经过本量具量测**；表里列名写作「+1 取列表」。
- **曝光阶段（`recordExposure`）没有装配**：它不发上游请求（需要 GStorage.exposureTracker box）。
- 量具里没有 `clearSharedCachesFirst` 这类隐式开关；两个口径都显式调用 `_clearSharedCaches()` 起步。

## 复跑命令

```
flutter test test/features/shielding/recommendation_request_count_test.dart --reporter expanded
```

（本机 flutter 不在 PATH：`& 'D:\flutter-sdk\flutter\bin\flutter.bat' test ...`）

2026-10-06 在 production tip 822ba20f1 的树上运行：**4 个测试全绿**。

## 结果（每页 20 条候选）

| 第 2 页重复率 | 口径 | 第 1 页 标签/评论 | 第 2 页 标签/评论 | 第 2 页上游请求数（+1 取列表） |
| --- | --- | --- | --- | --- |
| 0% | A 逐页清缓存 | 20/20 | 20/20 | 41 |
| 0% | B 缓存存活 | 20/20 | 20/20 | 41 |
| 25% | A 逐页清缓存 | 20/20 | 20/20 | 41 |
| 25% | B 缓存存活 | 20/20 | 15/15 | 31 |
| 50% | A 逐页清缓存 | 20/20 | 20/20 | 41 |
| 50% | B 缓存存活 | 20/20 | 10/10 | 21 |
| 75% | A 逐页清缓存 | 20/20 | 20/20 | 41 |
| 75% | B 缓存存活 | 20/20 | 5/5 | 11 |
| 100% | A 逐页清缓存 | 20/20 | 20/20 | 41 |
| 100% | B 缓存存活 | 20/20 | 0/0 | 1 |

- 口径 A = 每页清掉进程级共享缓存（#74/#75 落地前「每页各自取数」的行为）。
- 口径 B = 缓存存活（当前 production 行为）。
- 断言同时覆盖：判定没有砍掉候选（两页 survivors 都是 20），所以请求数差异只来自跨页复用。
- 口径 B 的规律：第 2 页上游 = 1 + 2×(20 − repeats)，重复候选一次上游都不打
  （`RecommendationTagStore` 成功缓存 30min、`HomeFeedCommentGate` 判定缓存 30s / 256 条，
  两处都是**进程级共享**实例）。

## 口径 A 与 #48 基线的对齐

- 标签阶段：20 次/页 与 #48 记录一致（列表 1 + 标签 20 = 21）。
- 评论阶段：20 次/页 **不在 #48 的基线里**——#48 采样时评论门（#75）还没进管线。
  所以 A 口径整页 41 = 21（#48 口径）+ 20（#75 之后新增的阶段），
  这是「量具口径对齐」，不是「#48 基线被整体复现」。
- 冷缓存边界测试：30s 后评论判定重新发起 20 次，标签成功缓存（30min）仍为 0 次。

## 没测到的（本票的边界）

- **真实页间重复率**：表里是 0/25/50/75/100% 的扫描；production 上真实重复率需要线上或设备侧数据，
  本量具给不出，因此「每页上游请求数下降多少」在真实刷流场景下的具体值仍未实测。
- 列表请求本身、曝光阶段、以及评论/标签响应体的真实耗时都不在量测范围。
- 只覆盖 `homeFeed` 面：`hotAndRanking` 与 `relatedVideos` 面在产品定义里不挂标签/评论阶段
  （`enrichTags`/`gateComments` 为 null，已有结构断言），即每页上游 0 次 + 1 次列表。

## 与 #54 的关系

`#54` 的关闭依据是 YG 人工装机验收豁免（「每页上游请求数有实测下降」这一条未做量测）。
本票不推翻那次豁免：它给的是**单元级、可复跑的机制量测**，不是设备侧验收。

## 产物

- 量具：test/features/shielding/recommendation_request_count_test.dart
- 证据：docs/diagnostics/map47-request-count-harness.md（docs/ 被 .gitignore:189 整体忽略，需 `git add -f`）
- 分支：research/map47-request-count-harness（基于 production tip 822ba20f1）
