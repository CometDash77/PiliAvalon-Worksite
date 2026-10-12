# Jev 评论过滤：实现与验证

关联：[map #109](https://github.com/CometDash77/PiliAvalon-Worksite/issues/109)、[实施 #112](https://github.com/CometDash77/PiliAvalon-Worksite/issues/112)。本项基于 PR #104 的 09f066def，未混入原共享工作区的其他任务改动。

## 已确认行为

独立评论开关默认关闭，受 Jev 总开关控制。预设隐藏明显广告引流、直接辱骂/人身攻击、重复刷屏和明显无关灌水；保留正常批评/不同意见、相关玩笑和简短有意义回复。用户可编辑、保存并恢复预设；留空不调用。

普通规则先过滤，剩余主评论与递归子评论进入语义判断。主评论（视频/动态等）、楼中楼、对话、详情首层、预载首层及新发评论回填均等待判断后再更新可见状态。全隐藏的一页与上游空页分开处理，保留原分页游标及旧的评论定位规则。

首页已开启的评论门控复用相同标准，考虑置顶评论；抽样页未耗尽、评论为空或无法判断时保留视频。开启语义后仅合并在途同 aid 请求，不持久缓存付费判断；关闭时保留原有规则缓存。加载与语义判断共享每 aid 最多 8 秒预算，超时保留且不启动后续批次。整页仍使用原有最多 3 个并发 worker，没有整页 deadline。

## 输入与判断边界

只发送评论正文、用户标准及本次输入中相同正文的重复次数；没有作者、评论 ID、账号或 cookie。正文最多 2000 runes，超长内容保留、不以截断内容作隐藏判断；标准最多 4000 runes。重复次数仅反映本次读取的评论，不读取历史或跟踪用户。未提供视频全文/上下文的评论，相关性判断不足时应保留。

复用已确认 provider、系统安全密钥及按 provider 保存的模型；不跨 provider 重试。questions 是命名对象，每条问题明确引用对应 state.candidates 文本和 state.criteria，评论正文视为数据而不是指令。使用 type=noul、有限数值 0..1，达到共享隐藏阈值 0.95 才隐藏；低报告置信度、缺失/无效回答、不确定、凭据错误、限流、超时及服务失败保留。设置/provider/model/标准在途变更时旧结果失效。

接口核对一手资料：[TypeSafe API](https://docs.typesafe.ai/api)、[OpenRouter Decisions](https://openrouter.ai/docs/api/api-reference/alphadecisions/submit-a-decisions-request)。

## 验证证据

2026-10-10 最终全量 `flutter test --no-pub --reporter expanded`：**751/751 通过**。真实应用控制器的 queryData -> 普通规则 -> JevCommentScreening -> transport -> loadingState 链路已在受控请求/响应下执行，涵盖延迟返回前不展示、隐藏主/子/更深回复、刷新/追加、过滤空页、首层无 children、预载首层按当前策略判断及错误保留。生产 Dio transport 的 HTTP adapter 测试核对两家 provider、模型、认证、命名答案和隐私字段；不是只测独立判断函数。

首页 gate 测试验证实际文本输入、隐藏结果移除卡片、同 aid 合并、失败重试、策略变更、置顶评论与时间预算。设置 widget 测试验证编辑保存、重新打开恢复和恢复预设。

全仓 `flutter analyze --no-pub`：零 error/warning，3 条既有 info（vote_decoration 的 alpha、upstream_reply_selection_test/benchmark 的 cascade）；分析命令因此退出 1，不宣称全仓分析零提示。修改的 12 个 Dart 文件格式检查无改动，git diff --check 通过。独立只读审查复核预载首层与新发评论问题已解决，无新 blocker。

## 当前状态与限制

产品代码实现、受控真实链路回归已完成。仍待 PR 审查/合并；没有发布 APK、没有真机验收，也没有使用真实用户 Key。测试证明链路及结果映射，不能证明模型对任意真实评论的语义准确率。上线前应使用用户自己的已配置账户在设备检查隐藏/保留样本，误判可通过编辑标准或关闭评论开关处理。

