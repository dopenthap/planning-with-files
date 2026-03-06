# Benchmark Results — planning-with-files v2.22.0

Formal evaluation of `planning-with-files` using Anthropic's [skill-creator](https://github.com/anthropics/skills/tree/main/skills/skill-creator) framework. This document records the full methodology, test cases, grading criteria, and results.

---

## Why We Did This

In March 2026, the skill was flagged by two security scanners:

- **Gen Agent Trust Hub: FAIL**
- **Snyk W011: WARN (0.90 risk score)**

The root cause was a **toxic flow**: `WebFetch` and `WebSearch` were declared in `allowed-tools`, and the PreToolUse hook re-reads `task_plan.md` before every tool call. That combination — untrusted web content → written to files → auto-injected into context on every tool use — is a textbook indirect prompt injection amplification pattern.

We fixed it in v2.21.0 (removed `WebFetch`/`WebSearch` from `allowed-tools`, added Security Boundary section).

Then we had to prove the skill still works. So we ran formal evals.

---

## Test Environment

| Item | Value |
|------|-------|
| Skill version tested | 2.21.0 |
| Eval framework | Anthropic skill-creator (github.com/anthropics/skills) |
| Executor model | claude-sonnet-4-6 |
| Eval date | 2026-03-06 |
| Eval repo | Local copy (planning-with-files-eval-test/) |
| Subagents | 10 parallel (5 with_skill + 5 without_skill) |
| Comparator agents | 3 blind A/B comparisons |

---

## Test 1: Evals + Benchmark

### Skill Category

`planning-with-files` is an **encoded preference skill** (not capability uplift). Claude can plan without the skill — the skill encodes a specific 3-file workflow pattern. Assertions test workflow fidelity, not general planning ability.

### Test Cases (5 Evals)

| ID | Name | Task |
|----|------|------|
| 1 | todo-cli | Build a Python CLI todo tool with persistence |
| 2 | research-frameworks | Research Python testing frameworks, compare 3, recommend one |
| 3 | debug-fastapi | Systematically debug a TypeError in FastAPI |
| 4 | django-migration | Plan a 50k LOC Django 3.2 → 4.2 migration |
| 5 | cicd-pipeline | Create a CI/CD plan for a TypeScript monorepo |

Each eval ran two subagents simultaneously:
- **with_skill**: Read `SKILL.md`, follow it, create planning files in output dir
- **without_skill**: Execute same task naturally, no skill or template

### Assertions per Eval

All assertions are **objectively verifiable** (file existence, section headers, field counts):

| Assertion | Evals |
|-----------|-------|
| `task_plan.md` created in project directory | All 5 |
| `findings.md` created in project directory | Evals 1,2,4,5 |
| `progress.md` created in project directory | All 5 |
| `## Goal` section in task_plan.md | Evals 1,5 |
| `### Phase` sections (1+) in task_plan.md | All 5 |
| `**Status:**` fields on phases | All 5 |
| `## Errors Encountered` section | Evals 1,3 |
| `## Current Phase` section | Eval 2 |
| Research content in `findings.md` (not task_plan.md) | Eval 2 |
| 4+ phases | Eval 4 |
| `## Decisions Made` section | Eval 4 |

**Total assertions: 30**

### Results

| Eval | with_skill | without_skill | with_skill files | without_skill files |
|------|-----------|---------------|-----------------|---------------------|
| 1 todo-cli | 7/7 (100%) | 0/7 (0%) | task_plan.md, findings.md, progress.md | plan.md, todo.py, test_todo.py |
| 2 research | 6/6 (100%) | 0/6 (0%) | task_plan.md, findings.md, progress.md | framework_comparison.md, recommendation.md, research_plan.md |
| 3 debug | 5/5 (100%) | 0/5 (0%) | task_plan.md, findings.md, progress.md | debug_analysis.txt, routes_users_fixed.py |
| 4 django | 5/6 (83.3%) | 0/6 (0%) | task_plan.md, findings.md, progress.md | django_migration_plan.md |
| 5 cicd | 6/6 (100%) | 2/6 (33.3%) | task_plan.md, findings.md, progress.md | task_plan.md (wrong structure) |

**Aggregate:**

| Configuration | Pass Rate | Total Passed |
|---------------|-----------|-------------|
| with_skill | **96.7%** | 29/30 |
| without_skill | 6.7% | 2/30 |
| **Delta** | **+90.0 pp** | +27 assertions |

#### The One Failure (Eval 4, Assertion 6)

Assertion: `**Status:** pending on at least one future phase`
Result: FAIL

The agent completed all 6 migration phases in a single planning session, leaving none pending. The skill was followed correctly — this is a flawed assertion, not a skill failure. The skill does not require phases to remain pending. Revised assertion for future evals: `task_plan.md contains **Status:** fields` (without specifying value).

---

## Test 2: A/B Blind Comparison

Three independent comparator agents evaluated pairs of outputs **without knowing which was with_skill vs without_skill**. Assignment was randomized:

| Eval | A | B | Winner | A score | B score |
|------|---|---|--------|---------|---------|
| 1 todo-cli | without_skill | with_skill | **B (with_skill)** | 6.0/10 | 10.0/10 |
| 3 debug-fastapi | with_skill | without_skill | **A (with_skill)** | 10.0/10 | 6.3/10 |
| 4 django-migration | without_skill | with_skill | **B (with_skill)** | 8.0/10 | 10.0/10 |

**with_skill wins: 3/3 = 100%**

### Comparator Quotes

**Eval 1 (todo-cli):** *"Output B satisfies all four structured-workflow expectations precisely... Output A delivered real, runnable code (todo.py + a complete test suite), which is impressive, but it did not fulfill the structural expectations... Output A's strength is real but out of scope for what was being evaluated."*

**Eval 3 (debug-fastapi):** *"Output A substantially outperforms Output B on every evaluated expectation. Output B is a competent ad-hoc debug response, but it does not satisfy the structured, multi-phase planning format the eval specifies. Output A passes all five expectations; Output B passes one and fails four."*

**Eval 4 (django-migration):** *"Output B is also substantively strong: it covers pytz/zoneinfo migration (a 4.2-specific item Output A omits entirely), includes 'django-upgrade' as an automated tooling recommendation... The 18,727 output characters vs 12,847 for Output A also reflects greater informational density in B."*

---

## Test 3: Description Optimizer

**Status: EXCLUDED**

Requires `ANTHROPIC_API_KEY` in the eval environment. Not set. Per the project's eval standards, a test is only included in results if it can be run end-to-end and produce verified metrics.

---

## Summary

| Test | Status | Result |
|------|--------|--------|
| Evals + Benchmark | ✅ Complete | 96.7% (with_skill) vs 6.7% (without_skill) |
| A/B Blind Comparison | ✅ Complete | 3/3 wins (100%) for with_skill |
| Description Optimizer | ❌ Excluded | No API key in eval environment |

The skill demonstrably enforces the 3-file planning pattern across diverse task types. Without the skill, agents default to ad-hoc file naming and skip the structured planning workflow entirely.

---

## Reproducing These Results

```bash
# Clone the eval framework
gh api repos/anthropics/skills/contents/skills/skill-creator ...

# Set up workspace
mkdir -p eval-workspace/iteration-1/{eval-1,eval-2,...}/{with_skill,without_skill}/outputs

# Run with_skill subagent
# Prompt: "Read SKILL.md at path X. Follow it. Execute: <task>. Save to: <output_dir>"

# Run without_skill subagent
# Prompt: "Execute: <task>. Save to: <output_dir>. No skill or template."

# Grade assertions, produce benchmark.json
# See eval-workspace/iteration-1/benchmark.json for full data
```

Raw benchmark data: [`eval-workspace/iteration-1/benchmark.json`](../planning-with-files-eval-test/eval-workspace/iteration-1/benchmark.json) (in eval-test copy, not tracked in main repo)
