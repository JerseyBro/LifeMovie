# Photo Experience Benchmark — Sprint 1.0

Status: Accepted (2026-09-14)
Scope: 只回答"哪些模式值得吸收、为什么、LifeMovie 借什么、不抄什么"。不是竞品百科。
Benchmark targets: Apple Photos (iOS 26) / Google Photos / Immich。

---

## 1. Apple Photos（iOS 26）

### What works

1. **全屏浏览的手势连续性**：swipe / scroll / pinch zoom / double-tap zoom 全部由系统级手势识别驱动，单张照片内部手势（zoom/pan）与页间手势（paging）从不"抢"。放大后手势 100% 归照片，回到 1x 立即恢复 paging，没有状态跳变。
2. **单击 chrome 显隐**：单击只切换控件可见性，不打断浏览；再单击立即恢复。控件淡入淡出而不是瞬移。
3. **底部缩略图 filmstrip**：横向 scrub 快速跳转，当前照片明确高亮。它传达"这是连续媒体流中的一帧"，而不是孤立的一张图。
4. **打开转场连续**：thumbnail → 全屏是同一个图像的缩放扩展（zoom transition），没有黑闪、没有"缩略图 → spinner → 图"三段式断裂。
5. **渐进加载**：全屏先出现低分辨率快速版本，高分辨率在后台替换，肉眼看到的是"变清晰"而不是"重新加载"。
6. **iOS 26 信息架构**：Library / Collections / Search 三 tab 回归；Collections 支持折叠、重排；Years / Months / Media Types / People & Pets / Trips / Memories / Utilities / Pinned Collections 多维度组织。

### Why it works

- 手势仲裁在系统层是一个**状态机**而不是多个并分布尔。任一时刻手势所有权唯一：Idle → Paging / Zooming / ZoomedPan / Dismissing。
- 加载策略是"**先给可看的，再给清晰的**"——感知延迟（perceived latency）优先于绝对延迟。
- 信息架构分离了"**管理媒体**（Library）"与"**探索媒体**（Collections）"两种心智任务。

### LifeMovie should borrow

- 手势状态机模型（见 ADR_MEDIA_VIEWER_ARCHITECTURE.md）。
- 单击 chrome 显隐 + 淡入淡出。
- filmstrip（Memory 范围内）传达"故事中的一组照片"。
- 渐进加载：thumbnail 立即 → high preview 无缝替换，禁止 blank → spinner → image。
- Chrome 内容克制：Share / Favorite / Info / Edit，没有的按钮不放假的。

### LifeMovie should NOT copy

- **Library tab 本身**：管理全部照片是 Photos 的职责。LifeMovie 首页是 Memory Discovery，不做全量媒体管理器。
- Utilities（重复项清理、证件扫描等）与 Memories 自动成片的完整体系。
- 编辑器的完整度（Lightroom 级工具链）。LifeMovie V1 只做基础编辑。

---

## 2. Google Photos

### What works

1. **语义搜索入口**：People / Places / Things / Documents 等语义维度让"找"变成"问"。
2. **Search 结果的即时性**：输入即过滤，无刷新等待。
3. **按地点/时间聚合的 Memory 卡片流**：和 LifeMovie 的 Discovery 定位最接近的竞品模式。

### Why it works

- 语义维度背后是**索引先行**：搜索是查询，不是扫描。
- Memory 卡片强调"故事"而不是"文件"。

### LifeMovie should borrow

- 搜索框作为显性入口但不过度突出（"Search photos, places, years..."）。
- "查询是过滤、不是扫描"的性能模型：所有筛选走索引/内存查询，禁止每次筛选重建 20K 资产。

### LifeMovie should NOT copy

- 语义内容搜索（Things / Documents）需要 OCR/物体识别，本轮禁止引入。
- 云端备份心智。LifeMovie 是 Local First。
- 人物搜索依赖的人脸身份识别（当前项目禁令）。

---

## 3. Immich

### What works

1. **组合高级筛选**：People / Location / Album / Time / Media Type / Favorites / Camera 的组合过滤，并向 AND/OR 组合搜索演进。
2. **筛选状态透明**：用户始终知道当前为什么只看到这些结果。
3. **自托管心智**：本地优先、数据自有，与 LifeMovie 价值观一致。

### Why it works

- 筛选是**显式查询模型**（query object），UI 只是查询的渲染，所以组合语义可以明确（AND 跨维度 / OR 同维度）。

### LifeMovie should borrow

- `MemoryDiscoveryQuery` 显式查询模型：immutable、可组合、可测试。
- 跨维度 AND / 同维度 OR 的明确语义。
- Active filter chips + Clear All 的状态透明模式。

### LifeMovie should NOT copy

- Camera / 设备型号、Album 体系等 LifeMovie 数据尚不可靠的维度（V1 只做真实数据支持的筛选项）。
- Server/Web 架构心智。

---

## 4. 结论：LifeMovie 的定位

```text
Apple Photos 管"我的照片"（Library 思维）
LifeMovie 管"我的记忆"（Discovery 思维）

体验基准：Apple Photos 的媒体浏览手感
查询模型：Immich 的显式组合筛选
入口形态：Google Photos 的"搜索即提问"（但 V1 只做 metadata 搜索）
```

LifeMovie 保持 Discover First：AI 已经替用户发现了故事，首页是"人生记忆入口"，不是"更多筛选按钮"。

---

## Sources

- [iOS 26 Photos App: Everything That's Changed — MacRumors](https://www.macrumors.com/guide/ios-26-photos-app/)
- [iOS 26 Redesigns Photos App — Ubergizmo](https://www.ubergizmo.com/2025/06/ios-26-redesigns-photos-app/)
- [Apple Photos on iOS 26: Part 2 — 5 Minute Photos](https://5minutephotos.substack.com/p/apple-photos-on-ios-26-part-2-the)
- Immich feature set: https://immich.app（官方文档，组合筛选/People/Location/Media Type）
