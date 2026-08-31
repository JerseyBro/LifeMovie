# Memory Quality Model

Sprint 0.8 separates algorithmic score from human product evaluation.

## Human evaluation fields

Each `MemoryEvaluation` records:

- Accuracy: 1-5
- Meaningfulness: 1-5
- Surprise: 1-5
- Clarity: 1-5
- Sensitivity: 1-5, where 5 means safe
- Labels
- Anonymous candidate id
- Rule type
- Created time

## Privacy rules

Evaluation data must not contain real photos, videos, precise GPS, file paths, names, relationship labels, image bytes or private free text. Current feedback is local first and saved as anonymous structured labels.
