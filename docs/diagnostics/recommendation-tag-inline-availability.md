# 推荐面标签：能否内联 / 能否批量取回

调查对象：首页推荐面每页标签判定的取数通道（`RecommendationTagEnricher` → `UserHttp.videoTags` → `/x/web-interface/view/detail/tag`）。
调查树：`D:\Documents\vibe\PiliAvalon-Worksite`，`main` @ `e998665ab`（`git rev-parse --short HEAD`，工作树除未跟踪 `tool/bench/` 外干净）。
调查方式：源码通读 + 9 次无凭据真实 curl 探测（本机 `curl.exe`，无 cookie、无 wbi 签名，`User-Agent: Mozilla/5.0`）+ 社区 API 文档比对。**未做任何代码改动，未做任何 git 操作。**

## 结论（三选一）

**③ 都不行 → 标签阶段只能靠缓存/去重削减。**

取值条件（两句都成立时才是 ③，实测两句都成立）：

1. **不能内联**：推荐面实际调用的两个推荐接口，其条目 JSON 里**没有**标签名/标签列表字段。web 通道 item 字段实测无 `tag`/`tags`/`tname`；app 通道 item 只有分区名 `args.tname`（本仓库已把它当 `category` 消费，不是标签列表），也没有 `tag`/`tags`。
2. **不能批量**：`/x/web-interface/view/detail/tag` 一次只吃一个 `aid` **或** `bvid`。多传 bvid 时只认第一个（另一个被静默忽略），逗号拼接直接 `-400`；仓库内不存在任何可批量取视频标签的接口或调用点。

对「标签阶段」的处置建议：

- **保留标签阶段，任何票都不要写「删除标签阶段」或「每页标签请求压到常数 1」**——上游不给这两个能力，写了必然落不了地。
- 可削减的量只能来自三个来源，且**下界不是 1，而是「本页去重后未命中缓存的候选数」**：(a) 缓存命中（BVID+CID 缓存 + 负缓存，已由 #49 交付）；(b) 取标签只对**幸存候选**发起（现状已如此，见证据 F，所以收益来自提高前置规则命中率，而不是改标签层）；(c) 同批/跨页去重（页内 20 条一般互不相同，页内去重收益有限；跨页重复是否常见未验证，见「未验证」第 6 条）。
- 若哪天要拿到 ① 或 ②，唯一判据是**带登录凭据的推荐响应里出现标签字段**，或**标签接口接受列表入参**——两者目前都无法在无凭据下排除，见「未验证」第 1、2 条。

## 证据

### A. 推荐面条目模型解析到的字段全集（无 tag 字段）

来源：`lib/models/model_rec_video_item.dart:4-12`（基类 `BaseRcmdVideoItemModel`）、`lib/models/model_rec_video_item.dart:15-32`（`RcmdVideoItemModel.fromJson`）

web 条目模型解析的**全部**字段：`id→aid`、`bvid`、`cid`、`goto`、`uri`、`pic→cover`、`title`、`duration`、`pubdate`、`owner→Owner`、`stat→Stat`、`is_followed`、`rcmdReason`（`json["rcmd_reason"]?['content']`，见 `lib/models/model_rec_video_item.dart:31`）。基类另带 app 侧补充字段 `param`、`pgcbadge`。

**没有 `tag` / `tags` / `tname` / `tag_name` 任何一个。** 该票提到的 `lib/models_new/` 下推荐条目模型在本树不存在（`glob lib/models_new/**/*rcmd*` 无结果）；web 推荐条目在 `lib/models/`，app 推荐条目在 `lib/models/home/rcmd/result.dart`。

相关父类：`lib/models/model_video.dart:1-16`（title/bvid/cid/cover/duration/owner/stat + aid/desc/pubdate/isFollowed），`lib/models/model_video.dart:32-41`（`Stat.fromJson` 读 view/like/danmaku/reply/coin/favorite）。同样无标签字段。

### B. app 推荐条目模型字段全集（有分区名 tname，无标签列表）

来源：`lib/models/home/rcmd/result.dart:7-52`（`RcmdVideoItemAppModel.fromJson`）

解析字段：`player_args.aid`、`bvid`、`player_args.cid`、`cover`、`stat→RcmdStat`、`player_args.duration`、`title`、`owner→RcmdOwner`、`rcmdReason = json['rcmd_reason']`（`lib/models/home/rcmd/result.dart:25`）、`goto`、`param`、`uri`、`talk_back`、`pgcBadge`(← `cover_right_text`)、`card_type`、`three_point_v2`、`desc`。**无任何 tag 类字段。**

### C. 两个推荐接口的真实响应（实测，无凭据）

来源：curl 实测（本机，无 cookie / 无 wbi 签名 / 无 appkey 签名）

1. **web 首页推荐** `https://api.bilibili.com/x/web-interface/wbi/index/top/feed/rcmd?ps=20&fresh_idx=1&fresh_type=4&version=1&feed_version=V8&homepage_ver=1&brush=1` → `code:0`，返回 20 条 item，**未签名未登录也能取到数据**。item 字段全集实测：
   `id, bvid, cid, goto, uri, pic, pic_4_3, title, duration, pubdate, owner{mid,name,face}, stat{view,like,danmaku,vt}, av_feature, is_followed, rcmd_reason, show_info, track_id, pos, room_info, ogv_info, business_info, is_stock, enable_vt, vt_display, dislike_switch, dislike_switch_pc`
   → **无 `tag` / `tags` / `tname` / `desc` / `staff`**；未登录时 `rcmd_reason` 全为 `null`。
2. **app 首页推荐**（本仓库 `Api.recommendListApp` 指向的同一个 path：`lib/http/api.dart:5-6` `'${HttpString.appBaseUrl}/x/v2/feed/index'`）`https://app.bilibili.com/x/v2/feed/index?build=2001100&mobi_app=android_hd&platform=android&idx=0&column=4&pull=true` → `code:0`，`data.items[]` 实测字段：
   `card_type, card_goto, goto, param, cover, title, uri, args{up_id,up_name,tid,tname,aid}, player_args{aid,cid,type,duration}, idx, three_point_v2[], track_id, talk_back, report_flow_data, cover_left_text_1/2, cover_left_icon_1/2, cover_left_1/2_content_description, cover_right_text, desc_button{text,uri,event,type}, desc, can_play, goto_icon{...}, official_icon(部分条目)`
   → **有 `args.tname`（分区/频道名，实测样本如「林丹」「游戏」「星穹铁道剧情」），但没有任何标签列表字段**；注意该通道的顶层 `desc` 实测是 UP 名，不是简介。

### D. 标签接口 `/x/web-interface/view/detail/tag` 的入参与批量能力（实测）

来源：`lib/http/api.dart:685`（`static const String videoTags = '/x/web-interface/view/detail/tag';`；旧常量 `/x/tag/archive/tags` 在 `lib/http/api.dart:684` 被注释掉）；`lib/http/user.dart:331-348`（`UserHttp.videoTags({required String bvid, Object? cid})`，`queryParameters: {'bvid': bvid, 'cid': ?cid}`，签名形参只有**单个 bvid**，仓库内唯一的视频标签取用点）。

curl 实测（每次都是无 cookie、无签名）：

1. `?bvid=BV1uv411q7M3` → `{"code":0,"message":"OK","ttl":1,"data":[{"tag_id":1090382,"tag_name":"手帐","music_id":"","tag_type":"old_channel","jump_url":""},…]}`（共 3 个标签）→ **无 cookie、无 wbi 签名可用**；结构是平铺数组 `data[]`，字段 `tag_id / tag_name / music_id / tag_type / jump_url`。
2. `?bvid=BV1uv411q7M3&bvid=BV1CGam6HEuv` → 只回 `BV1uv411q7M3` 的 3 个标签。
3. `?bvid=BV1CGam6HEuv&bvid=BV1uv411q7M3`（**反向排序对照实验**）→ 只回 `BV1CGam6HEuv` 的 9 个标签（英雄联盟十五周年/第一视角/电子竞技/英雄联盟/上单/狗头吧/逍遥v浪迹峡谷/沙漠死神/MOBA）。
   → 2+3 合并结论：**重复 `bvid` 参数只取第一个，其余静默忽略；这不是批量接口。**
4. `?bvid=BV1uv411q7M3,BV1CGam6HEuv`（逗号拼接）→ `{"code":-400,"message":"请求错误","ttl":1}` → **不支持逗号拼接批量**。
5. `?aid=117369997365447` → 返回与 `BV1CGam6HEuv` 同一标签集合（顺序不同）→ `aid` 与 `bvid` 二选一，**仍是单条**。
6. 旧常量 `https://api.bilibili.com/x/tag/archive/tags?bvid=BV1uv411q7M3` → `code:0`，同一 3 个标签但结构更胖（`cover/head_cover/content/short_content/type/state/ctime/count{view,use,atten}/is_atten/likes/hates/attribute/liked/hated/extra_attr`），无 cookie 也可用；**同样没有任何批量入参**。

对照模型：`lib/models_new/video/video_tag/data.dart:1-20` `VideoTagItem.fromJson`：`tag_id→tagId`、`tag_name→tagName`、`tag_type→tagType`、`music_id→musicId`（后两字段正是上面实测中出现的字段，解析面与实测结构对得上）。

### E. 仓库内不存在其它可批量取标签的接口

来源：全仓库 `lib/http/*.dart` 通读 + `grep tag_name|detail/tag|archive/tags` 覆盖 `test/`、`docs/`

`lib/http/api.dart` 里所有与 tag 有关的常量：`lib/http/api.dart:443` `/x/relation/tags`（关注分组）、`lib/http/api.dart:447/449/451/454/456/458/460`（关注分组增删改）、`lib/http/api.dart:799-803`（直播收藏标签）、`lib/http/api.dart:1012`（关注分组排序）、`lib/http/api.dart:684/685`（视频标签）。**除视频标签那两个常量外都不是视频标签通道；仓库里没有任何可批量取视频标签的接口，`UserHttp.videoTags` 是唯一取用点。**

测试/文档侧无任何标签响应夹具可引用：`test/`、`docs/` 内无 `tag_name` / `detail/tag` / `archive/tags` 匹配；`test/features/shielding/shielding_adapters_test.dart` 只有 `rcmd_reason` 样例（32/41/63/197/752/1232 等行），**无标签 JSON 夹具**。`docs/` 现有内容只有 `docs/agents/issue-tracker.md`、`docs/agents/triage-labels.md`、`docs/agents/domain.md`。

### F. 适配层已把「内联标签」接线，但上游不送

来源：`lib/features/shielding/shielding_adapters.dart:10-76`（`fromRecommendationJson`）、`lib/features/shielding/shielding_adapters.dart:197-209`（`_tags`）

- `category = _string(json['tname'] ?? args?['tname'])`（`lib/features/shielding/shielding_adapters.dart:16`）→ **app 通道的分区名今天就是内联消费的**（对应证据 C-2 的 `args.tname`）。
- `final tags = _tags(json)`（`lib/features/shielding/shielding_adapters.dart:24`），`_tags` 读 `json['tag'] ?? json['tags']`，支持 Iterable 或逗号/空白分隔字符串（`lib/features/shielding/shielding_adapters.dart:197-209`）。
  → 结论：**一旦上游真的内联 `tag`/`tags`，现有代码无需改模型即可直接消费**；也就是说 ① 的门槛不在客户端，而在上游响应（证据 C 证明当前两个推荐接口不送）。
- 取标签只对幸存候选发起：web 路径 `RecommendFilter.filter` 之后才跑 `RecommendationTagEnricher().enrichAndFilter(survivors, …)`（`lib/http/video.dart:94-100`），app 路径同理（`lib/http/video.dart:200-206`）；`enrichAndFilter` 只对入参列表逐条取，缓存 miss 才入 pending（`lib/features/shielding/shielding_recommend_tag_enricher.dart:116-165`），并发默认 5、超时 3s、缓存 TTL 30min、失败/空标签 fail-open 保留（`lib/features/shielding/shielding_recommend_tag_enricher.dart:13/14/15/221-224`）。
- 每页 20 条的来源：`lib/pages/rcmd/controller.dart:26-27`（`appRcmd ? VideoHttp.rcmdVideoListApp(freshIdx: page) : VideoHttp.rcmdVideoList(freshIdx: page, ps: 20)`）。web 推荐请求本身经 wbi 签名（`lib/http/video.dart:57-116`，`WbiSign.makSign({version:1, feed_version:'V8', homepage_ver:1, ps, fresh_idx, brush, fresh_type:4})`）。

### G. 社区文档交叉验证（**社区文档，非第一方**）

来源（社区维护，非第一方）：`https://raw.githubusercontent.com/Dispa1r/bilibili-API-collect/refs/heads/master/docs/video/tags.md`（SocialSisterYi/bilibili-API-collect 的 fork；原仓库 master 上 `docs/video/tags.md`、`docs/video/video_tag.md`、`docs/video/recommend.md` 的 raw 路径实测 404，GitHub contents API 因限流 403）

- `docs/video/tags.md`（**社区文档，非第一方**）：`/x/tag/archive/tags` 的 url 参数表只有 `aid`（「必要（可选）| avid与bvid任选一个」）与 `bvid`（同注）两项，**未列任何批量参数**；响应字段表与我方实测（证据 D-6）逐字段一致。该文档标注认证方式为 Cookie（SESSDATA），但本次实测无 cookie 亦返回 `code:0`——**文档与实测在此点不一致，以实测为准**。
- `docs/video/recommend.md`（**社区文档，非第一方**）：首页推荐 `/x/web-interface/index/top/rcmd` 的示例 item 字段为 `id,bvid,cid,goto,uri,pic,title,duration,pubdate,owner,stat{view,like,danmaku},avfeature,isfollowed,rcmdreason{content,reasontype},showinfo,trackid`——**无 tag 字段**（与实测 C-1 吻合，实测另有若干新字段）；短视频 `/x/v2/feed/index` 的 items 字段表只列 `can_play/card_goto/card_type/cover/cover_left*/cover_right*/desc_button/param/player_args/talk_back/title/uri`，示例里另有 `args{up_id,up_name,rid,rname,tid,tname,aid}`——**同样无 tag 字段**（与实测 C-2 吻合）。

## 未验证

1. **登录态下推荐响应是否追加标签字段**（最关键的一条）。web 推荐接口未签名也返回 `code:0`，因此本次只证明了「匿名态下 item 无 tag 字段」；带 SESSDATA + wbi 签名的响应字段集**无法在无凭据下验证**（本环境无可用账号 cookie）。`/x/player/wbi/v2` 在无签名/未登录时返回 `{"code":-404,"message":"啥都木有"}`，也说明签名+登录态确实会改变可用面。
2. **标签接口在登录态下是否解锁列表入参**。匿名态实测 `bvid` 重复、逗号拼接、`aid` 三种写法都只有单条能力（证据 D）；登录态是否不同未验证。要验证需要「登录后同三组实验重放」。
3. **app 通道在真实 appkey 签名 + 登录态下的 items 字段集**。`x/v2/feed/index` 能匿名取到 `code:0`，但字段集是否随登录态变化未验证；`args.tname` 之外是否会出现 tag 列表同样未验证。
4. **`/x/web-interface/view/detail`（详情聚合）是否一次带回 `Tags`**。本仓库注释提到过该接口（`lib/http/api.dart:36,39`），但它本身是**单视频**接口，即使带 `Tags` 也不解决本票的批量问题，故未做探测。同样未探：搜索接口（`/x/web-interface/search/type` 匿名请求被风控返回「出错啦!」验证页 HTML）、其它可能一次带多视频元数据的接口（如 `archive/stat` 类，推测不含标签，**未实测，不作结论**）。
5. **「每页 20 次标签请求」这一基线数字的原始数据无法复核**。该数字来自已关闭票 #48，其产物 `docs/diagnostics/recommendation-request-baseline.md` 在本树与任何远程分支都不存在（`docs/` 被 `.gitignore:189` 整体忽略，从未 `git add -f` 过，见下节）。本报告只证明「标签请求按候选条数放大」这一**结构性**事实（`lib/http/video.dart:94-100`、`lib/features/shielding/shielding_recommend_tag_enricher.dart:180-235`），未独立复测 20 这个数字。
6. **跨页是否重复推同一 bvid**（决定跨页去重能省多少）未验证；本报告不给出页内/跨页去重的收益估计。
7. **匿名探测结果与实际 App 请求的等价性**：本次用桌面 UA、无 buvid/fp 指纹（App 路径实际会带 buvid/fp_local/fp_remote/session_id 等 header，见 `lib/http/video.dart:119-222`）；响应**结构**上是否与真机一致未验证，只能说匿名态的字段集里没有标签字段。

## 对 map #47 的影响

- **本票 #67 自身可据此关闭**：答案为 ③，取值条件见「结论」。
- **可划掉 map #47 的 fog 第 1 条**：「是否存在推荐接口本身可一次性带回标签的替代接口（若存在，可整条砍掉标签获取阶段）」→ 在**匿名态实测**下，两个在用的推荐接口都不带标签字段，`/x/web-interface/view/detail/tag` 也无批量能力；该 fog 可收敛为结论 ③。仅剩「登录态是否不同」这一条尾巴（未验证第 1、2 条），若要彻底钉死需在带 cookie 的环境复跑证据 C/D 的实验。
- **#49（统一并去重标签获取路径，closed）是唯一有效杠杆，方向不变**：既然 ① ② 都不成立，BVID+CID 缓存 + 同键并发合并 + 失败/空负缓存就是削减标签请求的全部手段，不需要为「内联」回炉重做。
- **#51（合并双过滤引擎并消灭重复判定）、#52（ShieldMatcher 热路径）目标不变**：两者是 CPU 侧重复判定与判定成本问题，与本票的取数通道结论无依赖关系。
- **#54（锁定性能/请求数验收基线，open）的目标式必须按 ③ 现实化**。它正文写的「每页额外请求数从 O(N) 降到 ≤ 常数 a + 去重后 b」在标签阶段只能实现为：**≤（本页幸存候选去重后未命中缓存的条数）**，即上界随 N 走、由命中率与去重率压低，**不许写成「标签请求 ≤ 常数 1」**。建议 #54 的目标行明确拆成「feed 请求 1 次/页」+「标签请求 = 幸存候选 unique 未命中数/页」两条口径。
- **给 #54 / #51 的可削减杠杆排序（本报告支持的范围内）**：① 取标签只对幸存候选发起（现状已如此，见证据 F，因此改标签层无收益，收益在提高前置规则命中率）；② 缓存命中与负缓存（#49 已交付）；③ 同键并发合并（#49 已交付）；④ 跨页去重（收益未知，需先验证未验证第 6 条）。**顺序里没有「删掉标签阶段」这一项。**
- **落盘注意（会影响票里链接可用性）**：`docs/` 被 `.gitignore:189` 整体忽略（实测 `git check-ignore -v docs/diagnostics/recommendation-tag-inline-availability.md` → `.gitignore:189:docs/`）。本报告要让票里的 `blob/...` 链接不 404，**必须由主会话用 `git add -f docs/diagnostics/recommendation-tag-inline-availability.md` 入库**；本报告作者未执行任何 git 操作。
