# Decision-Grill automated regression

## Acceptance evidence architecture

The runner uses five explicit ownership layers. `R` is runner safety and transport (processes, stdin, fixtures, repository and official-Skill identity) and is never Judge-overridable. `S` is a formal structural invariant such as a question ID, labelled state, message order, or required field. `T` is a typed formal record: all fields must be extracted from one message-local record and then matched against the case-owned identity contract. `J` is a case-owned natural-language semantic requirement, evaluated independently by the Judge. `H` splits one acceptance condition into its S/T hard gate and J semantic component.

Transcript extraction retains ordered message objects with origin, turn, input, raw-event location, raw text, and normalized text. Accepted-answer and fact/work evidence are extracted only within one source message. A blank line terminates a record; it may not cause cross-record assembly and does not invalidate a complete preceding record. Formal Markdown fields accept both `**Label**: value` and `**Label:** value` spellings; neither permits a missing field or cross-record assembly.

Each case declares `judge_semantic_requirements` as `{ id, description }` data. These requirements are language-neutral: legacy literal words may be recorded as advisory observations, but cannot become authoritative deterministic failures. The Judge receives the case declaration, hard deterministic evidence, typed event evidence, objective evidence, and the unmodified merged transcript. It reports requirement IDs through its existing `satisfied_conditions`, `violated_conditions`, and `evidence` fields; no Judge-result schema change is required.

Final precedence is: runner/safety error; preflight/evidence block; S hard failure; T hard failure; Judge semantic PASS/FAIL; Judge missing or invalid evidence BLOCKED. A hard S/T failure does not call the Judge. The final Markdown report and JSON aggregate use the same merge result.

StaticTest includes hermetic historical fragments only. Production code never reads `D:\temp` evidence. `20_CASE_CATALOG_CONTRACT_GATE` proves only that the catalog is exactly DG-001 through DG-020 and that every declaration passes production `Test-CaseContract`; it is not a Full replay or a product-regression result. `FOUR_CASE_PRODUCTION_PATH_REGRESSION_GATE` covers the DG-001 bold-colon ledger and message boundary, DG-008 historical supersession parsing, DG-012 multilingual formal required-send evidence, and DG-020 confirmation-only handling through their applicable production paths. It is intentionally four-case scope, not 20-case scope.

The immutable 2026-08-01 Full evidence is classified as `16 PASS / 3 FAIL / 1 BLOCKED`. It is preserved historical evidence, not a replay closure: DG-001, DG-008, and DG-020 have no saved Judge artifacts, and DG-012 has neither saved objective evidence nor Judge artifacts after its send-condition block. StaticTest PASS is not a real product Full PASS and must not infer missing transcript, objective, Judge, or merge evidence. A fresh Full regression producing `20 PASS / 0 FAIL / 0 BLOCKED` is the only final product-regression closure.

Run from `D:\ai-skills-lab` on the approved branch:

```powershell
.\scripts\run-decision-grill-regression.ps1 -Mode DryRun
.\scripts\run-decision-grill-regression.ps1 -Mode Core
```

`Full` is implemented for a later authorization but must not be run in this phase. The runner writes all raw JSONL and reports below `D:\temp\decision-grill-dg-run-<timestamp>` and never writes test output into the repository. Every case gets a fresh `codex exec` session; subsequent inputs use `codex exec resume` with the thread ID extracted from JSONL.

The case catalog preserves the 20 manual acceptance cases. `desktop_initial_input` retains the Desktop `/decision-grill` fixture form; `cli_initial_input` changes only that token to `$decision-grill`.

## Subsequent-input contract

Each `ordered_subsequent_inputs` item has exactly one same-indexed `send_condition_requirements` declaration. The declaration must set `mode` to either `required` or `conditional`; missing, unknown, duplicate, extra, or out-of-range indices fail prepare validation.

- `required`: established applicability sends the input; a non-established or unavailable condition blocks the case.
- `conditional`: established applicability sends the input; an explicitly non-established condition records `SKIP` without a resume call; unavailable evidence blocks the case.

The original fixture index never changes. A skipped input contributes independent conditional-input evidence to the Judge input but never creates a synthetic transcript turn, and deterministic assertions and the Judge continue using the real transcript.

## Declarative fixture contract

Every case owns a required `fixtures` array. An empty array is an explicit no-op: the runner creates no fixture directory or file. One or more fixtures are declared in order, each with exactly these fields:

```json
{
  "relative_path": "fixture-data/example.txt",
  "content": "exact UTF-8 content"
}
```

`relative_path` is a non-blank relative path below the canonical ActiveFolder. Rooted, drive, UNC, empty-segment, `.` and `..` paths are rejected, as are normalized targets outside (or equal to) ActiveFolder and duplicate normalized targets. `content` is required and must be a string; `""` creates an intentional zero-byte UTF-8 file. The runner validates every fixture and resolves every target before creating any directory or writing any file.

For each fixture, the runner revalidates ActiveFolder safety and the path chain before parent creation, verifies the path chain after creation, then immediately repeats safety and reparse checks before an UTF-8 no-BOM write. Existing target files are never overwritten. A metadata, containment, reparse, safety, or write failure is a runner contract/internal safety failure, not a product-case PASS/FAIL/BLOCKED result.

Fixture setup is selected only from the current case's `fixtures` data. The runner must not use a Decision-Grill case ID, title, input text, expected result, prose `fixture_setup`, mapping, or filename/content special case to select a fixture.

## Working-tree identity contract

Before every production mode, the runner accepts exactly one of two Git states: a clean working tree, or the authorized Decision-Grill dirty baseline. The dirty baseline is exactly four unstaged tracked modifications (`docs/productivity/decision-grill.md`, `skills/productivity/decision-grill/SKILL.md`, `specs/SPEC-001-decision-grill-v0.1.md`, and `tests/manual/decision-grill-v0.1.md`) plus six untracked automation/remediation files. No staged, deleted, renamed, copied, conflicted, type-changed, extra, missing, partial, or wrong-status entry is accepted.

The production parser consumes NUL-safe Git porcelain status and normalizes repository-relative paths using `/`, rejecting path escapes, duplicate normalized identities, and reparse points. At preflight it captures branch, HEAD, status, file type, length, and raw-byte SHA-256 for every dirty file. The baseline is never recreated. Shared safety revalidation compares the current identity at execution checkpoints before and after external calls, fixture operations, digest/Judge work, and report persistence. A difference is a runner safety/internal failure, never a product-case result.

## Runner reliability contract

Each resume prompt is transported directly from its same-index `ordered_subsequent_inputs` value. The runner rejects blank declared prompts during prepare validation, binds the value through explicit resume-invoker parameters, writes its exact UTF-8 no-BOM bytes to stdin, and closes stdin. `SEND` makes one resume invocation only after the process invoker is entered; `SKIP` and `BLOCKED` make none.

Product `PASS`, `FAIL`, and `BLOCKED` outcomes continue the selected suite. A runner-internal, preflight, or safety failure stops both Core and Full immediately. The trigger result is retained and every selected, not-yet-started case receives a persisted `NOT_EXECUTED` placeholder with `NOT_RUN` deterministic and Judge status, no thread, no calls, and `RUN_ABORTED_AFTER_RUNNER_ERROR` trigger evidence. `NOT_EXECUTED` is never a product `BLOCKED` outcome.

The aggregate summary is the sole source for JSON, Markdown, and console totals: PASS, FAIL, BLOCKED, RUNNER_INTERNAL_ERROR, NOT_EXECUTED, Executed, Planned, and Total. Its category sum must equal Planned, while Executed excludes only `NOT_EXECUTED`. Runner and safety failures have exit-code precedence.

For a case whose declarative objective-evidence requirements request official-Skills inventory, a successful before metadata inventory creates a generic finally postcondition. It attempts and persists the after metadata inventory after initial, resume, deterministic, Judge, or merge errors. An unavailable or changed after inventory is a safety failure; the original runner error remains secondary evidence. The inventory reads metadata only, never official Skill contents.

## Semantic automation contract

An indexed send condition may declare `require_question_format: true` and `required_term_groups`. The evaluator normalizes Unicode and whitespace, compares Latin alternatives case-insensitively on token boundaries, and compares CJK alternatives literally. All groups are required, while alternatives within a group are any-of. Case-owned multilingual alternatives may represent the same declared decision concept, but do not relax Q scope. Q heading, Question field, Recommended answer field, and every matched term must occur in the same Q block; no summary, ledger, or separate question can contribute evidence.

Cases may declare `required_keyword_groups` for generic any-of literal alternatives and `required_fact_work_assertions` for typed fact/work assertions. Each fact/work assertion has `status`, `affected_decision_pattern`, and `paired_decision_state`. The generic evaluator first extracts these three labelled fields from one visible, non-fenced formal record, normalizes legal Markdown wrappers, Unicode, and whitespace, then applies `affected_decision_pattern` as a full-value match to the extracted `Affected decision` field only. It never searches the raw record or whole transcript for a case pattern. A case-owned pattern may enumerate finite semantic identity alternatives, including an approved decision-specific modifier that retains a decision noun, but it must not become a broad keyword rule for `authorization`, `approval`, `decision`, or `Aurora.*release`. Missing fields, split records, prefix/suffix leakage, incidental prose, negation, and fenced samples do not qualify. The deterministic result contains typed expected and actual field evidence for the Judge input; Judge evaluation and merge semantics remain unchanged.

When a subsequent user input accepts a recommended answer or result, the Skill must first emit that question's formal acceptance ledger event with question ID, accepted result, and labelled resulting `ANSWERED` (or accepted equivalent) state. It must do so before any next question, Coverage Scan, summary, or session end. The post-input extractor requires that one same-record boundary and rejects wrong question IDs, future promises, pre-input events, fenced examples, negation, and cross-segment assembly. StaticTest includes a hermetic historical replay corpus for the observed DG-001 and DG-007 forms; it embeds minimal text fragments only and never reads `D:\temp` at test time.

Formal lifecycle evidence includes a labelled `Lifecycle`, current/resulting state, and a labelled historical `Previous`, `Prior`, or `Original` result/status when it records a supersession transition. A historical value may carry a same-line em-dash explanation; incidental prose, negation, bare tokens, and fenced samples remain invalid. Required subsequent inputs are gated by declared structural or typed evidence, not a single-language semantic phrase. Confirmation-only post-summary semantics are case-owned Judge evidence: deterministic rules retain the explicit confirmation-request and prohibit formal premature `CONVERGED` and a new question, but the semantic meaning that confirmation is the sole remaining condition is Judge-owned and does not require a single literal pattern. A fresh literal `Convergence status: NOT_CONVERGED` heading is not required when the existing summary already supplies that formal state.

## Source and payload encoding contract

The regression runner source is UTF-8 **with BOM** (`EF BB BF`) because Windows PowerShell 5.1 otherwise decodes no-BOM source through the local Default encoding. On Big5 systems, UTF-8 DBCS bytes can consume subsequent ASCII regex delimiters, corrupting production Unicode patterns and StaticTest fixtures before execution. The BOM affects only source decoding.

Stdin prompts, declarative fixture files, persisted evidence, and Judge transport remain UTF-8 **without BOM** and receive no automatic newline. StaticTest verifies both the source-BOM boundary and exact no-BOM payload bytes independently.

## K2 typed-evidence test matrix

K2 uses production `Test-Deterministic` and `Invoke-JudgeWithEvidenceGate` with injectable static adapters. It covers the DG-003 question-scoped Unicode matrix, typed PASS and typed deterministic FAIL evidence, generic pre-Judge typed-evidence rejection (missing evidence, count mismatch, null item, missing fields, non-Boolean `passed`, malformed nested evidence, and serialization loss), and a catalog case with no fact/work declaration. Gate rejection is a runner contract `BLOCKED` result with a generic subtype and never calls the Judge adapter.

## Generic targeted selection

`Targeted` selects catalog cases through one comma-separated `-CaseIds` string, for example:

```powershell
.\scripts\run-decision-grill-regression.ps1 -Mode Targeted -CaseIds "DG-001,DG-003,DG-005"
```

Each token is trimmed, must be a canonical `DG-###` identifier, resolves case-insensitively to the catalog's canonical ID, and is emitted in catalog declaration order. At least one ID is required. Blank tokens, duplicates (including case variants), unknown IDs, ranges, wildcards, aliases, titles, and indices are rejected. `Core` and `Full` reject `-CaseIds`; `DryRun` accepts it optionally and validates/reports the selected set without executing product cases or a Judge.

Targeted reuses the normal preflight, ActiveFolder safety, project-level Skill discovery, shared selected-case loop, resume transport, deterministic evaluation, Judge wrapper, fail-fast, NOT_EXECUTED, and aggregate reporting. Only selected cases appear in results or selected-set NOT_EXECUTED placeholders. Targeted validation never substitutes for a fresh Full regression and must use a fresh protected, non-reparse ActiveFolder.

## Selected-case result contract

The shared selected-case loop accepts exactly one object per selected case. It must carry the selected catalog case ID and one final category: `PASS`, `FAIL`, `BLOCKED`, `RUNNER_INTERNAL_ERROR`, or `NOT_EXECUTED`. Null, scalar, multiple pipeline outputs, missing or blank fields, unknown categories, and mismatched case IDs are runner-contract failures, never product outcomes.

For a malformed invocation result, the runner creates a generic `RUNNER_INTERNAL_ERROR` trigger containing the original output shape and any invocation exception, persists the aggregate JSON and Markdown, then creates `NOT_EXECUTED` only for the remaining selected cases. Unselected catalog cases never appear. The recovery path uses the same result contract in Targeted, Core, and Full flows.
