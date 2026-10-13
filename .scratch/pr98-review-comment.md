# PR #98 双轴评审记录（#97 普通态 Zen 首页入口）

- 日期：2026-10-08 · 评审人：Codex 协调位（code-review skill 双轴并行 sub-agent，本会话核验轮）
- 基准点：merge-base 20083a05e（origin/production S3 合入 tip）· head：codex/issue-97-zen-home-entry@c205f957f（bb6d76cc8 修复 + c205f957f 审查修正，两提交）
- diff：4 文件 +48/-22（lib/pages/home/view.dart、lib/pages/home/widgets/zen_mode_toggle.dart、lib/pages/main/view.dart、test/features/zen_mode/home_zen_layout_test.dart）
- 评审时 PR #98 状态 OPEN / MERGEABLE / CLEAN（01:49Z 实测）；CI workflow_dispatch run 37715033854（ref codex/issue-97-zen-home-entry，headSha 匹配 c205f957f）
- 独立复验（协调位，非代理）：基线 20083a05e 上跑修复版测试 = 红（真值表 zen off 断言 + 普通态 toggle 缺失两条失败，即 #97 现象的可执行复现）；修复分支全量 flutter test --no-pub 584/584 绿；analyze 14 条全部既有 info（vote_decoration / tool / probe 等未触碰文件），零新增。
- spec 源：issue #97 正文（现象/期望/根因/拍板）+ 维护者已拍板的 agent brief 评论（Key interfaces / Acceptance criteria / Out of scope）。standards 源：仓库无 CODING_STANDARDS.md / CONTRIBUTING.md，AGENTS.md 与 docs/agents/* 仅治理流程。

## Standards（代理报告原文）

(a) Documented standards: NONE exist (verified: no CODING_STANDARDS.md, no CONTRIBUTING.md; AGENTS.md and docs/agents/* are process docs only). Hard violations: 0. Tooling-enforced items skipped per brief (analyzer already clean).

(b) Baseline smells — all judgement calls, none blocking:

1. **Speculative Generality / Mysterious Name** — lib/pages/home/widgets/zen_mode_toggle.dart `showZenToggle: true`. After this diff, showZenToggle is constant true and has zero production readers: both former consumers (home/view.dart `if (layout.showZenToggle)`, main/view.dart sidebar gate) were unconditionally inlined in this same diff. The field is now written, never read outside tests. Fix: drop the field (and its truth-table asserts) or inline const ZenModeToggle() everywhere; if kept, the name promises variability it no longer has.
2. **Duplicated Code** — lib/pages/home/view.dart, customAppBar. Both if/else branches repeat the same row head (`const ZenModeToggle(), searchBar(),`). Only the trailing spacing/badges differ. Extract the shared head; keep branch-specific tails.
3. **Repeated Switches (mild)** — flag gating recurs in two shapes: home/view.dart uses `if (layout.showMessageBadge || layout.showUserAvatar)`; main/view.dart sidebar uses separate `if (layout.showUserAvatar) ... if (layout.showMessageBadge)`. HomeZenLayout already centralizes the decision values (correct direction); if gating grows, move composition helpers onto it rather than re-deriving conditions per view.
4. **Mysterious Name (mild)** — HomeZenLayout now also encodes normal-state chrome (#97 toggle-always-visible), not only zen layout. Doc comment was updated; the name wasn't. Candidate: HomeTopBarLayout. Cosmetic.
5. **Duplicated Code (test)** — test/features/zen_mode/home_zen_layout_test.dart: the tap → runAsync(100ms) → pumpAndSettle triple appears twice in one test; a tiny local tapToggle(tester) helper would collapse it and pin the 100ms magic delay in one place.

Positives: the layout truth table stayed a pure function and its tests were updated in lockstep — consistent with the existing R-rule test style.

## Spec（代理报告原文）

(a) Missing / partial

1. **Search-bar acceptance untested.** Spec: 「搜索栏普通态因左侧让位而缩短，点击仍打开搜索页」/「测试：布局真值表与顶栏 widget 断言双向更新」. The widget harness (home_zen_layout_test.dart:76-82) renders only toggle+badge+avatar; searchBar() appears in no test. Shortening holds in prod only because searchBar() is an Expanded (view.dart:179) — true by construction, asserted nowhere.
2. **Sidebar variant implemented but unverified.** Spec: 「平板/侧栏变体普通态同样出现 toggle，规则一致」. Done in userAndSearchVertical() (main/view.dart:577-586, own-flag gating), but zero tests exercise that widget; only the shared predicate is tested.
3. Minor: spec 「ON 态保持既有断言」 — kept (test:101-103), but the old programmatic ZenMode.set(true) entry in the top-bar test became tap-driven; settings-switch→layout reaction now covered only via the same Rx.

(b) Scope creep: None. All four files map to spec lines; the showMessageBadge||showUserAvatar discriminator and the sidebar's independent badge/avatar gating are behavior-preserving consequences of the恒真 contract, not additions.

(c) Implemented but looks wrong

1. **showZenToggle is dead in production code.** Spec: 「HomeZenLayout.resolve…showZenToggle 契约由 zen 改为恒真（两态均显示开关）」— resolve honors it (zen_mode_toggle.dart:28), but no lib caller reads the field anymore: customAppBar branches on layout.showMessageBadge||layout.showUserAvatar (view.dart:111); sidebar hardcodes const ZenModeToggle() (main/view.dart:578). The flag documented as the 「Zen 可见性规则 R1–R4/R8…纯判定」 survives only to feed tests; toggle visibility is no longer predicate-governed. Output identical today; contract honored vacuously — a future non-constant rule requires rewiring callers.
2. Same root: view.dart:111 encodes 「普通态」 only indirectly (== !zen solely because resolve couples badge/avatar to !zen). Correct today, obscure coupling.

Verification run: flutter test test/features/zen_mode 8/8 passed; flutter analyze 14 issues all pre-existing in unrelated files; ON-state branch byte-identical to pre-change branch (R1-R2 centering preserved, kZenModeToggleWidth mirror retained at view.dart:133); tap→entry/exit and dual persistence covered by tests. No functional defects found.

## 汇总（skill 第 5 步：不跨轴排序）

- Standards：0 硬违规、5 判断项；轴内最重 = 判断项 1（showZenToggle 恒真后成为生产代码死字段——但该恒真契约是 brief 明文要求，属可执行规格，按契约保留）。
- Spec：0 功能缺失、0 实质 scope creep、3 缺口注记 + 2 疑似项注记；轴内最重 = (c)1（与 Standards 判断项 1 同根：开关可见性不再由谓词治理，未来非恒真规则需重接调用方）。

## 交叉验证

两轴独立结论在 showZenToggle 死字段（Standards 判断项 1 ≡ Spec (c)1）及其派生的 view.dart:111 间接判别式（Standards 判断项 3 ≡ Spec (c)2）上交汇，互为印证。该契约本身来自维护者拍板的 brief（#97 进度区已裁决「按 brief 明文契约保留」），故两轴最重项均记 carried 不阻断。

## carried 判断项（pr83 基线 10 条延续 + 本片新增，处置方案待 YG 点名，生产代码改动不擅动）

pr83 基线 10 条全部延续，本 diff 相关判定：
1. [延续] ZenMode.enabled 公开可变 —— zen_mode.dart 不在本 diff。
2. [延续] 测试 setUpAll 裸 catch (_) —— 本片未触碰 bootstrap。
3. [无关] 测试镜像 settings_search/view —— 本 diff 无交集。
4. [延续·可关账] .gitignore 白名单 —— 本片测试文件在白名单目录内，零新增行。
5. [延续+扩大] ZenMode/HomeZenLayout 位置错位 —— 本片加剧 home/widgets 单文件三职责（Standards 判断项 4 同根）。
6. [延续] ZenModeToggle width 参数无人传 —— 本片 4 个使用点仍全部无参构造。
7. [延续] main 借位调用 resolve(zen, tabCount: 0) —— 本片沿用该调用点。
8. [延续] 合成子树 widget 测试缺真实消费路径覆盖 —— 本片 widget 用例仍是合成 Row；Spec (a)1 searchBar 无测试锁定是同族缺口。
9. [延续] R8 异常路径（put 异常时 Rx 不翻转）—— zen_mode.dart 未触碰。
10. [延续] manual visual acceptance pass 未做 —— #97 普通态形态（开关常显/搜索栏缩短/角标头像原位）需真机目验，与 #66 S3-S6 一并安排。

本片新增（均轻量、无阻断）：
11. [#97 新增 · 两轴交汇] showZenToggle 恒真后成生产死字段，开关可见性不再谓词治理；未来若要非常量规则需重接 home/main 调用方。处置：要么删字段改由视图直陈（同步真值表），要么把可见性判定真正收进谓词（customAppBar/main 消费 showZenToggle）。等 YG 点名。
12. [#97 新增] customAppBar 两分支共享行头重复（toggle+searchBar）。处置：抽共享行头。等 YG 点名。
13. [#97 新增] 搜索栏让位与侧栏变体无 widget 层锁定（Expanded 短缩靠构造成立）。处置：补 searchBar()/userAndSearchVertical 子树用例。等 YG 点名。
14. [#97 新增] 测试 tap→runAsync(100ms)→pumpAndSettle 三连重复两次（pr83 判断项 2 的 helper 化建议同族）。处置：抽 tapToggle 本地 helper。等 YG 点名。

## 决定

- 两轴均无阻断项（Standards 0 硬违规；Spec 0 功能缺失、0 scope creep）→ 按 S1/S2/S3 惯例合入：gh pr merge 98 --merge；merge 前复查 MERGEABLE/CLEAN。
- CI 证据：workflow_dispatch run 37715033854（headSha c205f957f 匹配）；merge 后 production push run 作 exact-SHA 验收证据，补挂 issue #97。
- 14 条 carried/注记已列处置方案，全部等 YG 点名后动生产代码。
- 本记录同步作为 PR #98 评论留档。