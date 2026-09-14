# Sprint 1.0 Report — Native Media Experience & Memory Discovery

Status: 机器验证完成（含 iOS Release Build），真机 Gate 待人工执行
Branch: `feat/native-memory-experience-v1.0`（自 `feat/product-experience-v0.9` @ `11bc600` 检出）
Date: 2026-09-14（Final Release Gate 轮更新）

---

## 1. Workspace

| 项 | 值 |
| --- | --- |
| 分支 | `feat/native-memory-experience-v1.0` |
| Base | `feat/product-experience-v0.9` @ `11bc600`（远端已验证阶段 HEAD） |
| 检出方式 | 保留 0.9 成果作为 checkpoint，未动 main |
| working tree | 仅 `CLAUDE.md` / `.DS_Store` 保持 untracked（未修改未提交） |
| remote | `https://github.com/JerseyBro/LifeMovie.git` |
| 远端分支 | 本轮修复：远端此前**不存在**该分支；已 `git push -u origin feat/native-memory-experience-v1.0` 并验证 `LOCAL == REMOTE == 33ab366` |

## 2. Benchmark（PART G）

交付文档：

- `docs/product/PHOTO_EXPERIENCE_BENCHMARK.md` — Apple Photos (iOS 26) / Google Photos / Immich 的 what works / why / borrow / NOT copy。
- `docs/product/DISCOVERY_HOME_BENCHMARK.md` — 首页信息架构基准与 LifeMovie 决策。

核心决策：Apple Photos 管"我的照片"，LifeMovie 管"我的记忆"；体验基准取 Apple、查询模型取 Immich、入口形态取 Google Photos 语义搜索（V1 仅 metadata）。

## 3. Viewer Architecture（PART A）

交付：`docs/adr/ADR_MEDIA_VIEWER_ARCHITECTURE.md`

- **旧架构审计**：四层识别器（vertical drag / PageView horizontal / InteractiveViewer scale / tap+double-tap）靠竞技场偶然结果仲裁；`_pageLocked` 在拖动中途切换 physics；tap chrome 有 ~300ms 双击判定延迟；媒体请求只增不减无取消；无 prefetch；CupertinoPageRoute 黑闪进场均违反原生手感要求。
- **新架构（Option A，纯 Flutter 自定义）**：显式手势所有权契约（idle/paging/dismissing/zooming/zoomedPan/animating 状态语义），`PageView` 保留系统级 paging 物理，自研 `PinchPanRecognizer`（双指立即接受、单指仅在 zoomed 时接受，否则自行弃权）+ `TapSequenceRecognizer`（单击即时生效，双击时序判定并回退 chrome）+ 竖直 dismiss 识别器。Option B（photo_view）被否：只解决最不难的 zoom 数学，不解决仲裁与生命周期；Option C（iOS 原生桥）保留为 Fallback 路径。
- **媒体加载**：thumb(360) 立即 → preview(2200) 无缝替换；±1 窗口 prefetch；preview LRU≤3、thumb LRU≤30；离窗请求经 `cancelThumbnailRequest` 取消；`cacheWidth` 按设备像素上限解码；失败保留 thumb + 重试位。
- **打开转场**：`PhotoViewerRoute` 以被点缩略图屏幕 rect → 全屏 contain rect 的连续缩放 + 黑底淡入；字节来源 `ThumbnailBytesCache`（MediaPreview 落入的 LRU），无 spinner 断裂。

## 4. Media UX

| 能力 | 实现 |
| --- | --- |
| 打开即位置 | tapped index 精确打开（detail/时间线/搜索均携带 rect+thumb） |
| 水平 paging | PageView 速度敏感 snap；zoomed 时整个触摸序列锁定 |
| pinch zoom | 双指立即接管；绕焦心缩放；1x–5x 连续 |
| zoomed pan | 单指 pan，T·S 矩阵 clamp + 0.35 rubber-band + 惯性 fling |
| double tap | 绕点击点 2.4x，240ms easeOutCubic，无跳变 |
| interactive dismiss | 照片跟手 + 背景压暗 + 缩小；距离 120px 或速度 700 完成否则 spring 回位 |
| chrome | 单击即时显隐；双击回退；淡入淡出 180ms |
| filmstrip | Memory 范围缩略图条，点跳 + 横向 scrub + selection haptic |
| Info | 拖拽 sheet：日期/时间/城市级地点/类型/尺寸/时长/所属记忆（无数据不显示行） |
| 底部操作 | 收藏（写回 PhotoKit）/ 分享（系统 share sheet）/ 信息 / 编辑；无假按钮 |
| 视频 | 海报 + play/pause + scrub + mute（video_player，`loadVideoPlaybackUrl` 走 PHImageManager AVURLAsset） |

## 5. Editor

- **模型**：`memory_domain.EditRecipe`（rotation quarter turns / straighten / 归一化 crop / 七项调整 / 滤镜），immutable、JSON 序列化、`isIdentity` 语义。
- **持久化**：`EditRecipeStore`（app support 目录 JSON，`lifemovie_edit_recipes.json`）；identity 配方不落盘；**PhotoKit 原图零接触**，导出副本/写回相册明确留待后续决策。
- **UI**：调整（滑块）/ 滤镜（chips）/ 裁剪（旋转 90°、拉直滑块、居中 aspect）三栏；还原带触觉反馈；Cancel 不触 store，Done 持久化。
- **渲染**：`colorMatrixFor` 纯函数 4x5 RGBA 矩阵（编辑器与 Viewer 共用）；Viewer 应用色彩矩阵 + 四分之一旋转；crop/straighten 仅编辑器预览（V1 边界，见 Remaining Debt）。

## 6. Discovery

- **IA**：`发现 / 时光 / 搜索` 三 tab；For You 首屏 Hero Memory 单卡（cinematic cover + 标题 + 故事线索 + 继续回看），Explore 维度（最近发现/地点/人物/旅途/年份/初见/每年相聚/成长变化）按真实数据出现，无空壳 section。
- **查询模型**：`memory_domain.MemoryDiscoveryQuery`（years/placeIds/personIds/memoryTypes/mediaTypes/favoritesOnly/sort），immutable；**跨维度 AND / 维度内 OR**；`without()` 支撑 active chip 单删。
- **引擎**：`DiscoveryQueryEngine`（纯过滤/排序，推荐态保持 ranking 顺序不重打分）；`DiscoveryDimensionIndex`（500m 聚类地点、personIds 分组、类型 section、年份分布）；`DiscoverySearchService`（年份 token + 类型关键词 + 注入式文本匹配，为语义搜索留接口；禁止为此引入 backend）。
- **Timeline**：年 → 月 → 缩略图网格，点击开 Viewer（主动探索）。
- **Search**：大搜索框 + Quick Filters（年份 top3/旅途/视频/收藏）+ Advanced Filter Sheet（时间/地点/记忆类型/媒体分组）+ 结果列表。
- **People**：仅在资产存在 personIds 分组时渲染，中性文案"这个人"，不推断身份（隐私红线）。
- **Place**：城市级 CLGeocoder 标签 + 内存缓存，UI 不出现精确坐标。

## 7. Performance

- 既有 60K/75K 大库回归全部通过（`PERF_SMOKE_V081`：75K 全规则 494ms / ranking 57ms / top10 596ms）。
- 筛选不重建 20K 资产：过滤在候选集合（≤128 in smoke）上进行，资产侧查询走索引分页；`DiscoveryController` 派生数据惰性计算并缓存。
- Viewer 内存预算：preview 字节 LRU ≤ 3 项 + 离窗取消 + `cacheWidth` 解码上限；thumb LRU ≤ 30。
- 机器环境测试数据（合成 metadata，无真实媒体）。

## 8. Tests（Gate 7 自动化验证结果）

| 检查 | 结果 |
| --- | --- |
| `dart format`（packages + app） | 0 changed |
| `flutter analyze`（domain / media_library / engine / design_system / app） | 全部 No issues |
| memory_domain tests | 1/1 通过 |
| media_library tests | 11/11 通过 |
| memory_engine tests | 48/48 通过（含 Sprint 0.8.1 全部回归 + 15 项 discovery 查询测试） |
| memory_app tests | 54/54 通过（viewer 手势/加载、editor 非破坏性、discovery controller/timeline、既有 copy/perf/vertical slice） |
| iOS release build（--no-codesign） | **PASS**（Final Release Gate 轮完成，详见 §12） |

新增测试文件：`viewer_gesture_policy_test.dart`、`viewer_media_loader_test.dart`、`media_viewer_page_test.dart`（移植+扩充）、`media_editor_test.dart`、`discovery_home_test.dart`、engine `discovery_query_test.dart`。
既有测试断言零修改（media_library 仅补 4 个新接口方法的 mock 实现）。

## 9. Device（Gate 8/9 — 待人工执行）

以下 Gate 依赖真机（Jersey 17 Pro Max / iOS 26.6 / 20K+ 真实图库 / release build），机器环境无法替代，按任务要求停止并等待人工验证。Release build 已于本轮完成（§12.2），安装命令见 §12.2 末尾；设备当前不可达（需插线或同一局域网且解锁）。

**Gate 8 — Media UX**（整体评价，非逐手势问答）：
- [ ] A / B / C 分级（Sprint 1.0 要求 ≥B，目标 C）
- [ ] 无明显 gesture fighting / double tap jump / zoom pan broken / horizontal paging lock / dismiss jump / 2s blank spinner / wrong image / stale image / crash

**Gate 9 — Discovery UX**：
- [ ] 3 taps 内：找某一年 / 找某地点 / 找 Travel / 回到推荐 / 清除筛选
- [ ] 用户能明确理解当前 filter state（active chips 可见可删）
- [ ] Recovery：normal kill/reopen、scan kill/reopen → 无 DB 损坏、无重复爆炸、Feed 恢复

**Gate 10 — First WOW**（UI 完成后跑 Top10，禁止当场改 Ranking）：
- [ ] Top5 / Top10 meaningful、WOW、Wrong、Unwanted、Duplicate 记录

## 10. Remaining Debt（只列真实债务）

1. **crop/straighten 仅编辑器预览生效**：Viewer 只应用色彩矩阵与旋转；跨页持久裁剪布局需要按 asset 记录渲染管道（V1 明确边界）。
2. **Auto Enhance 未实现**（任务标记"可选"）。
3. **地点标签依赖系统逆地理编码**：离线/失败时回退中性"地点 N"；无离线城市库。
4. **搜索文本匹配为 deterministic 包含匹配**：`textOf` 注入位已留出，但语义搜索（embedding/OCR/NL）未引入（本轮禁止）。
5. **视频播放未真机验证**：`loadVideoPlaybackUrl` 对 iCloud 优化视频可能返回 AVComposition 而非 AVURLAsset，此时返回 null（显示海报，不崩溃）——需真机确认覆盖率。
6. **Android**：新增 channel 方法（setFavorite/share/video/placeLabel）未实现 Android 侧；Android 仍为 Mock 路径。
7. **Feed 默认仍取 diversity limit 20**：For You 无限滚动接全量 ranked list 未做（筛选态已接全量）。
8. **filmstrip 高度耦合 Memory 场景**：Timeline 打开 Viewer 时以月资产为范围，跨范围导航待产品定义。

## 11. Final Verdict

**PASS WITH MINOR PRODUCT DEBT** —（机器可验证范围）

依据：
- 基准/ADR/查询模型/维度索引全部交付且可测试；
- Viewer V3 手势契约以纯 Dart 状态决策 + widget 测试落地，覆盖任务 §47 全部 11 项（open index / chrome / paging / double tap / zoom reset / zoom blocks page / dismiss / dismiss cancel(spring back) / thumb fallback / preview upgrade / request failure）；
- Editor 非破坏性契约有存储层测试兜底（identity 不落盘、cancel 不改 store、round-trip）；
- 全部既有回归（含 Ranking/Dedup/Diversity/Sensitivity、60K/75K 大库、权限映射）零修改通过；
- 真机 Gate（Media UX ≥B / Discovery 3-taps / Recovery / First WOW）按要求留待人工，不自动判定。

按任务要求：完成后不自动进入 Ranking Calibration，停止并等待人工审核。

## 12. 构建记录

### 12.1 历史记录（上一轮）

- 上一轮 `flutter build ios --release --no-codesign` 未能执行，原因为本机 Xcode 未安装 iOS 26.5 平台组件。当时以 `xcrun swiftc -parse` 替代验证，并注明待平台组件安装后补跑。

### 12.2 Final Release Gate 轮（2026-09-14）

**环境已恢复**：Xcode 26.6（17F113）/ iOS SDK 26.5 已安装，`xcodebuild -showsdks`、`xcrun simctl list runtimes`（iOS 26.5）、`flutter doctor -v`（Flutter 3.44.4 / Dart 3.12.2 / CocoaPods 1.16.2）全部正常，无 ENVIRONMENT BLOCKER。

**Release Build 结果：PASS**

- 工具链下构建尝试两次均确定性停滞于 dSYM 生成阶段（`dsymutil` 对 `App.framework` 与 `native_assets/objective_c.framework` 零 CPU 挂起，Runner.app 本体已产出）。
- 独立重放 + 二分定位（详见下）确认与代码无关：同一二进制在 `/tmp` 及 `/Users/yvonne` 下 dsymutil 均正常完成（exit 0）。
- **根因**：`/Users/yvonne/Documents/CodeX` 目录 vnode 在内核层卡死——该目录 `stat`/路径 lookup 正常，但 `opendir`/readdir 永久阻塞；dsymutil 的 CFBundle bundle 探测会从产物目录逐级向上 opendir，撞上该节点即挂起。非挂载点、非 iCloud Desktop/Documents 同步（均关闭）、重启 mediaanalysisd 后依旧。已隔离在内核中，**需重启系统清除**。
- **绕过方案（已验证）**：以同一 HEAD `33ab366` 克隆仓库至健康路径 `/Users/yvonne/.lifemovie_build/lifemovie`，`flutter pub get` + `pod install` + `flutter build ios --release --no-codesign` **完整通过**：

```
Xcode build done.                                           29.6s
✓ Built build/ios/iphoneos/Runner.app (19.8MB)
BUILD_EXIT=0
```

- 构建日志无 warning / error（仅 --no-codesign 标准提示）。Swift 编译、插件注册、4 个新 native channel（setFavorite / presentShareSheet / loadVideoPlaybackUrl / loadPlaceLabel）、AVFoundation / PhotoKit / UIKit、CocoaPods、linker、generated registrant 全部经 Release 完整类型检查与链接。
- 产物：`/Users/yvonne/.lifemovie_build/lifemovie/apps/memory_app/build/ios/iphoneos/Runner.app`，19.8MB，bundle `com.lifemovie.memoryApp`，version 1.0.0 (1)，构建时间 2026-09-14 12:36。
- 仓库内**无任何代码修改**（本轮修复为零代码 diff；报告文档更新除外）。

**待人工（GATE 9 真机安装）**：

```bash
xcrun devicectl device install app \
  --device D5D7955B-6AB4-5F3C-ADB9-C08F6E3D7C73 \
  /Users/yvonne/.lifemovie_build/lifemovie/apps/memory_app/build/ios/iphoneos/Runner.app
xcrun devicectl device process launch \
  --device D5D7955B-6AB4-5F3C-ADB9-C08F6E3D7C73 \
  com.lifemovie.memoryApp
```

设备当前 `unavailable`（未插线 / 无线不可达）。建议先重启本机清除 CodeX vnode 卡死，之后可直接在原工作区重新构建，产物路径回到常规 `build/ios/iphoneos/`。
