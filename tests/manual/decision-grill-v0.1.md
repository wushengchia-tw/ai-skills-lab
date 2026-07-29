# Decision-Grill v0.1 Manual Acceptance Tests

All test cases are derived from SPEC-001 acceptance criteria. Execute manually only after implementation review authorizes testing. Every case remains NOT_RUN in this document.

## DG-001 — Normal answerable decision

- Related acceptance criterion: 1
- Scenario: **Given** a normal answerable decision, **when** the session begins, **then** one primary question with a recommendation is asked and the confirmed answer is recorded.
- Preconditions: A bounded decision goal is available.
- User input: “Should we launch to all customers now?” followed by an answer to the first question.
- Expected Agent behavior: Ask one primary question with a recommendation and record the confirmed answer.
- Expected ledger or decision state: One `ANSWERED` question; decision state confirmed.
- Expected convergence status: NOT_CONVERGED unless all conditions later hold.
- Pass criteria: No independent second question appears before the answer is processed.
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
- User input: “Use the provisional option.”
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
- Expected ledger or decision state: BLOCKER remains `OPEN` or `BLOCKED`.
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
- Expected ledger or decision state: Related question is `BLOCKED`, `PROVISIONAL`, or `DEFERRED` as appropriate.
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
- Expected ledger or decision state: Original question `SUPERSEDED`; replacement answer recorded.
- Expected convergence status: Re-evaluated after dependent questions update.
- Pass criteria: The Agent does not silently retain the overturned answer.
- Actual result: NOT_RUN
- Status: NOT_RUN

## DG-009 — Cyclic dependency

- Related acceptance criterion: 9
- Scenario: **Given** cyclic dependencies appear, **when** detected, **then** the Agent identifies the cycle and upstream prerequisite instead of repeating questions.
- Preconditions: Two unresolved questions depend on each other.
- User input: Answers that reveal the cycle.
- Expected Agent behavior: Identify the cycle and the upstream prerequisite.
- Expected ledger or decision state: Affected question is `BLOCKED`; no repeated rephrased questioning.
- Expected convergence status: NOT_CONVERGED until the cycle is handled.
- Pass criteria: The Agent explicitly explains the cycle.
- Actual result: NOT_RUN
- Status: NOT_RUN

## DG-010 — No material coverage gap

- Related acceptance criterion: 10
- Scenario: **Given** coverage has no material gap, **when** scanning that area, **then** the Agent does not manufacture a question.
- Preconditions: A coverage area is already clearly supported.
- User input: Continue the interview.
- Expected Agent behavior: Do not manufacture a question for that area.
- Expected ledger or decision state: Area covered or `NOT_APPLICABLE`; no unnecessary `OPEN` question.
- Expected convergence status: Unchanged.
- Pass criteria: Coverage scanning remains gap-driven rather than questionnaire-driven.
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
- Preconditions: One or more convergence conditions remain unmet.
- User input: “Stop and summarize.”
- Expected Agent behavior: Stop questions and produce the full summary.
- Expected ledger or decision state: Open or blocked items remain recorded.
- Expected convergence status: NOT_CONVERGED.
- Pass criteria: The summary does not claim completion.
- Actual result: NOT_RUN
- Status: NOT_RUN

## DG-013 — Normal converged completion

- Related acceptance criterion: 13
- Scenario: **Given** all convergence conditions are met, **when** the user confirms, **then** all eight summary sections are produced with `CONVERGED`.
- Preconditions: The first seven objective convergence conditions are satisfied.
- User input: “I confirm convergence.”
- Expected Agent behavior: Produce all eight summary sections.
- Expected ledger or decision state: All required classifications are resolved, recorded, provisional, or deferred.
- Expected convergence status: CONVERGED.
- Pass criteria: Summary includes explicit user confirmation and every required section.
- Actual result: NOT_RUN
- Status: NOT_RUN

## DG-014 — Unconverged summary structure

- Related acceptance criterion: 14
- Scenario: **Given** convergence conditions are not met, **when** a summary is produced, **then** it includes all eight sections and `NOT_CONVERGED`.
- Preconditions: At least one convergence condition is unmet.
- User input: “Show the summary.”
- Expected Agent behavior: Produce all eight sections with `None` for empty sections.
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
