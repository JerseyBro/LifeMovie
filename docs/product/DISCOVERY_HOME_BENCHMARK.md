# Discovery Home Benchmark — Sprint 1.0

Status: Accepted (2026-09-14)
Scope: 首页信息架构与筛选/搜索模式的基准分析。只回答"借什么、不抄什么"。

---

## 1. 问题定位

Sprint 0.9 的首页是 **Memory Candidate Feed**：一个 AppBar 标题 + 10 张纵向卡片列表。它回答了"引擎能不能发现故事"，但没有回答"用户如何探索自己的人生图库"。

用户心智里缺三样东西：

1. **入口感**：打开 App 应该感觉"这是在帮我探索我的人生相册"，而不是"这里有一个列表"。
2. **主动性**：AI 发现是被动接收；用户还需要主动探索（时间、地点、旅途）。
3. **可达性**：找到"某一年 / 某个地方 / 某段旅行"应该在 3 次点击内完成。

---

## 2. Apple Photos（iOS 26）信息架构

### What works

1. **Library / Collections / Search 三 tab 分离**（iOS 26 回归）：把"管理"与"探索"分成两个心智空间，Search 独立成 tab。
2. **Collections 的多维组织**：Years / Months、Media Types、People & Pets、Trips、Memories、Utilities、Pinned Collections，且可折叠、重排。
3. **Years 视图**：极度缩小的年度热力拼图，证明"时间维度本身可以是一个探索界面"。

### Why it works

- 每个维度都是**真实数据的投影**：没有数据的维度（如无人物数据）不会出现空壳。
- 折叠/重排给了用户对信息架构的控制权。

### LifeMovie should borrow

- **维度有数据才出现**：DiscoveryDimension 每个 section 按真实候选/资产分布渲染，不伪造空壳。
- **时间作为一级探索维度**：Timeline tab（2026 → 月 → Memory 簇）。
- Search 作为一级入口。

### LifeMovie should NOT copy

- Library 全量管理 tab。
- Pinned Collections / 手动相册管理。
- Memories 的自动成片体系（LifeMovie 未来方向但不是本轮）。

---

## 3. Google Photos 语义入口

### What works

1. **People / Places / Things / Documents 语义入口**：搜索页本身就是维度导航。
2. **搜索框位置**：顶部显眼但不占据首屏焦点。

### Why it works

- 语义入口背后是可靠的索引（人脸/地点/物体），索引决定 UI，不是 UI 先行。

### LifeMovie should borrow

- 搜索页顶部大搜索框 + Quick Filters 的两级结构。
- "按地点/年份找照片"作为最高频搜索场景优先做好。

### LifeMovie should NOT copy

- Things / Documents / OCR 语义搜索（无索引基础，禁止伪造）。
- People 语义入口（当前无人脸身份能力；只有注入 personIds，不展示 People section，除非有可靠 person grouping 数据）。

---

## 4. Immich 组合筛选

### What works

1. **多维度组合过滤**（People / Location / Time / Media Type / Favorites）且继续演进 AND/OR 组合。
2. **筛选结果即时可见 + 状态透明**。

### Why it works

- 筛选是**查询对象**不是 UI 状态拼接；查询可组合、可序列化、可测试。

### LifeMovie should borrow

- `MemoryDiscoveryQuery`（dateRange / years / placeIds / memoryTypes / mediaTypes / favorites / sort），跨维度 AND、同维度 OR。
- Active filter chips + Clear All。
- Advanced Filter Sheet 分组：Time / Place / Memory / Media，只实现数据真实支持的组。

### LifeMovie should NOT copy

- Camera 型号、Album 体系筛选（数据不可靠）。
- Desktop 式多列筛选面板（移动端用 bottom sheet）。

---

## 5. LifeMovie Discovery Home V3 信息架构（决策）

```text
LifeMovie
├── For You / 发现        ← AI Memory 核心（Hero + Memory Cards + Recently Discovered）
├── Timeline / 时光       ← 主动时间探索（年 → 月 → 簇）
├── Search / 搜索         ← 统一 Discovery Search + Quick Filters + Advanced Filter Sheet
（People / Places / Trips / Years / First Memories / Together / Evolution
  作为 For You 内的 Explore 维度 section，按真实数据出现；不设空壳 tab）
```

- 底部导航：**发现 / 时光 / 搜索** 三个 tab。发现是核心，永远第一。
- Hero Memory：首屏只突出一个最值得看的 Memory（cinematic photo + title + story hint），禁止 score / rule / AI badge / 技术标签。
- Explore 维度（People / Places / Trips / Years / First Memories / Together / Evolution / Recently Discovered）作为 For You 内的横滑 section，**有真实数据才渲染**。
- People 维度：只有当 personIds 分组可靠（有注入标注）时才出现；真实产品中无可靠数据则整个 section 不出现。
- Places：来自资产 GPS 聚类的 Place cards（城市级）；不做地图。
- Trips：来自 TravelStoryRule 候选。
- 最终感觉："这是我的人生记忆入口，而且 AI 已经替我发现了一些我自己都没注意到的东西。"
