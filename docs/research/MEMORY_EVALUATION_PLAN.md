# Memory Evaluation Plan

## Goal

Validate whether LifeMovie can produce memories that are meaningful, surprising, accurate and safe.

## Method

Future real user validation should involve 5-10 users. For each user:

1. Run local indexing on their device.
2. Show Top 10 candidates.
3. Collect structured feedback:
   - 有意义
   - 有惊喜
   - 一般
   - 不准确
   - 不希望看到这种内容
4. Record optional structured reasons only:
   - 人物不对
   - 地点不对
   - 时间不对
   - 这些照片不是同一个故事
   - 重复
   - 太普通
   - 太私人
   - 表达不舒服

## Metrics

- Top 1 acceptance
- Top 3 acceptance
- Top 5 Meaningful Rate
- WOW Rate
- Wrong Rate
- Sensitive/Creepy Rate
- Second Memory Rate

## Privacy

Do not export photos, videos, exact GPS, file paths, names, relationship labels or private text. Store only anonymous candidate ids, rule type, coarse statistics, scores and labels.
