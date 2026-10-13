重做 #49（[#74](https://github.com/CometDash77/PiliAvalon-Worksite/issues/74)）的产品产物，与 #73 同一批（map #47 的「重做」决议）。

## 为什么

推荐面每次取标签都会重复请求同一个 bvid（同一批内重复、批与批之间重复、详情页再来一次），一个坏掉的分 P 还会每批重试一次。原 #49 的产物在 2026-10-05 丢失（见 [map #47](https://github.com/CometDash77/PiliAvalon-Worksite/issues/47) 的产物审计），本 PR 是按原票面 spec 的重做，硬约束是「先入库、后有远程证据」。

## 改了什么（一个提交 `c10a00de7`）

- 新增 `lib/features/shielding/recommendation_tag_store.dart`（235 行）：全进程共享的标签仓库。键为 `bvid + cid`（同视频不同分 P 不互相复用）；同键并发请求合并成一个共享 Future；失败与空结果进 30 秒负缓存，成功进 30 分钟缓存；容量默认 10MB、上限 50MB，按估算字节旧→新驱逐；**只缓存原始标签、不缓存判定结果**，调用方拿回标签后用当前批次规则重新匹配（与 #73 的阶段契约一致）。
- `lib/features/shielding/shielding_recommend_tag_enricher.dart` 退化为薄层：去掉私有缓存，新增 `fetchSharedTags()` 作为推荐面与详情页共用的唯一入口。幸存者过滤、并发池（默认 5，钳 1–10）、单调用方 3 秒超时（钳 1–10）、fail-open 语义全部不变。
- `lib/pages/common/common_intro_controller.dart:148-155`：`queryVideoTags()` 不再直调 `UserHttp.videoTags`，改走共享入口，详情页因此能吃到推荐面已经取回的标签。
- 不做单调用方取消：调用方超时或页面离开后共享请求照样跑完并写回缓存，因此没有订阅者计数、也没有随之而来的竞争状态。

## 顺手修掉的一个在飞位泄漏

在飞位原先登记在 `_load()` 调用**之后**，而 async 函数体在第一个 await 前是同步执行的：fetcher 同步抛错时 `_load()` 会吞掉异常并在返回前跑完，于是登记进去的是一个已完成、永远没人清理的 future，该键从此再也发不出请求。现在在飞位在加载开始前登记，成功与出错两条路径都释放，并补了回归测试。

## 验收

- `flutter test --no-pub` → **554 passed**（基线 539，净增 15），exit 0。
- `flutter analyze --no-pub --no-fatal-infos` → 14 issues，**0 error / 0 warning**，exit 0。
- 远程 CI：run [#37408586817](https://github.com/CometDash77/PiliAvalon-Worksite/actions/runs/37408586817)（`workflow_dispatch`，`headSha c10a00de7`）。
- 请求数上界的证明在 `test/features/shielding/shielding_recommend_tag_enricher_test.dart:674-718`：K=8、24 个槽位只有 8 个不同 bvid、两批各跑一次后，`fetchLog` 长度 ≤ 8（上界）、`fetchLog.toSet()` 恰为 8（下界，证明不是靠「不发请求」蒙过）、`toSet().length == fetchLog.length`（一个键在缓存生命周期内从不重发）。

## 需要审阅者注意的一处既有测试替换

`'failed tag fetch is not cached'` 被替换为 `'a failed tag fetch is negative-cached for 30s instead of retried'`——旧测试断言的正是本票要修掉的行为（失败必须能立刻重试、不缓存），与票面「失败/空结果负缓存 30s」直接冲突，属票面要求的语义替换。`test/features/` 下没有别的文件被改。

## 边界

不碰 #51（仍等 map 外的 #65）、不碰 #54（性能口径）、不碰 #75（评论门）。
