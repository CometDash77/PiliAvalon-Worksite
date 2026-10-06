# tool/bench — ShieldMatcher 热路径量具与证据（map #47 / 票 #52）

本目录是开发期量具，不被 `lib/` 引用，也不参与 `flutter test`（`test/` 之外）。三个文件：

- `shield_matcher_bench.dart` —— 微基准：固定 72 条规则 × 20 候选，输出每轮 / 单次判定中位数（µs）。
- `_reference_shield_matcher.dart` —— `lib/features/shielding/shielding_matcher.dart` 在
  commit `e998665ab`（票 #52 改造前）的逐字冻结副本。**不得修改**，否则差分等价结论失效。
- `shield_matcher_equivalence.dart` —— 差分夹：同一批 ruleSet / candidate 同时喂给冻结副本与当前实现，
  比较 `visible#blockedBy.id#allowedBy.id#errors(ruleId:message)` 签名。

## 结论速览

| 指标 | 改动前（`e998665ab`） | 改动后 |
| --- | --- | --- |
| 每轮判定中位数（20 候选 × 72 规则） | 530.1 µs | 137.0 µs（−74.2%） |
| 单次 `match` 中位数 | 26.50 µs | 6.85 µs |
| 差分比较 / 不一致 | — | 100,024 / 0 |
| `flutter test test/features/shielding --no-pub` | 269 通过 | 282 通过 |
| `flutter test --no-pub`（全库） | 465 通过 | 478 通过 |
| `flutter analyze --no-pub --no-fatal-infos` | 67 issues | 3 issues |

基线在**未改动的 HEAD** 上采集，环境、负载、量具完全相同。

## 环境前提：必须先给 Flutter SDK 打仓库自带补丁

工具链版本由仓库自锁：`.fvmrc` = `{"flutter":"3.47.2"}`，`pubspec.yaml:25` 同为 `3.47.2`，CI 用
`flutter-version-file: pubspec.yaml` 取同一版本。未打补丁时 `lib/` 大面积编译失败（例如
`lib/common/widgets/text_more/paragraph_more.dart:129` 依赖 `lib/scripts/text_painter.patch` 引入的
`textPainter` getter），此时"套件无法编译"并不代表仓库破损。

```powershell
$env:FLUTTER_ROOT     = '<flutter sdk>'   # 例：D:/flutter-sdk/flutter
$env:GITHUB_WORKSPACE = (Resolve-Path .).Path
lib/scripts/patch.ps1 android
```

Windows 上若脚本找不到 pub cache（默认分支按 `~/.pub-cache` 查找，实际路径是
`%LOCALAPPDATA%\Pub\Cache`），手工等效步骤：

1. 在 SDK 目录 `git reset --hard HEAD`，对 `lib/scripts/` 下 24 个补丁逐个 `git apply --check` +
   `git apply`（android 集合 = 通用 21 个 + `bottom_sheet_android.patch` + `scroll_view.patch` + `navigator.patch`）。
2. 对 `%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\material_ui-1.1.1` 应用 `lib/scripts/material/*.patch`
   （9 个，android 另加 `bottom_sheet_android.patch`）；补丁文件先做 CRLF→LF 归一化。
3. `flutter pub get`。

## 跑法

```powershell
dart run tool/bench/shield_matcher_bench.dart          # 微基准
dart run tool/bench/shield_matcher_equivalence.dart    # 差分等价夹
flutter test test/features/shielding --no-pub          # 屏蔽语义回归套件
flutter test --no-pub                                  # 全库（CI 同款）
flutter analyze --no-pub --no-fatal-infos
```

注意：`dart run` 会向 stderr 打 `Running build hooks...`，PowerShell 会把它包装成 NativeCommandError
并使管道退出码变 1；判断成败看 stdout，不看退出码。

## 差分夹覆盖了什么

- 4000 组随机规则集 × 24 候选（96,000 次比较）。
- 穷举 17 type × 6 mode × 24 pattern × 7 scope = 17,136 条规则的规则集 × 24 候选 × 3 轮，规则实例跨候选复用，
  专门压 rule-identity 缓存。
- 惰性 tokens 自洽：60 组随机规则集 + 穷举规则集 × 24 候选；eager 列表与 provider 并存时 eager 胜出；
  同一 ruleSet/候选重复判定结果稳定。
- provider 调用计数：无 token 规则时不得调用；有 token 规则时每次判定至多一次。
- 边界含非法 regex（`[`）、非法 range（`300..60`、`20..10`）、空 pattern、`both` scope 折叠、
  allow 覆盖 block、disabled 规则。

## 改了什么（保持语义的前提）

1. 规则侧按 `ShieldRule` 实例编译一次：`Expando<_CompiledRule>` 缓存 `pattern.toLowerCase()`、空 pattern 判定、
   enum 归一化、编译好的 `RegExp`、解析好的 `_ParsedRange`（含失败对象；失败同样缓存并原样重抛，
   所以坏规则依旧每次判定报同样的 error）。
2. 规则集侧按 (实例, scope) 缓存 `enabled && scope 匹配` 的规则列表。
3. 候选侧单次判定记忆化：`_MatchContext` 缓存候选值、`toLowerCase`、enum 归一化与分词结果。
4. 适配器惰性分词：`ShieldCandidate` 新增可选 `tokensProvider` / `authorTokensProvider`，
   `shielding_adapters.dart` 的 6 处急切 `_tokens([...])` 改为 provider。
5. 正则提升为 `static final`（matcher 的 enum / token 分隔符与 range 解析正则、适配器的 tag / token 分隔符）。

未采用的早退：找到 block + allow 后提前 return —— 原实现会遍历全部适用规则以收集所有 error，提前返回属于
语义变更；保留完整遍历，只保留原有 scope/globalEnabled 早退，并新增"适用规则列表为空 → 返回
`visibleResult`"（与循环结果等价，不可能产生 error）。

键为对象身份且模型深不可变（`ShieldRuleSet.rules` 是 `List.unmodifiable`，`ShieldRule`/`ShieldRuleSet`
字段全 `final`），缓存不会描述过期数据；`regex`/`range` 仍在 `.any` 之前求值，保留"候选无值也报 pattern
错误"的行为；token 取值链保持"非空 eager → provider（非空）→ 按类型切分原始值"。

## 不覆盖什么

- 真机每页上游请求数（票 #54 的口径）；本机测不到真机请求数，不冒充该口径。
- 真机掉帧 / 首屏耗时（需要设备侧采样）。
- `RecommendationTagEnricher` 的并发合并 / 失败负缓存与 `HomeFeedCommentGate` 的同 aid 缓存
  （票 #49 / #50 声称的成果，在当前仓库中不存在，需另行核实）。

## 附注：为什么证据放在 `tool/bench/` 而不是 `docs/diagnostics/`

本仓库 `.gitignore:189` 忽略整个 `docs/`（`git ls-files docs` 为空），因此 `docs/diagnostics/*.md`
无法随代码进入版本库，任何指向它的验收记录都无法被复核。证据放在与量具同目录的受控文件中。
