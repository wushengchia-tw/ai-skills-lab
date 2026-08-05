# Decision-Grill v0.1 Manual Acceptance Tests

All test cases are derived from SPEC-001 acceptance criteria. Execute manually only after implementation review authorizes testing. Every case remains NOT_RUN in this document.

## DG-001 — Normal answerable decision

- Related acceptance criterion: 1
- Scenario: **Given** a normal answerable decision, **when** the session begins, **then** one primary question with a recommendation is asked and the confirmed answer is recorded.
- Preconditions: A bounded decision goal is available.
- User input: “Should we launch to all customers now?” followed by an answer to the first question.
- Expected Agent behavior: Ask one primary question with a recommendation and append its visible accepted-result ledger event before any next independent question.
- Expected ledger or decision state: One `ANSWERED` question; ledger event identifies `Q-001`, accepted/`ANSWERED` lifecycle, and decision result.
- Expected convergence status: NOT_CONVERGED unless all conditions later hold.
- Pass criteria: No independent second question appears before the answer is processed; if `Q-002` appears, the accepted-result ledger event appears first.
- Actual result: NOT_RUN
- Status: NOT_RUN

## DG-002 — Unknown decision

- Related acceptance criterion: 2
- Scenario: **Given** a user says “I don't know,” **when** the item is a decision, **then** Unknown Handling is followed without recording a confirmed decision.
- Preconditions: A material decision question is open.
- User input: “I don't know.”
- Expected Agent behavior: Apply Unknown Handling and do not record a confirmed decision.
- Expected ledger or decision state: Question remains `OPEN`, `PROVISIONAL`, `DEFERRED`, or `BLOCKED`; never confirmed solely from unknown.
- Expected convergence status: NOT_CONVERGED if the unknown is unresolved or blocking.
- Pass criteria: The Agent distinguishes fact versus decision and offers safe options.
- Actual result: NOT_RUN
- Status: NOT_RUN

## DG-003 — Provisional decision

- Related acceptance criterion: 3
- Scenario: **Given** an IMPORTANT item lacks certainty, **when** the user accepts a provisional answer, **then** all required provisional-decision fields are recorded with status `PROVISIONAL`.
- Preconditions: An IMPORTANT question has insufficient certainty.
- User input: “I explicitly accept and use the provisional option.”
- Expected Agent behavior: Record every required provisional-decision field.
- Expected ledger or decision state: Related question and decision are `PROVISIONAL`.
- Expected convergence status: May continue toward convergence if no BLOCKER remains.
- Pass criteria: Answer, reason, assumption, risk, validation condition, review trigger, owner, and status are represented.
- Actual result: NOT_RUN
- Status: NOT_RUN

## DG-004 — Deferred IMPORTANT question

- Related acceptance criterion: 4
- Scenario: **Given** an IMPORTANT question is deferred, **when** the user chooses defer, **then** the ledger records DEFERRED, consequence, and revisit trigger.
- Preconditions: An IMPORTANT question is open and is non-blocking.
- User input: “Defer this.”
- Expected Agent behavior: Record the deferral and its consequence and revisit trigger.
- Expected ledger or decision state: Question status `DEFERRED`.
- Expected convergence status: May converge if all other conditions hold.
- Pass criteria: It is not re-asked without new information.
- Actual result: NOT_RUN
- Status: NOT_RUN

## DG-005 — Unresolved BLOCKER

- Related acceptance criterion: 5
- Scenario: **Given** an unresolved BLOCKER exists, **when** the user asks to converge, **then** the summary is `NOT_CONVERGED` and names the remaining blocker.
- Preconditions: At least one BLOCKER is unresolved.
- User input: “Confirm convergence.”
- Expected Agent behavior: Produce a summary that names the remaining blocker.
- Expected ledger or decision state: Legal approval remains `BLOCKED` with the blocker and affected launch decision recorded; it is not `OPEN` because the user cannot provide the external approval directly.
- Expected convergence status: NOT_CONVERGED.
- Pass criteria: The Agent never claims shared understanding is complete.
- Actual result: NOT_RUN
- Status: NOT_RUN

## DG-006 — Environment fact available

- Related acceptance criterion: 6
- Scenario: **Given** a needed fact exists in the current environment, **when** the Agent needs it, **then** the Agent looks it up instead of asking the user.
- Preconditions: A required fact is present in current files or tools.
- User input: A question that depends on that fact.
- Expected Agent behavior: Look up the fact rather than asking the user for it.
- Expected ledger or decision state: Fact informs the question without an unnecessary user prompt.
- Expected convergence status: Unchanged until decision conditions are met.
- Pass criteria: The user is not asked to supply the discoverable fact.
- Actual result: NOT_RUN
- Status: NOT_RUN

## DG-007 — Research required

- Related acceptance criterion: 7
- Scenario: **Given** a needed fact requires extended or cross-source work, **when** it cannot be obtained in-session, **then** it is marked `RESEARCH_REQUIRED` without being claimed as confirmed.
- Preconditions: A needed fact requires long-running or cross-source research.
- User input: A question dependent on that unavailable fact.
- Expected Agent behavior: Mark the fact `RESEARCH_REQUIRED` and do not present it as confirmed.
- Expected ledger or decision state: Fact/work record is `RESEARCH_REQUIRED` and the affected decision state is also recorded; it is `BLOCKED` when the unavailable fact prevents safe progress.
- Expected convergence status: NOT_CONVERGED when it blocks a BLOCKER.
- Pass criteria: No external research workflow is automatically started.
- Actual result: NOT_RUN
- Status: NOT_RUN

## DG-008 — Superseded answer

- Related acceptance criterion: 8
- Scenario: **Given** a user overturns an earlier answer, **when** the new answer is accepted, **then** the original ledger entry is `SUPERSEDED` and dependencies are re-evaluated.
- Preconditions: An earlier question is `ANSWERED`.
- User input: “I am reversing that earlier decision.”
- Expected Agent behavior: Record the new answer and re-evaluate dependencies.
- Expected ledger or decision state: A visible labelled `Lifecycle: SUPERSEDED` record identifies the original question; replacement answer recorded; dependent states are re-evaluated and no stale confirmed support-capacity state remains.
- Expected convergence status: Re-evaluated after dependent questions update.
- Pass criteria: The Agent does not silently retain the overturned answer.
- Actual result: NOT_RUN
- Status: NOT_RUN

## DG-009 — Cyclic dependency

- Related acceptance criterion: 9
- Scenario: **Given** cyclic dependencies appear, **when** detected, **then** the Agent identifies the cycle and upstream prerequisite instead of repeating questions.
- Preconditions: Two unresolved questions depend on each other.
- User input: Answers that reveal the cycle.
- Expected Agent behavior: Mark affected decision items `BLOCKED`, then identify the cycle and the upstream prerequisite.
- Expected ledger or decision state: Affected question is `BLOCKED` with cycle impact; no repeated rephrased questioning or automatic `PROVISIONAL`/`DEFERRED` state.
- Expected convergence status: NOT_CONVERGED until the cycle is handled.
- Pass criteria: The Agent explicitly explains the cycle.
- Actual result: NOT_RUN
- Status: NOT_RUN

## DG-010 — No material coverage gap

- Related acceptance criterion: 10
- Scenario: **Given** coverage has no material gap, **when** scanning that area, **then** the Agent does not manufacture a question.
- Preconditions: A coverage area is already clearly supported.
- User input: Continue the interview.
- Expected Agent behavior: Treat the complete summary as the ledger baseline. Do not repeat Goal Lock or coverage scanning; because confirmation is the sole pending condition, explicitly ask the user to confirm.
- Expected ledger or decision state: Supplied areas remain covered or `NOT_APPLICABLE`; no unnecessary `OPEN` question.
- Expected convergence status: `NOT_CONVERGED` until explicit confirmation.
- Pass criteria: No duplicate goal or coverage question appears, and the response states that explicit confirmation is the sole remaining condition before making an explicit confirmation request rather than a proceed action.
- Actual result: NOT_RUN
- Status: NOT_RUN

## DG-011 — Goal exceeds one session

- Related acceptance criterion: 11
- Scenario: **Given** the goal exceeds a single session, **when** Scope Lock identifies that condition, **then** the Agent stops deepening and recommends `wayfinder`.
- Preconditions: The stated goal has too many unresolved independent decisions for one session.
- User input: “Plan the entire multi-team transformation.”
- Expected Agent behavior: Stop deepening and recommend `wayfinder`.
- Expected ledger or decision state: Scope is not expanded into an unbounded interview.
- Expected convergence status: NOT_CONVERGED.
- Pass criteria: `wayfinder` is recommended but not invoked.
- Actual result: NOT_RUN
- Status: NOT_RUN

## DG-012 — Early stop

- Related acceptance criterion: 12
- Scenario: **Given** the user asks to stop early, **when** the request is received, **then** the Agent produces a `NOT_CONVERGED` summary without claiming completion.
- Preconditions: Legal approval is required before the Aurora pilot may launch, has not been received, and is recorded as an unresolved BLOCKER; one or more convergence conditions therefore remain unmet.
- User input: “Stop and summarize.”
- Expected Agent behavior: Do not insert generic goal confirmation; establish or show the legal-approval BLOCKER, then stop questions and produce the full summary.
- Expected ledger or decision state: Open or blocked items remain recorded.
- Expected convergence status: NOT_CONVERGED.
- Pass criteria: The summary names legal approval, does not claim completion, and startup is not intercepted by generic goal confirmation.
- Actual result: NOT_RUN
- Status: NOT_RUN

## DG-013 — Normal converged completion

- Related acceptance criterion: 13
- Scenario: **Given** all convergence conditions are met, **when** the user confirms, **then** all eight summary sections are produced with `CONVERGED`.
- Preconditions: The first seven objective convergence conditions are satisfied.
- User input: “I confirm convergence.”
- Expected Agent behavior: Only after explicit confirmation, produce or update all eight summary sections with user confirmation recorded as confirmed.
- Expected ledger or decision state: All required classifications are resolved, recorded, provisional, or deferred.
- Expected convergence status: CONVERGED.
- Pass criteria: No pre-confirmation result says `CONVERGED`; the post-confirmation summary includes explicit user confirmation and every required section.
- Actual result: NOT_RUN
- Status: NOT_RUN

## DG-014 — Unconverged summary structure

- Related acceptance criterion: 14
- Scenario: **Given** convergence conditions are not met, **when** a summary is produced, **then** it includes all eight sections and `NOT_CONVERGED`.
- Preconditions: At least one convergence condition is unmet.
- User input: “Show the summary.”
- Expected Agent behavior: Produce all eight sections with `None` for empty sections; an incomplete summary continues only existing missing coverage and does not become a post-summary convergence baseline.
- Expected ledger or decision state: Remaining issue remains visible.
- Expected convergence status: NOT_CONVERGED.
- Pass criteria: No summary section is omitted.
- Actual result: NOT_RUN
- Status: NOT_RUN

## DG-015 — No file mutation

- Related acceptance criterion: 15
- Scenario: **Given** any normal session, **when** it completes, **then** the Skill does not create or modify files.
- Preconditions: A normal interview is running in a repository.
- User input: Complete or stop the interview.
- Expected Agent behavior: Keep all records in conversation only.
- Expected ledger or decision state: Session-local ledger only.
- Expected convergence status: Any valid status.
- Pass criteria: No file is created or modified.
- Actual result: NOT_RUN
- Status: NOT_RUN

## DG-016 — No plan implementation

- Related acceptance criterion: 16
- Scenario: **Given** a user describes a plan, **when** the interview runs, **then** the Skill does not implement the plan.
- Preconditions: The user presents an implementable plan.
- User input: “Now implement the plan.”
- Expected Agent behavior: Refuse to implement and retain the interview boundary.
- Expected ledger or decision state: No implementation action is recorded.
- Expected convergence status: Unchanged.
- Pass criteria: No code, file, or project change is made.
- Actual result: NOT_RUN
- Status: NOT_RUN

## DG-017 — Official Skills unchanged

- Related acceptance criterion: 17
- Scenario: **Given** official Skills exist, **when** `decision-grill` is used, **then** it does not modify or override them.
- Preconditions: Official Skills are present.
- User input: Use `/decision-grill` for a decision interview.
- Expected Agent behavior: Run independently without altering or overriding official Skills.
- Expected ledger or decision state: Normal session-local records only.
- Expected convergence status: Any valid status.
- Pass criteria: No official Skill content or behavior is modified.
- Actual result: NOT_RUN
- Status: NOT_RUN

## DG-018 — No grill-me installation requirement

- Related acceptance criterion: 18
- Scenario: **Given** `grill-me` is not installed, **when** `decision-grill` is used, **then** it remains usable without requiring `grill-me` installation.
- Preconditions: `grill-me` is not installed.
- User input: Start `/decision-grill`.
- Expected Agent behavior: Conduct the interview without requiring `grill-me`.
- Expected ledger or decision state: Normal session-local records only.
- Expected convergence status: Any valid status.
- Pass criteria: No installation prompt or dependency requirement appears.
- Actual result: NOT_RUN
- Status: NOT_RUN

## DG-019 — No automatic Skill invocation

- Related acceptance criterion: 19
- Scenario: **Given** a next action is appropriate, **when** the summary recommends `to-spec` or `wayfinder`, **then** it recommends but does not invoke either.
- Preconditions: A summary recommends `to-spec` or `wayfinder`.
- User input: Complete the current decision interview.
- Expected Agent behavior: Recommend the next action only.
- Expected ledger or decision state: Recommendation is recorded in the closing summary.
- Expected convergence status: Any valid status.
- Pass criteria: Neither `to-spec` nor `wayfinder` is invoked automatically.
- Actual result: NOT_RUN
- Status: NOT_RUN

## DG-020 — Confirmation is required

- Related acceptance criterion: 20
- Scenario: **Given** the first seven objective convergence conditions hold, **when** the user has not explicitly confirmed, **then** the session is not marked `CONVERGED`.
- Preconditions: The first seven objective conditions are satisfied but user confirmation is absent.
- User input: Continue without explicitly confirming.
- Expected Agent behavior: Ask for confirmation and do not mark completion.
- Expected ledger or decision state: All objective work may be complete; confirmation remains pending.
- Expected convergence status: NOT_CONVERGED.
- Pass criteria: `CONVERGED` is not used before explicit confirmation.
- Actual result: NOT_RUN
- Status: NOT_RUN

## Executable fixtures for remediation regression

Run each fixture in a new Codex Desktop Session in `<active DG regression folder>`. Current fixture environment: `D:\temp\decision-grill-dg-retest-20260729-233153165`. Each initial input begins with `/decision-grill`. These fixtures define future regression execution only; they do not change the acceptance-case `Actual result` or `Status` fields above.

### VALIDATION-001 / DG-001

- Fixture environment setup: Start a new Codex Desktop Session with the project-level `decision-grill` Skill available in `<active DG regression folder>`. Do not create files or invoke any other Skill.
- Exact initial input: `/decision-grill\nStart a bounded decision interview. Goal: decide whether to launch the Aurora pilot to its 100 invited customers on 2026-10-01. The Product Owner and Support Lead are the decision owners. The choice is launch on 2026-10-01 or delay the pilot. Ask the first material decision question only.`
- Ordered subsequent inputs:
  1. `Accept the recommendation.`
- Input timing: Send input 1 only after the Agent has presented one primary question with a recommendation; do not send any other response first.
- Expected behavior: The Agent asks exactly one primary question in the required question format, including a recommendation, then appends a visible accepted-result ledger event before considering any next independent question.
- Observable evidence: Before input 1, the transcript contains one question identifier (expected `Q-001`) and no second independent decision question. After input 1, the response visibly records a ledger event with `Question ID: Q-001`, accepted or `ANSWERED` lifecycle, and the decision result. A `Q-002`, if any, follows that event.
- PASS conditions: No second independent question appears before input 1 is processed; the first question has a recommendation; and the accepted-result ledger event precedes any `Q-002`.
- FAIL conditions: A second independent question appears before processing input 1; the first question lacks a recommendation; the accepted-result ledger event is missing; or `Q-002` precedes that event.
- BLOCKED conditions: The project-level Skill is unavailable, the session cannot accept `/decision-grill`, or an unrelated system error prevents the first response.
- Pre/post file or Skill environment comparison required: No. Transcript inspection only.

### VALIDATION-012 / DG-002

- Fixture environment setup: Start a new Codex Desktop Session with the project-level `decision-grill` Skill available in `<active DG regression folder>`. Do not pre-classify the user's later response as a fact or a decision.
- Exact initial input: `/decision-grill\nStart a decision interview. Goal: decide whether to enable optional SMS incident alerts for the Aurora pilot. This is a material decision. The decision goal and scope are confirmed. Do not ask for Scope Lock confirmation. Ask the material decision question.`
- Ordered subsequent inputs:
  1. `I don't know.`
- Input timing: Send input 1 only after the Agent asks the material SMS-incident-alerts decision question. Do not add any explanation before or with that exact input.
- Expected behavior: The Agent explicitly classifies the missing item as an unknown fact or an undecided decision, or asks exactly one narrow classification question. It must not record a confirmed decision.
- Observable evidence: The transcript after input 1 contains an explicit classification statement or one narrow classification question, and the ledger/state is not confirmed.
- PASS conditions: The Agent self-classifies or asks one narrow classification question; no new topic question precedes that classification; and no confirmed decision is recorded.
- FAIL conditions: The Agent presumes confirmation, records a confirmed decision, asks more than one classification question, or moves to a different decision topic before classifying.
- BLOCKED conditions: The initial material question is not produced, `/decision-grill` is unavailable, or the session ends before input 1 can be sent.
- Pre/post file or Skill environment comparison required: No. Transcript inspection only.

### VALIDATION-013 / DG-011

- Fixture environment setup: Start a new Codex Desktop Session with the project-level `decision-grill` Skill available in `<active DG regression folder>`. Ensure no other Skill is manually invoked.
- Exact initial input:
  ```text
  /decision-grill
  Plan the entire multi-team transformation.
  ```
- Ordered subsequent inputs: None.
- Input timing: None; inspect the first Agent response only.
- Expected behavior: Scope Lock identifies an oversized goal, recommends `wayfinder` only, and stops the interview boundary without invoking it.
- Observable evidence: The first response recommends `wayfinder` but contains no `Q-001`, no request for a charter, no Coverage Scan, no follow-up decision question, and no evidence that `wayfinder` was called or created.
- PASS conditions: `wayfinder` is recommendation-only; no question ledger item is created; no charter is requested; Coverage Scan is not entered; and no subsequent decision question is asked.
- FAIL conditions: The Agent invokes or creates `wayfinder`, presents `Q-001`, asks for a charter, enters Coverage Scan, or asks a follow-up decision question.
- BLOCKED conditions: `/decision-grill` does not start or the initial response is unavailable.
- Pre/post file or Skill environment comparison required: Yes. Compare the active Skill environment before and after for automatic Skill invocation or creation; no change is expected.

### VALIDATION-014 / DG-012

- Fixture environment setup: Start a new Codex Desktop Session with the project-level `decision-grill` Skill available in `<active DG regression folder>`. Do not resolve legal approval outside the conversation.
- Exact initial input: `/decision-grill\nStart a bounded interview to decide whether the Aurora pilot may launch. Legal approval is required before launch, has not been received, and is an unresolved BLOCKER. Ask the legal-approval decision question.`
- Ordered subsequent inputs:
  1. `Stop and summarize.`
- Input timing: Send input 1 only after legal approval is visibly represented as an unresolved `BLOCKER` or the corresponding primary question is shown.
- Expected behavior: Immediately stop asking questions and produce the complete fixed eight-section Closing Summary with `NOT_CONVERGED`.
- Observable evidence: The response after input 1 contains all eight numbered summary sections, names legal approval under remaining blockers or equivalent state, states `Convergence status: NOT_CONVERGED`, and contains no further question.
- PASS conditions: All eight sections exist; legal approval remains unresolved; status is `NOT_CONVERGED`; user confirmation is not confirmed; and questioning stops immediately.
- FAIL conditions: Any summary section is absent; legal approval is omitted; `CONVERGED` or completed shared understanding is claimed; or a new question is asked after the stop request.
- BLOCKED conditions: The legal-approval blocker was not established before input 1, the stop input cannot be delivered, or `/decision-grill` is unavailable.
- Pre/post file or Skill environment comparison required: No. Transcript inspection only.

### VALIDATION-015 / DG-014

- Fixture environment setup: Start a new Codex Desktop Session with the project-level `decision-grill` Skill available in `<active DG regression folder>`. Do not resolve legal approval outside the conversation.
- Exact initial input: `/decision-grill\nStart a bounded interview to decide whether the Aurora pilot may launch. Legal approval is required before launch, has not been received, and is an unresolved BLOCKER. Ask the legal-approval decision question.`
- Ordered subsequent inputs:
  1. `Show the summary.`
- Input timing: Send input 1 only after legal approval is visibly represented as unresolved.
- Expected behavior: Produce a `NOT_CONVERGED` fixed summary containing all eight sections; each empty section explicitly says `None`.
- Observable evidence: The response includes `## 1. Confirmed Decisions` through `## 8. Recommended Next Action`, states `NOT_CONVERGED`, identifies legal approval as remaining, and writes `None` in every empty section.
- PASS conditions: All eight fixed sections are present; empty sections say `None`; legal approval remains visible; and the convergence status is `NOT_CONVERGED`.
- FAIL conditions: Any section is omitted, an empty section is left blank rather than `None`, legal approval is omitted, or the summary says `CONVERGED`.
- BLOCKED conditions: The blocker is not established, `/decision-grill` is unavailable, or no summary response is returned.
- Pre/post file or Skill environment comparison required: No. Transcript inspection only.

### VALIDATION-016 / DG-015

- Fixture environment setup: Before starting, recursively inventory product files under the active project root and record a SHA-256 manifest for each file. Exclude Codex and Git runtime metadata: `.codex`, `.agents`, `.git`, `.gitignore` runtime state, `.DS_Store`, editor caches, and all session/transcript artifacts outside the product tree. Define the post-test manifest with the identical roots and exclusions. Confirm there are no pre-existing product files named ledger, summary, log, transcript, or test-result for this fixture.
- Exact initial input: `/decision-grill\nStart a bounded decision interview. Goal: decide whether the Aurora pilot launches on 2026-10-01. Ask one material decision question with a recommendation.`
- Ordered subsequent inputs:
  1. `Stop and summarize.`
- Input timing: Send input 1 only after the first primary question is shown. Take the post-test manifest only after the final summary response is complete.
- Expected behavior: Keep ledger, summary, and session state in conversation only; do not create or mutate product files.
- Observable evidence: The before/after manifests have identical file paths and SHA-256 values; no product file with ledger, summary, log, transcript, or test-result in its name appears.
- PASS conditions: The compared manifests are identical and the prohibited product artifact search has zero hits.
- FAIL conditions: Any in-scope product file is added, removed, or hash-changed; or a prohibited product artifact is created or mutated.
- BLOCKED conditions: A baseline or post-test manifest cannot be collected with the specified exclusions, or unrelated concurrent product writes make comparison unreliable.
- Pre/post file or Skill environment comparison required: Yes. Required product-file inventory and SHA-256 comparison with the stated runtime-metadata exclusions.

### VALIDATION-017 / DG-016

- Fixture environment setup: Start a new Codex Desktop Session with the project-level `decision-grill` Skill available in `<active DG regression folder>`. Capture a pre-test product-file manifest and observe the session tool/Skill activity.
- Exact initial input:
  ```text
  /decision-grill
  Now implement the plan.
  ```
- Ordered subsequent inputs: None.
- Input timing: None; inspect the immediate first response and then take the post-test manifest.
- Expected behavior: Immediately refuse implementation and state the interview boundary. It must not ask for a plan, path, or files; call tools; modify files; or start another Skill.
- Observable evidence: The first response is a refusal limited to decision clarification controls. Session activity shows no tool call and no other Skill activation; before/after product manifests match.
- PASS conditions: Immediate refusal; no request for plan, path, or files; no tool activity; no file mutation; and no other Skill starts.
- FAIL conditions: The Agent requests implementation details, invokes a tool or Skill, edits or creates a file, or begins implementation.
- BLOCKED conditions: Tool/Skill activity cannot be observed, a manifest cannot be obtained, or `/decision-grill` is unavailable.
- Pre/post file or Skill environment comparison required: Yes. Compare product-file manifest and observable Skill/tool activity before and after.

### VALIDATION-018 / DG-017

- Fixture environment setup: Before starting, inventory every official `.system` Skill file in the applicable official-Skills root and record either a sorted path-plus-SHA-256 manifest or a deterministic aggregate hash. Also verify that the global user Skill root contains no installed `decision-grill` directory; the project-level copy in `<active DG regression folder>` is allowed.
- Exact initial input: `/decision-grill\nStart a bounded decision interview. Goal: decide whether the Aurora pilot launches on 2026-10-01. Ask one material decision question with a recommendation.`
- Ordered subsequent inputs:
  1. `Stop and summarize.`
- Input timing: Send input 1 after the first primary question. Re-inventory official `.system` Skills and the global user Skill root after the summary response.
- Expected behavior: Run independently through session-local records without altering official Skills or installing a global `decision-grill` Skill.
- Observable evidence: The official-Skills manifest or aggregate hash is identical before and after; the global user Skill root still has no `decision-grill`; and the transcript shows no override or installation action.
- PASS conditions: No official-Skill path or hash changes and no global `decision-grill` installation appears.
- FAIL conditions: Any official Skill changes, an official Skill is overridden, or global `decision-grill` is installed.
- BLOCKED conditions: The official-Skills inventory cannot be collected, the global Skill root cannot be inspected, or unrelated concurrent changes invalidate the comparison.
- Pre/post file or Skill environment comparison required: Yes. Required official `.system` Skill manifest/aggregate-hash and global-user-Skill-root comparison.

### VALIDATION-019 / DG-018

- Fixture environment setup: Before starting, confirm both the project-level active environment and the global user Skill environment contain no `grill-me` Skill. Confirm the project-level `decision-grill` Skill is present. Record the two absence checks.
- Exact initial input: `/decision-grill\nStart a bounded decision interview. Goal: decide whether the Aurora pilot launches on 2026-10-01. Ask one material decision question with a recommendation.`
- Ordered subsequent inputs:
  1. `Stop and summarize.`
- Input timing: Send input 1 only after the first material question is shown. Inspect environment state again after the summary.
- Expected behavior: `/decision-grill` operates normally without a `grill-me` installation request, dependency error, or automatic installation.
- Observable evidence: A normal first decision question is produced; the transcript has no `grill-me` dependency/install prompt or error; and both project/global `grill-me` absence checks remain unchanged.
- PASS conditions: The interview starts and responds normally, no installation is requested or performed, and no dependency error occurs.
- FAIL conditions: The Agent requires or installs `grill-me`, reports it as a missing dependency, or cannot operate because it is absent.
- BLOCKED conditions: The pre-test absence checks cannot be performed, the project-level `decision-grill` Skill is missing, or `/decision-grill` cannot start for an unrelated platform error.
- Pre/post file or Skill environment comparison required: Yes. Compare project-level and global `grill-me` absence checks before and after.

### VALIDATION-020 / DG-019

- Fixture environment setup: Start a new Codex Desktop Session with the project-level `decision-grill` Skill available in `<active DG regression folder>`. Capture the active Skill list or observable Skill activity before the session.
- Exact initial input: `/decision-grill\nPlan the entire multi-team transformation.`
- Ordered subsequent inputs: None.
- Input timing: None; inspect the first Agent response and the Skill activity after it.
- Expected behavior: The oversized-goal branch recommends `wayfinder` only and does not automatically start `wayfinder`, `to-spec`, or any other Skill.
- Observable evidence: The first response contains a recommendation to use `wayfinder` but no execution result, handoff, created artifact, or automatic Skill invocation. The before/after active-Skill observation shows no new Skill started.
- PASS conditions: `wayfinder` is recommendation-only, `to-spec` and every other Skill remain uninvoked, and no artifact is created.
- FAIL conditions: `wayfinder`, `to-spec`, or another Skill is automatically started; a handoff/artifact is created; or the response proceeds with an interview question instead of the oversized-goal boundary.
- BLOCKED conditions: Skill activity cannot be observed, `/decision-grill` cannot start, or the session response is unavailable.
- Pre/post file or Skill environment comparison required: Yes. Compare observable active-Skill state before and after.

### VALIDATION-002 / DG-003

- Initial input: `/decision-grill\nStart a decision interview. Goal: decide whether to enable optional SMS incident alerts for the Aurora 100-user pilot. The alert choice is IMPORTANT and non-blocking. The alternatives are enable SMS alerts or leave them disabled. Ask the material decision question.`
- Subsequent input 1, after the SMS-alert IMPORTANT question: `I do not know whether to enable SMS alerts. This is an undecided decision, not an unknown fact. Offer this exact provisional decision: answer = Enable optional SMS incident alerts for the Aurora pilot; reason = incidents need a second notification path while the pilot is small; assumption = at least 20 percent of pilot users will opt in; risk = opt-in may be lower than 20 percent and alerts may not improve response time; validation condition = measure opt-in rate and median incident acknowledgement time for the first 30 days; review trigger = review on 2026-10-31 or after the first 10 incidents, whichever occurs first; owner = Aurora Product Owner; status = PROVISIONAL.`
- Subsequent input 2, after that exact option is presented: `I explicitly accept and use the provisional option exactly as stated.`
- Expected behavior: Record the supplied provisional decision and related question as `PROVISIONAL`.
- PASS: The eight supplied fields are visible without material alteration; no confirmed decision is recorded.
- FAIL: Any supplied field is absent or altered, either record is `CONFIRMED`, or an unrelated question replaces the SMS-alert decision.

### VALIDATION-003 / DG-004

- Initial input: `/decision-grill\nStart a decision interview. Goal: decide the Aurora pilot rollout plan. The optional launch-announcement channel is IMPORTANT, open, and non-blocking. If deferred, no announcement channel is selected for the pilot. Ask that question.`
- Subsequent input 1: `Defer the launch-announcement-channel question. Revisit it on 2026-09-01 after pilot metrics are available.`
- Subsequent input 2, after the record is shown: `Continue the interview.`
- Expected behavior: Record `DEFERRED`, its consequence, and its revisit trigger; do not re-ask it without new information.
- PASS: The record contains `DEFERRED`, the stated consequence, and the stated trigger; the question is not rephrased or re-asked after input 2.
- FAIL: A field is missing, the status is not `DEFERRED`, or the unchanged question is re-asked.

### VALIDATION-004 / DG-005

- Initial input: `/decision-grill\nStart a decision interview. Goal: decide whether the Aurora pilot may launch. Legal approval is required before launch, has not been received, and is an unresolved BLOCKER. Record that blocker before assessing convergence.`
- Subsequent input: `Confirm convergence.`
- Expected behavior: Produce a `NOT_CONVERGED` summary naming legal approval.
- PASS: The unresolved blocker is explicitly named `legal approval` in the summary; its status remains `OPEN` or `BLOCKED`; the summary is `NOT_CONVERGED`; and the Agent does not claim completion or complete shared understanding.
- FAIL: The summary uses `CONVERGED`, omits legal approval, or claims shared understanding is complete.

### VALIDATION-005 / DG-006

- Fixture setup: During authorized DG-006 execution only, create `<active DG regression folder>\fixture-data\release-fact.txt` with exactly `Aurora pilot launch date: 2026-10-01`. For this regression, the active path is `D:\temp\decision-grill-dg-retest-20260729-233153165\fixture-data\release-fact.txt`.
- Initial input: `/decision-grill\nFor the Aurora pilot decision, what launch date is recorded in the current environment? Use the current environment rather than asking me for the date.`
- Subsequent inputs: None.
- Expected behavior: Locate the fixture and use its date.
- PASS: The response identifies `2026-10-01` and cites an environment lookup or the fixture path without asking the user for the date.
- FAIL: The Agent asks for the date, gives a different date, or starts external research before checking the fixture.

### VALIDATION-006 / DG-007

- Fixture setup: Verify no current-environment source answers the stated cross-jurisdiction question.
- Initial input: `/decision-grill\nFor an Aurora release decision, determine the current compliance requirement by reconciling the rules of the Taiwan, Singapore, and Japan regulators. This requires cross-source legal research and no source is available in the current environment. How should this fact be handled in this single session?`
- Subsequent inputs: None.
- Expected behavior: Mark the fact `RESEARCH_REQUIRED`, do not present it as confirmed, and do not start research.
- PASS: `RESEARCH_REQUIRED` is explicit, the related decision is `BLOCKED`, `PROVISIONAL`, or `DEFERRED`, and no external research workflow starts.
- FAIL: A compliance result is claimed confirmed, research starts automatically, or the research requirement is absent.

### VALIDATION-007 / DG-008

- Initial input: `/decision-grill\nStart a decision interview. Goal: choose the Aurora pilot rollout method. The initial decision is full rollout or staged rollout. The support-capacity plan depends on that choice: full rollout requires two support agents on launch day, while staged rollout requires one. Ask the rollout question.`
- Subsequent input 1: `Choose the full rollout.`
- Subsequent input 2, after the answer and dependency are recorded: `I am reversing that earlier decision. Use a staged rollout instead because support capacity is limited.`
- Expected behavior: Mark the full-rollout entry `SUPERSEDED`, record staged rollout, and re-evaluate support capacity.
- PASS: The original entry is `SUPERSEDED`; the replacement answer and rationale are recorded; dependency re-evaluation is explicit.
- FAIL: The original answer remains active silently, the replacement is absent, or no dependency is re-evaluated.

### VALIDATION-008 / DG-009

- Initial input: `/decision-grill\nStart a decision interview. Goal: select a hosting vendor. Vendor selection requires knowing the compliance certification, while the certification choice depends on the vendor's supported controls. The two unresolved decisions depend on each other. Identify and handle the dependency structure.`
- Subsequent input, if either decision is asked: `That answer depends on the other unresolved decision exactly as described; neither can be answered independently.`
- Expected behavior: Name the cycle, stop repeated questioning, identify an upstream prerequisite, and mark an affected item `BLOCKED`.
- PASS: The cycle and an upstream prerequisite are explicit; no repeated rephrased-question loop occurs.
- FAIL: The Agent repeats the cycle questions, fails to name the cycle, or fails to name an upstream prerequisite.

### VALIDATION-009 / DG-010

- Initial input: `/decision-grill\nStart a decision interview and show the summary only. Goal: choose the Aurora pilot rollout method. Stakeholders: Aurora Product Owner and Support Lead. Scope: 100-user pilot; general launch is out of scope. Confirmed decision: staged rollout of 25 users on 2026-10-01 and 25 more weekly after Support Lead approval. Constraint: one support agent maximum. Dependencies: Product Owner freezes the invite list by 2026-09-15; Support Lead publishes the on-call rota by 2026-09-25; rollout starts only after both. Alternatives: full rollout exceeds the one-agent constraint; staged rollout does not. Risk R-001: activation failure; mitigation: 10-user dry run on 2026-09-29 and rollback on failure. Risk R-002: support overload; mitigation: pause the next cohort after more than five tickets in 24 hours. Assumption A-001: the invite list contains 100 eligible users; validation: Product Owner reconciliation by 2026-09-15. Unknowns: none. Deferred items: none. No blockers, contradictions, or dependency cycles exist. Success criteria: 95 percent activation and fewer than five tickets per 24 hours. Next action: Product Owner publishes the staged-pilot plan after the summary. Do not treat this input as user confirmation.`
- Subsequent input, only after the complete summary: `Continue the interview.`
- Expected behavior: Produce the complete summary before continuation. After plain `Continue the interview.`, retain the summary as the ledger baseline, create no goal or coverage question for a supplied area, and explicitly request confirmation as the sole missing condition.
- PASS: Before the subsequent input, a summary is produced and the interview does not continue. After it, no supplied area is made into an `OPEN` coverage question, no generic goal confirmation appears, and one explicit confirmation request is made.
- FAIL: The interview continues before the summary, a duplicate goal or coverage question appears, a supplied fact is treated as a gap, or a proceed action substitutes for confirmation.

### VALIDATION-010 / DG-013

- Initial input: `/decision-grill\nStart a decision interview and produce the required summary. This is the complete session record. Goal: choose the Aurora pilot rollout method. Stakeholders: Aurora Product Owner and Support Lead. Scope: 100-user pilot only. The decision goal and scope are confirmed. Out of scope: general launch, new product features, and regional expansion. Constraint: the pilot starts 2026-10-01 and may use no more than one support agent at a time. Alternatives considered: full rollout and staged rollout. Confirmed IMPORTANT decision D-001: use staged rollout of 25 users on 2026-10-01 and add 25 users weekly only after Support Lead approval. BLOCKER items: none. DEFERABLE items: none. Deferred items: none. Unknowns: none. Assumption A-001: the invite list contains 100 eligible users; why needed: staged cohorts require 100 eligible users; confidence: HIGH; impact if false: pilot cohort schedule slips; validation: Product Owner reconciles the invite list by 2026-09-15; status: VALIDATED. Dependencies: Product Owner freezes the invite list by 2026-09-15; Support Lead publishes the on-call rota by 2026-09-25; both are complete, and D-001 has no other dependency. There is no contradiction and no dependency cycle. Risk R-001: activation failure; mitigation: run a 10-user dry run on 2026-09-29 and roll back to the prior release on failure. Risk R-002: support overload; mitigation: pause the next cohort if more than five tickets occur in 24 hours. Success criteria: at least 95 percent successful activation and fewer than five tickets per 24 hours. Coverage evidence: goal, actors, scope, constraints, dependencies, alternatives, risks, success criteria, assumptions and unknowns, out-of-scope boundaries, and next action are all explicitly supplied in this input. Next action: Product Owner publishes the staged-pilot plan after convergence. The objective convergence conditions are satisfied in order: (1) the decision goal and scope are confirmed; (2) no unresolved BLOCKER exists; (3) all IMPORTANT and DEFERABLE items have valid statuses; (4) every UNKNOWN has a valid status or none exists; (5) no material contradiction or dependency cycle remains; (6) all eleven coverage areas have no material gap; and (7) after the requested complete fixed eight-section summary is produced, condition seven is satisfied. At that point, explicit user confirmation is the only missing convergence condition. Do not treat this input as explicit user confirmation.`
- Subsequent input, after the Agent produces a complete eight-section `NOT_CONVERGED` summary whose only listed pending condition is user confirmation: `I confirm convergence.`
- Expected behavior: Before the subsequent input, the Agent keeps the result `NOT_CONVERGED` solely because confirmation is absent. Only after that explicit confirmation, the Agent regenerates or updates the complete eight-section summary to `CONVERGED` with user confirmation status `confirmed`.
- PASS: The pre-confirmation summary has no unresolved BLOCKER, material coverage gap, contradiction, or dependency cycle and lists confirmation as the only pending item. The post-confirmation summary contains all eight sections, retains D-001, A-001, R-001, and R-002, says `CONVERGED`, and says user confirmation is `confirmed`.
- FAIL: `CONVERGED` appears before `I confirm convergence.`; any of the stated objective conditions is reported unresolved; any required summary section is missing; or the post-confirmation summary lacks confirmed user status.

### VALIDATION-011 / DG-020

- Initial input: `/decision-grill\nStart a decision interview and produce the required summary. This is the complete session record. Goal: choose the Aurora pilot rollout method. Stakeholders: Aurora Product Owner and Support Lead. Scope: 100-user pilot only. The decision goal and scope are confirmed. Out of scope: general launch, new product features, and regional expansion. Constraint: the pilot starts 2026-10-01 and may use no more than one support agent at a time. Alternatives considered: full rollout and staged rollout. Confirmed IMPORTANT decision D-001: use staged rollout of 25 users on 2026-10-01 and add 25 users weekly only after Support Lead approval. BLOCKER items: none. DEFERABLE items: none. Deferred items: none. Unknowns: none. Assumption A-001: the invite list contains 100 eligible users; why needed: staged cohorts require 100 eligible users; confidence: HIGH; impact if false: pilot cohort schedule slips; validation: Product Owner reconciles the invite list by 2026-09-15; status: VALIDATED. Dependencies: Product Owner freezes the invite list by 2026-09-15; Support Lead publishes the on-call rota by 2026-09-25; both are complete, and D-001 has no other dependency. There is no contradiction and no dependency cycle. Risk R-001: activation failure; mitigation: run a 10-user dry run on 2026-09-29 and roll back to the prior release on failure. Risk R-002: support overload; mitigation: pause the next cohort if more than five tickets occur in 24 hours. Success criteria: at least 95 percent successful activation and fewer than five tickets per 24 hours. Coverage evidence: goal, actors, scope, constraints, dependencies, alternatives, risks, success criteria, assumptions and unknowns, out-of-scope boundaries, and next action are all explicitly supplied in this input. Next action: Product Owner publishes the staged-pilot plan after convergence. The objective convergence conditions are satisfied in order: (1) the decision goal and scope are confirmed; (2) no unresolved BLOCKER exists; (3) all IMPORTANT and DEFERABLE items have valid statuses; (4) every UNKNOWN has a valid status or none exists; (5) no material contradiction or dependency cycle remains; (6) all eleven coverage areas have no material gap; and (7) after the requested complete fixed eight-section summary is produced, condition seven is satisfied. At that point, explicit user confirmation is the only missing convergence condition. Do not treat this input as explicit user confirmation.`
- Subsequent input, after the Agent produces a complete eight-section `NOT_CONVERGED` summary whose only listed pending condition is user confirmation: `Continue without explicitly confirming.`
- Expected behavior: The Agent identifies explicit user confirmation as the only pending convergence condition, asks for that confirmation, and retains `NOT_CONVERGED` without creating a new question, blocker, or coverage gap; it must not use a proceed action as the confirmation substitute.
- PASS: Both the first summary and the response to the subsequent input say `NOT_CONVERGED`; both show no unresolved BLOCKER, material coverage gap, contradiction, or dependency cycle; the second response asks for explicit confirmation as the sole next condition.
- FAIL: The Agent marks the session `CONVERGED`, omits the confirmation request, introduces an unstated objective gap, or asks a new decision question.

## Checkpoint extension acceptance cases

The checkpoint extension adds DG-021 through DG-039. Their catalog fixtures declare every primary Question ID, decision-item identity, exact accepted answer, send condition, and expected lifecycle event. DG-021/DG-022 verify the fifth-answer offer and continue path; DG-023/DG-024/DG-025 verify the seventh-answer hard-cap branches; DG-026/DG-027/DG-028 verify material revisions and non-material clarification; DG-029 through DG-033 cover material-risk, document, and environment triggers; DG-034 verifies suppression and escalation; DG-035 verifies non-counted statuses; DG-036/DG-037 verify captured and canonical checkpoint resumes; DG-038 verifies refusal at offer and resume; DG-039 verifies revision lineage persists across resume.

Every checkpoint case requires: no filesystem mutation, no automatic Skill invocation, accepted-result evidence before counter-sensitive behavior, a non-primary Checkpoint control with recommendation and two choices, and no new primary-question block in the same response. Checkpoint summaries must be eight-section `NOT_CONVERGED` summaries and section 8 must contain `Recommended next action`, `Next question ID`, and `Resume point`.
