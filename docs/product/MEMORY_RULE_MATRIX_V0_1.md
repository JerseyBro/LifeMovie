# Memory Rule Matrix V0.1

| Rule | Product value | Main signals | Safety stance | Status |
|---|---|---|---|---|
| SamePlaceAcrossYears | Repeated return to same place | year count, visit count, routine penalty | Do not label home/work/school | Implemented |
| FirstMemory | Earliest library record | earliest window for person/place | Say “相册里最早”, never “第一次见面” | Implemented |
| TravelStory | Continuous journey | time continuity, movement, density, video ratio | Do not infer honeymoon/family/couple | Implemented |
| PersonTimeline | Person story seed | injected person id, year span | Say “这个人”, no relationship inference | Implemented |
| AnnualTogether | Recurring annual window | person id + day-of-year window | No festival or relationship inference | Implemented |
| LongTermEvolution | Time-span story | person/place year span | No body/age/appearance judgment | Implemented |
| DateCluster | Baseline dense period | short date gaps, density | Low product specificity | Retained |
| SamePlace | Visit session | spatial cluster + time gap | Avoid huge routine cluster | Retained |
| YearRecap | Architecture validation | year grouping | Generic | Retained |
