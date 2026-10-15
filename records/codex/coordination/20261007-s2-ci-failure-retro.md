# S2 CI 失败-修复 retro（run 37565641514 → PR #84 → run 37568139515）

- 日期：2026-10-07 · 记录：Codex 协调位（YG 发话「从第一性原理出发，继续完成未完成事项」后补记）
- 上游记录：issue #66 评论「S2 — CI 验收证据（含一次失败根因与修复）」、handoff 20261007-115830-291-CI修复验收闭环.md

## 时间线

1. S2 经 PR #82 合入 production（HEAD 0aaf67cd1）→ production push run 37565641514（2m17s）：**completed failure**，579 passed / 1 failed。
2. 唯一失败：test/pages/setting/models/zen_mode_settings_test.dart「is indexed by settings search for 极简 and zen queries」。
3. 根因定位 → 修复 PR #84（fix/zen-s2-ci-appsupport @ 55b9df8d6，仅测试基建）→ PR 分支 workflow_dispatch run 37567105293 **success** → merge（112db34b）→ production run 37568139515 **success**（11m25s）= S2+fix 组合验收证据。

## 根因链（确定性失败，非 flaky）

- lib/pages/setting/models/style_settings.dart:63 `if (Platform.isLinux) _useSSDModel(),` —— 本地 Windows 永不进入，CI ubuntu 必然进入。
- → style_settings.dart:817 `File(path.join(appSupportDirPath, 'use_ssd'))`
- → lib/utils/path_utils.dart:8 `late final String appSupportDirPath` 在测试环境未初始化 → **LateInitializationError**。
- 抛出点在六列表（extra/privacy/recommend/video/play/style）spread 的**列表字面量构造阶段**——测试内 safeTitle/safeSubtitle 的 try/catch 只保护行构造回调，保护不了列表构造，故测试自身防线失效。
- 判定：Linux-only 路径 + 未初始化 late final = 确定性崩，re-run 无意义。

## 修复模式（可复用）

- 测试 setUpAll 对 late final 显式赋临时目录一次（late final 允许恰好一次赋值），try/catch 兜住同 isolate 二次赋值；与同文件 downloadPath / Hive.init 的既有处理同构；生产代码零改动。
- 排查闭环方法：对 late 全局做全库**构造期**引用扫描（列表初始化阶段 vs 回调体内），确认仅此一处，单点修复即闭环。

## 教训

1. **平台分支盲区**：`Platform.isXxx` 分支在本地永不执行，CI 才是首次真实执行点。「本地全绿」推不出「CI 绿」。新测试触及平台分支时，PR 阶段必须 workflow_dispatch 提前验证（S2 时该流程未确立：PR #82 merge 前未跑 dispatch；S3 起已固化）。
2. **构造期 late final 引用不可被 try/catch 保护**：错误发生在字段初始化/列表字面量构造阶段，在任何 try 之外；防线必须放在 setUpAll 初始化本身。
3. **判定纪律**：先根因后重试——平台分支 + LateInitializationError 这类签名直接判确定性失败，re-run 是浪费。
4. **验证链留证**：失败 run、根因、修复 PR、dispatch run、production 绿 run 全部留 ID 进链（issue #66 评论），验收结论可回放。

## 已固化的 CI 流程模板

- ci.yml pull_request 触发仅限 main → base production 的 PR 天然无 checks。
- PR 阶段：`gh workflow run ci.yml --ref <branch>` dispatch（约 12 分钟）→ 绿 → `gh pr merge N --merge` → production push run（约 11 分钟）= exact-SHA 验收证据；watch 用后台 job（gh run watch --exit-status），勿轮询。
