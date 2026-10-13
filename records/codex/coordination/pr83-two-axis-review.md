# PR #83 双轴评审记录（Zen S3）

- 日期：2026-10-07 · 评审人：Codex 协调位（code-review skill 双轴并行 sub-agent）
- 基准点：merge-base c2ee7624b（S1 tip）· head：codex/issue-66-zen-s3@5538353a4（单提交 5538353a4 "feat(zen): hide home chrome via zen toggle and layout predicate (S3)"）
- diff：4 文件 +305/-70（lib/pages/home/view.dart、lib/pages/home/widgets/zen_mode_toggle.dart 新增、lib/pages/main/view.dart、test/features/zen_mode/home_zen_layout_test.dart 新增）
- merge-base = c2ee7624b（S1 tip）→ diff 即 S3 净变更；评审时 PR 状态 OPEN / MERGEABLE / CLEAN；CI workflow_dispatch run 37570552292（ref codex/issue-66-zen-s3，headSha 匹配 5538353a4）已 success（2026-10-07T04:27:58Z）
- 注：本地工作区在 issue-51 分支，两轴代理均以 git diff/show 对分支对象核验，未改任何文件

## Standards（代理报告原文）

【硬违规：0】仓库无 CODING_STANDARDS.md / CONTRIBUTING.md，AGENTS.md 与 docs/agents/* 仅治理流程，无代码风格条款可引。本轴无硬违规。

【判断项（基线 smell 命中，均为轻量）】
1. Speculative Generality（轻）：zen_mode_toggle.dart:37 `const ZenModeToggle({super.key, this.width = kZenModeToggleWidth})`——全仓 5 个使用点（home/view.dart:115、main/view.dart:578、测试 77/107 行）均无参构造，width 无人传。建议内联删除。
2. Primitive Obsession / 参数语义借用（轻）：main/view.dart:574 `HomeZenLayout.resolve(zen: ZenMode.isOn, tabCount: 0)`——硬编码 0 借用与平板/侧栏语境无关的 tabCount（resolve 中 tabCount 仅影响 showTabStrip，main 侧不消费）。宜拆语义化入口如 resolveTopBar(zen) / resolveTabStrip(zen, tabCount)。
3. Divergent Change / 文件组织（轻）：zen_mode_toggle.dart 单文件承载三个变化原因——跨页共享的纯布局判定 HomeZenLayout（规则变更）、UI widget ZenModeToggle（样式变更）、布局常量 kZenModeToggleWidth；文件名只揭示其三。HomeZenLayout 宜独立成文件并提位。
4. Duplicated Code（轻）：home_zen_layout_test.dart 中 tester.tap → runAsync(100ms delay) → pumpAndSettle 序列重复两次（约 104-118 行）；两 view 的 Obx+resolve 消费形状重复（规则本体已聚拢于 resolve，可接受）。
正面：HomeZenLayout.resolve 把 5 个 show* 布尔从视图 if 级联抽为纯判定+真值表测试，是对 Repeated Switches/Primitive Obsession 的主动消解；tabBar/正文/appBar 条件全部单点化。

【既有判断项基线 5 条逐条判定】
1. ZenMode.enabled 公开可变 —— 延续。zen_mode.dart 不在本 diff，static final RxBool enabled 原样；S3 全部新消费点走 isOn/set 合规路径，欠账未修。
2. setUpAll 裸 catch (_) 吞错 —— 延续+局部改善。新测试文件逐字复制 catch (_) { // Already initialized } 与共享 box 顺序依赖；但 setUp 内 await ZenMode.set(false) 有 await，较 S1 的未 await 写法改善。
3. 测试镜像 settings_search/view —— 无关。本 diff 与该 view 无交集，新测试直调 resolve 断言，无镜像风险。
4. 测试白名单 Shotgun Surgery —— 改善。实测 merge-base .gitignore 已含 !test/features/zen_mode/ 与 !test/features/zen_mode/**（S1 建 zen_mode_store_test.dart 时加），S3 新文件落在已白名单目录，本次零新增行。
5. ZenMode 位置错位 —— 延续。ZenMode 本体仍在 lib/utils/ 未动；另生相邻错位：HomeZenLayout 被 main/view.dart:574 跨页消费 + 测试 4 处引用，却位于 lib/pages/home/widgets/，main 页 import home 的 widgets 目录，宜提共享/feature 级位置。

【diff 内部新 smell】即判断项 1-4，均轻量，无阻断合并项。

## Spec（代理报告原文）

(a) spec 要求了但缺失或部分实现：
1. 真实子树 widget 覆盖缺口（部分实现）。§9 "use widget tests where the on-screen subtree is the contract"；checklist "add a widget test ... for the top-bar/tab-strip subtrees"。第一个 widget 测试 pump 的是自拼合成 Row（Text('MSG_BADGE')/Text('USER_AVATAR')），非 customAppBar 真实子树；zen ON 下 TabBar 消失、body 空白（R4）、search box 存在（R1）均无 widget 层断言，R4 仅被纯谓词真值表覆盖。
2. R1 "tapping it still opens /search" 无测试锁定。行为应满足（searchBar() view.dart:175 onTap Get.toNamed('/search') 未被 diff 触碰，zen 下复用），但无任何断言。
3. §9 "a manual visual acceptance pass" 无法从 diff 体现，需人工验收跟进（最终确认 R2 居中与 R4 视觉空白）。
功能行 R1–R8 本身经逐条核对均落地，无功能缺失。

(b) scope creep：无实质越界。文件范围严格等于 checklist 所列 3 代码文件+1 测试文件。两处极轻微：① zen ON 时图标 primary 色（color: ZenMode.isOn ? primary : null）为 spec 未要求的激活态配色，在 §12 "toggle 图标"裁量精神内；② home/view.dart 注释引用 "(R8/R13)"，R13 不在所给节选内，纯注释无行为影响。

(c) 看似实现了但可能不对：
1. 合成子树测试的虚假信心：测试 1 断言对象是测试自建的 Obx Row，不经过 home/view.dart 的 customAppBar 消费逻辑；若 view 层 if(layout.showMessageBadge) 等条件写错，该测试仍绿。HomeZenLayout.resolve 被测了，view.dart 的消费逻辑没有。
2. R8 "immediately" 依赖 ZenMode.set 内部顺序：lib/utils/zen_mode.dart 为 "await GStorage.setting.put(...); enabled.value = value;"——Rx 翻转在 await Hive put 之后，且 onPressed 未 await（fire-and-forget）；正常路径 put 为内存级即时、"immediately" 满足，但 put 异常时 Rx 永不翻转、UI 静默不恢复，异常路径无兜底。
3. toggle 触摸目标 40dp：kZenModeToggleWidth=40 的 SizedBox 钳制 IconButton，低于 Material ≥48dp 惯例；40 恰等镜像宽使 R2 几何居中成立，但热区偏小（§12 裁量范围，manual pass 留意）。
4. userAndSearchVertical 借位调用 resolve(zen, tabCount: 0)：仅消费 toggle/badge/avatar 三位，功能正确（R6 满足）但把 Home 布局谓词当位掩码借用，语义勉强，resolve 增位时易误用。

【已核对满足】R1 searchBox 唯一复用；R2 左右各 40+对称 padding(14,6,14,0) 几何居中；R3 resolve !zen 隐藏 badge/avatar；R4 6px spacer 即 checklist 明示允许的 "existing empty spacer"、body SizedBox.shrink；R5 _bottomNav（main/view.dart:325-408）未动；R6 侧栏 Obx 缩减；R7 接受性；R8 Obx 整页包裹 off 即恢复；§9 白名单 .gitignore !test/features/zen_mode/** 存在且 git ls-tree 确认两测试文件被跟踪；真值表纯谓词 HomeZenLayout.resolve ✓；§12 deferred（图标/文案/动画/helper 命名）均不算缺失。

结论：功能符合 spec，无阻断项；建议补真实 HomePage 子树的 widget 测试（zen ON 下 TabBar 消失+body 空+searchBox 在）后合入。

## 汇总（skill 第 5 步：不跨轴排序）

- Standards：0 硬违规、4 判断项；轴内最重 = 判断项 2（main/view.dart:574 硬编码 tabCount: 0 借位调用，出现在生产调用点，resolve 增位时易误用）。
- Spec：0 功能缺失（R1–R8 逐条落地）、0 实质 scope creep、3 缺口注记 + 4 疑似项注记；轴内最重 = (a)1/(c)1 同根：widget 测试为合成子树而非真实 customAppBar 消费路径，view 层条件错误时测试假绿。

## 交叉验证

本轮为单轮双轴（上会话首轮两代理因会话切换失效，本会话按原文材料重派），无重跑对照轮。两轴独立结论在「main 侧借位调用 resolve(zen, tabCount: 0)」上交汇（Standards 判断项 2 ≡ Spec (c)4），互为印证；该点与 carried 第 5 条（位置错位）同根。

## carried 判断项（pr82 基线 5 条 + 本片新增，处置方案待 YG 点名，生产代码改动不擅动）

pr82 基线 5 条：
1. [S1 已有 · 延续] ZenMode.enabled 公开可变，可绕过 set() 造成 store/Rx 脱同步。处置方案：zen_mode.dart 私有字段 + getter（S1 领地生产代码）；时机：与 R8 异常兜底（见下）合并为一次 zen_mode.dart 小改，等 YG 点名。
2. [S1 已有 · 延续+局部改善] 测试 setUpAll 裸 catch (_) 吞错；共享 box 顺序依赖（本片 setUp 已 await，较 S1 改善）。处置方案：抽共享 zen 测试 helper（bootstrap + delete await + tap/runAsync/pumpAndSettle 序列一并消解本片判断项 4）；时机：S6 之前或 retro，等 YG 点名。
3. [S2 新增 · 无关] 测试镜像 settings_search/view → 抽共享 matcher。仍 open，与本片无关；时机：同 2 的共享 helper 改造。
4. [S2 新增 · 改善] .gitignore 白名单 Shotgun Surgery：S1 建的 test/features/zen_mode/ 目录白名单已覆盖 S3 及后续 zen 测试，S3 零新增行；S4/S5 测试同目录，此条实质消解大半，S6 的 quiet_state_test.dart 已在白名单。可关账。
5. [S1 已有 · 延续+扩大] ZenMode 单例在 lib/utils/ 位置错位；本片另生相邻错位：HomeZenLayout 被 main 跨页消费却位于 lib/pages/home/widgets/。处置方案：HomeZenLayout 独立文件并随 ZenMode 一并提位（lib/features/zen_mode/ 或等价共享位，连同本片判断项 3 单文件三职责一起）；时机：独立重构小 PR，等 YG 点名。

本片新增：
6. [S3 新增] Speculative Generality：ZenModeToggle width 参数无人传，内联删除。小改，可并入任何后续 zen PR，等 YG 点名。
7. [S3 新增] main 借位调用 resolve(zen, tabCount: 0)（两轴交汇点）。处置方案：resolve 拆 resolveTopBar(zen) / resolveTabStrip(zen, tabCount) 语义化入口 + main 侧改调用 + 测试同步。涉及生产代码，等 YG 点名。
8. [S3 注记] 合成子树 widget 测试缺真实消费路径覆盖 + R1 无测试锁定。处置方案：补真实 HomePage/customAppBar 子树 widget 测试（zen ON：TabBar 消失 + body 空 + searchBox 在 + tap 开 /search）；等 YG 点名。
9. [S3 注记] R8 异常路径：ZenMode.set 中 put 异常时 Rx 不翻转、UI 静默不恢复，onPressed fire-and-forget 无兜底。处置方案：set 内 try/finally 或先翻 Rx 后落盘的顺序论证（S1 领地）；等 YG 点名。
10. [S3 注记] manual visual acceptance pass 未做（§9 要求，S3-S6 均需）；40dp 热区偏小在 §12 裁量内，manual pass 时一并留意。需真机构建，待安排。

## 决定

- 两轴均无阻断项（Standards 0 硬违规；Spec 0 功能缺失）→ 按 S1/S2 惯例合入：gh pr merge 83 --merge；merge 前复查 MERGEABLE/CLEAN。
- CI 证据：workflow_dispatch run 37570552292 success @ 2026-10-07T04:27:58Z（headSha 5538353a4 匹配）；merge 后 production push run 作 exact-SHA 验收证据。
- 10 条 carried/注记已列处置方案与时机，全部等 YG 点名后动生产代码；S4（PR #85）为另一会话领地，不踩。
- 本记录同步作为 PR #83 评论留档。
