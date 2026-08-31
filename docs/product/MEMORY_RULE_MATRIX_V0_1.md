# Memory Rule Matrix V0.1 (Sprint 0.8 + 0.8.1)

| Rule | Product value | Main signals | Safety stance | Status |
|---|---|---|---|---|
| SamePlaceAcrossYears | Repeated return to same place | `distinctYearCount`, `calendarSpanYears`, `longestConsecutiveYearRun`, visit count, routine penalty, distance cluster (500m) | Do not label home/work/school; only `longest>=3` may say `连续 X 年` else `X 个不同年份`/`多次` | Implemented (0.8.1 year+cluster fix) |
| FirstMemory | Earliest library record | earliest `firstWindow` for person/place cluster | Say “相册里最早”, never “第一次见面” | Implemented (0.8.1 cluster fix) |
| TravelStory | Continuous journey | Phase A: located time continuity + movement + place count + distance; Phase B: enrich with **all** assets in window (`locatedMediaCount`/`totalMediaCount`/`locationCoverage`), density, video ratio | Do not infer honeymoon/family/couple; uses `locationCoverage` confidence | Implemented (0.8.1 two-phase) |
| PersonTimeline | Person story seed | injected person id, `distinctYearCount`/`calendarSpanYears`/`longestConsecutiveYearRun` | Say “这个人”, no relationship inference; copy `从 firstYear 开始` / `跨越 span 年` | Implemented (0.8.1 year fix) |
| AnnualTogether | Recurring annual window | person id + circular `dayOfYear` distance `<=24d` with Dec31/Jan1 wrap, `longestConsecutiveYearRun` | No festival or relationship inference; only `longest>=3` may say `每年`/`连续` | Implemented (0.8.1 window fix) |
| LongTermEvolution | Time-span story | person/place `distinctYearCount`/`calendarSpanYears`/`longestConsecutiveYearRun` via distance cluster | No body/age/appearance judgment; `span>=4` → `跨越 X 年` else `X 个年份` | Implemented (0.8.1 year+cluster fix) |
| DateCluster | Baseline dense period | short date gaps, density | Low product specificity | Retained |
| SamePlace | Visit session | distance cluster + time gap `maxSessionGap 14d` | Avoid huge routine cluster | Retained (0.8.1 cluster fix) |
| YearRecap | Architecture validation | year grouping | Generic | Retained |

Notes: All location grouping after 0.8.1 uses `LocationClusterConfig(radiusMeters:500)` distance clustering, not `toStringAsFixed(1)`. Ranking `recurrence` prefers `distinctYearCount`. Evaluation uses opaque `eval-` id, not raw place ids.
