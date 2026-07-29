# Decision-Grill

## What it does

`decision-grill` is an independent, stateless, single-session, general-mode decision interview. It finds material decisions and gaps, classifies questions, handles unknowns safely, records session-local provisional decisions and assumptions, and ends with a fixed conversation-only summary.

## When to use it

Use `/decision-grill` before acting on a plan, product direction, business choice, operating decision, course design, or other bounded decision that needs sharper shared understanding within one conversation.

## When not to use it

Do not use it to implement a plan, create files, maintain terminology or ADRs, perform deep external research, or plan a multi-session effort. Use `wayfinder` when the decision goal is too large for one session. Use the appropriate documentation or specification Skill only after the interview identifies that as a next action.

## How to invoke it

Invoke it explicitly with `/decision-grill`. It is user-invoked and is not selected automatically by the model.

## Relationship with grill-me

`decision-grill` is independent of `grill-me`. It does not replace, modify, require, or upgrade `grill-me`; users do not need `grill-me` installed. Both value focused questioning, but `decision-grill` adds decision classification, unknown handling, provisional decisions, objective convergence, and a fixed summary.

## Relationship with grilling

`decision-grill` retains the core principles associated with `grilling`: one primary question at a time, Agent-owned fact finding, user-owned decisions, and no action before shared understanding. It does not call, depend on, replace, or modify the official `grilling` primitive.

## Relationship with grill-with-docs

`decision-grill` does not replace or modify `grill-with-docs`. It remains stateless and creates no files. If a decision interview needs durable glossary or ADR artifacts, the user may choose `grill-with-docs` as a separate next step.

## Relationship with to-spec

`decision-grill` does not replace or automatically invoke `to-spec`. After a converged decision interview, the summary may recommend `to-spec` when the user wants a specification, but the user must choose that next action.

## Relationship with wayfinder

`decision-grill` does not replace or automatically invoke `wayfinder`. When a goal cannot reasonably converge in one session, it stops deepening and recommends `wayfinder` as the appropriate cross-session decision-map workflow.

## Question classifications

Every material question has one classification:

- **BLOCKER** — the current decision cannot be safely completed while unresolved.
- **IMPORTANT** — it should be resolved, made provisional, or explicitly deferred.
- **DEFERABLE** — it can be recorded and delayed without blocking current convergence.

Only material decisions, risks, contradictions, or coverage gaps become questions. The Skill does not ask questions just to complete a checklist.

## Unknown and provisional-decision handling

When the user says they do not know or are uncertain, the Skill first distinguishes a fact from a decision. It finds available facts from the environment itself; unavailable facts are marked `UNKNOWN`, assessed for blocking impact, and paired with two to four viable options plus a recommended provisional decision.

A provisional decision records its answer, reason, assumption, risk, validation condition, review trigger, owner, and status. Unknown does not become a confirmed decision automatically: the user chooses whether to accept a provisional answer, defer it, or stop.

## Minimum coverage framework

The interview scans for material gaps across: Goal; Actors and stakeholders; Scope; Constraints; Dependencies; Alternatives and trade-offs; Failure modes and risks; Success and acceptance criteria; Unknowns and assumptions; Out-of-scope boundaries; and Next action.

This is a coverage check, not a fixed questionnaire. Areas already supported by the conversation or environment are not asked again, and irrelevant areas may be `NOT_APPLICABLE`.

## Convergence conditions

The session can converge only when all BLOCKER items are resolved; IMPORTANT items are confirmed, provisional, or deferred; DEFERABLE items are recorded; each unknown has a status, owner, or next step; no material conflict or cycle remains; coverage is complete; the summary is shown; and the user explicitly confirms.

The user's confirmation does not override unresolved objective conditions. An early stop produces a `NOT_CONVERGED` summary.

## Closing summary format

Every closing summary includes convergence status, remaining blockers, coverage gaps, user-confirmation status, and these eight sections:

1. Confirmed Decisions
2. Provisional Decisions
3. Assumptions
4. Unknowns
5. Deferred Questions
6. Risks
7. Out of Scope
8. Recommended Next Action

Empty sections explicitly say `None`.

## User controls

At any point, you can accept a recommendation, choose or modify an alternative, say unknown or uncertain, defer, request an explanation, reject a premise, mark an item out of scope, view the current summary, view remaining BLOCKER items or coverage gaps, reopen a decision, stop with an unconverged summary, or confirm convergence.

## Limitations

`decision-grill` is limited to one conversation and general mode. It does not create or modify files, maintain glossary or ADR records, perform external deep research, install itself, chain to other Skills automatically, or implement your plan. It does not replace or modify any official Skill.

## Example session

The user asks whether a training program should launch to every customer at once. The Skill locks the goal to deciding the launch scope, checks stakeholders and constraints, then asks one BLOCKER question about whether support capacity is known. If the answer is unknown, it looks for available capacity data; if data is unavailable, it offers a provisional limited rollout, explains the risk, and records the validation trigger. Once all material questions are resolved, provisional, or deferred, it presents the eight-section summary and asks the user to confirm convergence.

## Installation note

`decision-grill` is installed independently when the user chooses to install it. It does not require `grill-me`, does not install itself, and does not install, update, or modify any other Skill.
