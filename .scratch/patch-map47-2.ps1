$ErrorActionPreference = 'Stop'

$p = Join-Path $PSScriptRoot 'map47-body.md'
$orig = Join-Path $PSScriptRoot 'map47-body.orig2.md'

$t = [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8)
[IO.File]::WriteAllText($orig, $t, (New-Object Text.UTF8Encoding($false)))

function Replace-Once([string]$text, [string]$old, [string]$new, [string]$tag) {
  $n = ([regex]::Matches($text, [regex]::Escape($old))).Count
  if ($n -ne 1) { throw "$tag : expected exactly 1 match, found $n" }
  return $text.Replace($old, $new)
}

# E1: #49 行降级 + 指向 #74
$t = Replace-Once $t `
  '- [统一并去重标签获取路径](https://github.com/CometDash77/PiliAvalon-Worksite/issues/49) — 推荐面与详情页共用 BVID+CID 标签缓存；相同键并发合并，失败/空结果负缓存 30 秒。' `
  '- [统一并去重标签获取路径](https://github.com/CometDash77/PiliAvalon-Worksite/issues/49) — 推荐面与详情页共用 BVID+CID 标签缓存；相同键并发合并，失败/空结果负缓存 30 秒。 **2026-10-06 产物审计：上述产物不在版本库也不在工作树（`lib/features/shielding/shielding_recommend_tag_enricher.dart` 只有 30 分钟 TTL，无并发合并、无负缓存）；结论仍有效，实施按 YG 的决定重做为 [#74](https://github.com/CometDash77/PiliAvalon-Worksite/issues/74)。**' `
  'E1'

# E2: #50 行降级 + 指向 #75
$t = Replace-Once $t `
  '- [评论门请求归并进页内热路径](https://github.com/CometDash77/PiliAvalon-Worksite/issues/50) — 评论门保留在标签之后；同 aid 判定做短期缓存，持续补位的并发池削减批次等待且不增加每页请求。' `
  '- [评论门请求归并进页内热路径](https://github.com/CometDash77/PiliAvalon-Worksite/issues/50) — 评论门保留在标签之后；同 aid 判定做短期缓存，持续补位的并发池削减批次等待且不增加每页请求。 **2026-10-06 产物审计：产物不在版本库也不在工作树（`lib/features/shielding/home_feed_comment_gate.dart` 只有 `maxConcurrent = 3` 与 3 秒超时，无按 aid 缓存）；已按同一决定重做为 [#75](https://github.com/CometDash77/PiliAvalon-Worksite/issues/75)。**' `
  'E2'

# E3: #53 行降级 + 已被 #73 取代
$t = Replace-Once $t `
  '本地 500 测试通过，详情及交付边界见票。' `
  '本地 500 测试通过，详情及交付边界见票。 **2026-10-06 产物审计：当时那批产物从未入库；已重做成 [#73](https://github.com/CometDash77/PiliAvalon-Worksite/issues/73) 并入库（分支 `codex/issue-73-pipeline-redo`，远程 CI run 37405131412 三 job 全绿、539 测试通过）。**' `
  'E3'

# E4: #52 行补 production 线复跑事实
$t = Replace-Once $t `
  '早先落在 research/shieldmatcher-hotpath-bench 的是同一对照装置的另一个变体。' `
  '早先落在 research/shieldmatcher-hotpath-bench 的是同一对照装置的另一个变体；2026-10-06 该批改动已 rebase 到 `origin/production` 线并入 `codex/issue-73-pipeline-redo`（`76afd9843` + `6485a9446`），production 线复跑中位 148.7 µs/轮（与 459.4 µs 不是同一量具变体，别混用）。' `
  'E4'

# E5: Decisions so far 追加 #73 一行
$t = Replace-Once $t `
  '合并目标（main / production）留给 YG 定。' `
  ("合并目标（main / production）留给 YG 定。" + "`n`n" + '- [重做 #53：把五面手写筛选管线收敛成一条共享管线](https://github.com/CometDash77/PiliAvalon-Worksite/issues/73) — 2026-10-06：产物重做并入库（4 提交 `76afd9843` / `6485a9446` / `7d84f671c` / `fc3b6c7f5`，基线 = `origin/production` @ `d0820e6c9`）；远程证据 run 37405131412（`headSha fc3b6c7f5`）三 job 全绿（539 tests passed / analyze 3 issues / Android x86_64 / emulator smoke），本机差分夹 100,024 次比较 0 不一致。边界：不合并（等 YG）、不碰 #51 与 #54。') `
  'E5'

# E6: Plan 勾上 #53 那一项
$t = Replace-Once $t `
  '- [x] 拆开过滤模块耦合，收敛调用点' `
  '- [x] 拆开过滤模块耦合，收敛调用点（[#73](https://github.com/CometDash77/PiliAvalon-Worksite/issues/73)，2026-10-06 重做并入库：远程 run 37405131412 三 job 全绿）' `
  'E6'

# E7: Current status 顶部插入本轮小节
$sec = @'
### 2026-10-06 第三轮（重做 #53 → #73 入库；#74 在飞）

- **这次推的是哪张票**：[重做 #53：把五面手写筛选管线收敛成一条共享管线](https://github.com/CometDash77/PiliAvalon-Worksite/issues/73)（`wayfinder:task`，认领 → 闸门诊断 → 实施 → 验收 → 关闭）。#72 的决议是「重做」，本轮先做掉三票里的第一票。
- **落在哪条线上**：整条分支 rebase 到 `origin/production`（`d0820e6c9`）——本地 `production` 引用停在 `aef19ec34` = tag `v2.1.5+5524`，已落后远程两个提交（`df31356a9` live 快速屏蔽 + PR #70 合并）。rebase 时 `lib/features/shielding/shielding_matcher.dart` 撞上真冲突（#52 把 `_valuesForRule` 换成 `_rawValues` 开关，production 在同一处加了 `roomId`），解法 = 取 #52 版，再把 production 的 roomId 搬进新开关（`lib/features/shielding/shielding_matcher.dart:165`）。
- **冻结参照件必须补一行**：`tool/bench/_reference_shield_matcher.dart` 原先只按 main 冻结，枚举多了 `roomId` 后成非穷举开关、编译报 error（会让 CI 的 analyze 直接失败）。补入逐字镜像 production 的两行，其余一字未动；差分夹按 `ShieldRuleType.values` 穷举，sweep 规则数 17,136 → 18,144，反而把 `roomId` 的等价性证明进来了（100,024 次比较 / 0 不一致）。
- **远程证据**：run 37405131412（`headSha fc3b6c7f51646e677ef63d0f34a2337dee284728`）conclusion success；`Flutter verification` → `🎉 539 tests passed.`、analyze `3 issues found`（exit 0）；`Build Android x86_64 artifact`、`Android emulator runtime smoke` 均 success。
- **本机复跑**：`flutter test --no-pub` 539 通过（exit 0）、`flutter analyze --no-pub --no-fatal-infos` 14 issues / 0 error、差分夹 100,024 次比较 / 0 mismatch、bench 每轮中位 148.7 µs。
- **本轮之后的开口**：#74（重做 #49：标签获取去重 + 同键并发合并 + 失败/空负缓存）正在 `codex/issue-74-tagenrich-redo` 上实施；#75（重做 #50：评论门持续补位 worker + 同 aid 合并 + 成功缓存）待开；三票都排在 production 线上。**分支一律不合并**，并入 production 的时机与方式由 YG 定（他 2026-10-06 给出的顺序：先进 production；等 map 全部完成、验收通过、stable APK 装到机器上无问题，再进 main——方向没反）。
- **仍然有效的提醒**：本文件 Decisions so far 里 #49 / #50 / #53 三行的产物在树上并不存在，本轮只把 #53 这一票重做并入库，读那三行时以本轮与上一轮的两条审计说明为准。

'@
$t = Replace-Once $t '### 2026-10-06（#52 存活产物入库 + 产物审计）' ($sec + '### 2026-10-06（#52 存活产物入库 + 产物审计）') 'E7'

[IO.File]::WriteAllText($p, $t, (New-Object Text.UTF8Encoding($false)))

$b = [IO.File]::ReadAllBytes($p)
"bytes = $($b.Length)"
"chars = $($t.Length)"
"lines = $(($t -split "`n").Count)"
"first4 = $($b[0..3] -join ',')"
"E1 landed: $($t.Contains('决定重做为 [#74]'))"
"E2 landed: $($t.Contains('重做为 [#75]'))"
"E3 landed: $($t.Contains('已重做成 [#73]'))"
"E4 landed: $($t.Contains('production 线复跑中位 148.7'))"
"E5 landed: $($t.Contains('2026-10-06：产物重做并入库'))"
"E6 landed: $($t.Contains('[#73](https://github.com/CometDash77/PiliAvalon-Worksite/issues/73)，2026-10-06 重做并入库'))"
"E7 landed: $($t.Contains('### 2026-10-06 第三轮（重做 #53 → #73 入库；#74 在飞）'))"
"E3 marker: $($t.Contains('当时那批产物从未入库；已重做成 [#73]'))"

$d = Compare-Object ([IO.File]::ReadAllLines($orig, [Text.Encoding]::UTF8)) ([IO.File]::ReadAllLines($p, [Text.Encoding]::UTF8))
"only-in-old: $(($d | Where-Object SideIndicator -eq '<=').Count)"
"only-in-new: $(($d | Where-Object SideIndicator -eq '=>').Count)"
