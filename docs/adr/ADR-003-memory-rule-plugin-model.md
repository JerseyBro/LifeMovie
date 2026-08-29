# ADR-003 Memory rule plugin model

Status: accepted

Discovery hypotheses are independent `MemoryRule` implementations registered in `MemoryEngine`. This keeps future product directions replaceable and prevents a conditional God Service.
