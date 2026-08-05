# SPEC-001: Decision-Grill v0.1

## Specification Metadata

- Specification ID: SPEC-001
- Product: decision-grill
- Version: v0.1
- Repository: wushengchia-tw/ai-skills-lab
- Branch: feature/grill-me-pro
- Baseline commit SHA: aff0946881db89d00f6fbd947410af9a4a7b43db
- Status: APPROVED
- Specification type: Product behavior specification
- Implementation authorization: Not granted
- Installation authorization: Not granted

## Problem Statement

The existing `grill-me` and `grilling` flow is valuable: it asks one question at a time, keeps environment-discoverable facts with the Agent, leaves real decisions to the user, and avoids acting before shared understanding. However, it does not define objective convergence conditions, question classification, standard unknown handling, provisional-decision management, cycle and repeated-question protection, a fixed convergence summary, a single-session research-versus-decision blocking boundary, or a minimum coverage framework.

## Product Goal

`decision-grill` v0.1 is an independent, stateless, general-mode, single-session decision-interview Skill. Without modifying any official Skill, it helps users:

- identify important but not-yet-explicit decisions;
- distinguish necessary decisions, important decisions, and deferrable items;
- safely handle unknown, uncertain, and insufficient information;
- create provisional decisions and assumptions;
- converge under concrete stop conditions; and
- produce a fixed, conversation-only convergence summary.

## Non-Goals

- Do not replace `grill-me`.
- Do not modify `grilling`.
- Do not replace `grill-with-docs`.
- Do not manage a glossary or ADRs.
- Do not replace `to-spec`.
- Do not create a cross-session decision map.
- Do not conduct external deep research directly.
- Do not implement the user's plan.
- Do not automatically create or modify project documents.
- Do not add domain-specific modes.
- Do not automatically install or update a Skill.
- Do not automatically invoke `to-spec`, `wayfinder`, or any other Skill.

## Core Interaction Principles

1. Ask one primary question at a time.
2. The Agent must find facts that are available from the environment.
3. The user confirms genuine product or business decisions.
4. Do not begin implementation before convergence is complete.
5. Every question includes a recommended answer.
6. Ask only when a material decision, risk, contradiction, or gap exists.
7. Do not ask valueless questions merely to complete a checklist.
8. The user may accept a recommendation, modify it, defer it, answer unknown, or request an explanation.

## Session Lifecycle

| Phase | Purpose | Agent behavior | Entry condition | Completion condition |
| --- | --- | --- | --- | --- |
| Intake | Understand the initial request. | Restate the request, distinguish stated facts from candidate decisions, and identify the likely decision goal. | User starts a decision interview. | Enough context exists to propose a decision goal. |
| Scope Lock | Bound the session to one achievable decision goal. | Apply the Goal Lock precedence and evidence rules; mark adjacent matters as out of scope or deferred. | Intake has a proposed or directly evidenced goal. | A directly authorized bounded goal proceeds to the requested Decision-Grill behavior; an ambiguous goal is clarified or confirmed; an oversized goal stops with a `wayfinder` recommendation. |
| Coverage Scan | Locate material gaps across the minimum framework. | Inspect the 11 coverage areas using conversation, available documents, and environment facts; create questions only for material gaps. | Scope is locked. | All coverage areas are assessed as covered, gap, or NOT_APPLICABLE. |
| Decision Interview | Resolve the next material question. | Present exactly one primary question, its recommendation, alternatives, and deferral effect; append the required ledger event from the answer. | A non-blocked material question exists. | The answered question is visibly recorded before any next eligible independent question is presented. |
| Dependency and Conflict Check | Protect against contradictions and cycles. | Compare answers, dependencies, assumptions, and provisional decisions; surface cycles and their upstream prerequisite. | A decision changes, or no open question remains. | Material dependencies, contradictions, and cycles are resolved, deferred, or explicitly blocked. |
| Convergence Check | Evaluate objective completion conditions. | Evaluate every convergence condition and identify any remaining blocker or gap. | Coverage and interview work have reached a candidate stopping point, or the user requests confirmation. | All objective conditions are met, or a NOT_CONVERGED state is established. |
| Closing Summary | Produce a durable-in-conversation account of the result. | Emit all eight required summary sections, including `None` for empty sections. | A convergence check has run, or the user requests an early stop. | Summary contains status, blockers, coverage gaps, and user-confirmation status. |
| User Confirmation | Obtain the user's final confirmation. | Ask the user to confirm the convergence result after the summary. | A CONVERGED candidate summary exists. | User explicitly confirms; otherwise retain NOT_CONVERGED and record the reason. |

## Question Model

Every primary question must include:

- Question ID
- Classification
- Coverage area
- Decision question
- Why this matters
- Recommended answer
- Alternatives
- Consequence of deferral
- Current status

Only these classifications are allowed:

- **BLOCKER:** The current decision cannot be safely completed while unresolved.
- **IMPORTANT:** It should be addressed; if not decidable, create a provisional decision or explicitly defer it.
- **DEFERABLE:** It may be recorded and postponed without blocking current convergence.

## Question Presentation Format

Present exactly one primary question to the user in this form:

```markdown
### Q-001 — [BLOCKER]

**問題：**
<question>

**為什麼重要：**
<reason>

**建議答案：**
<recommended answer>

**其他選項：**
- <option>
- <option>

**延後的影響：**
<impact>

請回答以下任一方式：

- 接受建議
- 選擇其他方案
- 修改建議
- 不知道
- 延後
- 請先說明
```

Do not present multiple independent primary decision questions at once.

## Answer Handling

| User answer | Required Agent handling |
| --- | --- |
| Accept recommendation | Append a visible accepted-result ledger event, record the recommended answer as confirmed or `ANSWERED`, re-evaluate dependents, and only then continue if another material question exists. |
| Choose alternative | Append a visible answered-result ledger event with the selected alternative and rationale if supplied, then re-evaluate dependencies and risks. |
| Modify recommendation | Restate the modified decision for confirmation, record it once confirmed, and re-evaluate consequences. |
| Unknown | Apply the Unknown Handling procedure; never convert it automatically into a formal decision. |
| Uncertain | Record the uncertainty, determine whether a fact or decision is missing, and offer provisional, defer, research-required, or stop options. |
| Defer | Mark the question DEFERRED, record its consequence and revisit trigger, and do not repeat it without new information. |
| Ask for explanation | Explain the question, recommendation, alternatives, and impact without treating the request as an answer. |
| Reject premise | Reassess whether the question is based on a false assumption; mark it OUT_OF_SCOPE, SUPERSEDED, or replace it with one corrected question. |
| Out of scope | Mark OUT_OF_SCOPE with the reason and do not pursue it unless the scope lock changes. |
| Stop and summarize | Stop interviewing, run the closing-summary process, and mark NOT_CONVERGED unless all convergence conditions already hold. |

## Unknown Handling

When the user answers unknown, uncertain, or says information is insufficient, the Agent must:

1. Determine whether the missing item is a fact or a decision.
2. If it is an available fact, search the current environment first.
3. If it cannot be found, mark it `UNKNOWN`.
4. Determine whether the UNKNOWN is blocking.
5. Offer two to four viable options.
6. Offer a recommended provisional decision.
7. Explain the risk of adopting that provisional answer.
8. Let the user accept the provisional answer, defer it, or stop.
9. Never automatically convert unknown into a confirmed decision.

## Provisional Decision Model

Every provisional decision must contain:

- Decision ID
- Provisional answer
- Reason
- Assumption
- Risk
- Validation condition
- Review trigger
- Owner
- Status

Allowed status values are `PROVISIONAL`, `CONFIRMED`, `INVALIDATED`, and `DEFERRED` only.

## Assumption Model

Every assumption must contain:

- Assumption ID
- Statement
- Why needed
- Confidence: `HIGH`, `MEDIUM`, or `LOW`
- Impact if false
- Validation method
- Status

## State and Ledger Contract

### Decision-item states

Allowed decision-question statuses are `OPEN`, `ANSWERED`, `PROVISIONAL`, `DEFERRED`, `BLOCKED`, `OUT_OF_SCOPE`, and `SUPERSEDED` only.

- `OPEN` means the active decision question can currently be answered or decided directly by the user. Do not use `OPEN` for unavailable data, external approval, dependency release, a cycle, or another condition that prevents safe progress.
- `BLOCKED` means the decision cannot safely progress because of an external prerequisite, approval, dependency, cycle, or required unknown fact. Record both the blocker and every affected decision item.
- `RESEARCH_REQUIRED` is a fact or work-status record, never a decision-question status and never a resolved decision. Pair it with the affected decision's status. If the missing fact prevents safe progress, that decision is `BLOCKED`; otherwise the user may explicitly choose `PROVISIONAL` or `DEFERRED`.
- `PROVISIONAL` and `DEFERRED` require an explicit user selection. Never assign either automatically to escape a blocker, research need, or cycle.

### Question ledger

The Agent must maintain a session-internal ledger containing:

- Question ID
- Parent or dependency
- Classification
- Coverage area
- Status
- User answer
- Decision state
- Last asked reason
- Blocker and affected decision item, when status is `BLOCKED`

Rules:

- Do not re-ask an `ANSWERED` question with different wording.
- When a new answer overturns an older answer, mark the original question `SUPERSEDED`, re-evaluate every dependent item, and remove or replace any stale confirmed state that depended on the superseded answer.
- On detecting a cycle, first mark each affected decision item `BLOCKED` with the cycle and its impact, then stop repeated questioning and identify the upstream question or rule that must be resolved first. Proposing that rule does not itself unblock the cycle.
- Do not re-raise a `DEFERRED` question in the same session without new information.

### Ledger events and accepted-result ordering

Append a visible, conversation-local ledger event whenever an answer is accepted or recorded. Each event must identify the question, lifecycle (`ANSWERED` or accepted), and the decision result or resulting state. For example:

```markdown
**Ledger event:**
- Question ID: Q-001
- Lifecycle: ANSWERED
- Decision result: <accepted recommendation or selected alternative>
- Status: ANSWERED
```

When the user accepts a recommendation or answers a question, append this event before presenting any next independent `Q-...` question. The event is a record of that result, not a claim that the whole session is `CONVERGED`.

## Minimum Coverage Framework

The general mode must check these 11 areas:

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

Rules:

- This is a coverage check, not a fixed questionnaire.
- Ask only when a material gap exists.
- Do not re-ask an item clearly supported by the conversation, documents, or environment.
- Mark irrelevant items `NOT_APPLICABLE`.
- After Coverage Scan, identify each remaining material coverage gap.

## Research Boundary

- In a single session, the Agent obtains facts available from current files, the codebase, tools, or connected environments.
- Do not ask the user for facts the Agent can find itself.
- Mark long-running, cross-source, or single-session-exceeding research as `RESEARCH_REQUIRED` on the fact or work record, and pair it with the affected decision-item state.
- Never present `RESEARCH_REQUIRED` as a confirmed fact.
- If a missing research fact prevents safe progress, mark the affected decision `BLOCKED` and the session cannot be declared complete.
- If research affects only IMPORTANT or DEFERABLE items, offer provisional or defer options, but record either only after the user selects it.
- v0.1 does not automatically start `wayfinder` or external research; recommend the next step only in the summary.

## Scope Control

- Apply Goal Lock in this order before Intake, Coverage Scan, or a primary question:
  1. Refuse an implementation, edit, create, modify, run, or execute request absolutely. This takes precedence over every other Goal Lock outcome.
  2. If the goal is multiple, oversized, or unbounded for one session, stop the interview and recommend `wayfinder` without invoking it; if the user requests a summary, produce only the required `NOT_CONVERGED` summary.
  3. If the goal is absent, ambiguous, or not directly authorized, request one goal clarification or confirmation.
  4. If the goal is explicit, single, achievable, and bounded, and the user directly requests a material decision question, blocker record, or decision summary, treat that request as sufficient Goal Lock evidence and proceed directly to that requested behavior.
- Goal Lock evidence is semantic rather than phrase-based. It must assess the goal's explicitness, singularity, boundedness, achievability, and the user's direct request; it must not require a fixed wording or a separate confirmation turn when those facts are already present.
- Mark new matters that do not affect the goal as `OUT_OF_SCOPE` or `DEFERRED`.
- Do not expand the interview indefinitely because adjacent issues appear.
- An implementation request remains refused even if it also contains a bounded goal; an oversized goal remains terminal even if it also requests a question or blocker record, except that a requested summary receives only the required `NOT_CONVERGED` summary.
- An implementation refusal must not request a plan, path, or files, invoke another Skill, call tools, or perform any implementation action.

## Convergence Conditions

All of the following must hold:

1. All BLOCKER items are resolved.
2. All IMPORTANT items are confirmed, provisional, or explicitly deferred.
3. All DEFERABLE items are recorded.
4. Every UNKNOWN has a status, owner, or next step.
5. No material dependency, contradiction, or cycle remains unhandled.
6. The Minimum Coverage Framework is complete.
7. The fixed Closing Summary has been produced.
8. The user explicitly confirms the convergence result.

Additional rules:

- If the user requests a stop, produce an unconverged summary but do not mark the session complete.
- Never claim shared understanding is complete while a BLOCKER remains unresolved.
- User confirmation cannot replace the first seven objective conditions.

## Post-Summary State Machine

A complete Closing Summary establishes the current ledger baseline for goal, scope, decisions, assumptions, unknowns, risks, out-of-scope items, and recommended next action. Producing that summary never by itself changes the session to `CONVERGED`.

After a complete summary, process the next user message in this exact order:

1. **User modification or reopening.** If the user actually changes, rejects, or reopens a goal, scope, decision, assumption, or risk, reopen only the affected ledger items and their dependents. Return to the applicable lifecycle phase for that affected scope; do not repeat a full interview or a generic Goal Lock/coverage scan.
2. **Objective condition or material gap remains.** If an existing ledger item remains a material gap, ask only the highest-priority eligible unresolved ledger item. Do not re-ask locked goal evidence or scan coverage that the summary already established.
3. **Confirmation-only.** If all first seven objective conditions hold and explicit user confirmation is the only missing condition, retain `NOT_CONVERGED`, state that confirmation is the sole remaining condition, and make one clear request for explicit confirmation. Do not introduce a question, blocker, assumption, goal, or coverage gap; do not use an action phrase such as “proceed”, “continue with the plan”, or “looks good” as a substitute for that request.
4. **Explicit confirmation.** Mark `CONVERGED` only when the user explicitly confirms and the first seven objective conditions still hold. Regenerate or update the complete summary with confirmed user status.
5. **Incomplete summary.** If the summary was not complete, continue only the existing missing coverage or ledger work; it is not a post-summary baseline.

Plain `Continue the interview.` is neither a modification nor a reopening. It follows step 2 when a material gap exists, otherwise step 3 when confirmation is the only missing condition.

## Closing Summary

Output this structure every time a summary is requested or required:

```markdown
# Decision-Grill Summary

## 1. Confirmed Decisions

## 2. Provisional Decisions

## 3. Assumptions

## 4. Unknowns

## 5. Deferred Questions

## 6. Risks

## 7. Out of Scope

## 8. Recommended Next Action
```

Also include:

- `Convergence status: CONVERGED / NOT_CONVERGED`
- Remaining blockers
- Coverage gaps
- User confirmation status

Write `None` explicitly for an empty section; do not omit any section.

## Recommended Next Action Rules

The summary may recommend only:

- Proceed with current plan
- Use `to-spec`
- Use `grill-with-docs`
- Use `domain-modeling`
- Use `wayfinder`
- Conduct research
- Revisit provisional decisions
- Stop because blockers remain

Never execute a recommended next action automatically.

## Failure Modes and Safeguards

| Failure mode | Safeguard |
| --- | --- |
| Infinite questioning | Enforce scope lock, material-gap checks, and convergence conditions. |
| Repeated questions | Use the Question Ledger; do not re-ask ANSWERED or unchanged DEFERRED questions. |
| Premature convergence | Require all eight convergence conditions before `CONVERGED`. |
| Treating unknown as a formal decision | Apply Unknown Handling and require user confirmation for every confirmed or provisional decision. |
| Agent deciding for the user | Present recommendations and alternatives, but reserve genuine decisions for explicit user confirmation. |
| Scope expansion | Mark adjacent matters OUT_OF_SCOPE or DEFERRED; recommend `wayfinder` for oversized goals. |
| Over-reliance on a checklist | Treat coverage as a scan and ask only about material gaps. |
| Continuing without a material gap | Stop asking when coverage and ledger show no substantive open issue. |
| Losing summary baseline | Apply the post-summary state machine; do not repeat locked-goal or completed-coverage questions. |
| Treating an action phrase as confirmation | Keep `NOT_CONVERGED` and request explicit confirmation. |
| Claiming confirmation from insufficient research | Mark the missing fact or work `RESEARCH_REQUIRED` and retain the paired affected decision state; use `BLOCKED` when safe progress depends on it. |
| Starting implementation before convergence | Treat implementation as a non-goal and recommend next actions only after the summary. |

## User Controls

The user may at any time request:

- Accept recommendation
- Defer
- Mark as out of scope
- Show current decision summary
- Show remaining BLOCKER items
- Show coverage gaps
- Reopen a decision
- Stop and produce an unconverged summary
- Confirm convergence

## Acceptance Criteria

1. **Given** a normal answerable decision with sufficient Goal Lock evidence, **when** the session begins, **then** the Agent asks one primary question with a recommendation and records the confirmed answer without a redundant goal-confirmation turn.
2. **Given** a user says “I don't know,” **when** the item is a decision, **then** the Agent follows Unknown Handling and does not record a confirmed decision.
3. **Given** an IMPORTANT item lacks certainty, **when** the user accepts a provisional answer, **then** the Agent records every required provisional-decision field and status `PROVISIONAL`.
4. **Given** an IMPORTANT question is deferred, **when** the user chooses defer, **then** the ledger records DEFERRED, consequence, and revisit trigger.
5. **Given** an unresolved BLOCKER exists, **when** the user asks to converge, **then** the summary is `NOT_CONVERGED` and names the remaining blocker.
6. **Given** a needed fact exists in the current environment, **when** the Agent needs it, **then** the Agent looks it up instead of asking the user.
7. **Given** a needed fact requires extended or cross-source work, **when** it cannot be obtained in-session, **then** the Agent marks the fact `RESEARCH_REQUIRED`, records the affected decision state, and does not claim either as confirmed.
8. **Given** a user overturns an earlier answer, **when** the new answer is accepted, **then** the original ledger entry is `SUPERSEDED`, all dependents are re-evaluated, and no stale dependent confirmed state remains.
9. **Given** cyclic dependencies appear, **when** detected, **then** the Agent marks each affected item `BLOCKED`, identifies the cycle and upstream prerequisite, and does not repeat questions.
10. **Given** coverage has no material gap, **when** scanning that area, **then** the Agent does not manufacture a question.
11. **Given** the goal exceeds a single session, **when** Scope Lock identifies that condition, **then** the Agent stops deepening and recommends `wayfinder`.
12. **Given** the user asks to stop early, **when** the request is received, **then** the Agent produces a `NOT_CONVERGED` summary without claiming completion.
13. **Given** all convergence conditions are met, **when** the user confirms, **then** the Agent produces all eight summary sections with `CONVERGED`.
14. **Given** convergence conditions are not met, **when** a summary is produced, **then** it includes all eight sections and `NOT_CONVERGED`.
15. **Given** any normal session, **when** it completes, **then** the Skill does not create or modify files.
16. **Given** a user describes a plan, **when** the interview runs, **then** the Skill does not implement the plan.
17. **Given** official Skills exist, **when** `decision-grill` is used, **then** it does not modify or override them.
18. **Given** `grill-me` is not installed, **when** `decision-grill` is used, **then** the session remains usable and does not require installation of `grill-me`.
19. **Given** a next action is appropriate, **when** the summary recommends `to-spec` or `wayfinder`, **then** the Skill recommends but does not invoke either.
20. **Given** the first seven objective convergence conditions hold, **when** the user has not explicitly confirmed, **then** the Agent must not mark the session `CONVERGED`.
21. **Given** an explicit, single, achievable bounded goal and a direct request for a material decision question, blocker record, or decision summary, **when** Scope Lock evaluates the request, **then** the Agent proceeds directly to that behavior without requiring exact wording or an additional goal confirmation.
22. **Given** an absent, ambiguous, or not directly authorized goal, **when** Scope Lock evaluates the request, **then** the Agent requests goal clarification or confirmation before proceeding.
23. **Given** a user accepts a recommendation, **when** the Agent continues the interview, **then** a visible ledger event for that question's accepted result appears before any next independent `Q-...` question.

## Out of Scope for v0.1

- Domain-specific modes
- File-writing mode
- ADR creation
- Glossary maintenance
- Issue tracker integration
- Cross-session persistence
- Automatic research agents
- Automatic Skill chaining
- Automatic implementation
- Installation automation
- Modifying existing official Skills

## Checkpoint Extension

### Formal acceptance and convergence clarification

Each accepted answer MUST have one message-local ledger event containing the
Question ID, Lifecycle, Decision result, and Resulting status. Markdown blank
lines between those labelled fields do not split the event. A complete record
without explicit user confirmation remains `NOT_CONVERGED`: the output MUST say
that confirmation is the sole remaining condition and request it. Once the user
confirms, the output MUST explain that the completed record and confirmation
together justify `CONVERGED` in a labelled `Convergence rationale:` record.

Checkpoint controls are not primary questions. A declared fifth-answer
continuation, seventh-answer confirmation, or material trigger MUST be honored
as declared; it MUST NOT be replaced by an immediate terminal checkpoint.

### Interval counting and baseline

Maintain a conversation-local checkpoint interval. Count only a unique primary Question ID that is created in that interval, is not already a baseline answered question, and first formally becomes `ANSWERED`. The accepted-result ledger event is emitted before the counter changes. Do not infer a count from Question ID spelling or sequence. `OPEN`, `PROVISIONAL`, `DEFERRED`, `BLOCKED`, `OUT_OF_SCOPE`, `SUPERSEDED`, revisions, invalidations, and fact/work records do not count.

At initial intake, establish `baselineAnsweredQuestionIds` from already effective answered decisions. A checkpoint summary supplies the next interval's baseline. Reopened or invalidated baseline questions never become newly counted merely because a new interval starts. A new Question ID counts only if it is a genuinely new decision item and first becomes `ANSWERED` in that interval.

### Offers and hard cap

After the fifth counted answer event, output a non-primary Checkpoint control before any next primary question. It offers Create checkpoint and Continue interview and includes one recommendation. Continue keeps the counter at five, produces no summary, and is not explicit convergence confirmation. Create checkpoint emits a complete eight-section `NOT_CONVERGED` summary, then closes the interview.

Before the fifth counted answer, make the same offer after a completed material ledger event for a material financial commitment, equity/control/governance right, legal liability, guarantee, repurchase, indemnity, material contractual obligation, decisive external-document dependency, imminent environment change, or the second material revision of one decision item. Except environment change, require new `ANSWERED` evidence or material ledger progress. Suppress the same interval/category/decision-item offer until material escalation.

After the seventh counted answer event, no new eighth primary question may be created. Run the existing convergence check. If an objective condition remains, emit the complete `NOT_CONVERGED` checkpoint summary then close. If only explicit confirmation remains, request it without a primary question. Explicit confirmation emits `CONVERGED`; rejection, non-confirmation, or deepening emits the `NOT_CONVERGED` checkpoint summary then closes.

### Revision lineage and resume

Every decision item has a stable decision-item identity and a Question-ID lineage. Material revisions change direction, condition, threshold, owner, responsibility, or scope; wording-only clarification does not. Replacement Question IDs for the same item inherit the lineage and material revision count. Revision events visibly link the prior and current result and never increment the answer counter.

For every materially revised decision item, exactly one canonical lineage snapshot appears in the summary section matching its current status: Confirmed Decisions, Provisional Decisions, Unknowns when invalidated with unknowns, or Deferred Questions. It includes Decision item ID, Current status, Current Question ID, Question IDs in lineage, Material revision count, Replaces Question ID, Last superseded answer event ID, and Current effective decision. Resume scans all four sections. Only Question IDs with an effective `ANSWERED` result are restored as baseline answered IDs.

### Closing Summary additions

The eighth section retains exactly one recommendation and also contains:

```text
Recommended next action: <one allowed action>
Next question ID: <already established or explicitly reserved eligible unresolved Question ID / None>
Resume point: <unresolved item, resume location, and do-not-re-ask constraint>
```

The next ID is never generated at resume time or inferred by arithmetic. A checkpoint summary is a transition action; only after it is completely output is the interview closed. Resuming it establishes a new interval with a reset counter and trigger history but restores the summary baseline and lineage.

## Open Specification Questions

| Question | Status | Product Owner decision | Implementation impact |
| --- | --- | --- | --- |
| Which existing category directory should contain the Skill? | DECIDED | Place the Skill under `skills/productivity/decision-grill/`. | Establishes the canonical Skill path and positions it alongside related decision-interview productivity Skills. |
| Is an independent documentation page required? | DECIDED | Yes. Create `docs/productivity/decision-grill.md` during the separately authorized implementation phase. | Requires one dedicated usage and behavior document, but does not authorize creating it in this task. |
| Are fixtures or manual test cases required? | DECIDED | Manual acceptance test cases are required for v0.1. Automated fixtures are not required unless implementation review later identifies a concrete need. | Requires a manual test document or test section covering all 20 acceptance scenarios. |
| What is the exact Skill description? | DECIDED | `A structured single-session interview that classifies decisions, handles unknowns safely, and converges with a fixed summary.` | Fixes the future `SKILL.md` front-matter description. |
| Should `disable-model-invocation` be `true`? | DECIDED | Yes. Set `disable-model-invocation: true`. | The Skill remains explicitly user-invoked and must not be selected automatically by the model. |

## Approval Criteria

This specification may change from DRAFT to APPROVED only when all conditions hold:

1. All behavior rules are consistent with APPROVED DECISION-001.
2. Acceptance Criteria are complete and verifiable.
3. The Product Owner decides the Open Specification Questions.
4. No existing `SKILL.md` has been modified.
5. No implementation or installation has started.
6. The Product Owner explicitly approves the specification.

## Approval Record

- **Decision:** APPROVED
- **Approved by:** Product Owner
- **Approval date:** 2026-07-29
- **Approved version:** v0.1
- **Canonical Skill path:** `skills/productivity/decision-grill/SKILL.md`
- **Required documentation path:** `docs/productivity/decision-grill.md`
- **Validation approach:** Manual acceptance testing covering all 20 Given / When / Then scenarios
- **Automated fixtures:** Not required for v0.1
- **Approved Skill description:** `A structured single-session interview that classifies decisions, handles unknowns safely, and converges with a fixed summary.`
- **Invocation policy:** `disable-model-invocation: true`
- **Implementation authorization:** Not granted by this document
- **Installation authorization:** Not granted
- **Existing Skill modification authorization:** Not granted

## Stop Condition

This specification is approved as the authoritative behavioral baseline for `decision-grill` v0.1.

Approval of this specification does not by itself authorize implementation, installation, or modification of any existing official Skill.

Implementation may begin only under a separate, explicitly authorized implementation task with exact file scope, acceptance tests, and stop conditions.
