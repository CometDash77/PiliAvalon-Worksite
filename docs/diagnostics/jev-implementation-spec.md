# Jev 个性化推荐筛选 — 可照做实现规格

来源：GitHub `CometDash77/PiliAvalon-Worksite` issue #30 / #31 / #32 / #33 / #34 / #35 / #36 / #37 / #38 / #43 / #59 / #65（正文 + 全部评论）。
生成方式：只读 fetch（`gh issue view`）+ 只读源码核对（production 基线 `3f7d5c83f6c6489d1f87340974dc45bd10743308`，并对照当前工作树）。
引用块 **逐字来自 issue**，块尾标注来源票号。凡 issue 未写死的点一律进第 8 节，不在正文里替它补决策。

> 实现状态事实（动手前必须知道）：#65 的 2026-10-02 进度评论声称已落地 provider / 设置 / evaluator / 接入，但 #65 的 2026-10-06 审计评论与实测一致地否定它 —— 当前工作树 `rg -i 'jev|typesafe|secure_storage' lib` 除生成的 `*.pbjson.dart` base64 噪音外 **零命中**，`lib/` 下没有 `jev*` 目录或文件。设计已定稿，代码尚未存在（或已丢失、待重做）。

---

## 1. 推荐面清单、预 Jev 过滤顺序

### 1.1 在范围内的面（8 个独立开关面）

> "The confirmed scope includes home Web/App recommendations, related videos, hot videos, rankings, and the standalone Live Recommendation page. Jev must receive only candidates that survive every lower-cost existing filter, then make the last decision before rendering."
> — #30 正文

> "the user decided to include both PGC sections explicitly marked “推荐” and BGM/music recommendation lists in Jev screening. Each remains independently controlled by its per-surface switch, alongside the Jev master switch."
> — #43 评论

> "The one-page view presents the Jev master switch, all eight independently controlled recommendation surfaces (home Web/App, related, hot, rankings, Live, PGC “推荐”, and BGM/music)"
> — #35 评论

**八面** = Home Web、Home App、related、hot、rankings、Live、PGC「推荐」、BGM/music；每面一项独立开关 + 一个 master 开关。

### 1.2 逐面的 Dart 入口、上游 API、既有 pre-Jev 顺序、列表状态

「既有阶段顺序」逐字取自 #30 关联的 surface inventory 报告（production 基线）；`file:line` 为本次在**当前工作树**核对到的位置（架构已演进为 `lib/features/shielding/` 流水线，等价语义不变）。

**Home Web**
- 入口：`lib/pages/rcmd/controller.dart:24-28` `RcmdController.customGetData()` → `VideoHttp.rcmdVideoList(freshIdx: page, ps: 20)`
- 上游 API：`VideoHttp.rcmdVideoList`（`lib/http/video.dart:54`）→ `Api.recommendListWeb`（`/x/web-interface/wbi/index/top/feed/rcmd`），WbiSign 签名，参数 `ps` / `fresh_idx` / `brush` / `feed_version: V8`
- 既有顺序：

  > "Keep only goto == av; drop blacklisted owners; map candidate; legacy deterministic RecommendFilter.filter (duration/play/like/derived metrics/title) then ShieldingAdapters.isVisible; fetch detail tags and run tag-only second shield pass (cache, bounded concurrency 5, 3s timeout, fail-open); optional home comment gate (bounded batches, 3s timeout, fail-open); repeat-exposure filter/record." — #30
- 落点：`lib/http/video.dart:71-98` 的 `RecommendationPipeline` + `RecommendationSurfaces.homeFeed()`（`lib/features/shielding/recommendation_surfaces.dart:37-56`）。阶段序 = 取批次快照 → candidateSource → judge → enrichTags → gateComments → recordExposure（`lib/features/shielding/recommendation_pipeline.dart:76-98`）
- 列表状态：`page = 0` 起（`freshIdx` 语义）；`onRefresh()` 归零 `page` 并 `isEnd = false`；`isEnd` 恒 false（无尽流）；`enableSaveLastData` 时 `page == 0` 把上次结果前插（`> 200` 时只取前 50）。**no-backfill：无「被过滤就补拉」逻辑**

**Home App**
- 入口：同一 `RcmdController`（`Pref.appRcmd` 分支） → `VideoHttp.rcmdVideoListApp(freshIdx: page)`
- 上游 API：`VideoHttp.rcmdVideoListApp`（`lib/http/video.dart:105`）→ `Api.recommendListApp`（`/x/v2/feed/index`），带 app-key / buvid / fp_local 等 header
- 既有顺序：

  > "Drop ad cards, unplayable cards, blacklisted owners; optional legacy zone-title gate; legacy RecommendFilter.filter then ShieldingAdapters.isVisible; detail-tag enrichment/second pass; optional home comment gate; repeat-exposure filter/record." — #30
- 落点：`lib/http/video.dart:157-197`（共用 `RecommendationSurfaces.homeFeed()`）
- 原文差异：

  > "Separate endpoint, candidate model, and early eligibility checks from Web; Jev coverage cannot assume one shared raw mapping path." — #30
- 列表状态：与 Home Web 同一 controller 语义

**Related videos（相关视频）**
- 入口：`lib/pages/video/related/controller.dart:23` `VideoHttp.relatedVideoList(bvid: bvid)`（`RelatedController`）
- 上游 API：`Api.relatedList` = `/x/web-interface/archive/related`
- 既有顺序：

  > "Optional legacy related filter (like/view ratio and minimum duration), then ShieldingAdapters.filterRelatedVideos with its independent related-video switch/scope." — #30
- 落点：`lib/http/video.dart:382-386` + `RecommendationSurfaces.relatedVideos()`（`lib/features/shielding/recommendation_surfaces.dart:70-79`）；取列表前置过滤 `relatedVideoCandidates()`（同文件 83-103，受 `applyFilterToRelatedVideos` 控制）
- 原文：

  > "This path does not pass through the home enrichment, comment, or exposure stages. It also serves related-card lists used by autoplay." — #30
- 列表状态：单次加载；无分页流、无 refresh 流

**Hot videos（热门）**
- 入口：`lib/pages/hot/controller.dart:16-18` `VideoHttp.hotVideoList(pn: page, ps: 20)`
- 上游 API：`Api.hotList` = `/x/web-interface/popular`
- 既有顺序：

  > "Drop blacklisted owners; legacy title and like/view gates; optional legacy zone-title gate; recommendation shielding adapter." — #30
- 落点：`lib/http/video.dart:214-243` + `RecommendationSurfaces.hotAndRanking()`（`lib/features/shielding/recommendation_surfaces.dart:60-66`）
- 列表状态：`pn` 分页、`ps = 20`，走 `CommonListController` 标准分页/refresh

**Rankings（排行榜）**
- 入口：`lib/pages/rank/zone/controller.dart` `ZoneController` → 视频分区榜 `getRankVideoList(rid)`；PGC 榜 `pgcRankList` / `pgcSeasonRankList`
- 上游 API：`Api.pgcRank` = `/pgc/web/rank/list`、`Api.pgcSeasonRank` = `/pgc/season/rank/web/list`
- 既有顺序：

  > "UGC rank filters blacklist/title/like-ratio/optional-zone, then recommendation shielding. PGC rank methods map and return rows without those gates or shared shielding. Popular Series/Precious map and return rows without a Jev-equivalent local gate. Treat those ranking variants as separate integration paths." — #30
- 落点：UGC 榜走 `lib/http/video.dart:944-946` 的 `hotAndRanking()`；PGC 榜 / 每周必看 / 入站必刷（`Api.popularSeriesOne` = `/x/web-interface/popular/series/one`、`Api.popularPrecious` = `/x/web-interface/popular/precious`）**当前绕过共享适配器**
- 列表状态：榜单单页为主

**Live（直播推荐区）**
- 入口：`lib/pages/live/controller.dart:167` / `:183` `LiveController.customGetData` → `LiveHttp.liveFeedIndex(pn: page)`；非零分区用 `liveSecondList`
- 上游 API：`Api.liveFeedIndex` = `<liveBaseUrl>/xlive/app-interface/v2/index/feed`
- 既有顺序：

  > "liveFeedIndex returns LiveIndexData with follow/area modules and card-list modules; area browsing is a second endpoint. No calls to RecommendFilter, ShieldingAdapters, or the shared video adapter were found in these live list paths." — #30
- 集成缝（已定）：

  > "the Live-only seam is LiveController page-response handling after low-cost saved-rule filtering and immediately before rendering; the Jev service/provider/question/settings and compact preference summary are shared, while Live adapter and source-page state stay local." — #37 评论
- 列表状态（必须保留）：

  > "Preserved source-pagination, refresh, error, no-backfill, and filtered-empty requirements." — #37 评论

  当前实现（`lib/pages/live/controller.dart`）：`sourcePageCount`（过滤前原始页大小）、`isFilteredEmpty => sourcePageCount > 0`、`autoPagingPaused = removed > 0 && removed == _lastRawPageSize`（整页被隐藏即暂停自动翻页、不回填），用户真实滚动才解除
- 归属：Live 字段映射 / 列表状态细节 **归 #19–22 所有**；#37 明确 quick shielding 由 `#45/#46` 拥有

**PGC「推荐」区**
- 入口：`lib/pages/pgc/controller.dart:136` `PgcController.customGetData()` → `PgcHttp.pgcIndex(...)`；页面在 `lib/pages/pgc_index/`
- 上游 API：`Api.pgcIndexResult` = `/pgc/season/index/result`、`Api.pgcIndexCondition` = `/pgc/season/index/condition`
- 范围限定：

  > "the user decided to include PGC sections explicitly marked “推荐” in Jev screening" — #43 评论
- 既有阶段：**无共享视频屏蔽适配器**，映射后原样返回行

**BGM / music 列表**
- 入口：`lib/pages/music/video/controller.dart:31` `MusicRecommendController` → `MusicHttp.bgmRecommend(musicId)`
- 上游 API：`Api.bgmRecommend` = `/x/copyright-music-publicity/bgm/recommend`（`lib/http/api.dart:946`）
- 既有阶段：**无本地屏蔽门**，映射后直接返回

### 1.3 统一排序规则

> "Run existing deterministic and other lower-cost filters before Jev; Jev is the final screening decision before render." — #65 正文

> "All lower-cost filters run first; Jev is the last decision before rendering. Low-confidence results remain visible, and provider failures also keep the candidate visible." — #34 正文

成本动因：

> "All existing lower-cost deterministic and other inexpensive filters must finish first; Jev evaluates only surviving candidates immediately before rendering. This placement is explicitly cost-driven." — #36 正文

### 1.4 绕过共享适配器的路径

> "Identify paths that bypass shared adapters or would require separate integration." — #30 验收

> "PGC rankings and “每周必看/入站必刷” currently bypass the shared recommendation adapters." — #30 正文

---

## 2. Provider 契约

### 2.1 结论：不靠 key 格式路由（#31）

> "Key-format routing is not guaranteed by the published contracts." — #31 评论

> "OpenRouter official key-management examples show keys beginning `sk-or-v1-`, and its current-key response exposes a masked label with that form … TypeSafe official API reference requires `Authorization: Bearer API_KEY` but does not define a TypeSafe key prefix or machine-readable prefix contract … A prefix heuristic may be an optional early hint for the documented OpenRouter example, but it cannot be the provider decision rule. Unknown, ambiguous, or non-matching input must stop before any provider request and ask the user to choose or correct the provider. Do not try the same key against the other provider." — #31 评论

### 2.2 TypeSafe 直连契约

> "TypeSafe direct contract: `POST https://api.typesafe.ai/v1/systemone`, `Authorization` `Bearer API_KEY`, JSON `{state, model: jev-latest, questions}`. Response returns `model`, `answers` keyed by question id, and `usage`; Noul returns noul in [0,1], while Choice and Score additionally return probabilities and confidence. Official errors include 401 invalid or missing key, 422 validation, 429 rate limit, and 529 overload" — #31 评论

> "TypeSafe documents independent parallel questions in one request, a shared state evaluated once, token usage, current Jev 1.13 input price of $0.042/M, and limits on total and per-question context. It also documents that Noul returns a yes-probability rather than a separate confidence field, that Chinese/CJK accuracy is lower than English, and that irrelevant or adversarial state can reduce quality." — #36 评论

### 2.3 OpenRouter 契约

> "OpenRouter Jev contract: `POST https://openrouter.ai/api/alpha/decisions`, `Authorization` `Bearer OPENROUTER_API_KEY`, JSON with the same typed-decision shape but an OpenRouter model id such as `typesafe/jev-1.13` or `~typesafe/jev-latest`. The official OpenRouter model page documents this endpoint and model id … OpenRouter official Jev guide shows raw response can also include `id`, `provider`, and `usage.cost`; its SDK uses `alpha.decisions`, not chat completions" — #31 评论

> "OpenRouter's Jev route has a separate Decisions contract and endpoint-specific data policies; check current pricing, limits, and retention for the selected provider before release." — #36 评论

### 2.4 归一化与 pin 语义

> "Normalize both providers into one internal Jev result, retaining Noul probability and Choice or Score confidence where present; do not assume Noul has a separate confidence field." — #31 评论

> "Pin the OpenRouter model id if reproducibility matters; jev-latest and ~typesafe/jev-latest track moving aliases." — #31 评论

> "Validate the threshold and batch strategy against locally labeled data; pin `typesafe/jev-1.13` for reproducibility." — #59 评论

**`typesafe/jev-1.13` 是什么** —— #31 只有一句直接说明：

> "an OpenRouter model id such as `typesafe/jev-1.13` or `~typesafe/jev-latest`" — #31 评论

即：**OpenRouter 侧的模型 id 字符串**，钉在「请求 JSON 的 model 字段」这一层；不是 Dart 包名、不是 semver 版本、也不对应 TypeSafe 直连的 `model: jev-latest`。#59 实测回显：

> "returned `typesafe/jev-1.13-20260917`、Noul `0.01`，用量 373 输入 / 23 输出 token，费用 `$0.000015666`" — #59 评论

（同一密钥打 TypeSafe 直连收到 401；未重试、未跨 provider 试密钥。）

### 2.5 路由与验证硬规则

> "1. Store an explicit provider selection with the key; use format checks only for UX hints. 2. Validate by calling only the selected provider endpoint, never by blind cross-provider fallback. 3. Treat 401 or invalid key, malformed input, unsupported model, timeout, 429 or 529, or other request failure as Jev unavailable; preserve the already-filtered recommendation and surface a corrective or status message." — #31 评论

> "- Provider selection is explicit: the user must select TypeSafe or OpenRouter when saving or changing a Jev key. A key format must never silently determine the provider. - A documented `sk-or-v1-` format may be shown as a pending OpenRouter suggestion, but the user must confirm the suggested provider before saving or validating. Other formats do not automatically select a provider. - If a key-format hint conflicts with the selected provider, show a mismatch warning and require the user to reconfirm the selected provider before validation. Do not silently switch providers. - If the format is unknown, explain that the provider cannot be inferred and require manual provider selection before validation. - Validation calls only the selected and confirmed provider's Jev endpoint. On failure, show that provider's error and corrective guidance; never switch providers or try the same key against the other provider." — #38 评论

### 2.6 密钥配给

> "Each app user brings and explicitly selects their own provider key; never bundle the Hermes validation key. Without a usable key, keep candidates visible and prompt for correction." — #59 评论

> "Users explicitly select a provider and supply their own key. Never bundle or reuse the Hermes validation key; never retry a key against another provider." — #65 正文

---

## 3. 原子 Jev 问题

### 3.1 逐字问题文本（#34 评论，用户确认）

> “这条推荐的核心内容，是否与用户明确不喜欢的主题存在足够强的语义匹配，以至于应在展示前屏蔽？”

### 3.2 上下文边界

> "最少候选上下文：标题；候选数据已提供时，附短简介或内容分类/标签，缺失则省略。不传作者、视频 ID、链接或长篇元数据。" — #34 评论

> "最少偏好上下文：最多 20 个未过期的负面主题及各自的大致次数。只发送摘要，不发送原始“不感兴趣”记录或可识别单条视频的信息。" — #34 评论

> "send only the minimum candidate fields and compact explicit-negative summary; do not send browsing/watch history, account identifiers, or cookies" — #65 正文

### 3.3 置信度语义与「实质性匹配」

> "只有当负面主题实质上属于候选核心内容时才屏蔽。偶然提及、泛化标签或仅共享单一元素都属于弱关联，应保留候选。低置信度判断以及 Jev/API 运行失败也保留候选。" — #34 评论

### 3.4 判定形态

> "Use one binary Noul decision for each candidate, only after all cheaper filters, and only hide on a conservative locally validated threshold." — #36 评论

> "keep an item visible on weak/ambiguous evidence, low Noul probability, timeout, request failure, missing answer, or deadline expiry." — #36 评论

**必须保持可见（多票一致）**：弱/模糊关联、低 Noul 概率、低置信度、超时、请求失败、缺答、deadline 到期、密钥缺失/无效、provider 错误、429/529、安全存储不可用。（#34 / #36 / #31 / #32 / #59 / #65）

---

## 4. 本地显式负反馈档

#33 用户确认的全部规则逐字：

> "- Record only an explicit “不感兴趣” or dislike tap on a recommendation card. Exclude video-detail dislikes, comment interactions, skipping, and viewing behavior.
> - On-device, use the marked card's title, displayed recommendation reason, and the reason the user selected when available. Summarize into short preference themes.
> - Retain themes and approximate counts only. Do not retain per-video rows, video IDs, links, or uploader details.
> - Keep at most 20 themes; when full, remove the theme with the oldest new feedback. Delete a theme after six months without new feedback.
> - Let the user delete one theme or clear the entire profile.
> - Platform “撤销” only cancels the platform feedback; it does not decrement the local theme count. The user may delete the theme or clear the profile.
> - When Jev is off, pause new collection; retain the profile and continue its expiry timers. Resume collection when Jev is turned on." — #33 评论

| 决策项 | issue 原文要求 | 落点 |
|---|---|---|
| 收集触发点 | 仅推荐卡片上的显式「不感兴趣」/点踩 | 卡片动作回调，非视频详情页 |
| 排除项 | 视频详情页点踩、评论互动、跳过、观看行为一律不收集 | 采集入口唯一化 |
| 卡片字段 | 卡片标题、卡片展示的推荐理由、用户选中的反馈理由（可用时） | 三字段输入摘要 |
| 保留物 | 仅「主题 + 大致次数」；不存单条视频行、视频 ID、链接、UP 主 | 存储模型 |
| 主题 schema | **未给出字段名与类型**（见 G-05） | — |
| 上限 | 最多 20 个主题 | 满额淘汰 |
| 淘汰 | 满 20 时淘汰「最近新增反馈最早」的主题（LRU by last-new-feedback） | — |
| 过期 | 主题 6 个月无新反馈即删除 | — |
| 删除 | 支持删单个主题 + 清空全部 | UI 两个入口 |
| 平台撤销 | 只取消平台侧反馈，**不回滚本地计数** | 撤销动作不得写本地档 |
| Jev 关闭 | 暂停新采集，**保留档与过期计时**，重开恢复采集 | 状态机 |

---

## 5. 设置页

### 5.1 布局决议

> "The user reviewed the prototype in two steps and chose **A, the one-page settings layout**, as the preferred direction. They then asked for the privacy disclosure to be **collapsed by default with a concise summary and expandable details**." — #35 评论

> "The one-page view presents the Jev master switch, all eight independently controlled recommendation surfaces (home Web/App, related, hot, rankings, Live, PGC “推荐”, and BGM/music), explicit TypeSafe/OpenRouter selection, key entry with a local format hint, validation feedback, the invalid-key state, and the unavailable-secure-store state. It states that format recognition does not choose a provider and that a key is never retried with the other provider. Privacy details describe the minimum candidate fields and compact local explicit-negative summary, plus the excluded browsing/watch history, account identifiers, cookies, raw dislike records, and unrelated metadata." — #35 评论

字段清单与默认分组顺序（**顺序本身 issue 未逐条给出，见 G-13**；以下取 #35 枚举序）：

1. **Jev master 开关**（全局）
2. **逐面开关 × 8**：Home Web / Home App / 相关视频 related / 热门 hot / 排行榜 rankings / 直播 Live / PGC「推荐」/ BGM-music
3. **Provider 选择**：TypeSafe | OpenRouter 显式二选一（不得由格式决定）
4. **密钥输入**：本地格式提示（hint only）
5. **验证反馈**：校验结果态
6. **无效密钥态**
7. **安全存储不可用态**
8. **合规声明两条**：格式识别不选 provider；密钥绝不用另一 provider 重试
9. **隐私详情**：默认折叠，折叠态一句摘要，展开给完整字段说明

### 5.2 Provider / Key 状态机

issue 固定了**行为**，未固定**逐字文案**（见 G-11 / G-14）。行为逐条（来源 #31 / #32 / #38）：

| 状态 | 触发 | 必须的行为 |
|---|---|---|
| 未设置 | 无 key、未选 provider | Jev 不可用；候选保持可见并提示修正（#59） |
| 格式可疑（`sk-or-v1-`） | 输入匹配 OpenRouter 文档形态 | 显示为「pending OpenRouter suggestion」，保存/校验前用户必须确认（#38） |
| 格式未知 | 任何未匹配形态 | 说明无法推断 provider，要求手动选择后才能校验（#38） |
| 格式与已选 provider 冲突 | hint ≠ selection | 显示 mismatch 警告，要求重新确认所选 provider 后再校验；**不得静默切换**（#38） |
| 无效密钥 | 选中所属 provider 返回 401 / malformed / unsupported model | 视为 Jev unavailable，保留已过滤候选，给该 provider 的纠正提示（#31） |
| 限流 / 过载 / 超时 | 429 / 529 / timeout | 同「无效密钥」的 fail-open 处置（#31、#36） |
| 安全存储不可用 | 安全存储缺失 / 锁定 / 报错 | Jev credential 停用，不路由凭据，候选保持可见，给可恢复提示，**绝不退回明文 Hive**（#32） |
| 校验通过 | 选中 provider 端点返回成功 | 记录可用；不跨 provider 交叉验证（#31、#38） |

### 5.3 隐私陈述必须覆盖的排除清单

> "Do not send complete browsing/watch history, account identifiers, cookies, raw dislike records, author, video ID, URL, or long metadata." — #35「Current decisions」

---

## 6. 阈值与批大小

### 6.1 请求策略

> "Prefer small bounded batches with a keyed question per candidate and a shared compact preference state; keep an item visible on weak/ambiguous evidence, low Noul probability, timeout, request failure, missing answer, or deadline expiry. Per-item requests remain the isolation-first fallback. The report recommends testing batch sizes 3–5 as a hypothesis, not a provider guarantee." — #36 评论

### 6.2 数值

| 项 | 值 | 性质 | 来源 |
|---|---|---|---|
| 批上限 | 3–5 | **假设，待本地标注数据验证**，非 provider 保证 | #36 |
| 逐条请求 | 保留为 isolation-first 回退 | 已定 | #36 |
| 局部标注验证 | 用本地标注数据验证阈值与 batch | 已定 | #59、#65 |
| 隐藏精度下限 | `>=98% hide precision` | 「Starting safety target」起始安全目标 | #36 |
| 置信度下限 | `P(match) >= 0.95` | **仅候选**，必须通过 holdout 目标才算数 | #36 |
| 输入价格参考 | Jev 1.13 `$0.042/M` input tokens | 官方文档价（会变） | #36 |
| 实测成本参考 | 373 in / 23 out token，`$0.000015666` | 单条合成判断实测 | #59 |
| context 限制 | 文档说有 total / per-question 限制，**未给数值** | 未给 | #36（G-15） |
| 超时值 | **未给** | — | G-10 |
| 并发上限 | **未给** | — | G-10 |
| 重试策略 | **未给**（只说失败即 fail-open） | — | G-10 |

### 6.3 评估方法与指标

> "Proposed evaluation: a held-out, human-labelled multilingual set; report hide precision, recall, false-hide rate, coverage, calibration, end-to-end P50/P95 latency, input tokens per survivor, request count, and cost. Starting safety target: >=98% hide precision; a possible P(match) >=0.95 cutoff is only a candidate and must meet the holdout target. On any uncertain or unavailable result, preserve the recommendation. Do not retain or send complete history, raw dislike events, account identifiers, cookies, video IDs, URLs, uploader details, API keys, or unrelated long metadata; keep logs aggregate-only and exclude prompts, preferences, and per-item decisions." — #36 评论

### 6.4 CI 验收门

> "CI verifies lower-cost-before-Jev ordering; settings, per-surface switches, and secure storage; local preference lifecycle; and candidate visibility on missing/invalid keys, low confidence, timeout, rate limit, secure-store failure, and provider errors." — #65 正文

### 6.5 五阶段切片（#65 正文）

1. **Provider and settings foundation** — 显式 provider 选择、安全存储可用性/密钥状态、master 与逐面开关。门：单测证明不回退到另一 provider、不导出密钥、安全存储不可用时 Jev 停用。
2. **Local preference profile** — 只收集推荐卡片显式点踩；落地本地摘要、过期/删除、Jev 关闭暂停。门：模型/存储测试覆盖采集边界、生命周期、删除、暂停/恢复。
3. **Shared evaluator and fail-open pipeline seam** — 固定问题、最小输入、确定性过滤在前、有界 Jev 评估在渲染前最后。门：排序、弱/低置信匹配、密钥缺失/无效、超时、限流、provider 失败下候选仍可见。**此切片建立 `#51` 合并前必需的 attachment point。**
4. **Non-Live recommendation adapters** — 接入 Home/Web/App、related、hot、ranking、PGC、music，各自独立开关。门：逐面测试 + 本地标注阈值/批次验证 + 精确 SHA CI 通过。
5. **Live adapter** — 只在 PR #46 合入 production 后；在 `LiveController` 接入并保留既有页面状态契约。门：精确 merged SHA 相关回归套件 + Android smoke，含 no-backfill 与 filtered-empty 正确性。

原文约束：

> "Keep one standalone work-package issue as the only Jev entry point; slices are its internal sequence, not separate entry-point issues." — #65 正文

> "Do not merge #51's dual-filter engine before this work package closes." — #65 正文

---

## 7. 安全存储

### 7.1 决策

> "**Decision:** use the federated `flutter_secure_storage` API behind one Jev key-store boundary across the five shipped targets. Keep provider selection (non-secret) in ordinary settings if desired, but keep the credential only in secure storage. Do not store it in Hive: Worksite exports the whole Hive settings map and sends that payload through WebDAV backup/restore." — #32 评论

### 7.2 平台注意点

> "The shipped targets are Android, iOS, Windows, macOS, and Linux; there is no Flutter Web runner or Web build workflow. The current app uses Hive CE for settings, contains no secure-storage dependency or secure-store adapter, and has no Jev key to migrate." — #32 评论

> "Android package docs require API 23+, so check Worksite's Flutter-provided minSdk before integration. iOS uses Keychain; macOS uses Keychain and should avoid a shared keychain group unless needed because that can affect provisioning/distribution. Windows requires C++ ATL and stores encrypted values with a platform-protected key. Linux uses Secret Service/libsecret and a desktop keyring; Worksite's Linux build workflow will need libsecret build/runtime packaging support. Web is outside current Worksite support; the plugin's WebCrypto backend is experimental and LocalStorage-based, so Jev key entry should remain unavailable if a Web target is ever introduced until separately reviewed." — #32 评论

### 7.3 失败与生命周期

> "If secure storage is missing, locked, or errors, keep Jev disabled and do not route the credential; leave candidates visible under the map's fail-open filtering rule and show a recoverable message. Never fall back to plaintext Hive. The current baseline has no Jev secret, so no migration is needed. Future “clear key” / “reset all settings” must delete the secure-store item; exports and restores must omit it." — #32 评论

> "Before shipping, implementation must verify platform signing/build prerequisites and read/write/delete behavior on each supported target." — #32 评论

### 7.4 当前工作树实测（与 #32 写就时不同）

- `pubspec.yaml:178` **已声明** `flutter_secure_storage: ^11.2.0`（direct dependency）。**与 #32 的「no current secure-storage package」不一致** —— 该依赖应是随某次实现加进来的，后又随实现一起消失（见 #65 审计）。
- `pubspec.lock` 已解析出联邦实现：`flutter_secure_storage`、`flutter_secure_storage_darwin`、`flutter_secure_storage_linux`、`flutter_secure_storage_platform_interface`、`flutter_secure_storage_web`、`flutter_secure_storage_windows`
- Android：`android/app/build.gradle.kts:22,32,33` `compileSdk = 37` / `minSdk = flutter.minSdkVersion` / `targetSdk = 37`；`android/app/src/main/AndroidManifest.xml:40,42` `android:allowBackup="false"` + `android:fullBackupContent="false"`
- Linux：`linux/flutter/CMakeLists.txt:25-27` 只 `pkg_check_modules` 了 `gtk+-3.0` / `glib-2.0` / `gio-2.0`，**没有 libsecret**；该项当前缺失
- 键名：**issue 从未给出任何键名字符串**（G-02）；代码库亦无 Jev 键名常量

---

## 8. 缺口清单（issue 未明确 / 必须由你补决策）

1. **G-01 — `typesafe/jev-1.13` 只有一句话定义，缺「钉在哪一层」的正式说明。** #31 只说它是 OpenRouter 的 model id 示例；未说明客户端是否还要同时钉 TypeSafe 直连的 `model`、是否要记录回显的日期化快照 id（如 `typesafe/jev-1.13-20260917`）、升级与回滚策略全无。issue 未明确。
2. **G-02 — 安全存储键名未定义。** #32 决定用 `flutter_secure_storage` 与「one Jev key-store boundary」，但从未给出键名字符串、命名空间或分 provider 的键布局。issue 未明确。
3. **G-03 — `state`（共享偏好上下文）的 JSON 形状与体积上限未定义。** #31 只列请求字段名 `{state, model, questions}`；#34 只规定「最多 20 个未过期主题 + 大致次数」；#36 承认存在 total / per-question context 限制但未给数值。字段名、序列化格式、超限截断策略均无。issue 未明确。
4. **G-04 — `questions` 的 id / 键名与「keyed question per candidate」的 key 生成规则未定义。** #36 说「a keyed question per candidate」，但 key 用什么（aid / bvid / 序号）从未定；批内 key 冲突、跨批重复 key 的行为也未定。issue 未明确。
5. **G-05 — 本地负反馈主题的 schema（字段名与类型）未定义。** #33 只给行为约束（标题、展示推荐理由、用户选中理由 → 摘要主题 + 大致次数），从未给出字段名、类型、「大致次数」的量化方法（分桶？取整？）、主题去重/合并规则。issue 未明确。
6. **G-06 — 「六个月过期」的时间基准与结算时机未定义。** #33 说「Delete a theme after six months without new feedback」，但未说基准是「最后一次新反馈」还是「主题创建」、未说过期何时结算（读取时惰性 / 定时 / 下次采集）、未说过期中的主题是否仍参与请求。issue 未明确。
7. **G-07 — 采集触发点存在票间张力，未收敛。** #33 说「a recommendation card」，#65 进度评论把范围收窄成「仅首页推荐卡片显式点踩」，而 #43 又把 PGC 与 BGM 纳入 Jev 面。八个面里哪些面的卡片提供「不感兴趣」动作、哪些面的点踩进本地档，无票裁决。issue 未明确。
8. **G-08 — 推荐理由字段的来源与缺失降级未定义。** #33 要求用「displayed recommendation reason」，但各面模型字段不同（`rcmd_reason` 只在部分原始 json 里），字段名与取不到时的降级路径均无。issue 未明确。
9. **G-09 — 阈值与批大小从未被本地数据验证。** #36 明说 3–5 是 hypothesis、`P(match) >= 0.95` 只是候选；#59/#65 把验证列为验收门；#65 进度评论承认「仓库里未找到可用的本地标注集，因此阈值与 batch 的数据验收还未完成」。标注集来源、标注口径、holdout 划分规则全无。issue 未明确。
10. **G-10 — 超时值、批内并发、重试策略均无数值。** #36 只说「deadline expiry」「timeout」要保持可见，没给 deadline 秒数、每批并发上限、是否重试。（#65 进度评论提到实现时的「最多 5 条/批 + 单轮 8 秒 deadline」，但那是实现自述、未被任何决策票确认，且该实现已不在树上。）issue 未明确。
11. **G-11 — 设置页逐字文案与逐态 UI 形态未定义。** #38 定了五个行为分支（显式选择 / pending suggestion / mismatch warning / unknown format / 只打选中 provider），但每个状态的显示文案、控件形态、「重新确认」的交互（二次弹窗？复选框？）均无。issue 未明确。
12. **G-12 — 逐面开关的准确名称（i18n key 与用户可见标签）未定义。** #35 只用英文描述性短语枚举八面，没有最终显示名、命名 key 或分组标题。issue 未明确。
13. **G-13 — 一页式布局的字段分组顺序未定义。** #35 定了「one-page layout」并枚举必须出现的元素，但从未给出从上到下的显示顺序、分组边界、错误信息挂载位置。issue 未明确。
14. **G-14 — 隐私折叠态的「concise summary」逐字文本未定义。** #35 只说 collapsed by default + concise summary + expandable details，摘要那句话的内容没有票写死。issue 未明确。
15. **G-15 — provider 侧配额/限流/context 上限数值未采集。** #36 明确要求「check current pricing, limits, and retention for the selected provider before release」，该检查从未执行、结果从未记录。issue 未明确。
16. **G-16 — 「面开关关着」时是否采集与计时未定义。** #33 只回答「Jev off」暂停采集且继续计时；「master 开着、该面开关关着」是否采集与计时无票回答；删档后是否重建、清空档是否也清平台侧记录也未定。issue 未明确。
17. **G-17 — PGC 与 BGM 面的判定输入边界未细化。** #43 只说纳入并由独立开关控制；PGC 的「推荐」区与音乐列表都不是标准视频候选模型（`PgcIndexItem` / `BgmRecommend`），它们能提供哪些候选字段（标题 / 分类 / 标签）、缺字段时 Jev 是否跳过，均无票说明。issue 未明确。
18. **G-18 — PGC 榜、每周必看、入站必刷的归属未收口。** #30 明确它们「bypass the shared recommendation adapters」且「Treat those ranking variants as separate integration paths」，但没有任何票决定这三条是否属于 Jev 的「rankings」面、还是留在范围外。issue 未明确。
19. **G-19 — Live 面集成依赖 PR #46 合入，当前未合。** #37 与 #65 都要求「only after PR #46 merges to production」；未合并前 Live 切片不得开始。issue 未明确（依赖外部票状态）。
20. **G-20 — 设置页「用户手动触发的合成样例连接验证」是否为规格的一部分未定义。** #65 进度评论提到实现了该手动校验，但没有任何决策票要求或禁止它，也未定义发送什么、是否消耗额度、返回什么。issue 未明确。
21. **G-21 — 结果缓存与去重策略未定义。** 同一候选在多面/多次渲染重复出现时是否复用判定、缓存 TTL、失效触发（偏好档变更 / 面开关变更）均无票。现有屏蔽流水线已有同类先例（`HomeFeedCommentGate.decisionCacheTtl = 30s` / `decisionCacheMaxEntries = 256`），但没有任何票把该模式扩展到 Jev。issue 未明确。
22. **G-22 — 整批候选全被隐藏时的行为未定义。** #37 只对 Live 保留了 filtered-empty 与 no-backfill 语义；Home / 热榜 / 排行 / PGC / music 在整页被 Jev 屏蔽时是显示空态、停止自动翻页、还是不回填，无票作答。issue 未明确。
23. **G-23 — 「聚合-only 日志」的落点与保留期未定义。** #36 要求「keep logs aggregate-only and exclude prompts, preferences, and per-item decisions」，但日志载体（本地 / 遥测）、聚合粒度、保留时长均无。issue 未明确。
24. **G-24 — 密钥变更 / 切换 provider 时本地偏好档如何处理未定义。** 切换 provider 是否清空档、是否要求重新确认，无票作答。issue 未明确。
25. **G-25 — 「二元 Noul 判定」与「保留 Choice/Score confidence」的关系未收口。** #36 定的是二元 Noul；#31 又要求归一化时「retaining Noul probability and Choice or Score confidence where present」。用哪种问题类型（Noul / Choice / Score）作为产品问题、confidence 缺失时阈值如何退化，无票统一。issue 未明确。

---

## 附：引用到的关键源码坐标

- 推荐流水线：`lib/features/shielding/recommendation_pipeline.dart:61-98`（`RecommendationPipeline.run()` 六阶段）
- 面策略：`lib/features/shielding/recommendation_surfaces.dart:35-104`（`homeFeed` / `hotAndRanking` / `relatedVideos` / `relatedVideoCandidates`）
- 纯判定层：`lib/features/shielding/recommendation_filter.dart`；兼容门面：`lib/utils/recommend_filter.dart:126-213`
- 标签富集（既有边界先例）：`lib/features/shielding/shielding_recommend_tag_enricher.dart:14-36`（并发默认 5、钳制 [1,10]；超时默认 3s、钳制 [1,10]；失败 fail-open）
- 评论门（既有边界先例）：`lib/features/shielding/home_feed_comment_gate.dart:35-43`（`defaultMaxConcurrent = 3`、`defaultTimeout = 3s`、`decisionCacheTtl = 30s`、`decisionCacheMaxEntries = 256`）
- 曝光去重：`lib/features/exposure_tracker/exposure_tracker.dart:100-101`（窗口来自 `SettingBoxKey.repeatExposureWindowDays`）
- Live 页状态契约：`lib/pages/live/controller.dart:24-53, 78-134, 161-226`
- 存储键命名先例：`lib/utils/storage_key.dart:3`（`SettingBoxKey`）、`:277-284`（`ShieldBoxKey`，形如 `piliavalon.shielding.v1.rules`）
