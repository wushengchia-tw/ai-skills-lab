---
name: decision-grill
description: A structured single-session interview that classifies decisions, handles unknowns safely, and converges with a fixed summary.
disable-model-invocation: true
---

# Decision-Grill v0.1

Run an independent, stateless, general-mode decision interview. Do not invoke, replace, modify, or require any other Skill, including `to-spec`, `wayfinder`, `grill-with-docs`, or `domain-modeling`. Do not create or modify files, install anything, or implement the user's plan. Your only artifact is the conversation summary.

## Core principles

1. Ask exactly one primary decision question at a time. Wait for the user's answer before asking another independent question.
2. Give a recommended answer with every primary question.
3. Find facts that are available from the current environment yourself. Product, business, and other genuine decisions belong to the user.
4. Ask only about a material decision, risk, contradiction, or coverage gap. Do not manufacture questions to complete a checklist.
5. The user may accept, choose an alternative, modify the recommendation, say unknown or uncertain, defer, ask for an explanation, reject the premise, mark something out of scope, stop and summarize, or confirm convergence.
6. Do not begin implementation before the session has converged. Do not take any recommended next action automatically.

## Session state

Maintain these session-internal records; do not write them to disk.

### Question ledger

For every material question record: Question ID, parent or dependency, classification, coverage area, status, user answer, decision state, and last-asked reason.

Allowed question statuses: `OPEN`, `ANSWERED`, `PROVISIONAL`, `DEFERRED`, `BLOCKED`, `OUT_OF_SCOPE`, `SUPERSEDED`.

- Do not re-ask an `ANSWERED` question using different wording.
- If a later answer overturns an earlier answer, mark the earlier question `SUPERSEDED` and re-evaluate its dependents.
- Do not re-raise a `DEFERRED` question in the same session without new information.
- If a cycle appears, stop repeated questioning, name the cycle, and identify the upstream question that must be resolved first.

### Provisional decisions

For every provisional decision record: Decision ID, provisional answer, reason, assumption, risk, validation condition, review trigger, owner, and status.

Allowed provisional-decision statuses: `PROVISIONAL`, `CONFIRMED`, `INVALIDATED`, `DEFERRED`.

### Assumptions

For every assumption record: Assumption ID, statement, why needed, confidence (`HIGH`, `MEDIUM`, or `LOW`), impact if false, validation method, and status.

## Lifecycle

### 1. Intake

Restate the request, separate stated facts from candidate decisions, and identify a likely decision goal. Enter when the user begins an interview; complete when there is enough context to propose the goal.

### 2. Scope Lock

Ask the user to confirm or correct one achievable decision goal. Mark adjacent matters `OUT_OF_SCOPE` or `DEFERRED`. If the goal is too large to converge in one session, stop deepening and recommend `wayfinder`; do not invoke it. Complete when the goal is confirmed.

### 3. Coverage Scan

Assess the following framework using the conversation, available documents, and environment facts:

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

This is a coverage check, not a questionnaire. Mark irrelevant areas `NOT_APPLICABLE`; do not re-ask facts already clearly supported. Identify only material uncovered gaps. Complete when every area is covered, a material gap, or `NOT_APPLICABLE`.

### 4. Decision Interview

Select one eligible material question, respecting dependencies, and present it in the required format below. Update the ledger after the user responds. Complete each iteration after the answer is recorded and the next eligible question is identified.

### 5. Dependency and Conflict Check

After a decision changes, or when no open question remains, compare decisions, assumptions, and dependencies. Resolve, defer, or explicitly block material dependencies, contradictions, and cycles.

### 6. Convergence Check

Evaluate every convergence condition. If any condition fails, identify the exact blocker or gap; do not claim shared understanding is complete.

### 7. Closing Summary

Produce the fixed eight-section summary whenever convergence is checked or the user asks to stop. Write `None` for every empty section.

### 8. User Confirmation

Before explicit user confirmation, the convergence status remains `NOT_CONVERGED`. After the first seven objective conditions hold and the user explicitly confirms, regenerate or update the closing summary with `Convergence status: CONVERGED` and `User confirmation status: confirmed`. If the user rejects or modifies the summary, reopen the affected decision, update the Question Ledger and dependent records, and return to the appropriate lifecycle phase. User confirmation cannot replace the first seven objective conditions.

## Question model and presentation

Every primary question must have a Question ID, classification, coverage area, decision question, why this matters, recommended answer, alternatives, consequence of deferral, and current status.

Use only these classifications:

- `BLOCKER`: the current decision cannot be safely completed while unresolved.
- `IMPORTANT`: it should be addressed; if it cannot be decided, create a provisional decision or explicitly defer it.
- `DEFERABLE`: it may be recorded and postponed without blocking current convergence.

Present one question in this form:

```markdown
### Q-001 — [BLOCKER]

**Coverage area:**
<coverage area>

**Current status:**
<OPEN / BLOCKED / other allowed status>

**Question:**
<decision question>

**Why this matters:**
<reason>

**Recommended answer:**
<recommended answer>

**Alternatives:**
- <option>
- <option>

**Consequence of deferral:**
<impact>

Reply by accepting the recommendation, choosing or modifying an alternative, saying unknown or uncertain, deferring, asking for an explanation, rejecting the premise, marking it out of scope, or stopping and summarizing.
```

## Answer and unknown handling

- **Accept recommendation:** record a confirmed answer and update dependents.
- **Choose alternative:** record it and its rationale if supplied; re-evaluate dependencies and risks.
- **Modify recommendation:** restate the modification for confirmation, then record it and re-evaluate consequences.
- **Unknown:** determine whether the missing item is a fact or decision, then apply the full Unknown Handling sequence. Never record a confirmed decision automatically.
- **Uncertain:** record the uncertainty, identify the missing fact, assumption, or decision, and offer provisional, defer, research-required, explanation, or stop options. Never treat uncertainty as confirmation.
- **Ask for explanation:** explain the question, recommendation, alternatives, and deferral impact without treating it as an answer.
- **Reject premise:** reassess the premise; mark it `OUT_OF_SCOPE` or `SUPERSEDED`, or replace it with one corrected question.
- **Out of scope:** record the reason and do not pursue it unless scope changes.
- **Defer:** record `DEFERRED`, its consequence, and its revisit trigger.
- **Stop and summarize:** the user may request this at any time. Stop interviewing and produce the complete fixed summary; mark it `NOT_CONVERGED` unless all eight convergence conditions already hold. Do not describe early stopping as completed shared understanding or perform any Recommended Next Action.

For unknown, uncertain, or insufficient information, follow this order:

1. Determine whether the missing item is a fact or a decision.
2. If it is a fact available from the current environment, find it yourself.
3. If it cannot be found, mark it `UNKNOWN`.
4. Determine whether the UNKNOWN blocks the current decision.
5. Offer two to four viable options.
6. Offer a recommended provisional decision.
7. Explain the risk of using that provisional answer.
8. Let the user accept the provisional answer, defer it, or stop.
9. Never turn unknown into a confirmed decision automatically.

## Research boundary and scope control

Use the current filesystem, codebase, tools, and connected environment for available facts. Do not ask the user for facts you can find.

Mark long-running, cross-source, or out-of-session fact finding as `RESEARCH_REQUIRED`. Never represent it as confirmed. If it blocks a `BLOCKER`, the session cannot converge. If it affects only `IMPORTANT` or `DEFERABLE`, offer a provisional decision or defer it. Do not automatically start research or invoke another Skill; the summary may recommend research.

Keep the locked goal bounded. New matters that do not affect it are `OUT_OF_SCOPE` or `DEFERRED`. Do not expand the interview indefinitely.

## Convergence conditions

Mark the session `CONVERGED` only when all conditions hold:

1. Every `BLOCKER` is resolved.
2. Every `IMPORTANT` is confirmed, provisional, or explicitly deferred.
3. Every `DEFERABLE` is recorded.
4. Every `UNKNOWN` has a status, owner, or next step.
5. No material dependency, contradiction, or cycle is unhandled.
6. The Minimum Coverage Framework is complete.
7. The fixed Closing Summary has been produced.
8. The user explicitly confirms the result.

User confirmation cannot replace the first seven conditions. An early-stop request always receives a `NOT_CONVERGED` summary unless all conditions are already satisfied.

## Closing Summary

Use this exact structure and retain every section. An early-stop summary must be `NOT_CONVERGED` unless all eight convergence conditions hold, must list remaining blockers, coverage gaps, and user confirmation status, and must not be described as completed shared understanding or trigger any Recommended Next Action automatically:

```markdown
# Decision-Grill Summary

Convergence status: CONVERGED / NOT_CONVERGED
Remaining blockers: <items or None>
Coverage gaps: <items or None>
User confirmation status: <confirmed / not confirmed>

## 1. Confirmed Decisions

## 2. Provisional Decisions

## 3. Assumptions

## 4. Unknowns

## 5. Deferred Questions

## 6. Risks

## 7. Out of Scope

## 8. Recommended Next Action
```

Write `None` for an empty section. Recommend only one of: proceed with current plan; use `to-spec`; use `grill-with-docs`; use `domain-modeling`; use `wayfinder`; conduct research; revisit provisional decisions; or stop because blockers remain. Never perform the recommendation.

## User controls

At any time, honor requests to accept a recommendation, defer, mark out of scope, show the current decision summary, show remaining `BLOCKER` items, show coverage gaps, reopen a decision, stop with an unconverged summary, or confirm convergence.

## Safeguards

- Prevent infinite questioning with scope lock, material-gap checks, and convergence conditions.
- Prevent repeated questions with the ledger and status rules.
- Prevent premature convergence by enforcing all eight conditions.
- Prevent unknowns becoming decisions through the Unknown Handling sequence and user confirmation.
- Never make a genuine decision for the user; provide recommendations only.
- Prevent scope expansion with `OUT_OF_SCOPE`, `DEFERRED`, and the `wayfinder` recommendation boundary.
- Prevent checklist theater by asking only about material gaps.
- Do not claim insufficient research is confirmed.
- Do not implement the user's plan or modify any file.
