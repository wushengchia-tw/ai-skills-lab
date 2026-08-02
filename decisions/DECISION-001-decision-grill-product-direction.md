# DECISION-001: Decision-Grill Product Direction

## Decision Metadata

- Decision ID: DECISION-001
- Repository: wushengchia-tw/ai-skills-lab
- Branch: feature/grill-me-pro
- Baseline commit SHA: 11751cfa19f79eac3317daa593f47fa1620d3b27
- Status: APPROVED
- Decision type: Product and architecture direction
- Implementation authorization: Not granted

## Context

- REVIEW-001 has been approved to enter the pre-specification decision phase.
- The official `grill-me`, `grilling`, `grill-with-docs`, `domain-modeling`, `to-spec`, `wayfinder`, and `batch-grill-me` remain unchanged.
- This document proposes product direction for a new Skill only; it does not authorize implementation.

## Decision Proposals

### DECISION-001-A — Final Skill Name

- **Decision question:** What should the final user-facing Skill name be?
- **Options considered:**
  1. `decision-grill`
  2. `grill-me-pro`
  3. `decision-architect`
- **Trade-offs:** `decision-grill` preserves familiar grill terminology while describing a decision-oriented workflow. `grill-me-pro` risks implying an official upgrade. `decision-architect` is broader but less clearly an interview tool.
- **Recommended option:** `decision-grill`
- **Rationale:** It clearly expresses a decision-interview position, does not cause users to mistake it for an upgrade to official `grill-me`, works for software, business, engineering, course, and operations decisions, and retains familiar grill semantics while expanding the workflow to be decision-oriented.
- **Risks:** The term may still be associated with `grill-me`; installation and documentation must make the independent relationship explicit.
- **Product Owner decision:** APPROVED

### DECISION-001-B — Relationship with grilling

- **Decision question:** How should `decision-grill` relate to the official `grilling` primitive?
- **Options considered:**
  1. Directly invoke existing `grilling`, then add supplementary rules.
  2. Create a fully independent interview flow.
  3. Modify official `grilling`.
- **Trade-offs:** Direct invocation maximizes reuse but couples behavior to the official primitive. An independent flow avoids that coupling and preserves existing Skills, but duplicates some instruction-level structure. Modifying `grilling` would alter the official primitive and exceeds the approved boundary.
- **Recommended option:** Create an independent `decision-grill` user entry and complete rule set, while reusing the core design principles of `grilling` without directly depending on or modifying official `grilling`.
- **Rationale:** This keeps the approved dependency boundary intact while preserving four proven interview principles:
  - Ask one question at a time.
  - The Agent finds facts.
  - The user confirms decisions.
  - No implementation occurs before shared understanding is complete.
- **Risks:** Behavioral drift from `grilling` is possible; the specification must state the retained principles explicitly.
- **Product Owner decision:** APPROVED

### DECISION-001-C — Domain Modes

- **Decision question:** Should the first version provide domain-specific modes?
- **Options considered:**
  1. Include multiple domain modes in the first version.
  2. Provide general mode only in the first version.
  3. Do not use modes at all.
- **Trade-offs:** Multiple modes can improve specialized coverage but expand first-version scope. General mode with a minimum coverage framework supports broad use while keeping scope bounded. No modes indefinitely could constrain future specialization.
- **Recommended option:** Provide general mode only in the first version, using one minimum coverage framework.
- **Rationale:** Software, business, investment, construction, course, and event modes belong to later versions and are not part of the first version.
- **Risks:** General mode may not surface every domain-specific consideration; the minimum coverage framework must be clear without over-prescribing questions.
- **Product Owner decision:** APPROVED

### DECISION-001-D — State Model

- **Decision question:** What state model should the first version use?
- **Options considered:**
  1. Fully stateless.
  2. Stateless by default, with optional document output.
  3. Mandatory document output.
- **Trade-offs:** Full statelessness avoids workspace mutation. Optional output is more convenient but creates document-format and authorization concerns. Mandatory output conflicts with the lightweight interview position and existing stateful Skills.
- **Recommended option:** Stateless by default.
- **Rationale:** The interview must generate a fixed convergence summary in conversation, but the first version must not automatically create or modify files. When documentation is needed, use `domain-modeling`, `grill-with-docs`, or `to-spec`.
- **Risks:** Users may want durable artifacts immediately; clear handoff guidance is required.
- **Product Owner decision:** APPROVED

### DECISION-001-E — Closing Summary

- **Decision question:** What fixed closing summary should the first version produce?
- **Options considered:**
  1. No fixed summary.
  2. A fixed conversation-only summary.
  3. A fixed summary automatically written to a file.
- **Trade-offs:** No fixed summary weakens reliable handoff. Conversation-only output preserves statelessness. Automatic file output creates state and overlaps with existing documentation Skills.
- **Recommended option:** Produce the following fixed structure in conversation only:
  1. Confirmed Decisions
  2. Provisional Decisions
  3. Assumptions
  4. Unknowns
  5. Deferred Questions
  6. Risks
  7. Out of Scope
  8. Recommended Next Action
- **Rationale:** A fixed summary resolves the current absence of a consistent closing artifact while retaining a stateless first version.
- **Risks:** Conversation-only summaries can be lost or copied inconsistently; documentation remains an explicit handoff rather than an automatic side effect.
- **Product Owner decision:** APPROVED

### DECISION-001-F — Question Classification

- **Decision question:** Which classification should govern question priority?
- **Options considered:**
  1. BLOCKER / IMPORTANT / DEFERABLE
  2. MUST / SHOULD / COULD
  3. CRITICAL / NORMAL / OPTIONAL
- **Trade-offs:** BLOCKER / IMPORTANT / DEFERABLE communicates convergence consequences directly. MUST / SHOULD / COULD is familiar but requirement-oriented. CRITICAL / NORMAL / OPTIONAL is simple but less clear about deferral.
- **Recommended option:** BLOCKER / IMPORTANT / DEFERABLE
- **Rationale:** The definitions align directly with an interview's stop conditions:
  - **BLOCKER:** The current decision cannot be safely completed while unresolved.
  - **IMPORTANT:** It should be handled; if it cannot be decided, a provisional decision may be created.
  - **DEFERABLE:** It can be recorded and postponed without blocking current convergence.
- **Risks:** Users may classify questions inconsistently; the specification must define agent guidance and escalation rules.
- **Product Owner decision:** APPROVED

### DECISION-001-G — Convergence Stop Conditions

- **Decision question:** When may a `decision-grill` session converge?
- **Options considered:**
  1. Stop when the user informally feels ready.
  2. Stop when all decision-tree branches are explored.
  3. Stop when explicit convergence conditions and user confirmation are satisfied.
- **Trade-offs:** Informal closure is fast but subjective. Exhaustive branching can be unbounded. Explicit conditions establish objective minimum coverage while retaining user confirmation.
- **Recommended option:** Require all of the following conditions:
  1. All BLOCKER items are resolved.
  2. All IMPORTANT items are confirmed, provisional, or explicitly deferred.
  3. All DEFERABLE items are recorded.
  4. All unknowns have a status, owner, or next step.
  5. No material dependency, contradiction, or cycle remains unhandled.
  6. The minimum coverage check is complete.
  7. The fixed convergence summary has been produced.
  8. The user explicitly confirms the convergence result.
- **Rationale:** These conditions make shared understanding observable without requiring every possible peripheral branch to be resolved.
- **Risks:** Applying the conditions too rigidly may extend small sessions; the minimum coverage framework must only prompt material decisions or gaps.
- **Product Owner decision:** APPROVED

### DECISION-001-H — Installation Relationship

- **Decision question:** How should `decision-grill` be installed and relate to existing Skills?
- **Options considered:**
  1. Ship as an independent Skill.
  2. Replace or overlay `grill-me`.
  3. Require co-installation with `grill-me` and related Skills.
- **Trade-offs:** Independent installation preserves user choice and official Skill boundaries. Replacement or overlay confuses compatibility. Required co-installation adds unnecessary dependencies for a stateless first version.
- **Recommended option:**
  - Install `decision-grill` as an independent Skill.
  - Do not override `grill-me`.
  - Do not require `grill-me` to be installed.
  - Do not modify `grill-with-docs`.
  - Do not automatically invoke `to-spec` or `wayfinder` in the first version.
  - When work exceeds a single session, recommend switching to `wayfinder` only.
- **Rationale:** This preserves independent installation and avoids changing or coupling existing workflows.
- **Risks:** Users may be uncertain which Skill to choose; documentation should explain the boundaries and referral to `wayfinder`.
- **Product Owner decision:** APPROVED

## Minimum Coverage Framework

The first-version general mode must check at least:

1. Goal
2. Actors and stakeholders
3. Scope
4. Constraints
5. Dependencies
6. Alternatives and trade-offs
7. Failure modes and risks
8. Success and acceptance criteria
9. Unknowns and assumptions
10. Out-of-scope boundaries
11. Next action

This is a minimum coverage check, not a requirement that every item produce a question. Ask only when a material decision or gap exists.

## Non-Goals

- Do not replace `grill-me`.
- Do not modify `grilling`.
- Do not replace `grill-with-docs`.
- Do not manage a glossary or ADRs.
- Do not replace `to-spec`.
- Do not create a cross-session decision map.
- Do not directly conduct research or implementation.
- Do not automatically write project documents.
- Do not add domain-specific modes.
- Do not install a Skill.

## Product Owner Decisions Required

| Decision | Recommendation | Product Owner decision | Notes |
| --- | --- | --- | --- |
| DECISION-001-A | `decision-grill` | APPROVED | |
| DECISION-001-B | Independent user entry using grilling principles without direct dependency or modification | APPROVED | |
| DECISION-001-C | First-version general mode with minimum coverage framework | APPROVED | |
| DECISION-001-D | Stateless by default; fixed conversation summary only | APPROVED | |
| DECISION-001-E | Fixed eight-section conversation summary | APPROVED | |
| DECISION-001-F | BLOCKER / IMPORTANT / DEFERABLE | APPROVED | |
| DECISION-001-G | Eight explicit convergence conditions plus user confirmation | APPROVED | |
| DECISION-001-H | Independent installation; recommend wayfinder only for multi-session work | APPROVED | |

## Approval Criteria

This document may change from PROPOSED to APPROVED only when all of the following are true:

1. The Product Owner approves or revises each of DECISION-001-A through DECISION-001-H.
2. The first-version scope and Non-Goals are confirmed.
3. The Minimum Coverage Framework is confirmed.
4. No existing `SKILL.md` has been modified.
5. No implementation or installation has occurred.

## Approval Record

- **Decision:** APPROVED
- **Approved by:** Product Owner
- **Approval date:** 2026-07-29
- **Approved decisions:** DECISION-001-A through DECISION-001-H
- **Approved first-version scope:** General mode only
- **Approved state model:** Stateless with fixed conversation-only convergence summary
- **Approved implementation direction:** Independent `decision-grill` Skill
- **Implementation authorization:** Not granted
- **Installation authorization:** Not granted
- **Existing Skill modification authorization:** Not granted

## Stop Condition

This product and architecture direction is approved as the baseline for specification work only.

Approval of this document does not authorize implementation, installation, or modification of any existing `SKILL.md`.

The next phase may create and review a separate specification for the approved first-version `decision-grill` scope. Implementation may begin only after that specification is separately approved.
