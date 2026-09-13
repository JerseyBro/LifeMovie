# ADR: Media Viewer Architecture (Viewer V3)

Status: Accepted (2026-09-14)
Deciders: Sprint 1.0 Productization
Related: docs/product/PHOTO_EXPERIENCE_BENCHMARK.md, docs/adr/ADR-002-media-abstraction.md

---

## Context（Architecture Audit @ 11bc600）

### 现状

`photo_viewer_page.dart`（342 行）采用 `PageView` + `InteractiveViewer` + 外层 `GestureDetector`（vertical dismiss）+ 内层 `GestureDetector`（tap / double-tap）+ `TransformationController`。

### 审计发现（Gesture Arena 与状态管理）

1. **手势仲裁靠"偶然的竞技场结果"，不是设计**。竞技场里有四类识别器同时竞争：
   - 外层 `VerticalDragGestureRecognizer`（dismiss）
   - `PageView` 内部 `HorizontalDragGestureRecognizer`（paging）
   - `InteractiveViewer` 内部 `ScaleGestureRecognizer`（pinch + pan，**1x 时也接受单指 pan**）
   - 内层 tap / double-tap

   `ScaleGestureRecognizer` 在 1x 时依然会接受单指拖动（它无法区分"放大后的 pan"和"1x 的误触 pan"）。竖直方向上它与外层 dismiss 识别器的胜负取决于竞技场注册顺序与接受时序，属于未定义行为边界，而不是有保证的所有权分配。Sprint 0.9 用 `_pageLocked`（zoom 状态 + interacting 布尔）规避，但这属于打补丁。

2. **手势进行中切换 physics**。`physics: _pageLocked ? NeverScrollable : PageScroll` 在拖动中途改变 `PageView` physics，会触发 scroll activity 替换，存在跳变风险（这正是"不突然锁死"要求的反例）。

3. **单击 chrome 响应有 ~300ms 延迟**。`onTap` 与 `onDoubleTap` 同GestureDetector 共存时，tap 必须等 double-tap 超时才能确认。iOS Photos 的 chrome 切换是即时的。

4. **zoom 状态同步用 setState 高频触发**。`_syncScale` 每帧比较 scale 差值 > 0.01 就 setState 重建整页子树，pinch 过程中整页 rebuild。

5. **dismiss 不是真正 interactive**。`Transform.translate` 有 clamp(0,420)，但无背景压暗、无照片缩小、无 rubber-band；达到阈值直接 `Navigator.pop()`（Sprint 0.9 加了 snap-back 动画，但完成 dismiss 仍是瞬断）。

6. **媒体加载无生命周期**。`_imageFutures` / `_thumbFutures` 两个 Map 只增不减：
   - 翻过的每一页的 2200px 预览字节永久驻留（20K+ 库、长 Memory 下内存不可控）；
   - 离开视口的请求从不 `cancelThumbnailRequest`；
   - 无 prefetch（`allowImplicitScrolling` 默认 false），快速滑动时每一页都是"进入后才请求"。

7. **打开转场断裂**。`CupertinoPageRoute` 推入全新黑色页面，进入后 thumbnail 才开始请求 → 黑闪 + 空窗，违反 benchmark 中的连续性要求。

8. **缺产品面**：无 filmstrip、无 Info、无编辑入口、无 favorite、无 share；chrome 只有 Close + 计数。视频资产被当图片渲染（无 poster/时长标识）。

9. **repository 缺口**：无 favorite 写入、无视频播放地址、无地点标签（Info 面板需要）；`MediaRepository` 抽象本身可扩展，符合 ADR-002 边界。

### 结论

现有架构的问题不是"Flutter 做不到"，而是**仲裁权从未被显式设计**。继续在现有文件上 patch（第 0.9 的做法）无法收敛，因为四层识别器的组合空间没有状态机约束。需要重写 viewer 交互层，并建立请求生命周期与内存预算。

---

## Options

### Option A — 纯 Flutter 自定义 Viewer（显式手势状态机）

单页内自研手势仲裁 + `PageView` 保留 iOS 级 paging 物理 + 方向门控识别器。

- gesture fidelity: **高**（仲裁显式化后可对齐 iOS 语义）
- 120Hz feel: 高（仅 Transform/Opacity 层动画）
- interactive dismiss: 高（自研）
- zoom physics: 高（自研 clamp + spring）
- paging: 高（复用 PageView ballistic/snap）
- PhotoKit integration: 走既有 `MediaRepository`（ADR-002）
- memory: 可控（自研 LRU + cancel）
- maintenance: 中（viewer 模块 ~1000 行，有状态机单测）
- Android portability: **好**
- Flutter integration: 原生
- testing: **好**（状态机纯 Dart 单测 + widget 测试）

### Option B — 成熟 Flutter photo viewer 库 + 自定义外壳

- gesture fidelity: 中高（库内 zoom 成熟，但库的识别器优先级同样不受我们控制；interactive dismiss 与库内手势的融合是社区已知难点）
- paging/dismiss/filmstrip/渐进加载/内存预算：仍需全部自研外壳
- memory: 不可控（库内缓存策略）
- maintenance: 中（外部依赖风险）+ 与 Option A 相同的自研外壳量
- testing: 中（库黑盒）
- 结论：**它只解决最不难的那部分（zoom 数学），不解决真正难的（仲裁与生命周期）**，还要引入依赖风险。

### Option C — iOS 原生 PhotoKit / UIKit Viewer Bridge（PlatformView）

- gesture fidelity: 最高（PHPhotos-style 系统手感）
- 120Hz: 最高
- interactive dismiss: 高
- paging/zoom: 高
- PhotoKit integration: 最深
- memory: 可控
- maintenance: **差**（Swift + Dart 双实现，Info/Editor 也要各写一份）
- Android portability: **死**（违背跨平台可维护性原则）
- Flutter integration: PlatformView 手势转发对全屏手势型页面有已知性能与手势冲突坑
- testing: 差（widget 测试覆盖不到）
- 成本：本轮最高，且把 Memory Detail 的业务数据（filmstrip 范围、Info 的 membership）桥接进 UIKit 层。

---

## Decision

**选择 Option A：纯 Flutter 自定义 Viewer V3，以显式手势状态机为核心。**

理由：

1. 审计证明失败原因在仲裁设计而非 Flutter 手势能力上限；Option B 不触及病根，Option C 成本/可移植性不可接受。
2. 状态机（纯 Dart）+ 方向门控识别器可以把"谁拥有手势"变成显式契约，并且可单测——符合仓库"薄展示层、厚可测业务"原则。
3. iOS 原生桥（Option C）保留为**回退方案**：若真机验收 Media UX Gate 低于 B 且定位为手势 fidelity 不可达，再按本 ADR 的 Fallback 路径执行。

### 手势状态机（规范）

```text
States: idle / paging / dismissing / zooming / zoomedPan / animating

idle
 ├── 水平单指 drag        → paging（PageView 拥有，速度敏感 snap）
 ├── 竖直单指 drag        → dismissing（照片跟手 + 背景压暗 + 缩小）
 ├── 双指 pinch           → zooming（绕焦心缩放，1x 连续放大）
 └── double tap           → animating（180–260ms 绕点击点 zoom in/out）

zooming / zoomed（scale > 1）
 ├── 单指 pan             → zoomedPan（图像 pan，clamp 边界）
 ├── pinch                → zooming（继续缩放）
 ├── double tap           → animating（回 1x）
 └── scale 回到 1x 且手势结束 → idle（paging/dismiss 恢复）

dismissing
 ├── 松手且 (distance ≥ 阈值 OR velocity ≥ 阈值) → 完成 dismiss（动画离场 + pop）
 └── 否则                          → animating（spring 回位）

不变量（invariants）:
- zoom > 1 的整个触摸序列内 paging 与 dismissing 禁止获得所有权（锁定在 onScaleStart 时刻判定，不在手势中途切换 physics）。
- 任一时刻恰好一个状态拥有手势；禁止多个 boolean 任意组合。
- 单击 chrome 显隐即时生效（tap 与 double-tap 分离仲裁：tap 立即翻 chrome，double-tap 在 tap 处理前判定；如 double-tap 发生，chrome 翻转被合并）。
```

### 媒体加载规范（Progressive Pipeline & Prefetch）

```text
质量层（沿用并正式化）:
  grid    360px    Feed/Detail 网格
  feed    720px    Feed 卡片
  detail  1200px   Detail hero
  viewer  2200px   全屏 Viewer（仅当前页与近邻）
  original 仅显式操作时

Viewer 生命周期:
  进入页 N：thumb(360) 立即 → preview(2200) 后台替换（无 spinner 遮挡）
  prefetch：N-1、N+1 preview；快速滑动时取消离开 ±1 窗口的未完成请求
  内存预算：preview 字节 LRU ≤ 3 项（N-1/N/N+1），thumb LRU ≤ 30 项
  解码预算：Image.memory(cacheWidth:) 按 device pixel 上限解码，禁止全尺寸位图常驻
  失败：保留 thumb，展示可重试错误位（不白屏）
```

---

## Trade-offs

- 自研 zoom/dismiss 数学与动画要自己维护（~600 行交互代码）；换来完全的所有权契约与可测试性。
- 单击 chrome 的即时性通过 tap/double-tap 分离仲裁实现，代码略复杂于单 GestureDetector，但消除 300ms 延迟。
- 不引入 viewer 三方依赖；代价是失去社区库的成熟度，但换来内存预算与仲裁控制权。
- Option C 的"最原生手感"暂不可得；以真机 Gate（≥B）验收，不达标再触发 Fallback。

## Migration

1. 新增 `lib/media_viewer/` 模块：gesture machine（纯 Dart）、viewer page、loader（LRU + cancel + prefetch）、filmstrip、chrome、open transition。
2. `memory_detail_page` 切换到 V3 并改用 zoom 打开转场（传入来源 rect + thumb bytes）。
3. 旧 `photo_viewer_page.dart` 删除（一次性替换，不做 bridge——遵循 Copy > Bridge 后退役旧实现）。
4. `MediaRepository` 增量扩展（favorite / share / video url / place label）保持接口向后兼容（新增方法带默认实现或在 Mock/PhotoKit 同步实现）。

## Fallback

若真机 Media UX Gate 结果 < B，且问题定位为 Flutter 手势 fidelity 天花板：
1. 保留 Dart 侧数据/加载/Info/编辑层（本 ADR 的 loader 与 repository 扩展不受影响）。
2. 以 Option C 替换交互层：iOS 原生 viewer（UIKit）以 PlatformView/UIViewController 呈现，Dart 通过 channel 提供 memory 范围 assets 与元数据。
3. 该决策需新一轮 ADR 修订并重跑真机 Gate。
