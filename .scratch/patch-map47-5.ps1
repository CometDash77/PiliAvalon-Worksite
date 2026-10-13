$ErrorActionPreference = 'Stop'
$path = (Resolve-Path .scratch/map47-body.md).Path
$t = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
$t = $t.Replace("`r`n", "`n")

function Replace-Once([string]$src, [string]$old, [string]$new, [string]$tag) {
  $count = ([regex]::Matches($src, [regex]::Escape($old))).Count
  if ($count -ne 1) { throw "$tag matched $count times (expected 1)" }
  Write-Host "$tag landed ($count)"
  return $src.Replace($old, $new)
}

# E1: Decisions so far -- append the #75 row after the #74 row
$e1old = 'PR [#77](https://github.com/CometDash77/PiliAvalon-Worksite/pull/77)，合并提交 `cd2cc65db`，其树与 `c10a00de7` 的树逐字节相同）；不碰 #51 与 #54。'
$e1new = @'
PR [#77](https://github.com/CometDash77/PiliAvalon-Worksite/pull/77)，合并提交 `cd2cc65db`，其树与 `c10a00de7` 的树逐字节相同）；不碰 #51 与 #54。
- [重做 #50：评论门持续补位 worker、同 aid 合并与成功缓存](https://github.com/CometDash77/PiliAvalon-Worksite/issues/75) — 2026-10-06：产物重做并入库（单提交 `28afe2151`，基线 `origin/production` @ `cd2cc65db`；`lib/features/shielding/home_feed_comment_gate.dart` +264/−28 把固定分批屏障换成持续补位 worker 池 + 同 aid in-flight 合并 + 30 秒 / 256 条成功判定缓存（策略键 = 评论配置 + 屏蔽规则 + ReplyGrpc 过滤开关），失败/超时/`Error` 一律不缓存且条目保留（fail-open）；`lib/features/shielding/recommendation_surfaces.dart` 未动，阶段顺序仍是「标签富集 → 评论门」）。远程证据 run 37412617335（`headSha 28afe2151`）三 job 全绿（569 tests passed / analyze 3 issues / Android x86_64 / emulator smoke）；本次新增 15 条用例且测试文件纯新增（原 5 条用例逐字未动）。边界：2026-10-06 已并入 production（PR [#78](https://github.com/CometDash77/PiliAvalon-Worksite/pull/78)，合并提交 `822ba20f1`，其树与 `28afe2151` 的树逐字节相同）；不碰 #51 与 #54。
'@
$t = Replace-Once $t $e1old $e1new 'E1'

# E2: Plan -- annotate the comment gate line
$e2old = '- [x] 评论门请求归并进页内热路径'
$e2new = '- [x] 评论门请求归并进页内热路径（[#75](https://github.com/CometDash77/PiliAvalon-Worksite/issues/75)，2026-10-06 重做并入库：远程 run 37412617335 三 job 全绿；已并入 production，PR [#78](https://github.com/CometDash77/PiliAvalon-Worksite/pull/78) / `822ba20f1`）'
$t = Replace-Once $t $e2old $e2new 'E2'

# E3: Current status -- insert the 5th round section, retitle the 4th round heading
$e3old = '### 2026-10-06 第四轮（重做 #49 → #74 入库并合入 production；#75 待开）'
$e3new = @'
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
'@
$t = Replace-Once $t $e3old $e3new 'E3'

# E4: Decisions so far -- mark the #50 audit row as landed
$e4old = '已按同一决定重做为 [#75](https://github.com/CometDash77/PiliAvalon-Worksite/issues/75)。**'
$e4new = '已按同一决定重做为 [#75](https://github.com/CometDash77/PiliAvalon-Worksite/issues/75)，并于 2026-10-06 重做入库（`28afe2151`，run 37412617335 三 job 全绿）、并入 production（PR [#78](https://github.com/CometDash77/PiliAvalon-Worksite/pull/78) / `822ba20f1`）。**'
$t = Replace-Once $t $e4old $e4new 'E4'

$t = $t.Replace("`r`n", "`n")
[IO.File]::WriteAllText($path, $t, (New-Object System.Text.UTF8Encoding($false)))

$bytes = (Get-Item $path).Length
$lines = ($t -split "`n").Count
Write-Host "crlf->lf done"
Write-Host "bytes=$bytes chars=$($t.Length) lines=$lines"
Write-Host "checks: hasRun37412617335=$($t.Contains('37412617335')) hasRun37413823756=$($t.Contains('37413823756')) hasPR78=$($t.Contains('pull/78')) hasMerge822=$($t.Contains('822ba20f1')) fifthRound=$($t.Contains('第五轮')) oldHeadingGone=$(-not $t.Contains('#75 待开'))"
