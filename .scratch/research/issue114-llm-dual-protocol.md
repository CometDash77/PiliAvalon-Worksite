# #114 研究记录：通用 LLM 双协议与视频/评论过滤接入契约

- 票：[CometDash77/PiliAvalon-Worksite#114](https://github.com/CometDash77/PiliAvalon-Worksite/issues/114)（map #111 子票，research）
- 研究执行日：2026-10-10；基线提交：09f066def5bb274b473650a1af55ccf15a1c0b51（#104 PR head）
- 方法：外部协议事实由研究代理 A 仅依据官方一手来源核验（官方 OpenAPI spec、官方页 .md 源、官方页镜像）；代码基线由研究代理 B 在 09f066def 与当前 HEAD 上映射。
- 上一轮预调查文件 `.scratch/research/task5-llm-overlap.md` 本地已不存在（2026-10-10 实测 not found），其结论已并入 #114 评论存档，本文为唯一现行记录。

## 1. 研究问题与决策依赖

| 问题 | 依赖 | 状态 |
| --- | --- | --- |
| 两种通用协议的最小可验证契约（URL/认证/分页/错误） | 仅官方一手来源 | 本文件 §2–§6 已核验 |
| 通用规则接入视频/评论的输出与失败契约 | #113 产品共识（Q1–Q8 已确认）+ 代码基线 | 协议侧 §8；代码侧待 §7 回填 |
| 端点/Key 隔离、重定向与脱敏 | 代码基线 + 协议事实 | §8.3 协议侧已定；代码侧待 §7 |
| 目录成功 ≠ 过滤成功、失败保留 | #113 决议 + 协议事实 | §8.4 |
| 产品入口/规则/失败偏好 | #113（closed，用户确认） | 不由本研究决定，仅映射 |

澄清项：本研究无需新 grilling——产品行为已在 #113 全量确认；未获确认的偏好一律记入 §9 未知，不做猜测。

## 2. OpenAI 协议（官方一手来源）

证据通道：直连 developers.openai.com / platform.openai.com → 403（反爬）；事实经官方 OpenAPI spec（openapi 3.1.0，servers: `https://api.openai.com/v1`）、官方页 .md 源与官方页镜像取得。凡未逐字证实的标『未证实』。

- Reference 页有效：「Create chat completion | OpenAI API Reference」— https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create （200；JS 渲染 SPA；该页 .md 变体 404）
- 字段契约一手依据（官方 spec）：https://raw.githubusercontent.com/openai/openai-openapi/master/openapi.yaml
- 端点：`POST https://api.openai.com/v1/chat/completions`（operationId=createChatCompletion；spec 注明新集成建议用 Responses API）— spec
- 认证：Bearer（securitySchemes.ApiKeyAuth={type:http, scheme:bearer}，全局 security）— spec
- 请求必填：`model`、`messages`（required=[model, messages]）— spec
- 其他请求字段：max_completion_tokens、stop、stream、tools、tool_choice、parallel_tool_calls、response_format、frequency_penalty、presence_penalty — spec
- 响应必填：`id`、`object`、`created`、`model`、`choices`；choices[] 项必填 finish_reason、index、message、logprobs — spec
- finish_reason 枚举：`stop, length, tool_calls, content_filter, function_call` — spec
- usage：CompletionUsage={prompt_tokens, completion_tokens, total_tokens, …} — spec
- tool 输出：tools+tool_choice 支持 — spec；JSON 输出：response_format（json_schema=Structured Outputs 优先；json_object=旧 JSON mode）— spec
- 错误信封：`{"error":{"code":string|null,"message":string,"param":string|null,"type":string}}` 四字段全 required — spec
- 429：头 `Retry-After`（integer，可缺省）；体 error.type=rate_limit_error、error.code=slow_down — spec（InferenceRateLimited response）
- 503：error.type=service_unavailable_error、error.code=server_is_overloaded — spec
- 限流头（指南）：`Retry-After`、`x-ratelimit-limit-requests`、`x-ratelimit-limit-tokens`、`x-ratelimit-remaining-requests`、`x-ratelimit-remaining-tokens` — https://developers.openai.com/api/docs/guides/rate-limits ；原文「Retry-After may be present on 429 responses caused by a temporary rate limit and 503 responses caused by temporary model overload」— 同页
- `x-ratelimit-reset-requests/-reset-tokens` 未见逐字确认 — 未证实

### 2.1 Models list
- 页面有效：「List models」— https://developers.openai.com/api/reference/resources/models/methods/list （200；.md 变体 200 可直读）
- 端点：`GET https://api.openai.com/v1/models`（operationId=listModels）— .md + spec
- 响应：`{"object":"list","data":[{"id":"model-id-0","object":"model","created":…,"owned_by":…,"shutdown_date":null,…}]}`（data[].id 即模型 ID）— .md + spec
- 分页：ListModelsResponse 仅 object+data，无 has_more 等分页字段 — spec
- 错误：403→PermissionErrorResponse{error: Error|string}；通用形状同上 — spec

## 3. Anthropic 协议（官方一手来源）

证据通道：platform.claude.com /docs/* 直连被重定向 claude.com/app-unavailable-in-region（地区拦截，非页面失效）；事实经官方页 .md 源与镜像取得，标注为未证实的均未逐字落实。

- 页面有效：「Create a Message」— https://platform.claude.com/docs/en/api/messages/create
- 端点：`POST https://api.anthropic.com/v1/messages` — 同页 curl 例（`anthropic-version: 2023-06-01` + `X-Api-Key` 实发）
- 认证头：`x-api-key`；`anthropic-version: 2023-06-01`（curl 例实发；页面 Headers 节现标注 anthropic-version 为 optional string）— 同页
- 请求必填：`max_tokens`、`messages`（MessageParam{content, role}）、`model` — 同页 Body 节
- 可选：system、stop_sequences、stream、temperature、thinking、tools、tool_choice 等 — 同页
- 响应关键字段：id、type:"message"、role:"assistant"、model、`content`（ContentBlock 数组）、`stop_reason`、stop_sequence、stop_details、`usage` — 同页响应示例
- content 块：TextBlock{type:"text",…}、ThinkingBlock{type:"thinking",…}、ToolUseBlock{type:"tool_use",…} — 同页
- stop_reason 枚举（页面逐字）：`end_turn / max_tokens / stop_sequence / tool_use / pause_turn / refusal / model_context_window_exceeded` — 同页
- usage：{input_tokens, output_tokens, cache_creation_input_tokens, cache_read_input_tokens, output_tokens_details.thinking_tokens, …} — 同页
- 错误信封（https://platform.claude.com/docs/en/api/errors 逐字）：`{"type":"error","error":{"type":"not_found_error","message":"…"},"request_id":"req_…"}`；表述「The API always returns errors as JSON, with a top-level error object that always includes a type and message value. The response also includes a request_id field」— 同页
- 错误码表：400 invalid_request_error、401 authentication_error、402 billing_error、403 permission_error、404 not_found_error、409 conflict_error、413 request_too_large、429 rate_limit_error、500 api_error、529 overloaded_error — 同 errors 页
- request id：每个响应带 `request-id` 头，与错误体 request_id 同值 — 同 errors 页
- 429 语义：rate_limit_error；「A tier spend-cap 429 has no retry-after header and keeps failing until access resumes」— 同 errors 页；retry-after 头=seconds to wait（spend-cap 429 不发送）— https://platform.claude.com/docs/en/api/rate-limits
- 重试：529 overloaded_error=暂时过载；官方 SDK 对连接错误/限流/5xx 指数退避自动重试，默认两次，honoring retry-after，`max_retries` 可配 — 同 errors 页

### 3.1 Models list
- 页面有效：「List Models」— https://platform.claude.com/docs/en/api/models/list
- 端点：`GET https://api.anthropic.com/v1/models`（较新模型列前）— 同页
- data[]：ModelInfo{type:"model", id, capabilities, …}，另有 created_at(RFC 3339)、display_name、lifecycle — 同页 Returns 节
- 分页契约：`has_more`:boolean；`first_id`:string|null（作上一页 before_id）；`last_id`:string|null（作下一页 after_id）；查询参数 after_id、before_id、limit（default 20, min 1, max 1000）、lifecycle（active|deprecated|retired）— 同页

## 4. Anthropic 官方 OpenAI SDK 兼容层边界

- 页面有效：「OpenAI SDK compatibility」— https://platform.claude.com/docs/en/cli-sdks-libraries/libraries/openai-sdk
- 定位原句：「Anthropic provides a compatibility layer that enables you to use the OpenAI SDK to test the Claude API. With a few code changes, you can quickly evaluate Anthropic model capabilities.」
- 接入：官方 OpenAI SDK + base URL 改指 Claude API + 换 Claude key + 换 Claude model 名；多 workspace key 需附 `anthropic-workspace-id` 头 — 同页
- 兼容端点清单当前页未见逐字列出（仅见「Rate limits follow Anthropic's standard limits for the /v1/messages endpoint」）— 未证实
- 不承诺一致（原文引句）：「The strict parameter for function calling is ignored…tool use JSON is not guaranteed to follow the supplied schema.」「Audio input is not supported…」「Prompt caching is not supported…」「System/developer messages are hoisted and concatenated into the top-level system field」「Most unsupported fields are silently ignored rather than producing errors.」— 同页
- response_format 表格原文「Ignored. For JSON output, use Structured Outputs with the native Claude API」；n 必须=1；thinking 可传但「the OpenAI SDK doesn't return Claude's thinking」— 同页
- 响应字段：id/choices[]（恒长 1）/finish_reason/object/created/model/usage.prompt_tokens/usage.completion_tokens/usage.total_tokens Fully supported；usage 明细、logprobs、service_tier、system_fingerprint、choices[].message.refusal Always empty — 同页
- 错误兼容原句：「The compatibility layer maintains consistent error formats with the OpenAI API. However, the detailed error messages will not be equivalent. Only use the error messages for logging and debugging.」— 同页
- 兼容层响应头：x-ratelimit-limit/-remaining-requests/-tokens、x-ratelimit-reset-requests/-tokens、retry-after、request-id 均 Fully supported — 同页

## 5. 票内引用 URL 逐一核对（全部有效）

1. developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create — 有效（200；SPA 壳）
2. developers.openai.com/api/reference/resources/models/methods/list — 有效（.md 可直读）
3. platform.claude.com/docs/en/api/messages/create — 有效
4. platform.claude.com/docs/en/api/models/list — 有效
5. platform.claude.com/docs/en/cli-sdks-libraries/libraries/openai-sdk — 有效

## 6. 最小可用请求骨架

```http
# OpenAI 官方直连
POST https://api.openai.com/v1/chat/completions
Authorization: Bearer $OPENAI_API_KEY
Content-Type: application/json

{"model":"MODEL_ID","messages":[{"role":"user","content":"Hi"}]}

# OpenAI 模型列表
GET https://api.openai.com/v1/models
Authorization: Bearer $OPENAI_API_KEY
# 响应最小集：object:"list" + data[].id；无分页字段

# Anthropic 官方直连
POST https://api.anthropic.com/v1/messages
x-api-key: $ANTHROPIC_API_KEY
anthropic-version: 2023-06-01
content-type: application/json

{"model":"MODEL_ID","max_tokens":1024,"messages":[{"role":"user","content":"Hi"}]}

# Anthropic 模型列表
GET https://api.anthropic.com/v1/models
x-api-key: $ANTHROPIC_API_KEY
anthropic-version: 2023-06-01
# 响应：data[].id + has_more/first_id/last_id
```

## 7. 代码基线（09f066def 与当前 HEAD）

### 7.0 基线确认
- PR #104 headRefOid = 09f066def5bb274b473650a1af55ccf15a1c0b51（gh pr view 104 实测，state OPEN）——与票内引用一致。
- 本地 HEAD 在研究期间从 5b514cf75 前进到 6b422e64（共享工作区并行交付）；基线→HEAD 在 jev / reply_controller / http / shielding 范围共 13 文件变更（全库 28 文件，+2711/−160）。
- `.scratch/research/task5-llm-overlap.md` 本地不存在（not found），其结论已由 #114 评论存档。

### 7.1 基线（09f066def）已存在（文件:行号按 HEAD 现值标注，基线同构）
- typed Decisions 协议双提供方：JevProvider{typeSafe: https://api.typesafe.ai/v1/systemone + jev-latest; openRouter: https://openrouter.ai/api/alpha/decisions + ~typesafe/jev-latest} — lib/features/jev/jev_contract.dart:5；契约注释钉死 typed-decision 语义（:32），聊天协议进不了这个枚举。
- 模型目录：OpenRouter GET https://openrouter.ai/api/v1/models?output_modalities=decisions（data[].id + architecture.output_modalities 过滤）/ TypeSafe GET https://api.typesafe.ai/v1/models（models[].name）；followRedirects:false；异常整体吞掉防 authorization 头外泄；目录≠验证，失败保留手填 — lib/features/jev/jev_model_catalog.dart:12-65。
- typed Noul probe：独立 Dio（注释明确不与共享 HTTP 客户端共享 cookie/账号/设备头）、合成无候选问题、9 值 outcome（ok/invalidKey 401/403、rateLimited 429/529、rejectedRequest 400/422、modelNotFound、serverError、timeout、networkError、malformedResponse）、detail=「HTTP $status：$summary」截断 200 runes（#101 detail 透传）— lib/features/jev/jev_http_probe.dart:50-196；错误消息提取兼容 error.message 与 message/detail/error 键（:163-175）。
- 凭据：SecureJevCredentialStore（安全存储，状态枚举 available/unavailable）— lib/features/jev/jev_credential_store.dart:36。
- 推荐链 final screen 挂点：lib/http/video.dart:977,1001,1077,1108、lib/http/pgc.dart:90、lib/http/music.dart:61、lib/features/shielding/recommendation_surfaces.dart:42-118。
- 评论面基线实测：仅低成本 shielding（applyShielding），无任何 Jev/语义筛选（git show 09f066def:lib/pages/common/reply_controller.dart 无 screenComments；jev_contract.dart 无 comment 面）。
- JevLimits：batchSize 3、requestTimeout 8s、并发 1（串行）、maxAttempts 1（无重试即 fail-open）、hideNoulThreshold 0.95、minReportedConfidence 0.9 — lib/features/jev/jev_contract.dart:104-137。

### 7.2 HEAD（6b422e64）新增——#109/#120 并行交付，不在 #114 引用基线内
- 新增文件：jev_comment_screening.dart、jev_rules.dart、jev_screen_log.dart、jev_verdict_cache.dart（git diff --name-status 实测 A）。
- JevSurface 新增 comment('video_comments'，已接线) — lib/features/jev/jev_contract.dart:65；live 未接线（#115）。
- 评论接入：lib/pages/common/reply_controller.dart:66 prepareListResponse→screenComments；:86-110 collect 递归覆盖主评论+楼中楼（reply.replies），rebuild 保结构；分页字段 cursorNext/paginationReply（:117-118）；刷新置顶 upTop（:123-125）；数据模型 gRPC ReplyInfo（lib/grpc/bilibili/main/community/reply/v1.pb.dart）。
- JevCommentScreening：预算=min(timeout, 8s)；policyKey=非秘密策略标识（enabled/commentEnabled/commentCriteria/provider.id/providerConfirmed/modelFor/hideNoulThreshold），凭据不入缓存；按文本去重计数；maxTextChars 2000（不完整前缀不屏蔽）；maxCriteriaChars 4000；cacheable 标志 — lib/features/jev/jev_comment_screening.dart:33-100。
- JevScreenLog：仅本地 Hive box、无遥测、环形 300 条、单条文本 200 runes、只存标题/正文/面（kind video|comment），不含 id/链接/账号 — lib/features/jev/jev_screen_log.dart:53-71。
- JevVerdictCache：generation 失效模式 — lib/features/jev/jev_verdict_cache.dart:17。
- HTTP 栈：共享 Dio（lib/http/http_client 区域 lib/http/init.dart:32 dio 单例）；Jev 探测/目录/评论筛选均自建 Dio 实例实现 cookie 隔离。

### 7.3 对通用 LLM 双协议的直接含义
- 可平移复用面（与 #111 Notes 一致）：per-provider 模型持久化与 modelFor、probe outcome/detail 模式、catalog 手填回退、独立 Dio 隔离、JevScreenLog 双 kind、policyKey 失效模式。
- 需要新增的轴：协议类型（OpenAI Compatible chat / Anthropic Compatible messages）× 端点 × Key——现有 JevProvider 枚举是 typed Decisions 专用，语义上不能塞聊天端点；通用线应是新协议枚举 + 自定义端点/Key 存储。
- 接入顺序（HEAD 现状）：applyShielding（低成本，reply_controller.dart:76）→ JevCommentScreening（:96）；通用 LLM 按 #113 决议插在 Jev 未命中之后，同一 prepareListResponse 串联点。
- 输出解析现状已按 OpenAI 错误信封取 error.message（jev_http_probe.dart:163-175）；Anthropic 信封 {type:error, error:{type,message}, request_id} 兼容该提取路径；request_id 可入排障日志（无敏感负载）。
- 预算对齐：JevLimits.requestTimeout=8s 与 #113 单页 8s 共享预算同数量级；通用线建议沿用「预算内单次、无重试、fail-open」现模式（maxAttempts=1）。

## 8. 接入契约映射（协议事实 → 规格建议）

> 本节只把 #113 已确认的产品共识映射到协议事实，属研究建议；不新增产品决策。未获确认项见 §9。

### 8.1 通用规则输出契约
- 两种协议均可用单轮非流式请求承载判定任务：OpenAI 侧解析 choices[0].message.content（choices 可多条，判定场景固定取第一条）；Anthropic 侧拼接 content 中 type:"text" 块（须跳过 thinking/tool_use 块）。
- 结构化判定输出：OpenAI 直连可用 response_format json_schema（spec）；Anthropic 直连原生无 response_format，需在提示词内约束 JSON 并自行解析；Anthropic OpenAI 兼容层 response_format 被忽略（原页），不可依赖。→ 规格建议：输出契约按『文本内 JSON + 宽松解析 + 解析失败视为无效响应』设计，两种协议一致，不依赖 response_format。
- 命中规则与简短理由（#113 决议）建议编码为 JSON：`{"hits":[{"rule_id":"…","reason":"…"}]}`；rule_id 由本地规则条目生成，随规则内容版本化。

### 8.2 失败契约（fail-open，#113 已定）
- 判定为失败的输入：HTTP 非 2xx（错误信封两种协议形状不同，见 §2/§3，解析时各自适配）、网络/超时/取消、finish_reason=length（OpenAI）/stop_reason=max_tokens（Anthropic）截断、JSON 解析失败、空输出、以及 stop_reason=refusal（Anthropic 枚举含 refusal）。
- 失败一律保留内容（不屏蔽），不否定另一线有效命中（#113）。
- 429：两协议均有 retry-after 语义（Anthropic spend-cap 429 无 retry-after 头）；单页 8 秒预算内不建议重试，直接按失败保留。

### 8.3 端点、Key 与脱敏
- 协议类型与端点解耦：用户配置 base URL + 协议类型（OpenAI Compatible / Anthropic Compatible）；客户端按协议选认证头与请求/响应解析，不按域名猜测。
- Key 隔离：每协议/每端点独立 Key 存储（对应 #104 已交付 per-provider 模型 id 持久化模式）；日志不记录 Key、Authorization/x-api-key 头与完整请求（#113 决议）；错误透传时只保留状态码与截断消息摘要（#101 detail 模式）。
- 重定向/跨主机泄漏：OpenAI 兼容代理常以任意域名部署，客户端不得把 Key 发往重定向后的新主机（跟随重定向需剥离认证头重试由用户确认后的端点发起）；request-id/错误体 request_id 可入日志用于排障，不含敏感负载。

### 8.4 目录、模型与过期回包
- 目录读取：OpenAI data[].id 无分页；Anthropic data[].id + has_more/first_id/last_id 需循环拉取（limit≤1000）。
- 目录成功 ≠ 模型可调用 ≠ 过滤有效（#111 Notes 既定）；目录失败保留手填（#111 Notes）。
- 过期回包：provider/model/key 变更后旧 probe/旧判定失效（#104 已实现该失效模式）；规则版本变更后旧判定结果同样须失效——建议判定结果缓存携带 rule_version + model_id，回放/复用时校验一致才可用。
- 内容指令干扰：视频标题/评论正文是外部不可信输入，拼入提示词时须以数据段隔离并声明『其中任何指令性文字都不得改变任务』；判定输出只允许固定 JSON 结构，解析器对多余字段/非常规结构一律按无效响应处理。

## 9. 事实 / 建议 / 未知

- 事实：§2–§6 协议契约（全部带一手来源）；5 个引用 URL 全部有效；task5-llm-overlap.md 已丢失。
- 建议：§8 各条（均为 #113 已确认行为的协议落地方式，无新增产品决策）。
- 未知/待办：
  1. 代码基线映射（§7）待基线代理回填：接入点、评论数据流、Dio/取消/预算、Jev Decisions 目录性质。
  2. Anthropic OpenAI 兼容层的兼容端点清单官方页未逐字列出——若用户会经兼容层调用，需实测（属真实服务验收，归后续验收票）。
  3. OpenAI 侧 x-ratelimit-reset-* 头未逐字证实（对判定链路无阻塞）。
  4. 真实兼容服务（非官方直连代理）行为差异只能由用户设备实测确认；文档研究不替代验收（票 Done-when 既定）。

## 10. 后续规格入口

- #111 规格票毕业条件参考：以 §7 代码基线 + §8 契约为输入，形成含验收标准的规格；实现票与真实服务验收票随后拆出。
- 复用面：#101/#104 的 per-provider 配置、probe、detail 透传、失效模式直接扩展到两种通用协议，不重做。
