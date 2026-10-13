# Fourth surgery on map #47 body. Each old string must match exactly once.
$path = 'D:\Documents\vibe\PiliAvalon-Worksite\.scratch\map47-body.md'
$t = [IO.File]::ReadAllText($path)
if ($t.Contains("`r`n")) { $t = $t.Replace("`r`n", "`n"); 'crlf->lf: True' } else { 'line endings: lf' }
$nl = "`n"

$e1old = '（PR [#76](https://github.com/CometDash77/PiliAvalon-Worksite/pull/76)，合并提交 `c24b5aa9b`，其树与 CI 验证过的 `fc3b6c7f5` 逐字节相同）；不碰 #51 与 #54。'
$e1new = $e1old + $nl + $nl + '- [重做 #49：标签获取统一去重、并发合并与负缓存](https://github.com/CometDash77/PiliAvalon-Worksite/issues/74) — 2026-10-06：产物重做并入库（单提交 `c10a00de7`，基线 `origin/production` @ `c24b5aa9b`；新增 `lib/features/shielding/recommendation_tag_store.dart` 235 行、`shielding_recommend_tag_enricher.dart` 退化为薄层并暴露 `fetchSharedTags()`、`lib/pages/common/common_intro_controller.dart:148-155` 由直调 `UserHttp.videoTags` 改走共享入口、两个测试文件）。远程证据 run 37408586817（`headSha c10a00de7`）三 job 全绿（554 tests passed / analyze 3 issues / Android x86_64 / emulator smoke）；请求数上界的证明在 `test/features/shielding/shielding_recommend_tag_enricher_test.dart:674-718`（K=8、24 槽位只有 8 个不同 bvid，`fetchLog` 长度 ≤ 8 且 `toSet()` 恰为 8）。边界：2026-10-06 已并入 production（PR [#77](https://github.com/CometDash77/PiliAvalon-Worksite/pull/77)，合并提交 `cd2cc65db`，其树与 `c10a00de7` 的树逐字节相同）；不碰 #51 与 #54。'

$e2old = '- [x] 统一并去重标签获取路径'
$e2new = $e2old + '（[#74](https://github.com/CometDash77/PiliAvalon-Worksite/issues/74)，2026-10-06 重做并入库：远程 run 37408586817 三 job 全绿；已并入 production，PR [#77](https://github.com/CometDash77/PiliAvalon-Worksite/pull/77) / `cd2cc65db`）'

$e3old = '## Current status' + $nl + $nl + '### 2026-10-06 第三轮（重做 #53 → #73 入库；#74 在飞）'
$section = @(
    '### 2026-10-06 第四轮（重做 #49 → #74 入库并合入 production；#75 待开）',
    '',
    '- **这次推的是哪张票**：[重做 #49：标签获取统一去重、并发合并与负缓存](https://github.com/CometDash77/PiliAvalon-Worksite/issues/74)（`wayfinder:task`，父图 #47）。#72 的「重做」决议里的第二票：认领 → 闸门诊断 → 实施 → 验收 → 关闭。',
    '- **闸门诊断**：#49 于 2026-10-02 关闭时明写「代码和报告尚未 commit/push」，产物审计确认树上没有（`RecommendationTagEnricher` 只有 30 分钟 TTL 缓存、无在飞合并、无负缓存）→ 判「真实但未入库，按原 spec 重做」。',
    '- **改了什么**（分支 `codex/issue-74-tagenrich-redo`，基线 `origin/production` @ `c24b5aa9b`，单提交 `c10a00de7`）：新增 `lib/features/shielding/recommendation_tag_store.dart`（键 `bvid|cid`、同键在飞合并、失败与空结果 30 秒负缓存、成功 30 分钟、默认 10MB 上限 50MB 按估算字节旧→新驱逐、只存原始标签不存判定结果）；`shielding_recommend_tag_enricher.dart` 退化为薄层并暴露 `fetchSharedTags()` 作为推荐面与详情页共用的唯一入口（幸存者过滤、并发池默认 5、单调用方 3 秒超时、fail-open 语义不变）；`lib/pages/common/common_intro_controller.dart:148-155` 的 `queryVideoTags()` 由直调 `UserHttp.videoTags` 改走共享入口，详情页因此复用推荐面已取的标签；不做单调用方取消。',
    '- **远程证据**：run 37408586817（`headSha c10a00de75ee9955aff30ddb2551ce94dd283f23`）conclusion success；决定性日志 `2026-10-06T03:23:23Z 🎉 554 tests passed.`、`2026-10-06T03:24:02Z 3 issues found. (ran in 38.3s)`（exit 0）；`Build Android x86_64 artifact` 与 `Android emulator runtime smoke` 均 success。',
    '- **本机复跑**：`flutter test --no-pub` 554 通过（exit 0）、`flutter analyze --no-pub --no-fatal-infos` 14 issues / 0 error（多于 CI 的 3 条 info 来自未跟踪的 `tool/probe/login_field_probe.dart`）。',
    '- **并入 production**：PR [#77](https://github.com/CometDash77/PiliAvalon-Worksite/pull/77)（2026-10-06T03:33:31Z）合并提交 `cd2cc65db`，其树与 CI 验证过的 `c10a00de7` 逐字节相同；push 触发的 `ci.yml` run 37409546588 三 job 全绿（`03:35:58Z 🎉 554 tests passed.` / analyze `3 issues found`）。',
    '- **本轮之后的开口**：#75（重做 #50：评论门持续补位 worker + 同 aid 合并 + 成功缓存）是本图「重做」批次的第三票，尚未开工；三票都排在 production 线上。',
    '- **仍然有效的提醒**：本文件 Decisions so far 里 #49 / #50 / #53 三行的产物在树上并不存在；#53 与 #49 已分别重做入库，读那三行时以三处审计说明为准。'
) -join $nl
$e3new = '## Current status' + $nl + $nl + $section + $nl + $nl + '### 2026-10-06 第三轮（重做 #53 → #73 入库；#74 随后落地，见上一节）'

$edits = @(
    @{ name = 'E1'; old = $e1old; new = $e1new },
    @{ name = 'E2'; old = $e2old; new = $e2new },
    @{ name = 'E3'; old = $e3old; new = $e3new }
)

foreach ($e in $edits) {
    $count = ([regex]::Matches($t, [regex]::Escape($e.old))).Count
    if ($count -ne 1) { throw "edit $($e.name): expected exactly 1 match, got $count" }
    $t = $t.Replace($e.old, $e.new)
    "$($e.name): landed ($count)"
}

$enc = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($path, $t, $enc)
"bytes=$((Get-Item $path).Length) chars=$($t.Length) lines=$(($t -split "`n").Count)"
"checks: has37408586817=$($t.Contains('37408586817')) has37409546588=$($t.Contains('37409546588')) hasCD2=$($t.Contains('cd2cc65db')) inFlightGone=$(-not $t.Contains('第三轮（重做 #53 → #73 入库；#74 在飞）'))"
