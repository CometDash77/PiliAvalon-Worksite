# #162 研究记录：思考控制与上游提示词缓存

- 票：[CometDash77/PiliAvalon-Worksite#162](https://github.com/CometDash77/PiliAvalon-Worksite/issues/162)（Wayfinder research；本文件是分支上下文指针与研究交付物）
- 研究日期：2026-10-15
- 代码基线：origin/wayfinder-141，HEAD 89e8c0ade；在隔离 worktree research/deepseek-thinking-cache 检查。未读取或改动主 checkout 中的未提交工作。
- 方法：只读检查仓库请求/设置/缓存代码；外部协议仅使用厂商官方 API 文档。未使用凭据、未调用付费推理 API。

## 结论

1. **思考控制是 model × API 路线能力，不是可跨协议通用的布尔值。** DeepSeek 明确给出 OpenAI Chat、Anthropic Messages 兼容层和 Responses API 各自的请求字段；OpenAI、Anthropic、Gemini 同样有模型级差异。未有对应官方能力依据时，控件应隐藏/禁用，不应把“关闭”静默映射成低强度、或反过来。
2. **当前筛选请求完全没有传思考/推理强度字段。** 配置只存 provider/protocol/base URL/model/确认状态与鉴权选择；Chat body 只有 model、messages、max_tokens、stream（Anthropic 另有 top-level system）。DeepSeek 模型即使 API 支持 thinking，当前客户端请求没有明确选择开/关或强度，因此实际值遵循上游默认。
3. **上游 prompt cache 与本地 verdict cache 是两件事。** DeepSeek / OpenAI 支持自动 prefix reuse；Anthropic 需 cache_control 标记；应用当前均未主动配置上游 cache 控制或保留 usage cache 指标。应用已有的是进程内判定结果缓存，命中后跳过推理请求。
4. **无语义变更的首选是观测，而非改写 prompt。** 维持当前固定 system 前缀与判定文本不变，先保留/读取供应商 usage 的 cached-token 计数、输入 token 数及 model/route，量到可用基线；之后若要改写 user payload 中规则/候选的排列，应以筛选回归证明等价后再做。命中率不作预设承诺。

## 厂商一手契约

| Provider / 路线 | 思考开关与强度 | 提示词缓存 | 边界 |
| --- | --- | --- | --- |
| **DeepSeek · OpenAI Chat Completions**（deepseek-flash、deepseek-v4-pro） | 官方表格：thinking: {type: enabled/disabled} 可显式开关；reasoning_effort 支持 low/high/max。未传时 thinking 默认开启、effort 默认 high。官方兼容映射：minimal→low、medium/xhigh→high、ultra→max；不应把映射外推到其他提供方/协议。 | 磁盘 context cache 默认启用、无需请求字段。必须完整复用已持久化的 prefix unit 才命中；响应 usage 有 prompt_cache_hit_tokens 与 prompt_cache_miss_tokens（Responses 格式使用 input_tokens_details.cached_tokens）。best-effort，不保证命中。 | 对 thinking 模式，temperature / presence_penalty / frequency_penalty 无效；兼容行为下也不一定报错。思考强度和开关是不同字段。官方文档：[Thinking Mode](https://api-docs.deepseek.com/guides/thinking_mode/) · [Chat Completions API](https://api-docs.deepseek.com/api/create-chat-completion/) · [Context Caching](https://api-docs.deepseek.com/guides/kv_cache/) · [Cache usage fields](https://api-docs.deepseek.com/news/news0802/) |
| **DeepSeek · Anthropic Messages 兼容层** | DeepSeek thinking guide 中 Anthropic 格式分为两项：thinking toggle 用 reasoning: {effort: none/low/high/max}（none 关闭）；强度用 output_config: {effort: low/high/max}。后者是独立的强度控制；字段只按 DeepSeek 这条兼容层契约使用，不假定任意 Anthropic-compatible 网关均接受该扩展。 | DeepSeek 自动 prefix cache 同上；该接口文档明确 Anthropic cache_control 标记被忽略，因此不应为 DeepSeek 该路线添加原生 Anthropic breakpoint。 | 该路线是 DeepSeek 官方接口，但不是 Anthropic 原生 Messages 服务。来源：[DeepSeek Thinking Mode](https://api-docs.deepseek.com/guides/thinking_mode/) · [DeepSeek Anthropic Messages API](https://api-docs.deepseek.com/guides/anthropic_api) · [DeepSeek Context Caching](https://api-docs.deepseek.com/guides/kv_cache/) · [Cache usage fields](https://api-docs.deepseek.com/news/news0802/) |
| **DeepSeek · Responses API** | 官方 endpoint schema 明确 reasoning.effort: none 关闭；low/high/max 开启；默认 thinking 开启，兼容接收 minimal→low、medium/xhigh→high。 | usage 返回 input_tokens_details.cached_tokens。 | 这条路线在本 repo 的 route enum 中存在，但未标记 screenable，故当前语义筛选不会用它。来源：[Responses API](https://api-docs.deepseek.com/api/create-response/) |
| **OpenAI · 模型能力** | Responses 用 reasoning.effort；Chat Completions 用对应 reasoning_effort。支持值与默认值按模型变化（文档列 none/minimal/low/medium/high/xhigh/max 的子集），不是“所有模型都能关”。 | 支持的模型默认启用隐式 prefix cache；cache reuse 要求 rendered prefix 相同，缓存读取/诊断需观测 usage/dashboard。模型、工具、格式、推理设置可影响 prefix。 | 本 repo 当前只筛选 Chat Completions 线路，未实现 OpenAI Responses 线路，也未传 reasoning 字段。来源：[Reasoning models](https://developers.openai.com/api/docs/guides/reasoning) · [Prompt caching](https://developers.openai.com/api/docs/guides/prompt-caching) |
| **Anthropic · Messages API** | thinking 类型、默认、能否关闭均依模型变化；现代模型可能采用 adaptive，部分模型始终思考，部分可 disabled，旧模型用 enabled + budget_tokens。output_config.effort 是独立的模型级强度旋钮；不能将它与 thinking on/off 当同一维度。 | 用顶层自动 cache_control 或显式 breakpoint 标记；默认 cache TTL 为 5 分钟。改动 thinking 配置/effort 会改变 cache prefix；官方指出少数模型支持 per-message effort 变更并保持 cache。 | 只对原生 Messages 字段保证；是否透传由兼容服务决定。来源：[Thinking / per-model support](https://platform.claude.com/docs/en/about-claude/models/extended-thinking-models) · [Effort](https://platform.claude.com/docs/en/build-with-claude/effort) · [Prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching) · [Thinking troubleshooting](https://platform.claude.com/docs/en/build-with-claude/thinking-troubleshooting) |
| **Google Gemini API** | thinking_level / 思考配置由型号决定，默认和可选 levels 不统一；不应概括为通用 on/off。 | Gemini 2.5+ implicit cache 默认开，模型各有最小 token 数；稳定公共内容放 prompt 前缀提高命中机会，usage 有 cached-token 计数。 | repo 内只有 Zen 预设暴露 Google 路线，且该路线不属于当前筛选引擎支持范围。来源：[Gemini thinking](https://ai.google.dev/gemini-api/docs/thinking#thinking-levels) · [Gemini context caching](https://ai.google.dev/gemini-api/docs/caching) |

### 路由/模型能力不能由协议名推断

repo 的预设含 DeepSeek、OpenRouter、MiMo、阿里云百炼、SiliconFlow、OpenCode Zen、Command Code 及两个自定义项；可配置路线包括 OpenAI Chat、OpenAI Responses、Anthropic Messages、Google 和 SystemOne。但过滤引擎目前只接受 OpenAI Chat 与 Anthropic Messages（代码依据见下）。特别是 OpenRouter、Zen、Command Code 属于路由/网关层时，某模型支持一个原生字段不等于网关会透传或等价实现该字段。需要 provider × model × route 的官方说明（或未来用户显式配置的能力信息）才可启用具体控件。

## 当前代码路径审查

- [llm_provider_presets.dart](../../lib/features/llm/llm_provider_presets.dart#L13-L38) 定义五类路线；line 34–37 仅将 OpenAI Chat / Anthropic Messages 标为 screenable。DeepSeek 预设使用 OpenAI Chat /chat/completions 或 Anthropic Messages /anthropic/v1/messages（[同文件](../../lib/features/llm/llm_provider_presets.dart#L185-L198)）。
- [llm_settings.dart](../../lib/features/llm/llm_settings.dart#L20-L57) 的 provider config 有 protocol/base URL/model/confirmed/http-confirmed/bearerAuth，没有 thinking 或 reasoning-effort 字段。模型能力目录仅用于 model id 选择（见 [llm_model_catalog.dart](../../lib/features/llm/llm_model_catalog.dart)），没有能力元数据。
- [llm_chat.dart](../../lib/features/llm/llm_chat.dart#L115-L141) 当前请求体：OpenAI Chat 发 model + system/user messages + max_tokens=1024 + stream=false；Anthropic 发 model + max_tokens=1024 + 顶层 system + user message。没有 thinking、reasoning_effort、reasoning、cache_control 或 prompt-cache key。
- [llm_prompt.dart](../../lib/features/llm/llm_prompt.dart#L7-L18) 固定 system prompt；comment user message 的候选在规则前（:57–82），video user message 的候选字段在规则前（:93–118）。system 前缀是最稳定部分，候选/规则数据随请求变化。若交换排序或把规则移入 system，虽然字段集合可相同，也会改变 prompt 序列与模型行为，不能当作严格语义无改动。
- [llm_response.dart](../../lib/features/llm/llm_response.dart#L8-L43) 只提取最终 text，忽略 reasoning blocks；[llm_chat.dart](../../lib/features/llm/llm_chat.dart#L143-L162) 校验 stop reason 后只返回文本，未保留 provider usage/cache token 统计。当前上游缓存命中率无法在 app 侧测量。
- [llm_verdict_cache.dart](../../lib/features/llm/llm_verdict_cache.dart#L8-L20) 与 [jev_verdict_cache.dart](../../lib/features/jev/jev_verdict_cache.dart#L8-L18) 是进程内已判 verdict 缓存：确定结果可被复用，规则/provider/model 代际变化后失效；这不等同于厂商重复 prompt 的 KV/prefix cache。

## 决策建议（供 Lead 记录，不代表改代码）

1. 能力配置粒度用 provider + model + route；枚举只取该具体官方契约确认的值。能力未知就不显示控制项；不支持 off 的模型不显示“关闭”。DeepSeek 的 Chat、Anthropic-compatible、Responses 三种控制形状虽相似，映射仍必须按路线编码。
2. 将“是否启用思考”与“强度”拆成独立维度，且允许能力关系表达“始终启用/不能关闭”或“字段不存在”。不要用 low 代替 off，不把某 provider 的 alias 归一化为另一个 provider 的字段。
3. 先补 usage 观察能力，至少让各路线 response 的 cache hit/miss token 和 input token 统计可查；字段缺失视为 unavailable，不推测。无凭据离线不能验证网关透传/实际模型默认值。
4. DeepSeek 自动 cache 不需要显式开关。现有固定 system prompt 是自然稳定前缀，但 current dynamic user content order may reduce reuse after first divergent token. 可先读取 DeepSeek usage 的 cache hit/miss 统计，不做 prompt reorder。Anthropic cache control 与 OpenAI/Gemini controls 具有不同字段，不能塞进通用请求体。

## Claim verification / limitations

- 上表控制字段、level/default、cache 标记/指标均逐项对照对应厂商官方页；DeepSeek 的三 API 路线分别对照 thinking guide、Chat schema、Responses schema，未把兼容协议当作实现证据。
- 代码结论逐行对照上述 HEAD 的 llm_provider_presets.dart、llm_settings.dart、llm_chat.dart、llm_prompt.dart、llm_response.dart 与两个 verdict-cache 文件。
- 搜索与阅读仅获取公开文档，不做任何 authenticated/paid API request。厂商文档滚动更新；model-level availability 需随模型目录/文档更新，不将本文视为永久能力表。聚合网关实际行为、账户套餐与区域限制未作 live probe，均不作保证。
