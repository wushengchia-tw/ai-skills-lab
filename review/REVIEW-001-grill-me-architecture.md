# REVIEW-001: Grill-Me Architecture Review

## Review Metadata

| Field | Value |
| --- | --- |
| Review ID | REVIEW-001 |
| Repository | wushengchia-tw/ai-skills-lab |
| Branch | feature/grill-me-pro |
| Baseline commit SHA | 2ab958093e83e0ec752e6c1c5932da465bf23e0c |
| Review date | 2026-07-29 |
| Status | APPROVED |
| Review type | Read-only architecture review |

## Scope

### In scope

- Review the current responsibilities and interactions of the grill-me interview flow and its related Skills.
- Identify architectural gaps that a future user-facing decision-interview Skill should address without changing existing Skills.

### Out of scope

- Modifying any existing Skill, documentation, configuration, implementation, or installation metadata.
- Deciding the final product name, implementation, or rollout plan.
- Replacing the existing domain-modeling, to-spec, wayfinder, batch-grill-me, or grilling responsibilities.

### Reviewed files

- `skills/productivity/grill-me/SKILL.md`
- `skills/productivity/grilling/SKILL.md`
- `skills/engineering/grill-with-docs/SKILL.md`
- `skills/engineering/domain-modeling/SKILL.md`
- `skills/engineering/to-spec/SKILL.md`
- `skills/engineering/wayfinder/SKILL.md`
- `skills/in-progress/batch-grill-me/SKILL.md`
- `docs/productivity/grill-me.md`

## Current Architecture

- `grill-me` is the user entry point: it is user-invoked and starts a `/grilling` session.
- `grilling` is the core interview primitive: it asks one question at a time, resolves a decision tree, investigates discoverable facts, and waits for the user's decisions.
- `grill-with-docs` composes `grilling` with `domain-modeling`.
- `domain-modeling` manages the glossary (`CONTEXT.md`) and ADRs as durable domain-model artifacts.
- `to-spec` is responsible for post-interview specification synthesis; it does not re-interview the user.
- `wayfinder` is responsible for cross-session, large-decision maps and their decision-ticket frontier.
- `batch-grill-me` is responsible for asking the batch design-tree frontier round by round.

## Strengths

- **Single-question interaction:** `grilling` explicitly asks one question at a time and waits for feedback, avoiding a bewildering multi-question exchange.
- **Fact and decision separation:** discoverable facts are investigated by the agent, while decisions remain with the user.
- **Clarify before implementation:** the flow prohibits action until shared understanding is confirmed.
- **Composable Skill architecture:** `grill-me` and `grill-with-docs` are deliberately thin entry points over reusable interview and domain-modeling capabilities.
- **Stateless and stateful responsibility separation:** `grill-me` is documented as stateless, while `grill-with-docs` adds durable glossary and ADR artifacts through `domain-modeling`.

## Findings

### FINDING-001 — Shared understanding lacks objective completion criteria

| Field | Detail |
| --- | --- |
| Severity | High |
| Evidence | `grilling` requires reaching a “shared understanding” and `grill-me` documentation describes visiting every decision-tree branch, but neither defines verifiable acceptance or convergence criteria. |
| Impact | Sessions can end based on subjective confidence, leaving material decisions, dependencies, or unresolved risks implicit. |
| Recommendation | Define explicit convergence criteria for a future entry Skill, including resolved blockers, recorded unknowns, and an acknowledged closing summary. |

### FINDING-002 — Questions have no BLOCKER / IMPORTANT / DEFERABLE classification

| Field | Detail |
| --- | --- |
| Severity | High |
| Evidence | `grilling` traverses decision-tree branches one by one, and `batch-grill-me` computes a frontier, but neither assigns question criticality. |
| Impact | Low-value questions can receive the same attention as decisions that must be settled before proceeding. |
| Recommendation | Add a question-priority model, initially using BLOCKER, IMPORTANT, and DEFERABLE (or a later-approved equivalent), to guide ordering and stop conditions. |

### FINDING-003 — “Unknown” and “uncertain” answers are not standardized

| Field | Detail |
| --- | --- |
| Severity | High |
| Evidence | `grilling` distinguishes environment-discoverable facts from user decisions, but provides no prescribed response when a user does not know a decision or a needed fact cannot currently be discovered. |
| Impact | An uncertain answer may be silently converted into a decision, repeatedly revisited, or leave downstream questions ambiguously blocked. |
| Recommendation | Define standard unknown states, their owner, follow-up action, and whether each blocks the session or can be deferred. |

### FINDING-004 — Provisional decisions and assumptions are unmanaged

| Field | Detail |
| --- | --- |
| Severity | High |
| Evidence | The reviewed interview Skills ask the user to resolve decisions, but have no explicit representation for a temporary decision, its rationale, validation trigger, or expiry. |
| Impact | Conditional choices can be mistaken for durable decisions, creating hidden risk when later work relies on them. |
| Recommendation | Capture provisional decisions and assumptions separately, with validation criteria and a named point at which they must be confirmed or revisited. |

### FINDING-005 — No protection against cycles or repeated questions

| Field | Detail |
| --- | --- |
| Severity | Medium |
| Evidence | `grilling` directs the agent to walk decision-tree branches and `batch-grill-me` recomputes a frontier after each round, but neither specifies visited-question tracking or cycle detection. |
| Impact | Dependent decisions can cause repeated questioning or circular investigation, reducing trust and preventing reliable convergence. |
| Recommendation | Maintain a session-local question ledger with identifiers, dependencies, status, and a rule to surface cycles rather than re-ask settled questions. |

### FINDING-006 — No fixed closing-summary format

| Field | Detail |
| --- | --- |
| Severity | High |
| Evidence | `grilling` stops only after the user confirms shared understanding; `grill-me` is stateless and leaves the conversation as its artifact, but neither prescribes a closing summary. |
| Impact | The user has no consistent final view of settled decisions, deferrals, assumptions, open risks, and next handoff. |
| Recommendation | Define a fixed conversation summary containing decisions, unresolved items, assumptions, deferred questions, and the recommended next Skill or action. |

### FINDING-007 — Research blocking and decision blocking boundary is incomplete

| Field | Detail |
| --- | --- |
| Severity | Medium |
| Evidence | `grilling` says to look up discoverable facts, while `wayfinder` distinguishes research, task, and grilling tickets and treats an exploration as an unsettled prerequisite. The single-session grill flow does not define the equivalent boundary or handoff. |
| Impact | A session may either ask the user for researchable facts or wait indefinitely on research without declaring which decisions are blocked and which can continue. |
| Recommendation | Specify when missing information is a research blocker versus a user-decision blocker, including a safe handoff to research or wayfinder for work that exceeds one session. |

### FINDING-008 — The decision tree has no minimum coverage boundary

| Field | Detail |
| --- | --- |
| Severity | High |
| Evidence | `grilling` and the `grill-me` documentation require walking every branch of a decision tree, but do not state the minimum decision categories or scope boundary that make a tree sufficiently covered. |
| Impact | “Every branch” can cause either premature closure of an under-specified tree or unbounded exploration of peripheral branches. |
| Recommendation | Establish a minimum coverage model for the intended decision domain, plus an explicit rule for out-of-scope and deferred branches. |

## Dependency Boundary

- Do not reimplement `domain-modeling` glossary or ADR responsibilities.
- Do not replace `to-spec`.
- Do not replace `wayfinder`.
- Do not directly modify `batch-grill-me`.
- Do not modify the official `grilling` primitive unless a later,
  separately approved architecture decision explicitly authorizes it.
- The default implementation direction is a separate user-entry Skill
  that composes or supplements existing primitives without changing them.

## Preliminary Recommendation

Keep the official Skills unchanged and create a separate user-entry Skill after approval.

- **Provisional name:** `decision-grill`
- **Positioning:** a single-session decision-interview tool with question classification, unknown handling, provisional decisions, and a convergence summary.

This is a preliminary direction only; it does not decide the final product name or authorize implementation.

## Open Decisions

- Final Skill name.
- Whether to reuse the `grilling` primitive.
- Whether software, business, engineering, or other modes are needed.
- Whether the new Skill remains stateless.
- Whether the closing summary is conversation-only or can optionally be written to a document.
- Question-classification names.
- Convergence stop conditions.
- Installation relationship with `grill-me` and `grill-with-docs`.

## Approval Criteria

This review may move from DRAFT to APPROVED only when:

1. The Product Owner accepts or revises all eight findings.
2. The dependency boundary is explicitly approved.
3. The preliminary recommendation is accepted only as the basis for
   specification work, not implementation.
4. All unresolved product choices remain listed under Open Decisions.
5. No existing SKILL.md has been modified.

## Approval Record

- **Decision:** APPROVED
- **Approved by:** Product Owner
- **Approval date:** 2026-07-29
- **Authorization scope:** Approved as the architecture-review baseline for subsequent specification work only.
- **Implementation authorization:** Not granted.
- **Existing Skill modification authorization:** Not granted.

## Stop Condition

This Architecture Review is approved only as the baseline for specification work.

Approval of this document does not authorize implementation, installation, or modification of any existing `SKILL.md`.

The next phase may resolve the listed Open Decisions and prepare a separate specification. No implementation may begin until that specification is separately reviewed and approved.
