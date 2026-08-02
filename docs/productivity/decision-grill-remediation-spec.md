# Decision-Grill Remediation Specification

## Status and scope

- Status: Batches A through C are preserved. Batch D generic conditional-input `SKIP` semantics are implemented under second-round Product Owner authorization.
- Baseline: DG initial acceptance results are 7 PASS, 3 FAIL, and 10 BLOCKED (20 total).
- This document does not authorize implementation, test execution, installation, commits, pushes, or PR changes.
- The DG isolation environment remains `D:\temp\decision-grill-dg-test-20260729-220847`.

## Product corrections

### Batch B — State recording and ledger events

**Reason.** Batch A established Goal Lock precedence and the PRODUCT-001 through PRODUCT-003 boundaries, but did not make decision-state meanings, research pairing, accepted-result event order, cycle blocking, or supersession re-assessment sufficiently observable.

**State contract.** `OPEN` is only an active decision the user can answer now. External approvals, unavailable facts, dependencies, and cycles are `BLOCKED` decisions with a named blocker and affected item. `RESEARCH_REQUIRED` records fact/work status and is paired with the affected decision state; a safety-blocking missing fact requires `BLOCKED`. `PROVISIONAL` and `DEFERRED` require explicit user choice. An accepted answer creates a visible ledger event with question, accepted/`ANSWERED` lifecycle, result, and resulting state before any next independent question. A cycle blocks affected items before an upstream rule is proposed. A supersession re-evaluates dependent states and removes stale confirmation.

| Observable behavior | Primary fixture | Regression risk |
| --- | --- | --- |
| Accepted result event precedes the next independent question | DG-001 | A bare confirmation word or `Q-002` can appear before a durable record. |
| External approval is a blocked decision | DG-005 | Treating unavailable approval as user-answerable `OPEN`. |
| Research status is paired with a decision state | DG-007 | Treating `RESEARCH_REQUIRED` as a decision state or solved result. |
| Supersession re-assesses dependents | DG-008 | Retaining a stale dependent confirmed state after its premise changes. |
| Cycle blocks affected items | DG-009 | Treating an upstream proposal as automatic cycle resolution or auto-deferring it. |

**Regression boundary.** Batch B adds no conditional `SKIP`. Batch C adds only the shared post-summary state machine below; assertions stay data-driven and no DG-specific product branch is added to the Skill or runner.

### Batch C — Post-summary sequencing

**State machine.** A complete summary establishes the current ledger baseline and remains `NOT_CONVERGED` unless all objective conditions plus explicit user confirmation hold. After that summary, the common branch order is: (1) actual user modification/reopening reopens only affected ledger scope; (2) an existing material gap continues with the highest-priority unresolved ledger item; (3) confirmation-only retains `NOT_CONVERGED` and makes one explicit confirmation request; (4) explicit confirmation plus still-valid objective conditions produces `CONVERGED`; (5) an incomplete summary resumes only existing missing coverage. Plain `Continue the interview.` is not a modification.

| Observable behavior | Primary fixture | Regression risk |
| --- | --- | --- |
| Summary baseline prevents duplicate Goal Lock or coverage scan | DG-010 | Re-asking a supplied goal or coverage area after `Continue the interview.` |
| Confirmation-only is still `NOT_CONVERGED` | DG-020 | Inventing a new gap or substituting a proceed action for confirmation. |
| Explicit confirmation is the final transition only | DG-013 | `CONVERGED` before explicit confirmation or after a changed decision. |
| Reopening is scoped to the changed ledger item | Post-summary matrix | Re-running the entire interview for one changed item. |

### PRODUCT-004 — Startup Goal Lock evidence

**Requirement.** Scope Lock uses one shared evidence rule and this precedence order: (1) implementation request refusal, (2) terminal oversized, multiple, or unbounded goal with a `wayfinder` recommendation, (3) clarification or confirmation for an absent, ambiguous, or not directly authorized goal, and (4) direct requested Decision-Grill behavior for an explicit, single, achievable bounded goal with direct authorization. A direct request to ask a material decision question, record a known blocker, or produce a decision summary is sufficient authorization; no fixed phrase or repeated goal-confirmation turn is allowed.

**Affected matrix.** DG-003, DG-004, DG-005, DG-008, and DG-012 rely on the shared rule without fixture rewrites. DG-012 additionally verifies that a legal-approval BLOCKER can be established at startup and is not intercepted by generic goal confirmation.

**Preservation.** PRODUCT-002 remains the terminal boundary for oversized goals, and PRODUCT-003 remains the absolute refusal boundary for implementation requests.

### PRODUCT-001 — Unknown Handling classification

**Requirement.** When a user answers with `I don't know`, `unknown`, `uncertain`, or equivalent wording, the Skill must first make the missing-item type explicit:

1. Determine and state whether the unknown is an **unknown fact** or an **undecided decision**.
2. If the wording alone is ambiguous, ask one narrow classification question (for example: “Do you mean the relevant fact is unavailable, or that you have not chosen an option?”). Do not ask for a new decision topic first.
3. For an unknown fact, search the current environment when applicable; otherwise record `UNKNOWN` or `RESEARCH_REQUIRED` as appropriate.
4. For an undecided decision, retain the question as unresolved and offer the safe decision options: provisional decision, defer, explanation, or stop.
5. Do not record a confirmed decision unless the user explicitly accepts or chooses one.

**Minimum change.** Add an explicit, user-visible ambiguity branch to the Answer and Unknown Handling instructions and align the safeguards wording.

**Regression focus.** DG-002, DG-003, DG-006, and DG-007. Risk: an overly broad clarification rule could create an unnecessary extra turn where fact-versus-decision is already explicit.

### PRODUCT-002 — Scope Lock terminal boundary

**Requirement.** Once Scope Lock determines that the stated goal cannot reasonably converge in one session, the Skill must:

1. State that the goal exceeds the single-session boundary.
2. Recommend `wayfinder` without invoking it.
3. Stop the Decision-Grill interview immediately for that request.
4. Not create a new Question Ledger item, ask for a transformation charter, ask a follow-up decision question, or enter Coverage Scan.
5. If a summary is requested, produce a `NOT_CONVERGED` summary only; otherwise wait for a new bounded goal or a user-directed next action.

**Minimum change.** Make the oversized-goal branch an explicit terminal return in Scope Lock and add a matching prohibition in Safeguards.

**Regression focus.** DG-011, DG-012, DG-014, and DG-019. Risk: a terminal branch must not prevent the user from later voluntarily supplying a new, bounded goal.

### PRODUCT-003 — Absolute no-implementation boundary

**Requirement.** A request to implement, edit, create, modify, run, or otherwise execute a plan must be refused at every lifecycle stage, including after convergence. The response must:

1. State that Decision-Grill only clarifies decisions, assumptions, risks, and convergence.
2. Decline implementation rather than conditionally offering to implement after receiving a plan, project path, or files.
3. Not ask the user to provide a plan for implementation purposes.
4. Offer only in-boundary alternatives: continue or start a decision interview, show/stop with a summary, or let the user choose a later recommended next action outside this Skill.
5. Make no code, file, project, Skill, or tool changes.

**Minimum change.** Replace the permissive “Do not begin implementation before the session has converged” wording with an absolute prohibition, and add an explicit implementation-request response rule.

**Regression focus.** DG-016, DG-015, DG-017, and DG-019. Risk: refusal text must not accidentally invoke another Skill or begin implementation through a tool call.

## Executable manual fixtures

All fixtures below run in a new Codex Desktop Session in the retained DG isolation environment. Every Initial input starts with the explicit `/decision-grill` invocation. The evaluator sends each subsequent input only after the stated observable prerequisite is visible. The fixture text is proposed for addition to the corresponding manual test case; it is not an instruction to run a test now.

### VALIDATION-002 / DG-003 — Provisional decision

- **Initial input:** `/decision-grill\nStart a decision interview. Goal: decide whether to enable optional SMS incident alerts for the Aurora 100-user pilot. The alert choice is IMPORTANT and non-blocking. The available decision alternatives are enable SMS alerts or leave them disabled. Ask the material decision question.`
- **Necessary subsequent inputs:** After the Agent presents the SMS-alert IMPORTANT question, send: `I do not know whether to enable SMS alerts. This is an undecided decision, not an unknown fact. Offer this exact provisional decision: answer = Enable optional SMS incident alerts for the Aurora pilot; reason = incidents need a second notification path while the pilot is small; assumption = at least 20 percent of pilot users will opt in; risk = opt-in may be lower than 20 percent and alerts may not improve response time; validation condition = measure opt-in rate and median incident acknowledgement time for the first 30 days; review trigger = review on 2026-10-31 or after the first 10 incidents, whichever occurs first; owner = Aurora Product Owner; status = PROVISIONAL.` After the exact provisional option is presented, send: `Use the provisional option exactly as stated.`
- **Expected behavior:** The Agent keeps the question unresolved until the provisional option is accepted, then records a provisional decision with answer, reason, assumption, risk, validation condition, review trigger, owner, and status `PROVISIONAL`.
- **PASS conditions:** The record contains exactly the supplied answer, reason, assumption, risk, validation condition, review trigger, owner, and `PROVISIONAL` status; the related question is `PROVISIONAL`; no confirmed decision is created.
- **FAIL conditions:** Any one of the eight supplied fields is absent or materially altered; either record is `CONFIRMED`; or an unrelated question replaces the SMS-alert decision.

### VALIDATION-003 / DG-004 — Deferred IMPORTANT question

- **Initial input:** `/decision-grill\nStart a decision interview. Goal: decide the Aurora pilot rollout plan. The choice of optional launch announcement channel is IMPORTANT, open, and non-blocking. Its consequence if deferred is that no announcement channel is selected for the pilot. Ask that question.`
- **Necessary subsequent inputs:** `Defer the launch-announcement-channel question. Revisit it on 2026-09-01 after pilot metrics are available.` Then, after the record is shown, send `Continue the interview.`
- **Expected behavior:** The Agent records the question as `DEFERRED`, including the supplied consequence and revisit trigger, and does not ask the same question again without new information.
- **PASS conditions:** `DEFERRED`, consequence, and revisit trigger are recorded; the deferred question is not rephrased or re-asked after `Continue the interview.`
- **FAIL conditions:** Missing consequence or revisit trigger; any status other than `DEFERRED`; or the Agent re-asks the unchanged deferred question.

### VALIDATION-004 / DG-005 — Unresolved BLOCKER

- **Initial input:** `/decision-grill\nStart a decision interview. Goal: decide whether the Aurora pilot may launch. Legal approval is required before launch, has not been received, and is an unresolved BLOCKER. Record that blocker before assessing convergence.`
- **Necessary subsequent inputs:** `Confirm convergence.`
- **Expected behavior:** The Agent produces a `NOT_CONVERGED` summary that explicitly names the unresolved legal-approval blocker.
- **PASS conditions:** Legal approval is visibly `BLOCKED`, with its blocker and affected launch decision recorded; the summary says `NOT_CONVERGED`; no claim of complete shared understanding appears.
- **FAIL conditions:** `CONVERGED` is used; the blocker is omitted or unnamed; or the Agent claims completion.

### VALIDATION-005 / DG-006 — Discoverable environment fact

- **Fixture environment setup:** Before the new Session, create only `<active DG regression folder>\fixture-data\release-fact.txt` containing exactly `Aurora pilot launch date: 2026-10-01`. For this regression, the active path is `D:\temp\decision-grill-dg-retest-20260729-233153165\fixture-data\release-fact.txt`.
- **Initial input:** `/decision-grill\nFor the Aurora pilot decision, what launch date is recorded in the current environment? Use the current environment rather than asking me for the date.`
- **Necessary subsequent inputs:** None.
- **Expected behavior:** The Agent locates and uses the file fact rather than asking the user to supply it.
- **PASS conditions:** The response identifies `2026-10-01` and cites the current-environment lookup or the fixture path; no user prompt requests the date.
- **FAIL conditions:** The Agent asks the user for the date, fabricates a different date, or starts external research before checking the fixture.

### VALIDATION-006 / DG-007 — Research-required fact

- **Fixture environment setup:** Verify that the DG isolation environment contains no source answering the stated question and that no external research is launched.
- **Initial input:** `/decision-grill\nFor an Aurora release decision, determine the current compliance requirement by reconciling the rules of the Taiwan, Singapore, and Japan regulators. This requires cross-source legal research and no source is available in the current environment. How should this fact be handled in this single session?`
- **Necessary subsequent inputs:** None.
- **Expected behavior:** The Agent marks the fact `RESEARCH_REQUIRED`, does not call it confirmed, explains the impact on the related decision, and does not launch external research.
- **PASS conditions:** `RESEARCH_REQUIRED` is explicit on the fact/work record; the fact is not presented as confirmed; the affected decision state is also explicit and is `BLOCKED` when the unavailable fact prevents safe progress; no external research workflow starts.
- **FAIL conditions:** The Agent claims a compliance answer as confirmed, begins research automatically, or fails to record the research requirement.

### VALIDATION-007 / DG-008 — Superseded decision

- **Initial input:** `/decision-grill\nStart a decision interview. Goal: choose the Aurora pilot rollout method. The initial decision is whether to use a full rollout or a staged rollout. The support-capacity plan depends on that choice: a full rollout requires two support agents on launch day, while staged rollout requires one. Ask the rollout question.`
- **Necessary subsequent inputs:** Accept the first rollout recommendation with `Choose the full rollout.` After the Agent records it and recognizes the support-capacity dependency, send `I am reversing that earlier decision. Use a staged rollout instead because support capacity is limited.`
- **Expected behavior:** The original rollout decision is marked `SUPERSEDED`, the staged-rollout answer is recorded, and the support-capacity dependency is re-evaluated.
- **PASS conditions:** The original entry is visibly `SUPERSEDED`; replacement answer and rationale are recorded; dependency re-evaluation is explicit; no stale confirmed support-capacity state remains.
- **FAIL conditions:** The original answer remains active silently, the new answer is not recorded, or dependencies are not re-evaluated.

### VALIDATION-008 / DG-009 — Cyclic dependency

- **Initial input:** `/decision-grill\nStart a decision interview. Goal: select a hosting vendor. There are two unresolved decisions: vendor selection requires knowing which compliance certification is required, and the certification choice depends on the vendor's supported controls. These two questions depend on each other. Identify and handle the dependency structure.`
- **Necessary subsequent inputs:** If the Agent asks either decision first, answer: `That answer depends on the other unresolved decision exactly as described; neither can be answered independently.`
- **Expected behavior:** The Agent first marks the affected item `BLOCKED`, identifies the cycle, stops rephrasing the two questions, and identifies an upstream prerequisite (for example, an independent compliance-policy authority or fixed certification baseline). That proposal does not itself clear the block.
- **PASS conditions:** The cycle and its upstream prerequisite are explicitly named; no repeated rephrased question loop occurs.
- **FAIL conditions:** The Agent repeatedly asks the cyclic questions, fails to name the cycle, or does not identify an upstream prerequisite.

### VALIDATION-009 / DG-010 — No material coverage gap

- **Initial input:** `/decision-grill\nStart a decision interview and show the summary only. The bounded goal is to choose the Aurora pilot rollout method. Stakeholders are Aurora Product Owner and Support Lead. Scope is a 100-user pilot; general launch is out of scope. The confirmed decision is staged rollout: 25 users on 2026-10-01, 25 more users each week after Support Lead approval. Constraint: no more than one support agent may be assigned to the pilot at any time. Dependencies: Product Owner freezes the pilot invite list by 2026-09-15; Support Lead publishes the on-call rota by 2026-09-25; the staged rollout may not begin until both are complete. Alternatives considered: full rollout gives faster feedback but exceeds the one-agent constraint; staged rollout fits that constraint. Risk R-001 is activation failure; mitigation is a 10-user dry run on 2026-09-29 with rollback to the prior release. Risk R-002 is support overload; mitigation is to pause the next 25-user cohort if more than five tickets occur in a 24-hour period. Assumption A-001 is that the invite list contains 100 eligible users; validation is Product Owner reconciliation by 2026-09-15. Unknowns: none. Deferred items: none. No blockers, contradictions, or dependency cycles exist. Success criteria are at least 95 percent successful activation and fewer than five support tickets per 24 hours. Next action is Product Owner publishes the staged-pilot plan after the summary. Do not treat this input as user confirmation.`
- **Necessary subsequent inputs:** After the summary, send `Continue the interview.`
- **Expected behavior:** The Agent first produces the summary. Only after that summary is complete does the evaluator send `Continue the interview.` The Agent treats the summary as the ledger baseline, does not manufacture an `OPEN` question for any supplied area, and requests explicit confirmation because it is the only pending condition.
- **PASS conditions:** Before `Continue the interview.`, the Agent produces the summary and no interview continuation occurs. After that exact subsequent input, no supplied-area coverage or goal question is created and the response makes one explicit confirmation request.
- **FAIL conditions:** The Agent continues the interview before the summary, repeats Goal Lock or coverage scan, creates an unsupported coverage question, treats an already supplied fact as a gap, or replaces the confirmation request with a proceed action.

### VALIDATION-010 / DG-013 — Fully converged session

- **Initial input:** `/decision-grill\nStart a decision interview and produce the required summary. This is the complete session record. Goal: choose the Aurora pilot rollout method. Stakeholders: Aurora Product Owner and Support Lead. Scope: 100-user pilot only. The decision goal and scope are confirmed. Out of scope: general launch, new product features, and regional expansion. Constraint: the pilot starts 2026-10-01 and may use no more than one support agent at a time. Alternatives considered: full rollout and staged rollout. Confirmed IMPORTANT decision D-001: use staged rollout of 25 users on 2026-10-01 and add 25 users weekly only after Support Lead approval. BLOCKER items: none. DEFERABLE items: none. Deferred items: none. Unknowns: none. Assumption A-001: the invite list contains 100 eligible users; why needed: staged cohorts require 100 eligible users; confidence: HIGH; impact if false: pilot cohort schedule slips; validation: Product Owner reconciles the invite list by 2026-09-15; status: VALIDATED. Dependencies: Product Owner freezes the invite list by 2026-09-15; Support Lead publishes the on-call rota by 2026-09-25; both are complete, and D-001 has no other dependency. There is no contradiction and no dependency cycle. Risk R-001: activation failure; mitigation: run a 10-user dry run on 2026-09-29 and roll back to the prior release on failure. Risk R-002: support overload; mitigation: pause the next cohort if more than five tickets occur in 24 hours. Success criteria: at least 95 percent successful activation and fewer than five tickets per 24 hours. Coverage evidence: goal, actors, scope, constraints, dependencies, alternatives, risks, success criteria, assumptions and unknowns, out-of-scope boundaries, and next action are all explicitly supplied in this input. Next action: Product Owner publishes the staged-pilot plan after convergence. The objective convergence conditions are satisfied in order: (1) the decision goal and scope are confirmed; (2) no unresolved BLOCKER exists; (3) all IMPORTANT and DEFERABLE items have valid statuses; (4) every UNKNOWN has a valid status or none exists; (5) no material contradiction or dependency cycle remains; (6) all eleven coverage areas have no material gap; and (7) after the requested complete fixed eight-section summary is produced, condition seven is satisfied. At that point, explicit user confirmation is the only missing convergence condition. Do not treat this input as explicit user confirmation.`
- **Necessary subsequent inputs:** After the Agent produces a complete eight-section `NOT_CONVERGED` summary whose only listed pending condition is user confirmation, send `I confirm convergence.`
- **Expected behavior:** Before the subsequent input, the Agent keeps the result `NOT_CONVERGED` solely because confirmation is absent. After it, the Agent regenerates or updates the complete eight-section summary to `CONVERGED` with user confirmation status `confirmed`.
- **PASS conditions:** The pre-confirmation summary has no unresolved BLOCKER, material coverage gap, contradiction, or dependency cycle and lists confirmation as the only pending item. The post-confirmation summary contains all eight sections, retains D-001, A-001, R-001, and R-002, says `CONVERGED`, and says user confirmation is `confirmed`.
- **FAIL conditions:** `CONVERGED` appears before `I confirm convergence.`; any of the stated objective conditions is reported unresolved; any required summary section is missing; or the post-confirmation summary lacks confirmed user status.

### VALIDATION-011 / DG-020 — Pre-converged, unconfirmed session

- **Initial input:** `/decision-grill\nStart a decision interview and produce the required summary. This is the complete session record. Goal: choose the Aurora pilot rollout method. Stakeholders: Aurora Product Owner and Support Lead. Scope: 100-user pilot only. The decision goal and scope are confirmed. Out of scope: general launch, new product features, and regional expansion. Constraint: the pilot starts 2026-10-01 and may use no more than one support agent at a time. Alternatives considered: full rollout and staged rollout. Confirmed IMPORTANT decision D-001: use staged rollout of 25 users on 2026-10-01 and add 25 users weekly only after Support Lead approval. BLOCKER items: none. DEFERABLE items: none. Deferred items: none. Unknowns: none. Assumption A-001: the invite list contains 100 eligible users; why needed: staged cohorts require 100 eligible users; confidence: HIGH; impact if false: pilot cohort schedule slips; validation: Product Owner reconciles the invite list by 2026-09-15; status: VALIDATED. Dependencies: Product Owner freezes the invite list by 2026-09-15; Support Lead publishes the on-call rota by 2026-09-25; both are complete, and D-001 has no other dependency. There is no contradiction and no dependency cycle. Risk R-001: activation failure; mitigation: run a 10-user dry run on 2026-09-29 and roll back to the prior release on failure. Risk R-002: support overload; mitigation: pause the next cohort if more than five tickets occur in 24 hours. Success criteria: at least 95 percent successful activation and fewer than five tickets per 24 hours. Coverage evidence: goal, actors, scope, constraints, dependencies, alternatives, risks, success criteria, assumptions and unknowns, out-of-scope boundaries, and next action are all explicitly supplied in this input. Next action: Product Owner publishes the staged-pilot plan after convergence. The objective convergence conditions are satisfied in order: (1) the decision goal and scope are confirmed; (2) no unresolved BLOCKER exists; (3) all IMPORTANT and DEFERABLE items have valid statuses; (4) every UNKNOWN has a valid status or none exists; (5) no material contradiction or dependency cycle remains; (6) all eleven coverage areas have no material gap; and (7) after the requested complete fixed eight-section summary is produced, condition seven is satisfied. At that point, explicit user confirmation is the only missing convergence condition. Do not treat this input as explicit user confirmation.`
- **Necessary subsequent inputs:** After the Agent produces a complete eight-section `NOT_CONVERGED` summary whose only listed pending condition is user confirmation, send `Continue without explicitly confirming.`
- **Expected behavior:** The Agent identifies explicit user confirmation as the only pending convergence condition, asks for that confirmation, and retains `NOT_CONVERGED` without creating a new question, blocker, or coverage gap.
- **PASS conditions:** Both the first summary and the response to the subsequent input say `NOT_CONVERGED`; both show no unresolved BLOCKER, material coverage gap, contradiction, or dependency cycle; the second response asks for explicit confirmation as the sole next condition.
- **FAIL conditions:** The Agent marks the session `CONVERGED`, omits the confirmation request, introduces an unstated objective gap, or asks a new decision question.

## Interaction and regression analysis

| Correction | Interaction | Main regression risk |
| --- | --- | --- |
| PRODUCT-001 | Feeds provisional, defer, environment-fact, and research paths. | Over-classifying a clearly stated decision as a fact, or adding needless clarification turns. |
| PRODUCT-002 | Must take precedence over Intake, Coverage Scan, Question Model, and bounded direct-request behavior. | Continuing even one follow-up question after recommending `wayfinder`, or blocking a later new bounded goal. |
| PRODUCT-003 | Must take precedence over every lifecycle stage, Goal Lock outcome, and recommended-next-action wording. | Conditional implementation offers, tool use, or accidental Skill chaining after a refusal. |
| PRODUCT-004 | Applies one semantic Goal Lock evidence rule after PRODUCT-002 and PRODUCT-003. | Exact-phrase gating, redundant confirmation, or case-specific startup behavior. |
| Batch B state/ledger | Applies one state model and event order across answers, research, dependencies, and cycles. | A product-specific branch, an eventless next question, or stale dependent confirmation. |
| Batch C post-summary sequencing | Applies one shared branch order after every complete summary. | Duplicate goal/coverage questions, early `CONVERGED`, action wording in place of confirmation, or a full-interview restart after a scoped change. |

The three changes are compatible but must have explicit precedence: implementation requests are always out of boundary; oversized goals terminate the current interview; unknown handling applies only while a bounded interview remains active.

## Fixture executability review

All ten fixtures pass the planning-level executability check:

| Fixture | New Session invocation | All prerequisite state supplied | Complete input sequence | Observable result | Deterministic PASS/FAIL check |
| --- | --- | --- | --- | --- | --- |
| DG-003 | `/decision-grill` | Yes | Yes | Eight provisional fields and statuses | Yes |
| DG-004 | `/decision-grill` | Yes | Yes | Deferred record and no re-ask | Yes |
| DG-005 | `/decision-grill` | Yes | Yes | Named blocker and `NOT_CONVERGED` summary | Yes |
| DG-006 | `/decision-grill` | Yes, through stated isolation-file setup | Yes | Environment lookup result | Yes |
| DG-007 | `/decision-grill` | Yes, through stated unavailable-source setup | Yes | `RESEARCH_REQUIRED` and no research action | Yes |
| DG-008 | `/decision-grill` | Yes | Yes | `SUPERSEDED` original and re-evaluated dependency | Yes |
| DG-009 | `/decision-grill` | Yes | Yes | Named cycle and upstream prerequisite | Yes |
| DG-010 | `/decision-grill` | Yes | Yes | Summary before continuation; no manufactured question | Yes |
| DG-013 | `/decision-grill` | Yes | Yes | Only confirmation pending, then `CONVERGED` | Yes |
| DG-020 | `/decision-grill` | Yes | Yes | Only confirmation pending and remains `NOT_CONVERGED` | Yes |

The future manual-test revision must retain these texts verbatim enough that each fixture has one clear Initial input, ordered subsequent inputs, observable expected behavior, and non-overlapping PASS and FAIL conditions.

## Proposed file scope

1. `specs/SPEC-001-decision-grill-v0.1.md`
   - Define decision-item state meanings, paired research status, event ordering, cycle blocking, and supersession re-assessment.
2. `skills/productivity/decision-grill/SKILL.md`
   - Add the explicit unknown fact versus undecided decision checkpoint.
   - Make Scope Lock's oversized-goal branch terminal.
   - Make the no-implementation boundary absolute and add the required refusal behavior.
   - Update safeguards to match all three rules.
3. `docs/productivity/decision-grill.md`
   - Synchronize user-facing documentation for unknown classification, terminal oversized-goal behavior, and the absolute implementation boundary.
4. `tests/manual/decision-grill-v0.1.md`
   - Add the ten executable fixtures above, including environment setup, inputs, observable evidence, and explicit PASS/FAIL conditions.
   - Preserve the 20 acceptance criteria and retain result history separately from future rerun evidence.

5. `tests/automation/decision-grill-cases.json`
   - Add only data-driven observable assertions for the Batch B and Batch C matrices.
6. `scripts/run-decision-grill-regression.ps1` only if a generic observable assertion cannot be expressed by the existing runner.

No manifest, README, official Skill, package, repository configuration, or PR file is proposed for modification.

## Recommended implementation and regression order

1. Reconfirm Product Owner authorization, branch, permitted file scope, and either a clean working tree or the exact authorized dirty baseline with immutable runtime identity.
2. Correct PRODUCT-003 in `SKILL.md` and verify DG-016's refusal boundary manually.
3. Correct PRODUCT-002 and verify DG-011 does not create a follow-up question.
4. Correct PRODUCT-001 and verify DG-002 first-classifies the unknown.
5. Add the ten manual executable fixtures to the manual acceptance test document.
6. Synchronize the public documentation page with the implemented behavior.
7. Run the full DG-001 through DG-020 regression suite in new isolated Sessions after the formal fixes. This is required because the core `SKILL.md` behavior rules change.
8. Execute targeted priority cases first: DG-002, DG-003 through DG-011, DG-012, DG-013, DG-014, DG-016, and DG-020. DG-012 and DG-014 are mandatory regression cases for the revised terminal and summary boundaries.
9. Re-run no-mutation, independent-Skill, dependency, and non-invocation evidence for DG-015 and DG-017 through DG-019 within the complete suite; do not rely solely on the previous equivalent evidence after the core-rule change.
10. Stop for Product Owner review before any commit, push, PR operation, or installation.

## Authorization gate

Batch A remains complete under second-round Product Owner authorization: the approved Goal Lock contract, shared Scope Lock behavior, product documentation, DG-012 alignment, and this remediation record are preserved. Batch B state-recording and ledger-event behavior is preserved. Batch C post-summary sequencing is preserved. Batch D adds only the generic runner contract: every subsequent input declares a same-index `required` or `conditional` mode; required false is `BLOCKED`, conditional false is `SKIP`, and unavailable applicability evidence is `BLOCKED`. A SKIP makes no resume call and adds no synthetic user or Agent transcript, but records indexed conditional evidence, continues deterministic and Judge evaluation, and leaves subsequent fixture indices unchanged. DG-009 declares its cyclic-decision reply as `conditional`: if neither cyclic decision is asked, it is skipped while the real transcript is still judged for the required cycle and affected-item `BLOCKED` behavior. No case-specific runner branch is permitted. No product regression execution, installation, commit, push, or PR operation is authorized.

## Batch E — Generic declarative fixture contract

Batch E remediates the integrated-review HIGH finding for case-specific runner fixture setup without changing any Decision-Grill product behavior or acceptance history. Every automation case owns a required machine-readable `fixtures` array. An empty array is a successful no-op; one or more ordered fixture objects each declare exactly `relative_path` and `content`. The DG-006 case owns the exact declaration for `fixture-data/release-fact.txt` with content `Aurora pilot launch date: 2026-10-01`; the runner contains no DG case-ID, filename, or content selection for that fixture.

Before any fixture directory or file is created, the generic runner validates all fixture metadata and resolves all targets. It rejects missing or invalid metadata, rooted/drive/UNC paths, empty, `.` or `..` segments, containment escapes, ActiveFolder itself, duplicate normalized targets, and pre-existing targets. It preserves declaration order, canonical Windows `OrdinalIgnoreCase` separator-boundary containment, ActiveFolder protected-root and reparse safeguards, immediate pre-directory and pre-write safety revalidation, no-overwrite behavior, and exact UTF-8 no-BOM content without an automatic newline. Fixture contract, containment, reparse, safety, and write failures retain runner internal/safety failure semantics; they are not product-case results. This Batch does not record any Full regression as executed or passed.

## Batch G — Immutable working-tree identity

Batch G remediates the DryRun preflight finding caused by an incomplete raw status-string allowlist. The runner accepts only either (1) a clean Git working tree or (2) the exact authorized ten-entry dirty baseline: four unstaged tracked modifications and six untracked Decision-Grill files. Staged, deleted, renamed, copied, conflicted, type-changed, missing, extra, partial, or wrong-status entries are rejected.

The runner parses NUL-safe porcelain status into normalized repository-relative paths, rejects path escapes and normalized-path collisions, and records branch, HEAD, status, safe regular-file existence, length, and raw-byte SHA-256 for every dirty entry. This initial identity is immutable for the run. Shared production safety revalidation compares every subsequent identity to it before and after external execution, fixture work, digest/Judge paths, and final report persistence. A difference is a runner safety/internal failure with identity evidence, never a product-case result.

The contract permits the formally authorized dirty baseline without hard-coding machine-absolute paths or permanent source hashes. It also permits a future clean baseline. Batch G preserves all acceptance history and does not claim that a Full regression has run or passed.

## Batch K2 — typed Judge verification and source encoding acceptance history

Batch K2 completes production-path StaticTest coverage for typed fact/work evidence. DG-007's catalog-owned `RESEARCH_REQUIRED`, affected-decision pattern, and paired decision state are evaluated by the generic deterministic parser and supplied to the generic Judge evidence gate. Typed PASS verifies captured Judge input contains the matched record and a JSON Boolean `passed: true`. Three typed deterministic failures (missing status, wrong affected decision, and wrong paired state) preserve expected, missing, and matched evidence, still call the injectable Judge once, and retain final product `FAIL` when the injected Judge returns `PASS`.

The pre-Judge gate validates typed evidence generically for missing evidence, low/high count, null item, required fields, Boolean CLR type, nested shape, and deterministic-input serialization. Invalid evidence returns runner-contract `BLOCKED` with `FACT_WORK_TYPED_EVIDENCE_INVALID` plus a generic subtype, never calls the Judge adapter, and does not select behavior by case ID. A non-applicable catalog case proceeds to Judge without fabricated fact/work evidence. DG-003 additionally verifies exact Chinese SMS event-alert text, U+3000, U+FF1F, Unicode normalization, and the production question-scoped evaluator.

### Source versus payload encoding contract

For Windows PowerShell 5.1, `scripts/run-decision-grill-regression.ps1` is UTF-8 with BOM (`EF BB BF`). This is source-decoding metadata only. Without it, Default Big5 decoding can interpret UTF-8 DBCS byte sequences in Unicode regexes or fixtures so that a trailing byte consumes an ASCII delimiter such as `]`, producing parser or regex failures. The runner's stdin, fixture, evidence, and Judge payload contracts remain UTF-8 without BOM and without automatic newline. StaticTest validates those boundaries independently.

## Generic case selection and targeted-validation acceptance history

The runner provides `Targeted -CaseIds "DG-001,DG-003"` as a generic catalog selection interface. The declaration is one comma-separated string for Windows PowerShell `-File` compatibility. Tokens are trimmed, must be `DG-###`, resolve OrdinalIgnoreCase against the current catalog, reject blank/duplicate/unknown/non-canonical values, and return canonical catalog IDs in declaration order. Targeted requires at least one selected case; DryRun may validate an optional declaration without product execution; Core and Full reject it.

Targeted feeds only the resolved case objects to the existing shared selected-case loop. It does not select fixture behavior, evaluator logic, Judge behavior, transport, or expected results by case ID. Planned, Executed, category totals, selected-only NOT_EXECUTED placeholders, JSON, and Markdown remain aggregate-derived. The fixed six-case command used for targeted validation is evidence only, not a production mapping. Fresh ActiveFolder isolation and a raw-byte project-level Source Skill copy remain mandatory; targeted execution is not a claim that Full regression has passed.

## Targeted recovery and result-contract acceptance history

The first two generic-selection Targeted attempts remain preserved failed evidence. Attempt 1 exposed an uninitialized post-input failure collection. Attempt 2 exposed two generic runner boundaries: a blocked case could return no object after constructing its case result, and the selected-case loop dereferenced `result` before validating invocation output. The recovery contract corrects both without case-ID branches: every early `Invoke-Case` exit returns its constructed result, and the shared loop validates exactly one case-result object with matching case ID and an approved final category before aggregation.

Malformed invocation output (null, scalar, multiple outputs, missing/blank/unknown result, or missing/mismatched case ID) becomes a persisted `RUNNER_INTERNAL_ERROR` trigger with original shape evidence. The selected remainder alone becomes `NOT_EXECUTED`; aggregate JSON, Markdown, totals, and the generic finally safety path remain available. Product `PASS`, `FAIL`, and `BLOCKED` remain product outcomes and continue selected execution.

Attempt 2 DG-001 raw messages, transcript extraction, resume call, and Judge input were complete. The output used `Ledger event — Q-001: ANSWERED. <accepted decision>. Status: ANSWERED.` The product specification requires a visible ledger event that identifies the question, accepted lifecycle, and decision result, but does not require the example's `Question ID`/`Lifecycle` labels. The DG-001 automation representation therefore accepts either the original labelled form or this equally explicit form, while still requiring Q-001, accepted lifecycle, non-empty decision text, and resulting ANSWERED/ACCEPTED status. This is a fixture representation correction, not a relaxation of product acceptance or a Judge override.

## Batch I — Runner reliability remediation

### Formal contract

Batch I corrects runner reliability without changing Decision-Grill product behavior, fixture semantics, product specification, or Skill text. A subsequent prompt is the exact non-blank value declared at its ordered fixture index. The production resume invoker binds that prompt and its arguments explicitly; it does not use PowerShell's automatic `$input` name or reconstruct text from a case identifier, title, or expected result. The existing UTF-8 no-BOM stdin write and stdin closure remain required. Only a `SEND` condition enters the resume invoker and increments its call count; `SKIP` and `BLOCKED` never do.

The labelled decision-state parser accepts plain, bold, and Markdown-inline-code values only at formal Status, State, Current status, Convergence status, or equivalent ledger fields. It rejects incidental prose, negation, unlabelled tokens, and fenced examples. This is a generic parser rule, not a DG-005 branch.

Core and Full share fail-fast semantics: product PASS, FAIL, and BLOCKED results continue; runner-internal, preflight, and safety failures stop the selected suite. The trigger result is preserved. Every remaining selected case receives a persisted NOT_EXECUTED record with NOT_RUN deterministic and Judge status, no thread, no initial/resume calls, no transcript, and `RUN_ABORTED_AFTER_RUNNER_ERROR` trigger evidence. NOT_EXECUTED is an execution status, never a product BLOCKED result.

One aggregate-derived summary drives JSON, Markdown, console, and exit classification. It records PASS, FAIL, BLOCKED, RUNNER_INTERNAL_ERROR, NOT_EXECUTED, Executed, Planned, and Total; category totals equal Planned and Executed excludes NOT_EXECUTED. Runner and safety errors take exit precedence. Reports record stop reason, trigger case and stage, last completed case, and remaining cases.

When a case declaratively requires official-Skills metadata evidence and a before inventory succeeds, the runner's generic finally postcondition attempts and persists an after inventory despite initial, resume, deterministic, Judge, or merge errors. A failed or changed after inventory becomes SAFETY_REVALIDATION_FAILED while retaining the original runner error as secondary evidence. The hook is metadata-only, never reads official Skill contents, and has no DG-017 case branch.

### Acceptance-history entry

The 2026-07-30 Full evidence remains failed evidence, not a passing regression claim. Its 12 empty-resume failures arose from the PowerShell `$Input`/automatic `$input` collision; DG-005 exposed missing labelled inline-code parsing; Full lacked runner-error fail-fast and complete totals; and DG-017 lacked after-inventory evidence on its error path. Batch I defines the generic runner correction and StaticTest coverage only. No DryRun, Core, Full, Codex CLI, Judge, installation, commit, push, or PR result is claimed by this entry.

## Batch J — Automation semantic contracts

Batch J changes automation assertions only. A send condition can require one Q-format block containing the heading, Question, Recommended answer, and all normalized term groups. Term groups are all-of and their literal alternatives are any-of; Latin matching is token-aware and CJK matching is literal. DG-003 therefore verifies SMS, event/事件, and alert/告警 concepts without an English phrase gate or a DG-specific runner branch.

`RESEARCH_REQUIRED` is asserted through a typed fact/work record, not decision `required_states`. A generic assertion requires its fact/work status, case-owned affected-decision regex, and paired decision state in one record; typed deterministic evidence remains available to Judge input. DG-007 requires the affected Aurora release decision to be BLOCKED. This remediates automation interpretation, not product behavior, and does not claim a Full pass.

## Unified five-case remediation and Attempt 4 preparation

Attempt 3 remains immutable failed evidence: DG-001 and DG-009 exposed generic labelled-state extraction false negatives; DG-003 exposed a contradictory case-owned event term despite the observed SMS incident-alert question; DG-005 exposed English-only legal-approval representation plus an unrecognized structured state record; and DG-007 exposed both a multiline state extraction gap and a missing formal fact/work record. The five-case disposition review is the design authority for these observations.

The generic state parser now accepts only anchored, non-fenced formal evidence: canonical labelled fields including `Resulting status`, an immediately following labelled value, and structured state-first or decision-first bullet records. It continues to reject incidental prose, negation, bare tokens, and code-fenced samples. This is generic parser behavior; it contains no case-ID branch.

DG-003's case-owned Q-scoped middle term group adds `incident` as an alternative to the existing event terms. DG-005 uses generic `required_keyword_groups` so either `legal approval` or the observed `法律核准` satisfies the same required blocker concept, while its required send pattern uses the same two alternatives. All other case declarations retain their semantic content.

The Source Skill now requires a visible, labelled fact/work record containing `RESEARCH_REQUIRED`, the affected decision, and its paired decision state in one record. This enforces the existing Product contract without treating research status as a decision lifecycle state or adding any case-specific wording. The typed deterministic evaluator consumes that generic record shape and continues to pass its typed evidence unchanged to the independent Judge gate.

StaticTest covers the observed `Resulting status` ledger form, multiline labels, state-first and decision-first structured records, and incidental/negated/fenced negatives; it also covers DG-003's observed incident form and the formal typed record with its existing PASS, FAIL, gate, and non-applicable matrices. This entry records implementation and StaticTest preparation only. Attempt 4 DryRun and Targeted evidence are recorded separately after they execute.

## Final targeted stabilization and Attempt 5 contract

Attempt 4 is preserved failed evidence with three exact semantic boundaries. DG-001 produced a formal Q-001 ledger event with an inline-code `ANSWERED` lifecycle, a non-empty decision result, and inline-code `Resulting status`; the case-owned accepted-event representation was too narrow. Its declaration now accepts only anchored Q-001 ledger forms with a plain, inline-code, or bold accepted lifecycle and matching labelled resulting state, while code fences, negation, incidental prose, unrelated questions, and missing ledger events remain rejected.

DG-007 produced the required formal record but named `Aurora release compliance requirement` as the affected item. A requirement is an unavailable fact, not necessarily the decision affected by it. The Source Skill therefore now requires the generic affected-decision field to name the actual decision and expressly forbids restating the fact, requirement, source, or research topic there. The case-owned affected-decision pattern remains decision-specific; no unconditional requirement alternative was added.

DG-009 produced formal decision-first cycle bullets prefixed by code-wrapped decision IDs. The generic state parser now accepts a line-start `D-###` identifier either plain or with paired backticks before a decision label, still requiring the same-line structured dash/colon and explicit state. It rejects prose, fenced samples, malformed/unpaired backticks, wrong identifier shapes, and cross-record values. No case-ID branch is introduced.

The new StaticTest matrices cover each Attempt 4 observed form plus the required positive and negative boundaries. Attempt 5 uses one fresh isolation, raw-byte project-level Source Skill installation, one DryRun, and one Targeted execution of DG-001, DG-003, DG-005, DG-007, DG-009, and DG-017. This entry records the authorized contract and not an Attempt 5 outcome.

## DG-007 final semantic closure and Attempt 6 contract

Attempt 5 is preserved failed evidence, not a Product, runner, Judge, or Source Skill defect. Its formal typed fact/work record contains `RESEARCH_REQUIRED`, `Aurora release authorization`, and paired `BLOCKED`; the generic typed evaluator correctly rejected only the case-owned surface pattern `Aurora.?s release decision`. Product Owner disposition accepts `Aurora release authorization` as a finite DG-007 affected-decision synonym alongside canonical `Aurora's release decision` and `Aurora’s release decision`. Compliance requirements, generic requirements, facts, readiness items, approval processes, partial forms, and broad keyword presence remain rejected.

DG-007's catalog declaration therefore uses a bounded, case-owned affected-decision regular expression. The generic typed evaluator continues to require a visible non-fenced formal record with fact/work status, affected decision, and paired decision state in one record; it rejects incidental prose, fenced samples, negated pseudo-records, split records, missing status, and missing paired state. No Source Skill, Product specification, Judge contract, or case-specific runner branch is changed. StaticTest uses the production `Test-Deterministic` typed assertion path for all accepted and rejected forms, preserves typed Judge/gate coverage, and records no Attempt 6 outcome until its fresh execution completes.

## Final contract stabilization, replay gate, and Attempt 7 contract

Attempts 4 through 6 identify two systemic contract boundaries. DG-007 failures varied across natural decision nouns (`authorization` and `approval`) because the prior evaluator applied the case pattern as a substring search over a raw record. The final contract extracts the labelled fact/work status, affected-decision value, and paired state from one formal record, normalizes only legal field wrappers and whitespace, and applies the case-owned identity pattern as a full-value match to the extracted affected-decision field. DG-007 permits the Product Owner approved Aurora-release identity values, including bare `Aurora release`, while requirements, facts, readiness, research, approval processes, partial/prefix values, incidental prose, negation, fences, and cross-record assembly remain failures.

DG-001 Attempt 6 is preserved as a product-output failure: an accepted answer advanced to Q-002 without a post-input accepted-result ledger event. The Source Skill now makes that generic order mandatory. On acceptance, it MUST first record the current question ID, accepted result, and labelled resulting accepted state; it MUST NOT ask a next question, enter Coverage Scan, summarize, or end before the event. Automation retains the strict post-input boundary rather than accepting the missing output. StaticTest embeds minimal, hermetic replay fragments from Attempts 4 through 6 and executes only production extractors and deterministic paths; production execution never reads historical `D:\temp` evidence.

## Unified acceptance architecture migration

The Acceptance Architecture Review is the design authority for the final v0.1 regression architecture. Runner safety and transport are `R`; formal message/state/order invariants are `S`; same-message typed records are `T`; case-owned natural-language requirements are `J`; and combined conditions are `H`. Only `R`, `S`, and `T` deterministic failures are authoritative. `J` is evaluated by the independent Judge from the case declaration and the unmodified transcript. Missing or invalid Judge evidence is `BLOCKED`, never a product semantic FAIL.

The runner now preserves message sequence evidence (turn, input, origin, raw-event location, raw and normalized text) and derives accepted-answer and fact/work records without crossing message or blank-record boundaries. DG-001’s Attempt 7 event is accepted because its trailing blank line terminates an already complete record; an event split across records or messages remains invalid. DG-009 removes English `cycle`/`upstream` literal keywords from deterministic authority and declares the circular-dependency and prerequisite explanations as language-neutral Judge requirements while retaining formal `BLOCKED` structure.

Historical Attempt 4–7 evidence remains immutable. StaticTest uses only hermetic replay fragments, including the Attempt 6 DG-001 missing-boundary negative and Attempt 7 trailing-blank positive. Production execution never reads historical evidence from `D:\temp`. The final merge is shared by per-case JSON, aggregate categories, and Markdown reporting: runner/safety; preflight/evidence block; S; T; Judge semantic PASS/FAIL; then Judge unavailable BLOCKED.

## Final four-case evidence-driven stabilization

The final Full regression at `D:\temp\decision-grill-dg-run-20260801-163030` is preserved as historical evidence. Its DG-001, DG-008, DG-012, and DG-020 non-PASS outcomes were classified against the Product specification, manual contract, Source Skill, case declarations, raw message boundaries, deterministic evidence, and Judge/merge ownership. No Product specification, manual, schema, or Source Skill change was required.

DG-001 contained a complete Q-001 acceptance event in one resume message: accepted lifecycle, non-empty decision result, and resulting accepted status before Q-002. The typed extractor had rejected only the legal Markdown spelling `**Label:** value`; it now accepts that spelling as well as `**Label**: value`, without accepting missing fields, wrong Q IDs, negation, fences, future promises, pre-input events, or cross-record/message assembly. DG-008 contained formal labelled historical supersession records (`Previous result: SUPERSEDED — ...`); the generic state parser now recognizes labelled previous/prior/original result-or-status records with a same-line em-dash explanation, while rejecting incidental or negated prose.

DG-012 was a case-representation false negative: its required send condition had demanded the English surface phrase `legal approval` even though the observed output established a formal `BLOCKED` record and question in Chinese. The required mode is unchanged; its declarative evidence is now the Q heading plus formal BLOCKED state. DG-020 was also a case-representation overconstraint: the contract required a new literal `Convergence status: NOT_CONVERGED` heading after a confirmation-only continuation. The product contract instead requires retention of unconverged state and an explicit confirmation request. The formal premature-CONVERGED and new-question prohibitions remain deterministic, while the confirmation-only semantics remain the case-owned Judge requirement.

StaticTest uses hermetic fragments of the four observed forms and production extractors/evaluators only; production execution never reads this historical directory. The four cases retain no case-ID branch in production code, and the catalog/prepare gate retains all twenty declared cases.

## Replay-gate integrity closure

The Final Four-Case independent review found that the former catalog-count assertion was named as though it replayed the latest Full run. It did not consume immutable raw evidence, execute all twenty cases through applicable production parsing, deterministic evaluation, Judge wrapper, and merge paths, or emit twenty per-case outcomes. That HIGH finding is closed by separating claims rather than manufacturing evidence.

`20_CASE_CATALOG_CONTRACT_GATE` now proves only exact DG-001 through DG-020 catalog identity, order, and production `Test-CaseContract` validity. `FOUR_CASE_PRODUCTION_PATH_REGRESSION_GATE` proves hermetic production-path regression for DG-001, DG-008, DG-012, and DG-020. Neither gate is a twenty-case Full replay or a product-regression closure; each is not a replay closure.

The immutable 2026-08-01 Full result remains `16 PASS / 3 FAIL / 1 BLOCKED`. Historical replay is not claimed because saved evidence is incomplete for faithful end-to-end replay: DG-001, DG-008, and DG-020 lack saved Judge artifacts, and DG-012 was blocked before objective/Judge evidence existed. StaticTest never reads `D:\temp` evidence and must not infer missing evidence or turn the historical aggregate into 20 PASS. Only a later fresh Full result of `20 PASS / 0 FAIL / 0 BLOCKED` can close product regression. This entry is append-only acceptance history; it does not alter historical outcomes.

The runner source remains UTF-8 with BOM for Windows PowerShell 5.1 source decoding. Stdin, fixtures, persisted evidence, and Judge payloads remain UTF-8 no-BOM with no automatic newline.

## Final pre-release autonomous closure — remediation iteration 1

The fresh Full attempt at `D:\temp\decision-grill-dg-run-20260801-215224` is preserved as evidence: 17 PASS, 3 FAIL, 0 BLOCKED, and no runner internal error. The three non-PASS cases expose one generic parser boundary and two automation/Skill representation boundaries; they do not require a Product-spec change.

DG-008 emitted the Source Skill's formal `Lifecycle: SUPERSEDED` record. The generic state parser previously recognized current/resulting and historical previous/prior/original labels but omitted the Skill's lifecycle label. It now accepts an anchored, non-fenced `Lifecycle` labelled value; incidental prose, negation, bare tokens, and fenced forms remain rejected. StaticTest exercises the actual DG-008 declaration through deterministic evaluation and the Judge/merge production wrapper.

DG-007 emitted a complete typed fact/work record whose affected decision was `Aurora release compliance approval`. This remains a decision value, not the rejected `compliance requirement` fact value. Its declaration now adds that one finite, full-value identity alternative while retaining all same-record, non-fenced, status, paired-state, and rejected requirement/fact/process boundaries. The Source Skill also now tells the Agent to preserve the decision identity without importing a qualifier from the unavailable fact's domain.

DG-010 made an explicit confirmation request but omitted the required explanation that confirmation was the sole remaining condition. The Source Skill and product documentation now require that explicit sentence. The catalogue retains a deterministic explicit-confirmation-request check, while the confirmation-only meaning remains the pre-existing `confirmation_only_explained` Judge semantic requirement; the duplicate semantic literal hard pattern was removed. StaticTest verifies the actual DG-010 production post-input evaluator accepts the structural request only with the declared Judge ownership and rejects an absent explicit request. This records a correction for a fresh rerun, not a replacement of the preserved Full result.

The subsequent fresh Targeted evidence at `D:\temp\decision-grill-dg-run-20260801-220953` passed DG-007 and DG-010 but preserved a DG-008 deterministic FAIL. Its transcript used `Q-001 is now SUPERSEDED` and `Q-002 is also SUPERSEDED` only as prose. The state parser correctly rejected that non-formal surface. The Source Skill, product documentation, manual fixture, and StaticTest Source-Skill invariant now require a visible labelled `Lifecycle: SUPERSEDED` record for the original and each superseded dependent; no prose relaxation or case-specific parser branch was introduced.

## Final pre-release autonomous closure — remediation iteration 2

Fresh Full attempt 2 at `D:\temp\decision-grill-dg-run-20260801-221447` preserved 18 PASS and no FAIL or runner-internal result, but did not meet final acceptance because DG-003 was BLOCKED before its second input and DG-006 was BLOCKED by an external Windows sandbox spawn denial. DG-003's first response correctly offered every provisional-decision field, but its second response left `PROVISIONAL` conditional instead of recording the user's accepted selection. The Source Skill now makes accepted, selected, or "use"d provisional options an immediate complete `Status: PROVISIONAL` record, and the catalog/manual input explicitly expresses that acceptance. This is a generic lifecycle-record rule, not a case-specific production branch or reduced acceptance condition. DG-006's deterministic evaluator and Judge evidence were correct; its agent-side current-environment query failed with `CreateProcessAsUserW` access denied. A final fresh Full retry is warranted only after this evidence-preserving correction and fresh skill installation.
