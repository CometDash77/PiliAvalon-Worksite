# Jev 规则编辑器验证记录

日期：2026-10-10（Asia/Hong_Kong）。需求地图 [#106](https://github.com/CometDash77/PiliAvalon-Worksite/issues/106)，已确认决策 [#108](https://github.com/CometDash77/PiliAvalon-Worksite/issues/108)，原型 [#110](https://github.com/CometDash77/PiliAvalon-Worksite/issues/110)，实现 [#116](https://github.com/CometDash77/PiliAvalon-Worksite/issues/116)。

用户已明确批准按原型实施：只隐藏；每条执行阈值 50%–100% 默认 95%；Yes/No 双向触发；Choice 模型单选、用户可指定多个隐藏选项；视频/直播内置负反馈可分别停用；评论仅自定义。沿用原视频推荐面开关，评论仅视频详情及其子回复，直播仅推荐卡。没有额外抓取字幕、作者历史或直播消息。

## 实现与边界

- 基于已交付的 `09f066def5bb274b473650a1af55ccf15a1c0b51`，保留模型目录、手填与 provider 独立模型配置。原型留在 `codex/jev-rule-editor-prototype`，正式分支不包含原型 HTML。
- 编辑、校验和编译均在本地进行；规则存储为独立版本化非密钥配置。每场景最多 20 条规则，Choice 2–20 项，问题最多 1000 字符，答案/选项说明最多 400 字符。
- 自定义 Noul 使用指定答案概率；Choice 验证返回选项、完整概率分布和 confidence。每条自定义规则附一条信息充分性问题，只有充分性概率至少 95% 且主答案达阈值才触发。尤其避免把资料不足当成 No 隐藏。该策略增加问题数量，仍在每批 3 个候选、串行、无重试、8 秒请求超时的已有边界内；阈值是用户确认的配置默认值，没有宣称实测校准。
- 内置规则仍沿用原默认阈值；评论不发送负反馈主题。仅自定义规则的请求也不发送无关主题。候选上下文限制标题/正文 1000 runes、短简介/父正文 800 runes、最多 12 个 80-rune 标签。
- 评论根楼与内嵌子回复先经过既有低成本规则；子回复跨父楼合批，源 count/cursor 保留。全隐藏的首个源页可以手动继续下一页。视频回复目标跳转等待 Jev 完成，再按最终可见列表定位；非视频路径保持旧行为。

## 实跑验证

- 最终 `05b60bb0b` 产品/测试代码：`flutter test --no-pub --reporter compact`：**736/736 通过**。
- 初次专项 104/104 通过；后续两项分页修正与 Choice wire/OR、延迟定位、空页继续按钮等验证，修正专项 **68/68 通过**，并纳入上述最终全量。
- `flutter analyze --no-pub --no-fatal-infos`：**0 error、0 warning**；仅 3 条原有 info，位于 dynamics vote、shielding upstream selection 测试与 matcher bench；本次文件无新增诊断。
- `git diff --check` 通过；`pubspec.yaml` / `pubspec.lock` 无变更。验证使用项目锁定的 pub.dev 包缓存。初次环境错误解析到镜像的新版本已纠正，未带入依赖升级。Windows 插件链接提示没有阻止 no-pub 测试或分析。

## Standards

独立只读审查：0 项发现。未发现可证实的仓库标准违规或需要提出的 baseline smell；重点核对异步列表提交、cursor 与源计数、损坏配置保留、隐私与失败保留。信心中等：代码审查不替代手动设备验收。

## Spec

独立只读审查初次发现两项 P2，均已修复并复核：全隐藏首评论页保留下一页入口；视频子回复在筛选完成后按目标 ID 定位，隐藏目标不跳。剩余发现 0；审查信心高。新增测试实际覆盖延迟期间不跳、前置评论被隐藏后索引调整，以及分页按钮防重复加载。

## 尚未验证

没有真实 Key 调用、手机安装或付费语义准确率/成本测量；没有宣称发布应用或合并生产分支。代码实现与回归结果可供 PR 审查，真实模型与设备验收仍需按集成流程进行。

协议一手依据：[TypeSafe API](https://docs.typesafe.ai/api)、[OpenRouter Decisions](https://openrouter.ai/docs/api/api-reference/alphadecisions/submit-a-decisions-request)。两者的 typed questions Map、Noul 和 Choice/probabilities/confidence 形状已独立核对。
