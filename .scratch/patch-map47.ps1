$ErrorActionPreference = 'Stop'
$p = Join-Path $PSScriptRoot 'map47-body.md'
$b = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
$nl = if ($b.Contains("`r`n")) { "`r`n" } else { "`n" }

function ReplOnce([string]$text, [string]$old, [string]$new, [string]$tag) {
  $n = ([regex]::Matches($text, [regex]::Escape($old))).Count
  if ($n -ne 1) { throw "[$tag] anchor count = $n (expected exactly 1)" }
  return $text.Replace($old, $new)
}

# ---------- E1: Decisions so far, #52 line tail ----------
$e1old = '；产品改动仍未入库，对照装置落在 research/shieldmatcher-hotpath-bench。'
$e1new = '；产品改动 2026-10-06 已入库、远程 CI 全绿（见 [把幸存的 #52 热路径改动入库并取得远程可复跑证据](https://github.com/CometDash77/PiliAvalon-Worksite/issues/71)）；早先落在 research/shieldmatcher-hotpath-bench 的是同一对照装置的另一个变体。'
$b = ReplOnce $b $e1old $e1new 'E1'

# ---------- E2: append #71 line to Decisions so far ----------
$e2tail = '；早先落在 research/shieldmatcher-hotpath-bench 的是同一对照装置的另一个变体。'
$e2anchor = $e2tail + $nl + $nl + '## Not yet specified'
$e2line = '- [把幸存的 #52 热路径改动入库并取得远程可复跑证据](https://github.com/CometDash77/PiliAvalon-Worksite/issues/71) — 2026-10-06：#52 唯一幸存的那批产品改动（`shielding_matcher.dart`、`shielding_adapters.dart`、`shielding_models.dart` + 新测试 `test/features/shielding/shielding_matcher_cache_test.dart`）以 `c58df090f` 入库，`tool/bench/` 那套量具（README + 冻结参照 `_reference_shield_matcher.dart` + `shield_matcher_bench.dart` + `shield_matcher_equivalence.dart`）以 `f9a19d353` 入库，推在 `codex/issue-52-shield-matcher-hot-path`；远程证据 = `gh workflow run ci.yml --ref codex/issue-52-shield-matcher-hot-path` → run 37397549674（`headSha f9a19d353`）conclusion success：`Flutter verification` 478 passed + analyze 3 issues、Android x86_64 构建、emulator runtime smoke 三 job 全绿。合并目标（main / production）留给 YG 定。'
$e2new = $e2tail + $nl + $e2line + $nl + $nl + '## Not yet specified'
$b = ReplOnce $b $e2anchor $e2new 'E2'

# ---------- E3: Plan checklist, add #71 line after the #52 line ----------
$e3old = '- [x] 优化 ShieldMatcher 判定热路径（[#52](https://github.com/CometDash77/PiliAvalon-Worksite/issues/52)，2026-10-05 关闭：语义等价 + 同负载每页中位耗时 ≈1.98x）'
$e3new = $e3old + $nl + '- [x] 把幸存的 #52 热路径改动入库并取得远程可复跑证据（[#71](https://github.com/CometDash77/PiliAvalon-Worksite/issues/71)，2026-10-06 关闭：远程 run 37397549674 三 job 全绿）'
$b = ReplOnce $b $e3old $e3new 'E3'

# ---------- E4: new Current status subsection ----------
$e4anchor = '## Current status' + $nl + $nl + '### 2026-10-05 第二轮（#52 收工）'
$e4block = @'
### 2026-10-06（#52 存活产物入库 + 产物审计）

- **这次推的是哪张票**：[把幸存的 #52 热路径改动入库并取得远程可复跑证据](https://github.com/CometDash77/PiliAvalon-Worksite/issues/71)。#52 的验收当时全过，但产品改动只停在本地 git 索引里（未提交、无 ref 指向），从 2026-10-03 16:26 起躺了三天。本次把它和量具一起提交、推分支、再用 `workflow_dispatch` 取了远程证据。结论 gist 见 Decisions so far 的 #71 一行。
- **本图第一次有了可远程复跑的产品产物**：分支 `codex/issue-52-shield-matcher-hot-path` @ `f9a19d353`（基于 `e998665ab`）。远程 `flutter test --no-pub` = 478 passed、`flutter analyze --no-pub --no-fatal-infos` = 3 issues（exit 0）、Android x86_64 构建与 emulator runtime smoke 均 success，整条墙钟约 10 分钟。合并目标（main / production）由 YG 定，本次不合并。
- **产物审计（重要：读上面的 Decisions so far 前先看这条）**：那三行「统一并去重标签获取路径」「评论门请求归并进页内热路径」「拆开过滤模块耦合，收敛调用点」读起来像现状，但**它们描述的产物在版本库和工作树里都不存在**——`lib/features/shielding/recommendation_pipeline.dart`、`lib/features/shielding/recommendation_filter.dart`、`lib/http/recommendation_screening.dart`、`lib/utils/recommendation_metrics.dart` 对所有 refs、所有 commit、甚至整个 `D:\Documents\vibe` 递归搜索都零命中；`docs/diagnostics/recommendation-{metrics,request-baseline,pipeline-boundaries}.md` 从未进过版本库（库里只有 #67 那份）；树上能看到的 `lib/features/shielding/shielding_recommend_tag_enricher.dart:73` 只有 30 分钟 TTL 缓存、没有并发合并、没有失败/空负缓存，`lib/features/shielding/home_feed_comment_gate.dart:21` 只有 `maxConcurrent = 3` 与 3 秒超时、没有按 aid 缓存。2026-10-05 记录的「35 文件 / +1582 −574 未提交改动」今天也已不在：`git worktree list` 只有一个工作树、`git stash list` 为空、`git rev-list --all --objects` 零命中、`git fsck --no-reflogs` 只有一个 dangling tree 且无 blob。本图至今的产物流失都发生在「验证完了但没提交」这一步，#52 是唯一幸存的一批。
- **这一发现已立票**：[消失的削减：标签缓存、评论门、共享管线的产物不在库里，重做还是划出范围](https://github.com/CometDash77/PiliAvalon-Worksite/issues/72)（HITL / `wayfinder:grilling`，无认领）——要真人定：这三票按「需重做」还是「划出本图范围」记、重开票的形态、以及「先提交、再验证」是否写进 Notes 当硬约束。**在它定下来之前，别把 Decisions so far 里那三行当作树上现状。**
- **frontier**：本次仍无「open ∧ 无认领 ∧ 阻塞已闭」的子票——[合并双过滤引擎并消灭重复判定](https://github.com/CometDash77/PiliAvalon-Worksite/issues/51) 被 map 外的 [Implement Jev-Based Personalized Recommendation Screening](https://github.com/CometDash77/PiliAvalon-Worksite/issues/65) 闸住，[锁定性能/请求数验收基线](https://github.com/CometDash77/PiliAvalon-Worksite/issues/54) 被 #51 闸住。新毕业的 #72 不依赖 #65，是当下唯一可推进的实质决定。
- **本次本机复跑**：`flutter test test/features/shielding --no-pub` = 282 通过；`flutter test --no-pub` = 478 通过；`dart run tool/bench/shield_matcher_equivalence.dart` = sweep 17,136 条规则、100,024 次比较 0 mismatch；`dart run tool/bench/shield_matcher_bench.dart` = 每轮中位 177.0 µs（min 127.0 / max 440.3）。**注意量具变体**：#52 票里的 909.6 → 459.4 µs 与本次入库 README 记的 530.1 → 137.0 µs 出自两个不同的对照变体（另一支是 `_legacy_shielding_matcher.dart`，冻结自 `0d4be712a`），不是同一组数字，别混用；同进程 A/B 的可复跑化留给 #54。
'@
$e4block = $e4block -replace "`r?`n", $nl
$e4new = '## Current status' + $nl + $nl + $e4block.TrimEnd("`r", "`n") + $nl + $nl + '### 2026-10-05 第二轮（#52 收工）'
$b = ReplOnce $b $e4anchor $e4new 'E4'

# ---------- write back ----------
[System.IO.File]::WriteAllText($p, $b, (New-Object System.Text.UTF8Encoding($false)))

# ---------- verify ----------
$v = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
"bytes = " + ([System.IO.FileInfo]$p).Length
"chars = " + $v.Length
"lines = " + ($v -split "`r?`n").Count
"E1 landed: " + $v.Contains('产品改动 2026-10-06 已入库')
"E2 landed: " + $v.Contains('- [把幸存的 #52 热路径改动入库并取得远程可复跑证据]')
"E3 landed: " + $v.Contains('- [x] 把幸存的 #52 热路径改动入库并取得远程可复跑证据')
"E4 landed: " + $v.Contains('### 2026-10-06（#52 存活产物入库 + 产物审计）')
"old sentence gone: " + (-not $v.Contains('产品改动仍未入库'))
