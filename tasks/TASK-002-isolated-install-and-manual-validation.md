# TASK-002: Isolated Installation and Manual Validation

## Task Metadata

- Task ID: TASK-002
- Product: decision-grill
- Version: v0.1
- Repository: wushengchia-tw/ai-skills-lab
- Branch: feature/grill-me-pro
- Baseline commit SHA: 566cdd27ee760683aa42700dd8fa3cb883f31474
- Pull Request: #1
- Pull Request state: Draft
- Status: APPROVED_FOR_ISOLATED_INSTALL_AND_SMOKE_VALIDATION
- Task type: Isolated installation and manual acceptance validation
- Installation authorization: Granted for isolated temporary project only
- Manual test authorization: Not granted for DG-001 through DG-020
- Commit authorization: Not granted
- Push authorization: Not granted
- Merge authorization: Not granted

## Objective

Validate `decision-grill` v0.1 in an isolated environment without changing the repository implementation files or the user's normal Skill installation.

The validation must determine whether:

1. The Skill can be installed independently.
2. It does not require `grill-me`.
3. Its metadata and invocation behavior work as specified.
4. It remains stateless.
5. It does not modify files or invoke other Skills automatically.
6. All 20 manual acceptance scenarios pass.
7. The Draft PR is eligible for final review.

## Authoritative Sources

- `specs/SPEC-001-decision-grill-v0.1.md`
- `tasks/TASK-001-implement-decision-grill-v0.1.md`
- `skills/productivity/decision-grill/SKILL.md`
- `docs/productivity/decision-grill.md`
- `tests/manual/decision-grill-v0.1.md`
- Draft PR #1

## Validation Environment Requirements

The validation must use an isolated temporary environment.

Requirements:

- Do not install into the user's normal global Skill directory.
- Do not overwrite or modify any existing installed Skill.
- Do not modify the Repository working tree.
- Do not use the production StockPilot AI project.
- Do not use another active project containing valuable uncommitted work.
- Use a disposable temporary directory.
- Record the exact temporary directory used.
- Record the installation mechanism and destination.
- Remove the temporary installation after validation.
- Confirm cleanup after testing.

## Preflight Discovery

Before installation, identify the repository-supported Skill installation method by reading existing repository documentation and scripts.

Allowed read-only discovery includes:

- repository README files;
- existing installation documentation;
- package metadata;
- existing Skill directory conventions;
- command help output.

Do not assume an installation command.

If the repository does not document a safe isolated installation method, stop and report `INSTALLATION_METHOD_UNRESOLVED`.

Do not install anything during this task-document creation phase.

## Proposed Validation Phases

### Phase 1 — Environment Baseline

Record:

- operating system;
- shell;
- Codex or Skill host version;
- repository branch and HEAD;
- Draft PR number and state;
- existing global or user Skill locations, without exposing secrets;
- temporary validation directory;
- pre-test Repository status.

### Phase 2 — Isolated Installation

When separately authorized:

1. Create a disposable temporary validation directory.
2. Install or copy only `decision-grill` using the repository-supported method.
3. Do not install `grill-me` as a dependency.
4. Confirm the installed Skill metadata:
   - `name: decision-grill`
   - approved description
   - `disable-model-invocation: true`
5. Confirm no other Skill was modified or installed.
6. Record installation evidence.
7. Stop if isolation cannot be guaranteed.

### Phase 3 — Smoke Validation

Before the 20 formal scenarios, verify:

1. `/decision-grill` can be invoked explicitly.
2. It does not activate automatically.
3. It starts with Intake and Scope Lock behavior.
4. It asks one primary question at a time.
5. It includes a recommended answer.
6. It does not write files.
7. It does not invoke another Skill.
8. It can produce a `NOT_CONVERGED` early-stop summary.

Any smoke-test failure blocks formal testing.

### Phase 4 — Manual Acceptance Tests

Execute DG-001 through DG-020 in order.

For every test record:

- Test ID
- Execution date and time
- Test environment
- Exact user input
- Relevant Agent output
- Observed ledger or decision state
- Observed convergence status
- Actual result
- Status
- Evidence or notes
- Finding ID, when applicable

Allowed final test statuses:

- PASS
- FAIL
- BLOCKED

Do not use partial pass.

Do not silently modify the expected result to match observed behavior.

### Phase 5 — Repository Mutation Check

Before and after installation and testing, record:

```powershell
git status --short
git diff --check
git rev-parse HEAD
```

Required outcome:

- HEAD unchanged.
- Repository working tree unchanged.
- No implementation file changed.
- No manual test file changed during execution.
- No new tracked or untracked Repository file created.

Test results must not be written into the Repository during this validation run unless separately authorized later.

### Phase 6 — Cleanup

After testing:

- Remove the isolated temporary Skill installation.
- Remove disposable validation directories.
- Confirm the normal user Skill environment was not modified.
- Confirm Repository working tree remains clean.
- Record cleanup result.

## Evidence Handling

During validation, results must be returned in the Codex completion report only.

Do not write evidence, logs, screenshots, transcripts, or updated test statuses into the Repository.

Do not modify:

- `tests/manual/decision-grill-v0.1.md`
- `skills/productivity/decision-grill/SKILL.md`
- `docs/productivity/decision-grill.md`
- review, decisions, specs, or tasks files

A later separately approved task may persist reviewed test results.

## Finding Classification

Use only:

- **BLOCKER** — installation isolation fails, repository mutation occurs, a core safety boundary is violated, or a required test cannot safely execute.
- **IMPORTANT** — a SPEC-001 behavior fails or a manual acceptance scenario fails.
- **MINOR** — wording, clarity, or non-behavioral documentation issue.

Every finding must contain:

- Finding ID
- Severity
- Related test
- Observed behavior
- Expected behavior
- Evidence
- Required correction
- Retest requirement

## Validation Pass Gate

Validation passes only when:

- Isolated installation succeeds.
- `grill-me` is not required.
- Explicit invocation succeeds.
- Automatic invocation does not occur.
- Smoke validation passes.
- DG-001 through DG-020 all have status PASS.
- No BLOCKER finding exists.
- No IMPORTANT finding exists.
- No Repository file changes.
- No normal user Skill installation changes.
- Temporary installation is fully removed.
- Draft PR remains open and Draft.
- No commit, push, merge, or PR-state change occurs.

## Draft PR Eligibility Rule

PR #1 may be recommended for final review only when the Validation Pass Gate is fully satisfied.

This task must not:

- mark the PR ready for review;
- approve the PR;
- merge the PR;
- close the PR;
- modify the PR body;
- create another PR.

## Stop Conditions

Immediately stop and report if:

- branch or HEAD differs;
- working tree is not clean;
- PR #1 is not open and Draft;
- isolated installation cannot be guaranteed;
- the supported installation method is unresolved;
- installation would modify a normal user Skill directory;
- `grill-me` becomes a required dependency;
- Repository files would need modification;
- smoke validation fails;
- a test could cause unsafe or irreversible effects;
- credentials or secrets would be exposed;
- Product Owner authorization has not been explicitly granted.

## Product Owner Authorization Record

- Preflight discovery authorization: COMPLETED
- Installation authorization: GRANTED
- Installation authorization scope: Isolated disposable project-level installation only
- Smoke validation authorization: GRANTED
- Manual test authorization: NOT_GRANTED
- Authorized by: Product Owner
- Authorization date: 2026-07-29
- Authorized source directory: A disposable clone of `wushengchia-tw/ai-skills-lab` checked out to `feature/grill-me-pro`
- Authorized temporary test project: A new disposable directory outside `D:\ai-skills-lab`
- Authorized installation method: `npx skills@latest add <disposable-source-path> --agent codex --skill decision-grill`
- Authorized project Skill destination: `.agents/skills/decision-grill`
- Authorized loading method: Start a new Codex session from the disposable test project
- Authorized cleanup method: Close the test session and remove both disposable directories
- Normal user Skill directory write authorization: Not granted
- Repository write authorization: Not granted
- Test-result persistence authorization: Not granted
- DG-001 through DG-020 execution authorization: Not granted
- Commit authorization: Not granted after this TASK-002 authorization commit
- Push authorization: Not granted after this TASK-002 authorization commit
- PR state-change authorization: Not granted
- Merge authorization: Not granted

## Completion Report Format

When separately authorized and completed, report only:

- branch
- HEAD
- PR number and Draft state
- operating system and shell
- isolated validation directory
- installation method
- installation result
- `grill-me` dependency check
- metadata check
- explicit invocation check
- automatic invocation check
- smoke validation result
- DG-001 through DG-020 results
- PASS count
- FAIL count
- BLOCKED count
- BLOCKER findings
- IMPORTANT findings
- MINOR findings
- repository pre-test status
- repository post-test status
- cleanup result
- normal user Skill environment unchanged
- Validation Pass Gate result
- recommendation for final PR review: YES or NO
- confirmation that no files, commits, pushes, PR states, or merge were changed

## Stop Condition

This task is authorized only for an isolated disposable project-level installation and Smoke Validation of `decision-grill`.

The authorization does not permit execution of DG-001 through DG-020, persistence of test results, modification of Repository files, modification of the normal user Skill environment, PR state changes, or merge.

After Smoke Validation and cleanup, stop and return the completion report for Product Owner review.
