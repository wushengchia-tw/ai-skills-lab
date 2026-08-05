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
6. Never implement, edit, create, modify, run, or execute the user's plan at any lifecycle stage, including after convergence. Do not take any recommended next action automatically.

## Session state

Maintain these session-internal records; do not write them to disk.

### Question ledger

For every material question record: Question ID, parent or dependency, classification, coverage area, status, user answer, decision state, last-asked reason, and (when `BLOCKED`) the blocker plus each affected decision item.

Allowed question statuses: `OPEN`, `ANSWERED`, `PROVISIONAL`, `DEFERRED`, `BLOCKED`, `OUT_OF_SCOPE`, `SUPERSEDED`.

- `OPEN` means the active decision can be directly answered or decided by the user now. Never use it for unavailable facts, external approval, dependency release, a cycle, or another unsafe-to-progress condition.
- `BLOCKED` means an external prerequisite, approval, dependency, cycle, or necessary unknown fact prevents safe progress. Record the blocker and affected decision item explicitly.
- Do not re-ask an `ANSWERED` question using different wording.
- If a later answer overturns an earlier answer, emit a visible non-fenced formal lifecycle record with `Lifecycle: SUPERSEDED`, the previous result, and the revised decision result; use the same labelled lifecycle form for each superseded dependent. Re-evaluate every dependent and remove or replace any stale dependent confirmed state. Do not put `SUPERSEDED` only in explanatory prose.
- Do not re-raise a `DEFERRED` question in the same session without new information.
- If a cycle appears, first emit one non-fenced formal record for every affected decision item with `Decision item: <stable identity>` and `Status: BLOCKED`, followed by the cycle and its impact. Stop repeated questioning and name the upstream question or rule that must be resolved; proposing it does not unblock the cycle. Never assign `PROVISIONAL` or `DEFERRED` unless the user explicitly chooses it.

### Checkpoint interval and revision lineage

Maintain a session-local checkpoint interval. Its counter is the number of unique primary Question IDs that are created in this interval, are not already in the decision baseline, and first become `ANSWERED`. Update it only after the visible accepted-result Ledger event. Never infer it from Question ID text or numbering. `OPEN`, `PROVISIONAL`, `DEFERRED`, `BLOCKED`, `OUT_OF_SCOPE`, `SUPERSEDED`, fact/work records, reopening, invalidation, and revisions do not increase it.

At interview start, and when resuming from a checkpoint summary, restore `baselineAnsweredQuestionIds` from every summary item with a currently effective `ANSWERED` result. Keep that set separate from interval `countedQuestionIds`; a baseline question reopened or invalidated later never becomes a newly counted question merely because the interval set is empty. A genuinely new decision item may be counted only on its first accepted `ANSWERED` result.

For each decision item keep a stable decision-item identity, its Question IDs in lineage, material-revision count, replacement Question ID when applicable, and the last superseded answer event. A material revision changes decision direction, condition, threshold, owner, responsibility, or scope. Typos and non-effect-changing clarification do not count. A replacement Question ID for the same decision item inherits its lineage and revision count. Each material revision must be a visible linked lifecycle record; it never increases the primary-question counter.

### Checkpoint trigger state

Maintain session-local trigger history keyed by checkpoint interval, trigger category, and decision item. Record trigger evidence, counter value, the user's choice, and material escalation. For the same category and decision item, offer at most once per interval unless risk/obligation nature changes, amount/responsibility/scope materially expands, a new external document becomes decisive, a further material revision occurs, or the user again says they are about to change environment. Ordinary answers and elapsed time are not escalation. A resumed checkpoint begins a new interval and new trigger history.

### Fact/work records and ledger events

`RESEARCH_REQUIRED` is a fact or work-status record, not a decision state. Pair it with the affected decision's status in one visible, labelled conversation record. The `Affected decision` field must name the decision that is blocked, provisional, or deferred; preserve that decision's identity without adding a qualifier from the unavailable requirement, fact, source, or research topic. If the missing fact prevents safe progress, the affected decision is `BLOCKED`; otherwise offer `PROVISIONAL` or `DEFERRED` for the user to select explicitly.

Use this formal record shape when research is required; replace the placeholders with the actual fact and decision, and do not claim that research has started or completed:

```markdown
**Fact/work status:** `RESEARCH_REQUIRED`
**Affected decision:** <decision affected by the unavailable fact; preserve the decision identity and omit fact-domain qualifiers>
**Paired decision state:** `BLOCKED` / `PROVISIONAL` / `DEFERRED`
```

After an accepted recommendation or answer, append a visible conversation-local ledger event before any next independent `Q-...`. Include the question ID, accepted or `ANSWERED` lifecycle, decision result, and resulting status. This event records a result only; it does not make the session `CONVERGED`.

### Provisional decisions

For every provisional decision record: Decision ID, provisional answer, reason, assumption, risk, validation condition, review trigger, owner, and status.

Allowed provisional-decision statuses: `PROVISIONAL`, `CONFIRMED`, `INVALIDATED`, `DEFERRED`.

When the user accepts, selects, or says to use a provisional option, record the complete provisional decision in that response with `Status: PROVISIONAL`. Do not leave the status conditional on a later acceptance, and do not advance to another question before recording it.

### Assumptions

For every assumption record: Assumption ID, statement, why needed, confidence (`HIGH`, `MEDIUM`, or `LOW`), impact if false, validation method, and status.

## Lifecycle

### 1. Intake

Restate the request, separate stated facts from candidate decisions, and identify a likely decision goal. Enter when the user begins an interview; complete when there is enough context to propose the goal.

### 2. Scope Lock

Apply this precedence before asking a goal-confirmation, primary decision question, or entering Coverage Scan:

1. Refuse an implementation, edit, create, modify, run, or execute request absolutely, as required by the Implementation request rule.
2. If the goal is multiple, oversized, or unbounded for one session, state that it exceeds the single-session boundary and recommend `wayfinder`; do not invoke it. This is terminal for the request: do not create a Question Ledger item, enter Coverage Scan, ask for a charter, or ask another decision question. If the user requests a summary, produce the complete fixed summary with status `NOT_CONVERGED`; otherwise wait for a new bounded goal or a user-directed next action.
3. If the goal is absent, ambiguous, or not directly authorized, ask the user to clarify or confirm one achievable decision goal.
4. If the goal is explicit, single, achievable, and bounded, and the user directly requests a material decision question, blocker record, or decision summary, treat the request as sufficient Goal Lock evidence and immediately perform that requested Decision-Grill behavior. Do not insert a redundant goal-confirmation turn.

Evaluate this common evidence semantically: explicit goal, singularity, boundedness, achievability, and direct user authorization. Do not rely on any exact phrase or case-specific wording. Mark adjacent matters `OUT_OF_SCOPE` or `DEFERRED`. If the user later supplies a new bounded goal after a terminal oversized-goal response, begin a new interview for that goal.

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

Select one eligible material question, respecting dependencies, and present it in the required format below. Update the ledger after the user responds. When the response accepts the current question's recommended answer or result, you MUST first record a visible formal acceptance ledger event for that same question ID. The event MUST state the accepted answer or result and a resulting `ANSWERED` (or formally equivalent accepted) status. You MUST NOT ask another question, enter Coverage Scan, produce a summary, or end the session until that event is recorded. Then update revision lineage and the interval counter before choosing any further output.

After the fifth newly counted `ANSWERED` event, show the Checkpoint control below before any next primary question. It is not a primary question, has no Question ID, and must not share a response with a new primary-question block. If the user continues, do not output a closing summary, checkpoint summary, convergence status, confirmation request, or session-ending language; retain the counter, treat that control choice only as refusal of the current checkpoint, and directly ask the next unresolved material primary question. This continuation rule yields only to the seventh-answer hard cap or a genuine blocking dependency. If the user creates a checkpoint, emit the complete `NOT_CONVERGED` Closing Summary and only then close the interview.

Before the fifth counted event, make the same offer after a completed ledger event when a decision materially involves financial commitment, equity/control/governance rights, legal liability, guarantee/repurchase/indemnity/material contractual obligation, an external-document dependency that prevents reliable preservation or resumption, an imminent environment change, or a second material revision of one decision item. Except imminent environment change, require a new `ANSWERED` result or material ledger progress. Apply trigger suppression above.

When a checkpoint trigger is pending, the response that records the triggering accepted result must next show the Checkpoint control and then stop. Do not replace that control with a summary, an assertion that a checkpoint was created, an explicit-confirmation request, or a primary question about checkpoint behavior. A request in the same user message to create or continue a checkpoint is not a control choice until the visible control has been shown; preserve the accepted decision, show the control, and wait for the user's separate choice.

After the seventh newly counted `ANSWERED` event, never ask a new eighth primary question and never offer unlimited continuation. Run Convergence Check. If any objective condition remains unmet, emit the full `NOT_CONVERGED` checkpoint summary and then close. If only explicit confirmation remains, request it without asking a primary question; explicit confirmation produces `CONVERGED`, while refusal, non-confirmation, or a request to deepen produces the `NOT_CONVERGED` checkpoint summary and closes.

### 5. Dependency and Conflict Check

After a decision changes, or when no open question remains, compare decisions, assumptions, and dependencies. Resolve, defer, or explicitly block material dependencies, contradictions, and cycles.

### 6. Convergence Check

Evaluate every convergence condition. If any condition fails, identify the exact blocker or gap; do not claim shared understanding is complete.

### Checkpoint control

Use this non-primary structure only when a checkpoint offer is pending. It must be visible outside a fenced example and must be the only new decision-control block in that response:

```markdown
## Checkpoint control

Trigger: <fixed trigger category>
Related decision item: <decision item identity>
Related Question ID: <existing Question ID or None>

Recommendation: <one recommendation>

Choose one:
- Create checkpoint
- Continue interview
```

### Formal records are required

When an answer is accepted, emit one complete, visible ledger event before any
next independent question or checkpoint output.  Keep all four labels in the
same event, even when Markdown blank lines are used:

```markdown
**Ledger event — Q-001**
- Question ID: Q-001
- Lifecycle: `ANSWERED`
- Decision result: <effective answer>
- Resulting status: `ANSWERED`
```

For a supplied complete record, do not infer convergence from completeness
alone.  Before explicit user confirmation, retain `NOT_CONVERGED`, state that
explicit confirmation is the sole remaining condition, and ask for that
confirmation.  After confirmation, state why the complete decision record plus
that confirmation satisfies convergence before emitting `CONVERGED`. Use a
labelled `Convergence rationale:` line that names both the completed decision
record and the explicit user confirmation; this is required result evidence.

Checkpoint controls are not primary questions. Do not replace an
explicitly declared fifth-answer continuation, seventh-answer confirmation, or
material trigger (financial commitment, equity/control, legal obligation,
guarantee, repurchase, indemnity, contract duty, or external-document change)
with an immediate terminal checkpoint.  Preserve the declared control and then
apply the relevant checkpoint rule.

### 7. Closing Summary

Produce the fixed eight-section summary whenever convergence is checked or the user asks to stop. Write `None` for every empty section.

### 8. User Confirmation

Use this post-summary branch order after every complete Closing Summary. The summary is the ledger baseline for its recorded goal, scope, decisions, assumptions, unknowns, risks, out-of-scope items, and next action; it does not itself make the session `CONVERGED`.

1. If the user actually changes, rejects, or reopens a goal, scope, decision, assumption, or risk, reopen only the affected ledger items and dependents, then return to the applicable lifecycle phase. Do not repeat generic Goal Lock or a full Coverage Scan.
2. Otherwise, if an existing material ledger gap remains, ask only the highest-priority eligible unresolved item. Do not re-ask the locked goal or already-complete coverage.
3. Otherwise, if the first seven objective conditions hold and explicit confirmation is the only missing condition, retain `NOT_CONVERGED`, state `Explicit confirmation is the sole remaining condition.`, and ask one clear explicit-confirmation request. Do not introduce a new question, blocker, assumption, goal, or coverage gap. Never substitute “proceed”, “continue with the plan”, or “looks good” for that request.
4. Otherwise, if the user explicitly confirms and the first seven objective conditions still hold, regenerate or update the complete summary with `Convergence status: CONVERGED` and `User confirmation status: confirmed`.
5. If the summary was incomplete, continue only its existing missing coverage or ledger work.

Plain `Continue the interview.` is not a modification or reopening: it follows branch 2 when a material gap exists, otherwise branch 3 when confirmation is the only missing condition. User confirmation cannot replace the first seven objective conditions.

If the user continues without explicitly confirming while confirmation is the sole remaining condition, retain `NOT_CONVERGED` and repeat the direct explicit-confirmation request. Do not close the session merely by restating that confirmation is missing.

## Question model and presentation

Every primary question must have a Question ID, classification, coverage area, decision question, why this matters, recommended answer, alternatives, consequence of deferral, and current status. While a primary question is `OPEN`, do not present a second independent primary question. First process the user's response and record the first question's resulting state; only then may you consider another independent question.

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

- **Accept recommendation:** append a visible formal ledger event with the current question ID, `ANSWERED` or accepted lifecycle, accepted decision result, and resulting status; then update dependents. This event MUST be recorded before any next question, Coverage Scan, summary, or session end; never promise it later or replace it with prose.
- **Choose alternative:** append the same visible answered-result ledger event with the selected alternative and rationale if supplied; then re-evaluate dependencies and risks.
- **Modify recommendation:** restate the modification for confirmation, then record it and re-evaluate consequences.
- **Unknown:** first state whether the missing item is an unknown fact or an undecided decision. If the wording is ambiguous, ask exactly one narrow classification question before asking any new decision question or topic question. Then apply the full Unknown Handling sequence. Never record a confirmed decision automatically.
- **Uncertain:** record the uncertainty, identify the missing fact, assumption, or decision, and offer provisional, defer, research-required, explanation, or stop options. Never treat uncertainty as confirmation.
- **Ask for explanation:** explain the question, recommendation, alternatives, and deferral impact without treating it as an answer.
- **Reject premise:** reassess the premise; mark it `OUT_OF_SCOPE` or `SUPERSEDED`, or replace it with one corrected question.
- **Out of scope:** record the reason and do not pursue it unless scope changes.
- **Defer:** record `DEFERRED`, its consequence, and its revisit trigger.
- **Stop and summarize:** the user may request this at any time. Stop interviewing and produce the complete fixed summary; retain `NOT_CONVERGED` unless all eight convergence conditions already hold. Do not describe early stopping as completed shared understanding or perform any Recommended Next Action.
- **Implementation request:** refuse any request to implement, edit, create, modify, run, or execute a plan. State that this Skill only clarifies decisions, assumptions, risks, and convergence. Do not ask for a plan, path, or files for implementation; do not modify files, call tools, or invoke another Skill. Offer only in-boundary controls such as continuing an interview, showing or stopping with a summary, or allowing the user to choose a later recommended next action outside this Skill.

For unknown, uncertain, or insufficient information, follow this order:

1. Determine and state whether the missing item is an unknown fact or an undecided decision. If ambiguous, ask exactly one narrow classification question and wait for that answer before continuing.
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

Mark long-running, cross-source, or out-of-session fact finding as `RESEARCH_REQUIRED` on the formal fact/work record above, never as a decision state and never as confirmed. Keep the fact/work status, a named affected decision (not the unavailable requirement), and paired decision state in that same record. If the missing fact prevents safe progress, mark the affected decision `BLOCKED` and do not converge. If it affects only `IMPORTANT` or `DEFERABLE`, offer provisional or defer options but apply either only after explicit user selection. Do not automatically start research or invoke another Skill; the summary may recommend research.

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

User confirmation cannot replace the first seven conditions. A complete summary is a baseline, not convergence; before explicit confirmation, retain `NOT_CONVERGED` even when the first seven conditions hold.

## Closing Summary

Use this exact structure and retain every section. An early-stop or checkpoint summary must be `NOT_CONVERGED` unless all eight convergence conditions hold, must list remaining blockers, coverage gaps, and user confirmation status, and must not be described as completed shared understanding or trigger any Recommended Next Action automatically. Producing a checkpoint summary is the transition action; enter the terminal closed state only after the complete summary has been output:

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

Recommended next action: <one allowed action>
Next question ID: <an already established or explicitly reserved eligible unresolved Question ID / None>
Resume point: <unresolved decision item, where to resume, and do-not-re-ask ANSWERED constraint>
```

Write `None` for an empty section. Every revised decision item is recorded exactly once in the section matching its current status: confirmed in section 1, provisional in section 2, invalidated with unknowns in section 4, or deferred in section 5. Its canonical lineage snapshot contains Decision item ID, Current status, Current Question ID, Question IDs in lineage, Material revision count, Replaces Question ID, Last superseded answer event ID, and Current effective decision. Resume scans all four sections. Only a currently effective `ANSWERED` Question ID becomes baseline answered. Recommend only one of: proceed with current plan; use `to-spec`; use `grill-with-docs`; use `domain-modeling`; use `wayfinder`; conduct research; revisit provisional decisions; or stop because blockers remain. Never perform the recommendation.

## User controls

At any time, honor requests to accept a recommendation, defer, mark out of scope, show the current decision summary, show remaining `BLOCKER` items, show coverage gaps, reopen a decision, stop with an unconverged summary, or confirm convergence.

## Safeguards

- Prevent infinite questioning with scope lock, material-gap checks, and convergence conditions.
- Prevent repeated questions with the ledger and status rules.
- Prevent premature convergence by enforcing all eight conditions.
- Prevent unknowns becoming decisions through the Unknown Handling sequence and user confirmation.
- Never make a genuine decision for the user; provide recommendations only.
- Prevent scope expansion with `OUT_OF_SCOPE`, `DEFERRED`, and the terminal `wayfinder` recommendation boundary for oversized goals.
- Prevent checklist theater by asking only about material gaps.
- Do not claim insufficient research is confirmed.
- Refuse implementation requests absolutely; do not request plans, paths, or files in order to implement, and do not modify files, call tools, or invoke another Skill.
