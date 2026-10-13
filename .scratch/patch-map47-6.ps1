$ErrorActionPreference = 'Stop'
$base = $PSScriptRoot
$in = Join-Path $base 'map47-body6.md'

$t = [IO.File]::ReadAllText($in, [Text.Encoding]::UTF8)
$t = $t -replace "^`u{FEFF}", ''
$t = $t.Replace("`r`n", "`n")
$lines = [System.Collections.ArrayList]@($t -split "`n")

# Predicate based (no wildcard patterns: lines contain '[' which -like treats specially)
function FindOne([scriptblock]$pred, [string]$label) {
    $hits = @()
    for ($i = 0; $i -lt $lines.Count; $i++) { if (& $pred $lines[$i]) { $hits += $i } }
    if ($hits.Count -ne 1) { throw "$label matched $($hits.Count) line(s), expected exactly 1" }
    return $hits[0]
}

$iDest = FindOne { param($l) $l.Contains('各推荐面的每页上游请求计数有实测下降') } 'Destination sentence'
$iPlan = FindOne { param($l) $l.StartsWith('- [ ]') -and $l.Contains('锁定性能/请求数验收基线') } 'Plan row for #54'
$iCS = FindOne { param($l) $l -eq '## Current status' } 'Current status header'
$iDec = FindOne { param($l) $l -eq '## Decisions so far' } 'Decisions header'

$iDecEnd = -1
for ($i = $iDec + 1; $i -lt $lines.Count; $i++) { if ($lines[$i].StartsWith('## ')) { $iDecEnd = $i; break } }
if ($iDecEnd -lt 0) { throw 'Decisions section end not found' }
$iDecLast = $iDecEnd - 1
while ($iDecLast -gt $iDec -and $lines[$iDecLast].Trim() -eq '') { $iDecLast-- }

$destNote = '> **2026-10-06 注**：Destination 末句「各推荐面的每页上游请求计数有实测下降」这一项经 YG 人工装机验收后按豁免关闭（pre-release `2.1.5-822ba20f1+5535`），**未做量测**——见 Current status 第六轮。'

$row54 = '- [锁定性能/请求数验收基线](https://github.com/CometDash77/PiliAvalon-Worksite/issues/54) — 2026-10-06：按 YG 的人工装机验收关闭（pre-release `2.1.5-822ba20f1+5535` / tag `map47-recommendation-pipeline.822ba20f1.37419405258` / run 37419405258），**原定的每页请求数与阶段耗时前后对比未量测**（#48 的基线产物从未入库、#51 未落地），属人工豁免而非成绩单；结构削减只有单元级证据（标签同键合并 ≤ K、评论门同 aid 合并与补位 worker 受控对照）。'

$plan54 = '- [x] 锁定性能/请求数验收基线（[#54](https://github.com/CometDash77/PiliAvalon-Worksite/issues/54)，2026-10-06 人工装机验收关闭；原定的请求数/耗时前后对比**未量测**，属人工豁免，见 Current status 第六轮）'

$sec6 = @(
    '### 2026-10-06 第六轮（#54 人工装机验收关闭；本图仅剩 #51）',
    '',
    '- **本轮动作**：YG 在真机上安装本图产出的 pre-release 并判定通过，指示「算 #54 通过」→ [#54](https://github.com/CometDash77/PiliAvalon-Worksite/issues/54) 已于 2026-10-06T05:50:46Z 关闭（结票评论 id `IC_kwDOSn1pPM8AAAABZj0Oew`）。',
    '- **pre-release 身份**：tag `map47-recommendation-pipeline.822ba20f1.37419405258`（[release](https://github.com/CometDash77/PiliAvalon-Worksite/releases/tag/map47-recommendation-pipeline.822ba20f1.37419405258)），版本 `2.1.5-822ba20f1+5535`，提交 `822ba20f1`，构建 run [37419405258](https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/37419405258)（workflow_dispatch / ref `production` / 只构建 Android）全绿；四个 APK（arm64-v8a 24.4MB、armeabi-v7a 24.3MB、x86_64 25.3MB、universal 66.3MB），签名证书指纹全部 `0DB8F8B964EC8778AA69CA12BC017276826062193F66A8DF9F0A14C64AF47051`（同 applicationId `com.example.piliplus`，可覆盖安装在既有正式版上）。',
    '- **`#54` 的关闭是豁免不是量测**：原验收要求的「每页上游请求数（按面）/ 标签请求数 / 评论请求数 / 首屏可见耗时 / 过滤阶段耗时」前后对比表**不存在**——#48 的基线文档从未入库（2026-10-06 产物审计），且本票的阻塞票 #51 仍未落地。既有证据只到结构属性与单元级：标签同键合并与缓存（`test/features/shielding/shielding_recommend_tag_enricher_test.dart:674-718` 断言 K 个不同 bvid → 请求数 ≤ K）、评论门同 aid 合并与补位 worker 受控对照（`test/features/shielding/home_feed_comment_gate_test.dart:560-626`，断言 `<700ms`，固定分批参照需 800ms）。',
    '- **人工验收的可见结论**：五个推荐面的屏蔽结果与旧正式版一致（YG 判定通过）；本次 pre-release 里「直播页可屏蔽」是新出现的，但归属 2026-10-05 的 PR [#70](https://github.com/CometDash77/PiliAvalon-Worksite/pull/70)（`df31356a9`，直播推荐屏蔽那条线），不是本图三票；正式版 tag `v2.1.5+5524`（`aef19ec34`，10-02）里没有 `lib/features/shielding/live_shielding.dart`，本图重写的匹配器只是把 production 新增的 `ShieldRuleType.roomId` 分支保住（`lib/features/shielding/shielding_matcher.dart`）。',
    '- **子票现状**：本图子票全部关闭，**仅 [#51](https://github.com/CometDash77/PiliAvalon-Worksite/issues/51) 仍开着**，且被 map 外的 [#65](https://github.com/CometDash77/PiliAvalon-Worksite/issues/65)（Implement Jev-Based Personalized Recommendation Screening，其声称的实现经审计同样不在树上）闸住。',
    '- **产物现状**：三票的产物与 #52 的热路径缓存都在 `production` 尖端 `822ba20f1` 上，可远程复跑；回退点互不牵连：`git revert -m 1 822ba20f1`（#75）/ `-m 1 cd2cc65db`（#74）/ `-m 1 c24b5aa9b`（#73+#52）。',
    '- **留给 YG 的决定**：他定下的进 main 前提是「map 全部完成 + 验收通过 + stable APK 实机无问题」。其中「验收通过」已由本轮人工装机验收满足，「map 全部完成」还差 #51——要么等 #65 关闭，要么明示把 #51 划出本图范围（写进 Out of scope）。',
    '- **给下一 session**：① 不要引用本次实施期间的临时探针数字（未入库）；② 需要正式请求数基线得先复活 #57 量具并重采 #48 基线，另开票；③ #65 关闭前不要动 #51。',
    ''
)

$new = New-Object System.Collections.ArrayList
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($i -eq $iPlan) { [void]$new.Add($plan54) } else { [void]$new.Add($lines[$i]) }
    if ($i -eq $iDest) { [void]$new.Add(''); [void]$new.Add($destNote) }
    if ($i -eq $iDecLast) { [void]$new.Add(''); [void]$new.Add($row54) }
    if ($i -eq $iCS) { [void]$new.Add(''); foreach ($l in $sec6) { [void]$new.Add($l) } }
}

$res = ($new -join "`n")
[IO.File]::WriteAllText($in, $res, (New-Object System.Text.UTF8Encoding($false)))

function CountContains([string]$needle) { return @($res -split "`n" | Where-Object { $_.Contains($needle) }).Count }

"bytes = $([Text.Encoding]::UTF8.GetByteCount($res))"
"chars = $($res.Length)"
"lines = $($new.Count)"
"h3 = $(@($res -split "`n" | Where-Object { $_.StartsWith('### ') }).Count)"
"hit_destnote = $(CountContains '**2026-10-06 注**')"
"hit_row54 = $(CountContains '属人工豁免而非成绩单')"
"hit_plan54 = $(CountContains '- [x] 锁定性能/请求数验收基线')"
"hit_sec6 = $(CountContains '### 2026-10-06 第六轮')"
"old_plan_gone = $(@($res -split "`n" | Where-Object { $_.StartsWith('- [ ]') -and $_.Contains('锁定性能/请求数验收基线') }).Count -eq 0)"
"fifth_still_there = $(CountContains '### 2026-10-06 第五轮')"
"has_run = $(CountContains '37419405258')"
"iDest=$iDest iDecLast=$iDecLast iPlan=$iPlan iCS=$iCS"
