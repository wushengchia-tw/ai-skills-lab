# TASK-001: Implement Decision-Grill v0.1

## Task Metadata

- Task ID: TASK-001
- Product: decision-grill
- Version: v0.1
- Repository: wushengchia-tw/ai-skills-lab
- Branch: feature/grill-me-pro
- Baseline commit SHA: 5c6e5065a26bdc78335d5d77231fc475bacbc430
- Status: APPROVED_FOR_IMPLEMENTATION
- Task type: Controlled implementation
- Implementation authorization: Granted
- Installation authorization: Not granted

## Objective

Implement the approved `decision-grill` v0.1 Skill exactly according to:

- `review/REVIEW-001-grill-me-architecture.md`
- `decisions/DECISION-001-decision-grill-product-direction.md`
- `specs/SPEC-001-decision-grill-v0.1.md`

The implementation must remain independent from official Skills and must not modify any existing official `SKILL.md`.

## Exact Allowed Files

Implementation may create only:

1. `skills/productivity/decision-grill/SKILL.md`
2. `docs/productivity/decision-grill.md`
3. `tests/manual/decision-grill-v0.1.md`

No other file may be created, modified, renamed, or deleted.

## Required Skill Metadata

The future `skills/productivity/decision-grill/SKILL.md` must use:

```yaml
---
name: decision-grill
description: A structured single-session interview that classifies decisions, handles unknowns safely, and converges with a fixed summary.
disable-model-invocation: true
---
```

## Required Skill Behavior

The Skill must implement all approved SPEC-001 behavior, including:

- independent general-mode interview flow;
- stateless operation;
- one primary question at a time;
- recommended answer for every question;
- BLOCKER / IMPORTANT / DEFERABLE classification;
- fact-versus-decision handling;
- Unknown Handling;
- provisional decisions;
- assumptions;
- question ledger behavior;
- minimum coverage framework;
- research boundary;
- scope control;
- convergence conditions;
- fixed eight-section closing summary;
- user controls;
- failure-mode safeguards;
- no automatic Skill chaining;
- no file creation or modification during normal use;
- no implementation of the user's plan.

## Required Documentation

The future `docs/productivity/decision-grill.md` must include:

1. What it does
2. When to use it
3. When not to use it
4. How to invoke it
5. Relationship with grill-me
6. Relationship with grilling
7. Relationship with grill-with-docs
8. Relationship with to-spec
9. Relationship with wayfinder
10. Question classifications
11. Unknown and provisional-decision handling
12. Minimum coverage framework
13. Convergence conditions
14. Closing summary format
15. User controls
16. Limitations
17. Example session
18. Installation note

The documentation must clearly state:

- `decision-grill` is independent;
- it does not replace or modify official Skills;
- it does not require `grill-me`;
- it remains stateless;
- it does not automatically invoke other Skills;
- it does not install itself.

## Required Manual Test Document

The future `tests/manual/decision-grill-v0.1.md` must contain all 20 Given / When / Then acceptance scenarios from SPEC-001.

Each test case must include:

- Test ID
- Related acceptance criterion
- Preconditions
- User input
- Expected Agent behavior
- Expected ledger or decision state
- Expected convergence status
- Pass criteria
- Actual result: NOT_RUN
- Status: NOT_RUN

## Implementation Constraints

- Do not modify official `grill-me`.
- Do not modify official `grilling`.
- Do not modify `grill-with-docs`.
- Do not modify `domain-modeling`.
- Do not modify `to-spec`.
- Do not modify `wayfinder`.
- Do not modify `batch-grill-me`.
- Do not modify review, decisions, or specs documents.
- Do not add domain-specific modes.
- Do not add automated fixtures.
- Do not add scripts, code, packages, dependencies, or CI.
- Do not install the Skill.
- Do not create a PR in the implementation task.
- Do not merge branches.

## Implementation Sequence

When separately authorized, Codex must:

1. Reconfirm branch, clean working tree, and exact baseline commit.
2. Create only the three allowed files.
3. Implement `SKILL.md` first.
4. Create the documentation page.
5. Create the manual test document.
6. Compare all three files against SPEC-001.
7. Run validation commands.
8. Stop before commit for Product Owner review.

## Validation Commands

The implementation task must run:

```powershell
git diff --check
git status --short
git diff --name-only
git diff -- skills/productivity/decision-grill/SKILL.md
git diff -- docs/productivity/decision-grill.md
git diff -- tests/manual/decision-grill-v0.1.md
```

The exact changed files must be only:

```text
skills/productivity/decision-grill/SKILL.md
docs/productivity/decision-grill.md
tests/manual/decision-grill-v0.1.md
```

## Acceptance Gate

Implementation is eligible for Product Owner review only when:

- Exactly three files were added.
- No existing file was modified.
- Skill metadata matches the approved values exactly.
- All SPEC-001 behavior is represented in SKILL.md.
- Documentation covers all 18 required sections.
- Manual test document contains all 20 scenarios.
- Every test status remains NOT_RUN.
- No installation occurred.
- No commit occurred.
- No push occurred.
- No PR was created.
- `git diff --check` passes.

## Stop Conditions

Immediately stop and report if:

- branch is incorrect;
- working tree is not clean before implementation;
- baseline commit differs;
- any unapproved file would be changed;
- an existing official Skill would need modification;
- implementation requires scope expansion;
- any SPEC-001 requirement is ambiguous or contradictory;
- validation reveals more than the three approved files;
- installation would be required;
- Product Owner approval has not been explicitly granted.

## Product Owner Authorization Record

- Implementation authorization: GRANTED
- Authorized by: Product Owner
- Authorization date: 2026-07-29
- Exact authorized files:
  1. `skills/productivity/decision-grill/SKILL.md`
  2. `docs/productivity/decision-grill.md`
  3. `tests/manual/decision-grill-v0.1.md`
- Commit authorization: Not granted for implementation files
- Push authorization: Not granted for implementation files
- Installation authorization: Not granted

## Completion Report Format

When implementation is separately authorized and completed, report only:

- branch
- baseline commit
- exact changed files
- Skill metadata check
- SPEC-001 behavior coverage
- documentation section coverage
- manual test count
- test statuses
- git diff --check
- git status --short
- confirmation that no commit, push, PR, or installation occurred

## Stop Condition

This task is approved for implementation of exactly the three authorized files.

Implementation must stop before commit, push, PR creation, or installation so the Product Owner can review the uncommitted diff.

No existing file may be modified during implementation.
