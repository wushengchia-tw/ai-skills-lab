# Decision-Grill

## What it does

`decision-grill` is an independent, stateless, single-session, general-mode decision interview. It finds material decisions and gaps, classifies questions, handles unknowns safely, records session-local provisional decisions and assumptions, and ends with a fixed conversation-only summary.

## When to use it

Use `/decision-grill` before acting on a plan, product direction, business choice, operating decision, course design, or other bounded decision that needs sharper shared understanding within one conversation.

## Goal Lock

Decision-Grill evaluates Goal Lock by evidence, not by a magic confirmation phrase. Its priority is: refuse implementation requests; stop oversized, multiple, or unbounded goals with a `wayfinder` recommendation; clarify an absent, ambiguous, or not directly authorized goal; otherwise proceed with a directly authorized bounded goal. A goal is locked when it is explicit, single, achievable in one session, and bounded, and the user directly asks it to raise a material decision question, record a known blocker, or produce a decision summary. It then performs that requested behavior immediately instead of asking the user to confirm the same goal again.

For example, “Decide whether to use a staged launch; record the known legal blocker” is sufficient. “Help me with the launch” needs clarification because the goal is ambiguous. “Plan every workstream for the company transformation” is too broad, so Decision-Grill recommends `wayfinder` and stops that interview (or produces only a `NOT_CONVERGED` summary if one is requested). A request to implement, edit, create, modify, run, or execute work is refused before any other Goal Lock behavior.

## When not to use it

Do not use it to implement a plan, edit or create project content, maintain terminology or ADRs, perform deep external research, or plan a multi-session effort. It refuses implementation requests at every stage and does not ask for a plan, project path, or files in order to implement. Use `wayfinder` when the decision goal is too large for one session. The Skill stops that interview immediately after recommending `wayfinder`; it does not continue with a charter or another decision question. Use the appropriate documentation or specification Skill only after the interview identifies that as a next action.

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

`decision-grill` does not replace or automatically invoke `wayfinder`. When a goal cannot reasonably converge in one session, it recommends `wayfinder` as the appropriate cross-session decision-map workflow and does not continue the interview. If the user requests a summary, it produces the complete fixed `NOT_CONVERGED` summary; otherwise, it waits for a new bounded goal or a user-directed next action. It does not create a Question Ledger item, a new interview question, a charter request, or a Coverage Scan; a later new bounded goal may begin a new interview.

## Question classifications

Every material question has one classification:

Only one independent primary question may be `OPEN` at a time. `OPEN` means the user can directly decide it now; it is never a placeholder for an unavailable approval, dependency, cycle, or missing fact. After the user answers or accepts, Decision-Grill first shows a ledger event identifying the question, `ANSWERED` or accepted lifecycle, decision result, and resulting status before it considers another independent question.

- **BLOCKER** — the current decision cannot be safely completed while unresolved.
- **IMPORTANT** — it should be resolved, made provisional, or explicitly deferred.
- **DEFERABLE** — it can be recorded and delayed without blocking current convergence.

Only material decisions, risks, contradictions, or coverage gaps become questions. The Skill does not ask questions just to complete a checklist.

## Unknown and provisional-decision handling

When the user says they do not know or are uncertain, the Skill first states whether the missing item is an unknown fact or an undecided decision. If that is ambiguous, it asks one narrow classification question before asking any new decision topic. It finds available facts from the environment itself; unavailable facts are marked `UNKNOWN` or `RESEARCH_REQUIRED` as a fact/work status, not as a decision state. A research-required record visibly labels the fact/work status, affected decision, and paired decision state together; the affected-decision field preserves the decision identity and does not introduce the unavailable fact's domain, requirement, source, or research topic as a qualifier. The affected decision is also recorded: it is `BLOCKED` when the fact prevents safe progress, or it may become `PROVISIONAL` or `DEFERRED` only if the user explicitly chooses that outcome. An undecided decision remains unresolved and is offered provisional, defer, explanation, or stop options. When a user accepts a recommended answer or result, the Skill records that question's formal acceptance ledger event—question ID, accepted result, and resulting `ANSWERED` (or equivalent accepted) state—before any next question, coverage work, summary, or session end.

A provisional decision records its answer, reason, assumption, risk, validation condition, review trigger, owner, and status. When the user accepts, selects, or says to use a provisional option, the response records the complete decision with `Status: PROVISIONAL` before another question; it does not leave that status conditional. Unknown does not become a confirmed decision automatically: the user chooses whether to accept a provisional answer, defer it, or stop.

## Minimum coverage framework

The interview scans for material gaps across: Goal; Actors and stakeholders; Scope; Constraints; Dependencies; Alternatives and trade-offs; Failure modes and risks; Success and acceptance criteria; Unknowns and assumptions; Out-of-scope boundaries; and Next action.

This is a coverage check, not a fixed questionnaire. Areas already supported by the conversation or environment are not asked again, and irrelevant areas may be `NOT_APPLICABLE`.

## Convergence conditions

The session can converge only when all BLOCKER items are resolved; IMPORTANT items are confirmed, provisional, or deferred; DEFERABLE items are recorded; each unknown has a status, owner, or next step; no material conflict or cycle remains; coverage is complete; the summary is shown; and the user explicitly confirms. A `BLOCKED` item names its blocker and affected decision. On a cycle, all affected decisions are first recorded `BLOCKED`; naming a possible upstream rule does not resolve it. When an answer is superseded, a visible formal `Lifecycle: SUPERSEDED` record identifies the previous and revised decisions before each dependent is re-evaluated and stale confirmed states are removed or replaced.

The user's confirmation does not override unresolved objective conditions. An early stop produces a `NOT_CONVERGED` summary.

## After a complete summary

A complete summary becomes the current ledger baseline; it does not mean the interview has converged. On the next message, Decision-Grill first reopens only the affected ledger scope if the user actually changes a goal, scope, decision, assumption, or risk. Otherwise it asks only the highest-priority unresolved ledger gap. If no material gap remains and explicit confirmation is the only missing condition, it stays `NOT_CONVERGED`, states `Explicit confirmation is the sole remaining condition.`, and clearly asks the user to confirm. It does not reopen a generic goal check or coverage scan, and it does not use “proceed”, “continue with the plan”, or “looks good” as a confirmation substitute.

Only an explicit user confirmation while all objective conditions still hold changes the status to `CONVERGED`. A plain “Continue the interview.” is not a modification: it continues the existing material gap, or requests explicit confirmation when that is the sole missing condition.

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

## Checkpoints and resuming

After the fifth genuinely new answered primary decision in one interview interval, Decision-Grill pauses before the next primary question and offers a checkpoint or continuation. Continuing is not confirmation and keeps the same interval count. After the seventh genuinely new answered primary decision, it never asks an eighth primary question: it either requests the existing explicit convergence confirmation or emits a `NOT_CONVERGED` checkpoint summary and closes.

It can offer the same pause earlier when a material decision creates a consequential financial, governance, legal, guarantee, repurchase, indemnity, contractual, external-document, environment-change, or repeated-revision risk. It does not repeat the same early reason without material escalation.

The eighth summary section always contains one `Recommended next action`, `Next question ID`, and `Resume point`. The next ID already exists or is explicitly reserved in the ledger; it is never generated by adding one to another ID. On resume, confirmed answers become the new baseline and are not counted again. A reopened old answer or a revision does not consume a new-question slot; a genuinely new decision item does.

When a decision has changed materially, its current summary section retains its lineage: decision item ID, current Question ID, all Question IDs in lineage, revision count, replacement relation, last superseded event, and current effective decision. This lets a later resume recognise a second revision even when it uses a replacement Question ID.

## User controls

At any point, you can accept a recommendation, choose or modify an alternative, say unknown or uncertain, defer, request an explanation, reject a premise, mark an item out of scope, view the current summary, view remaining BLOCKER items or coverage gaps, reopen a decision, stop with an unconverged summary, or confirm convergence.

## Limitations

`decision-grill` is limited to one conversation and general mode. It does not create or modify files, maintain glossary or ADR records, perform external deep research, install itself, chain to other Skills automatically, or implement your plan. It refuses implementation, edit, create, modify, run, and execute requests at every stage; it does not ask for plans, paths, or files to enable implementation. It does not replace or modify any official Skill.

## Example session

The user asks whether a training program should launch to every customer at once. The Skill locks the goal to deciding the launch scope, checks stakeholders and constraints, then asks one BLOCKER question about whether support capacity is known. If the answer is unknown, it looks for available capacity data; if data is unavailable, it offers a provisional limited rollout, explains the risk, and records the validation trigger. Once all material questions are resolved, provisional, or deferred, it presents the eight-section summary and asks the user to confirm convergence.

## Installation note

`decision-grill` is installed independently when the user chooses to install it. It does not require `grill-me`, does not install itself, and does not install, update, or modify any other Skill.
