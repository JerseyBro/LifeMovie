# Product Discovery V1.1

LifeMovie is currently validating Memory Discovery, not video editing.

Core product question:

> Can the system surface a memory the user did not think to search for, but recognizes as meaningful, accurate, surprising and safe?

## Positioning

Memory Discovery → Person Story → Memory Movie → Family Memory → 一生一影

Sprint 0.8 focuses only on the first step.

## First WOW candidate

The strongest low-risk first card is `SamePlaceAcrossYearsRule`:

> 你已经连续 6 年来到这里。  
> 2021 — 2026 · 6 次到访

It is understandable, does not require face recognition and can be validated with real photo metadata.

## Internal validation targets

- Meaningful Rate: Top 5 has at least 3 meaningful candidates, target >= 60%.
- WOW Rate: at least one “这个我自己没想到” moment, target >= 40% users.
- Negative Rate: wrong/sensitive/creepy, target < 20%.
- Second Memory Rate: user opens a second memory after the first, target >= 40%.

These are early internal thresholds, not industry benchmarks.

## Current status

Code supports candidate generation and local feedback capture. Real user validation is pending.
