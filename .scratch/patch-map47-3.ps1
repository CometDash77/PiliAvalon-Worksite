$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$bodyPath = Join-Path $root 'map47-body.md'
$assertPath = Join-Path $root 'assertions3.txt'

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$text = [IO.File]::ReadAllText($bodyPath, [Text.Encoding]::UTF8)
[IO.File]::WriteAllText((Join-Path $root 'map47-body.orig3.md'), $text, $utf8NoBom)
$before = $text
$log = New-Object System.Collections.Generic.List[string]

function Replace-Once {
    param([string]$text, [string]$old, [string]$new, [string]$tag)
    $count = ([regex]::Matches($text, [regex]::Escape($old))).Count
    if ($count -ne 1) { throw "$tag expected exactly 1 occurrence, found $count" }
    $script:log.Add("$tag count=$count")
    return $text.Replace($old, $new)
}

# E1: #71 row -> tail updated with the merge decision
$old1 = '三 job 全绿。合并目标（main / production）留给 YG 定。'
$new1 = '三 job 全绿。合并目标：2026-10-06 经 YG 决定并入 production —— 该批改动随 [重做 #53](https://github.com/CometDash77/PiliAvalon-Worksite/issues/73) 的分支一起进了 PR [#76](https://github.com/CometDash77/PiliAvalon-Worksite/pull/76)，合并提交 `c24b5aa9b`（2026-10-06T02:59:49Z）。'
$text = Replace-Once -text $text -old $old1 -new $new1 -tag 'E1'

# E2: #73 decisions row -> boundary line updated
$old2 = '边界：不合并（等 YG）、不碰 #51 与 #54。'
$new2 = '边界：2026-10-06 经 YG 决定并入 production（PR [#76](https://github.com/CometDash77/PiliAvalon-Worksite/pull/76)，合并提交 `c24b5aa9b`，其树与 CI 验证过的 `fc3b6c7f5` 逐字节相同）；不碰 #51 与 #54。'
$text = Replace-Once -text $text -old $old2 -new $new2 -tag 'E2'

# E3: third-round status bullet -> merge recorded
$old3 = '**分支一律不合并**，并入 production 的时机与方式由 YG 定（他 2026-10-06 给出的顺序：先进 production；等 map 全部完成、验收通过、stable APK 装到机器上无问题，再进 main——方向没反）。'
$new3 = '**2026-10-06 已按 YG 的决定并入 production**：PR [#76](https://github.com/CometDash77/PiliAvalon-Worksite/pull/76) 合并提交 `c24b5aa9b`（其树 = `fc3b6c7f5` 的树，逐字节相同），push 触发的 `ci.yml` run 37406851962 三 job 全绿（539 tests passed / analyze 3 issues）。后续顺序仍按他给的：等 map 全部完成、验收通过、stable APK 装到机器上无问题，再走 production → main（方向没反）。'
$text = Replace-Once -text $text -old $old3 -new $new3 -tag 'E3'

# E4: earlier round's bullet keeps its date, gains a pointer
$old4 = '合并目标（main / production）由 YG 定，本次不合并。'
$new4 = '合并目标（main / production）由 YG 定，本次不合并（后续：同一批改动已随 #73 的分支并入 production，见 Decisions so far 的 #73 一行）。'
$text = Replace-Once -text $text -old $old4 -new $new4 -tag 'E4'

# E5: restore the blank line between the third-round section and the older heading
$pattern = '说明为准。\r?\n### 2026-10-06（#52 存活产物入库'
$m = [regex]::Matches($text, $pattern)
if ($m.Count -ne 1) { throw "E5 expected exactly 1 match, found $($m.Count)" }
$text = [regex]::Replace($text, $pattern, "说明为准。`r`n`r`n### 2026-10-06（#52 存活产物入库")
$log.Add('E5 count=1')

[IO.File]::WriteAllText($bodyPath, $text, $utf8NoBom)

$bytes = [IO.File]::ReadAllBytes($bodyPath)
$header = ($bytes[0..3] | ForEach-Object { $_ }) -join ','
$lines = $text -split "`n"
"bytes = $($bytes.Length)"
"chars = $($text.Length)"
"lines = $($lines.Count)"
"first4 = $header"
$log | ForEach-Object { "landed: $_" }
"remaining merge-pending mentions = $(([regex]::Matches($text, '不合并')).Count)"
"has PR 76 = $($text.Contains('pull/76'))"
"has run 37406851962 = $($text.Contains('37406851962'))"

$old = [IO.File]::ReadAllText((Join-Path $root 'map47-body.orig3.md'), [Text.Encoding]::UTF8)
$oldLines = $old -split "`r?`n"
$newLines = $text -split "`r?`n"
$diff = Compare-Object $oldLines $newLines
"only-in-old = $(($diff | Where-Object SideIndicator -eq '<=').Count)"
"only-in-new = $(($diff | Where-Object SideIndicator -eq '>=').Count)"
