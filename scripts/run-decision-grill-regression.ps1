[CmdletBinding()]
param(
    [ValidateSet('Discovery', 'ResumeProbe', 'Utf8Probe', 'DryRun', 'Core', 'Full', 'Targeted', 'StaticTest')]
    [string]$Mode = 'DryRun',
    [string]$CaseIds,
    [string]$ActiveFolder,
    [string]$CodexPath,
    [ValidateRange(1, 600)]
    [int]$CodexTimeoutSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$ExpectedBranch = 'feature/grill-me-pro'
$ExpectedHead = 'cd2427630d949465dbafd462cf26a6f22dae664c'
$GlobalSkills = Join-Path $env:USERPROFILE '.codex\skills'
$OfficialSystemSkills = Join-Path $GlobalSkills '.system'
$SourceSkill = Join-Path $RepoRoot 'skills\productivity\decision-grill\SKILL.md'
$InstalledSkill = $null
$SkillHashValidation = [pscustomobject]@{ source_skill_path=$SourceSkill; source_skill_sha256=$null; installed_skill_path=$null; installed_skill_sha256=$null; hashes_match=$false; installed_skill_exists=$false }
$ProductSpecPath = Join-Path $RepoRoot 'specs\SPEC-001-decision-grill-v0.1.md'
$ExpectedProductSpecSha256 = 'B1BA5BF746E317CD1431B6E0F3351D0D438CBD66C3A7D48738ED7F37DB90129E'
$RemediationSpecPath = Join-Path $RepoRoot 'docs\productivity\decision-grill-remediation-spec.md'
$ExpectedRemediationSpecSha256 = '2E8B0C0B1C3758831C6A4DEB2D7203838338280F181D0FBB44542A1330ED03F2'
$CasesPath = Join-Path $RepoRoot 'tests\automation\decision-grill-cases.json'
$SchemaPath = Join-Path $RepoRoot 'tests\automation\decision-grill-result.schema.json'
$JudgePromptPath = Join-Path $RepoRoot 'tests\automation\decision-grill-judge-prompt.md'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$OutputRoot = Join-Path 'D:\temp' "decision-grill-dg-run-$Stamp"
$RawDir = Join-Path $OutputRoot 'raw'
$TurnsDir = Join-Path $OutputRoot 'turns'
$ResultsDir = Join-Path $OutputRoot 'results'
$EightSections = @('## 1. Confirmed Decisions','## 2. Provisional Decisions','## 3. Assumptions','## 4. Unknowns','## 5. Deferred Questions','## 6. Risks','## 7. Out of Scope','## 8. Recommended Next Action')
$ResolvedCodexPath = $null
$CodexVersion = $null
$CodexIsWindowsApps = $false
$RunnerInternalError = $false
$CodexTimeoutObserved = $false
$CodexInvocationSequence = 0
$PreflightActiveFolderCanonical = $null
$WorkingTreeIdentity = $null
$CodexInvocationMock = $null
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$AuthorizedDirtyWorkingTree = @(
    [pscustomobject]@{ path='docs/productivity/decision-grill.md'; xy=' M' },
    [pscustomobject]@{ path='skills/productivity/decision-grill/SKILL.md'; xy=' M' },
    [pscustomobject]@{ path='specs/SPEC-001-decision-grill-v0.1.md'; xy=' M' },
    [pscustomobject]@{ path='tests/manual/decision-grill-v0.1.md'; xy=' M' },
    [pscustomobject]@{ path='docs/productivity/decision-grill-remediation-spec.md'; xy='??' },
    [pscustomobject]@{ path='scripts/run-decision-grill-regression.ps1'; xy='??' },
    [pscustomobject]@{ path='tests/automation/README.md'; xy='??' },
    [pscustomobject]@{ path='tests/automation/decision-grill-cases.json'; xy='??' },
    [pscustomobject]@{ path='tests/automation/decision-grill-judge-prompt.md'; xy='??' },
    [pscustomobject]@{ path='tests/automation/decision-grill-result.schema.json'; xy='??' }
)

function New-OutputLayout {
    foreach ($Path in @($OutputRoot, $RawDir, $TurnsDir, $ResultsDir)) { New-Item -ItemType Directory -Force -Path $Path | Out-Null }
}

function Write-Utf8NoBom([string]$Path, [string]$Content, [switch]$NoOverwrite) {
    if (-not $NoOverwrite) {
        [System.IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
        return
    }
    $Stream = $null
    try {
        $Stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $Bytes = $Utf8NoBom.GetBytes($Content)
        $Stream.Write($Bytes, 0, $Bytes.Length)
    } finally {
        if ($null -ne $Stream) { $Stream.Dispose() }
    }
}

function Read-Utf8NoBom([string]$Path) {
    return [System.IO.File]::ReadAllText($Path, $Utf8NoBom)
}

function Get-Sha256([string]$LiteralPath) {
    $Sha256 = $null
    $Stream = $null
    try {
        $Sha256 = [System.Security.Cryptography.SHA256]::Create()
        $Stream = [System.IO.File]::OpenRead($LiteralPath)
        $Bytes = $Sha256.ComputeHash($Stream)
        return ((($Bytes | ForEach-Object { $_.ToString('x2') }) -join '').ToUpperInvariant())
    } finally {
        if ($null -ne $Stream) { $Stream.Dispose() }
        if ($null -ne $Sha256) { $Sha256.Dispose() }
    }
}

function Invoke-GitText([string]$Repository, [string[]]$Arguments) {
    $Output = @(& git -C $Repository @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed: $($Output -join '; ')" }
    return ($Output -join "`n").Trim()
}

function Get-GitPorcelainBytes([string]$Repository) {
    $Process = [Diagnostics.Process]::new()
    $Process.StartInfo = [Diagnostics.ProcessStartInfo]@{ FileName='git'; Arguments=('-C "{0}" status --porcelain=v1 -z --untracked-files=all' -f $Repository.Replace('"','\"')); UseShellExecute=$false; RedirectStandardOutput=$true; RedirectStandardError=$true; CreateNoWindow=$true }
    $Memory = [IO.MemoryStream]::new()
    try {
        if (-not $Process.Start()) { throw 'git status process did not start' }
        $ErrorTask = $Process.StandardError.ReadToEndAsync()
        $Process.StandardOutput.BaseStream.CopyTo($Memory)
        $Process.WaitForExit()
        $ErrorText = $ErrorTask.GetAwaiter().GetResult()
        if ($Process.ExitCode -ne 0) { throw "git status failed: $ErrorText" }
        return ,$Memory.ToArray()
    } finally { $Memory.Dispose(); $Process.Dispose() }
}

function ConvertTo-NormalizedRepositoryRelativePath([string]$Repository, [string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or [IO.Path]::IsPathRooted($Path) -or $Path -match '^[A-Za-z]:' -or $Path -match '^(?:\\\\|//)') { throw "invalid repository-relative path: $Path" }
    $Normalized = ($Path -replace '\\','/').Trim()
    $Segments = @($Normalized -split '/')
    if (@($Segments | Where-Object { [string]::IsNullOrWhiteSpace($_) -or $_ -eq '.' -or $_ -eq '..' }).Count -ne 0) { throw "invalid repository-relative path: $Path" }
    $Candidate = [IO.Path]::GetFullPath((Join-Path $Repository ($Segments -join '\\')))
    if (-not (Test-PathIsWithinDirectoryOrdinalIgnoreCase $Candidate $Repository) -or (Test-PathEqualOrdinalIgnoreCase $Candidate $Repository)) { throw "repository-relative path escapes repository: $Path" }
    return ($Segments -join '/')
}

function ConvertFrom-GitPorcelainV1Z([byte[]]$Bytes, [string]$Repository) {
    $Text = [Text.Encoding]::UTF8.GetString($Bytes)
    $Parts = @($Text -split "`0")
    $Entries = [Collections.Generic.List[object]]::new()
    $Keys = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    for ($Index = 0; $Index -lt $Parts.Count; $Index++) {
        $Record = $Parts[$Index]
        if ($Record.Length -eq 0) { continue }
        if ($Record.Length -lt 4 -or $Record[2] -ne ' ') { throw "invalid git porcelain v1 record: $Record" }
        $Xy = $Record.Substring(0,2)
        $Path = ConvertTo-NormalizedRepositoryRelativePath $Repository $Record.Substring(3)
        $OriginalPath = $null
        if ($Xy[0] -in @('R','C') -or $Xy[1] -in @('R','C')) {
            $Index++
            if ($Index -ge $Parts.Count -or [string]::IsNullOrWhiteSpace($Parts[$Index])) { throw "rename/copy record lacks original path: $Record" }
            $OriginalPath = ConvertTo-NormalizedRepositoryRelativePath $Repository $Parts[$Index]
        }
        if (-not $Keys.Add($Path)) { throw "duplicate normalized working-tree path: $Path" }
        $Entries.Add([pscustomobject]@{ path=$Path; xy=$Xy; original_path=$OriginalPath })
    }
    return @($Entries | Sort-Object path)
}

function Get-WorkingTreeIdentity([string]$Repository = $RepoRoot) {
    $CanonicalRepository = Get-NormalizedAbsolutePath $Repository
    Assert-PathChainHasNoReparsePoint -Path $CanonicalRepository -Purpose 'repository working-tree identity' | Out-Null
    $Branch = Invoke-GitText $CanonicalRepository @('branch','--show-current')
    $Head = Invoke-GitText $CanonicalRepository @('rev-parse','HEAD')
    $Entries = @(ConvertFrom-GitPorcelainV1Z (Get-GitPorcelainBytes $CanonicalRepository) $CanonicalRepository)
    $Evidence = [Collections.Generic.List[object]]::new()
    foreach ($Entry in $Entries) {
        $FullPath = Join-Path $CanonicalRepository ($Entry.path -replace '/','\\')
        $Chain = Test-PathChainHasNoReparsePoint $FullPath 'repository working-tree entry'
        $Exists = Test-Path -LiteralPath $FullPath
        $Item = if ($Exists) { Get-Item -LiteralPath $FullPath -Force } else { $null }
        $IsFile = $null -ne $Item -and -not $Item.PSIsContainer
        $IsReparse = $null -ne $Item -and (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
        $Evidence.Add([pscustomobject]@{ path=$Entry.path; xy=$Entry.xy; original_path=$Entry.original_path; exists=$Exists; item_type=if($IsFile){'file'}elseif($null -ne $Item){'directory'}else{'missing'}; length=if($IsFile){$Item.Length}else{$null}; sha256=if($IsFile -and $Chain.passed -and -not $IsReparse){Get-Sha256 $FullPath}else{$null}; path_chain_safe=$Chain.passed })
    }
    [pscustomobject]@{ repository=$CanonicalRepository; branch=$Branch; head=$Head; entries=@($Evidence | Sort-Object path) }
}

function Test-WorkingTreeBaseline([object]$Identity) {
    $Failures = [Collections.Generic.List[string]]::new()
    if ($Identity.branch -ne $ExpectedBranch) { $Failures.Add("branch expected $ExpectedBranch; actual $($Identity.branch)") }
    if ($Identity.head -ne $ExpectedHead) { $Failures.Add("HEAD expected $ExpectedHead; actual $($Identity.head)") }
    $Entries = @($Identity.entries)
    $Mode = if ($Entries.Count -eq 0) { 'clean' } else { 'authorized_dirty' }
    if ($Entries.Count -ne 0) {
        $Expected = @($AuthorizedDirtyWorkingTree | Sort-Object path)
        if ($Entries.Count -ne $Expected.Count) { $Failures.Add("authorized dirty baseline requires $($Expected.Count) entries; actual $($Entries.Count)") }
        for ($Index=0; $Index -lt $Expected.Count; $Index++) {
            if ($Index -ge $Entries.Count) { break }
            $Actual = $Entries[$Index]
            $Wanted = $Expected[$Index]
            if (-not [string]::Equals($Actual.path,$Wanted.path,[StringComparison]::OrdinalIgnoreCase) -or $Actual.xy -ne $Wanted.xy) { $Failures.Add("working-tree entry mismatch: expected $($Wanted.xy) $($Wanted.path); actual $($Actual.xy) $($Actual.path)") }
        }
    }
    foreach ($Entry in $Entries) {
        if ($Entry.xy -notin @(' M','??')) { $Failures.Add("disallowed git status $($Entry.xy): $($Entry.path)") }
        if ($Entry.original_path) { $Failures.Add("rename/copy is not allowed: $($Entry.path)") }
        if (-not $Entry.exists -or $Entry.item_type -ne 'file' -or -not $Entry.path_chain_safe -or [string]::IsNullOrWhiteSpace($Entry.sha256)) { $Failures.Add("working-tree identity cannot hash safe regular file: $($Entry.path)") }
    }
    [pscustomobject]@{ passed=($Failures.Count -eq 0); mode=$Mode; failures=@($Failures); identity=$Identity }
}

function Compare-WorkingTreeIdentity([object]$Expected, [object]$Actual) {
    $ExpectedJson = $Expected | ConvertTo-Json -Depth 8 -Compress
    $ActualJson = $Actual | ConvertTo-Json -Depth 8 -Compress
    [pscustomobject]@{ passed=($ExpectedJson -eq $ActualJson); expected=$ExpectedJson; actual=$ActualJson }
}

function Assert-WorkingTreeIdentity([string]$Purpose) {
    if ($null -eq $script:WorkingTreeIdentity) { return }
    $Actual = Get-WorkingTreeIdentity $RepoRoot
    $Validation = Test-WorkingTreeBaseline $Actual
    $Comparison = Compare-WorkingTreeIdentity $script:WorkingTreeIdentity $Actual
    if (-not $Validation.passed -or -not $Comparison.passed) {
        $script:RunnerInternalError = $true
        throw "WORKING_TREE_IDENTITY_CHANGED [$Purpose]: $($Validation.failures -join '; '); expected=$($Comparison.expected); actual=$($Comparison.actual)"
    }
}

function Test-ObjectProperty([object]$Object, [string]$Name) {
    return $null -ne $Object -and $null -ne $Object.PSObject.Properties[$Name]
}

function Get-OptionalArray([object]$Object, [string]$Name) {
    if (-not (Test-ObjectProperty $Object $Name)) { return @() }
    $Value = $Object.PSObject.Properties[$Name].Value
    if ($null -eq $Value) { return @() }
    return @($Value)
}

function Get-OptionalString([object]$Object, [string]$Name, [string]$Default = $null) {
    if (-not (Test-ObjectProperty $Object $Name)) { return $Default }
    $Value = $Object.PSObject.Properties[$Name].Value
    if ($null -eq $Value) { return $Default }
    return [string]$Value
}

function Get-OptionalObject([object]$Object, [string]$Name) {
    if (-not (Test-ObjectProperty $Object $Name)) { return $null }
    return $Object.PSObject.Properties[$Name].Value
}

function Get-OptionalBoolean([object]$Object, [string]$Name) {
    if (-not (Test-ObjectProperty $Object $Name)) { return [pscustomobject]@{ exists=$false; value=$null } }
    return [pscustomobject]@{ exists=$true; value=[bool]$Object.PSObject.Properties[$Name].Value }
}

function Resolve-CaseSelection([object[]]$Catalog, [string]$Declaration, [switch]$Required) {
    $Failures = [System.Collections.Generic.List[string]]::new()
    $Requested = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    if ([string]::IsNullOrWhiteSpace($Declaration)) {
        if ($Required) { $Failures.Add('CaseIds is required for Targeted mode') }
    } else {
        foreach ($RawToken in $Declaration.Split(',')) {
            $Token = $RawToken.Trim()
            if ([string]::IsNullOrWhiteSpace($Token)) { $Failures.Add('CaseIds contains a blank token'); continue }
            if ($Token -notmatch '(?i)^DG-\d{3}$') { $Failures.Add("CaseIds token is not a canonical case ID: $Token"); continue }
            if (-not $Requested.Add($Token)) { $Failures.Add("CaseIds contains a duplicate canonical ID: $Token") }
        }
        foreach ($Token in @($Requested)) {
            if (@($Catalog | Where-Object { $_.case_id -ieq $Token }).Count -ne 1) { $Failures.Add("CaseIds contains an unknown ID: $Token") }
        }
    }
    $Selected = @($Catalog | Where-Object { $Requested.Contains([string]$_.case_id) })
    if ($Required -and $Selected.Count -eq 0 -and $Failures.Count -eq 0) { $Failures.Add('CaseIds must select at least one catalog case') }
    return [pscustomobject]@{ passed=($Failures.Count -eq 0); declaration=$Declaration; requested_ids=@($Requested); selected_cases=@($Selected); selected_case_ids=@($Selected | ForEach-Object { $_.case_id }); failures=@($Failures) }
}

function Test-ModeCaseSelectionContract([string]$RequestedMode, [string]$Declaration, [object[]]$Catalog) {
    if ($RequestedMode -in @('Core','Full') -and -not [string]::IsNullOrWhiteSpace($Declaration)) { return [pscustomobject]@{passed=$false;selection=$null;failures=@("CaseIds is not permitted for $RequestedMode mode")} }
    if ($RequestedMode -eq 'Targeted') {
        $Selection = Resolve-CaseSelection $Catalog $Declaration -Required
        return [pscustomobject]@{passed=$Selection.passed;selection=$Selection;failures=@($Selection.failures)}
    }
    if ($RequestedMode -eq 'DryRun' -and -not [string]::IsNullOrWhiteSpace($Declaration)) {
        $Selection = Resolve-CaseSelection $Catalog $Declaration
        return [pscustomobject]@{passed=$Selection.passed;selection=$Selection;failures=@($Selection.failures)}
    }
    return [pscustomobject]@{passed=$true;selection=[pscustomobject]@{passed=$true;declaration=$Declaration;requested_ids=@();selected_cases=@();selected_case_ids=@();failures=@()};failures=@()}
}

function Get-RunnerException([System.Management.Automation.ErrorRecord]$ErrorRecord, [string]$CaseId) {
    [pscustomobject]@{
        reason = 'RUNNER_INTERNAL_ERROR'
        exception_type = $ErrorRecord.Exception.GetType().FullName
        message = $ErrorRecord.Exception.Message
        script_line = $ErrorRecord.InvocationInfo.ScriptLineNumber
        stack = $ErrorRecord.ScriptStackTrace
        active_case_id = $CaseId
    }
}

function Test-FixtureMetadata([object]$Case) {
    $CaseId = Get-OptionalString $Case 'case_id' '<missing case_id>'
    $Failures = [System.Collections.Generic.List[string]]::new()
    if (-not (Test-ObjectProperty $Case 'fixtures')) {
        $Failures.Add("$CaseId missing required property: fixtures")
        return @($Failures)
    }
    $Fixtures = $Case.PSObject.Properties['fixtures'].Value
    if ($null -eq $Fixtures -or $Fixtures -is [string] -or -not ($Fixtures -is [System.Collections.IEnumerable])) {
        $Failures.Add("$CaseId fixtures must be an array")
        return @($Failures)
    }
    foreach ($Fixture in @($Fixtures)) {
        if ($null -eq $Fixture -or $Fixture -is [string]) {
            $Failures.Add("$CaseId fixture must be an object")
            continue
        }
        $Names = @($Fixture.PSObject.Properties.Name)
        foreach ($Required in @('relative_path','content')) {
            if ($Names -notcontains $Required) { $Failures.Add("$CaseId fixture missing required property: $Required") }
        }
        foreach ($Name in $Names) {
            if (@('relative_path','content') -notcontains $Name) { $Failures.Add("$CaseId fixture has unsupported property: $Name") }
        }
        if (Test-ObjectProperty $Fixture 'relative_path') {
            $RelativePath = Get-OptionalObject $Fixture 'relative_path'
            if ($RelativePath -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$RelativePath)) { $Failures.Add("$CaseId fixture relative_path must be a non-blank string") }
        }
        if (Test-ObjectProperty $Fixture 'content') {
            $Content = Get-OptionalObject $Fixture 'content'
            if ($Content -isnot [string]) { $Failures.Add("$CaseId fixture content must be a string") }
        }
    }
    return @($Failures)
}

function Test-CaseContract([object]$Case) {
    $RequiredStrings = @('case_id','title','execution_priority','fixture_setup','desktop_initial_input','cli_initial_input','send_condition','expected_behavior','observable_evidence','file_mutation_policy','automatic_skill_invocation_policy')
    $RequiredArrays = @('ordered_subsequent_inputs','pass_conditions','fail_conditions','blocked_conditions','allowed_tools','forbidden_tools','fixtures')
    $Failures = [System.Collections.Generic.List[string]]::new()
    $CaseId = Get-OptionalString $Case 'case_id' '<missing case_id>'
    foreach ($Name in $RequiredStrings) {
        if (-not (Test-ObjectProperty $Case $Name)) { $Failures.Add("$CaseId missing required property: $Name"); continue }
        if ([string]::IsNullOrWhiteSpace([string]$Case.PSObject.Properties[$Name].Value)) { $Failures.Add("$CaseId required property is null or whitespace: $Name") }
    }
    foreach ($Name in $RequiredArrays) {
        if (-not (Test-ObjectProperty $Case $Name)) { $Failures.Add("$CaseId missing required property: $Name"); continue }
        $Value = $Case.PSObject.Properties[$Name].Value
        if ($null -eq $Value -or $Value -is [string] -or -not ($Value -is [System.Collections.IEnumerable])) { $Failures.Add("$CaseId required array has invalid type: $Name") }
    }
    try {
        foreach ($FixtureFailure in @(Test-FixtureMetadata $Case)) { $Failures.Add($FixtureFailure) }
        [void](Get-OptionalArray $Case 'required_keywords')
        $KeywordGroups = @(Get-OptionalArray $Case 'required_keyword_groups')
        foreach ($Group in $KeywordGroups) { if ($Group -is [string] -or $null -eq $Group -or @($Group).Count -eq 0 -or @($Group | Where-Object { $_ -isnot [string] -or [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) { $Failures.Add("$CaseId required_keyword_groups has invalid group") } }
        [void](Get-OptionalArray $Case 'forbidden_keywords')
        [void](Get-OptionalArray $Case 'post_input_required_patterns')
        [void](Get-OptionalArray $Case 'post_input_forbidden_patterns')
        [void](Get-OptionalArray $Case 'required_states')
        $FactWorkAssertions = @(Get-OptionalArray $Case 'required_fact_work_assertions')
        foreach ($Assertion in $FactWorkAssertions) {
            $Status = Get-OptionalString $Assertion 'status'; $Affected = Get-OptionalString $Assertion 'affected_decision_pattern'; $Paired = Get-OptionalString $Assertion 'paired_decision_state'
            if ($Status -ne 'RESEARCH_REQUIRED') { $Failures.Add("$CaseId fact/work assertion has invalid status") }
            if ([string]::IsNullOrWhiteSpace($Affected)) { $Failures.Add("$CaseId fact/work assertion missing affected_decision_pattern") } else { try { [void][regex]::new($Affected) } catch { $Failures.Add("$CaseId fact/work assertion has invalid affected_decision_pattern") } }
            if (@('OPEN','ANSWERED','PROVISIONAL','DEFERRED','BLOCKED','OUT_OF_SCOPE','SUPERSEDED') -notcontains $Paired) { $Failures.Add("$CaseId fact/work assertion has invalid paired_decision_state") }
        }
        if ($FactWorkAssertions.Count -gt 0 -and @(Get-OptionalArray $Case 'required_states') -contains 'RESEARCH_REQUIRED') { $Failures.Add("$CaseId RESEARCH_REQUIRED must not be a required decision state") }
        [void](Get-OptionalArray $Case 'required_states_all')
        [void](Get-OptionalArray $Case 'required_states_any')
        [void](Get-OptionalArray $Case 'forbidden_states')
        [void](Get-OptionalArray $Case 'allowed_states')
        $SemanticRequirements = @(Get-OptionalArray $Case 'judge_semantic_requirements')
        foreach ($SemanticRequirement in $SemanticRequirements) {
            $SemanticId = Get-OptionalString $SemanticRequirement 'id'
            $SemanticDescription = Get-OptionalString $SemanticRequirement 'description'
            if ([string]::IsNullOrWhiteSpace($SemanticId) -or [string]::IsNullOrWhiteSpace($SemanticDescription)) { $Failures.Add("$CaseId judge_semantic_requirements item requires id and description") }
        }
        [void](Get-OptionalObject $Case 'send_condition_requirements')
        $Inputs = @(Get-OptionalArray $Case 'ordered_subsequent_inputs')
        foreach ($DeclaredPrompt in $Inputs) {
            if ($null -eq $DeclaredPrompt -or [string]::IsNullOrWhiteSpace([string]$DeclaredPrompt)) { $Failures.Add("$CaseId ordered_subsequent_inputs contains a null or whitespace prompt") }
        }
        $Requirements = @(Get-OptionalArray $Case 'send_condition_requirements')
        if ($Inputs.Count -gt 0) {
            $Indices = [System.Collections.Generic.List[int]]::new()
            foreach ($Requirement in $Requirements) {
                $Index = Get-OptionalObject $Requirement 'input_index'
                $Mode = Get-OptionalString $Requirement 'mode'
                if ($null -eq $Index -or $Index -isnot [int] -or $Index -lt 1 -or $Index -gt $Inputs.Count) { $Failures.Add("$CaseId subsequent input requirement has invalid input_index") } else { $Indices.Add([int]$Index) }
                if ([string]::IsNullOrWhiteSpace($Mode)) { $Failures.Add("$CaseId subsequent input requirement missing mode") }
                elseif (@('required','conditional') -notcontains $Mode) { $Failures.Add("$CaseId subsequent input requirement has unknown mode: $Mode") }
                if (@(Get-OptionalArray $Requirement 'required_patterns').Count -eq 0 -and @(Get-OptionalArray $Requirement 'required_explicit_states').Count -eq 0) { $Failures.Add("$CaseId subsequent input requirement lacks declarative applicability evidence") }
                $QuestionFormat = Get-OptionalBoolean $Requirement 'require_question_format'
                $TermGroups = @(Get-OptionalArray $Requirement 'required_term_groups')
                if ($QuestionFormat.exists -and $QuestionFormat.value -isnot [bool]) { $Failures.Add("$CaseId require_question_format must be Boolean") }
                if ($QuestionFormat.exists -or $TermGroups.Count -gt 0) {
                    if (-not $QuestionFormat.exists -or -not $QuestionFormat.value -or $TermGroups.Count -eq 0) { $Failures.Add("$CaseId question-scoped condition requires format and term groups") }
                    foreach ($Group in $TermGroups) { if ($Group -is [string] -or $null -eq $Group -or @($Group).Count -eq 0 -or @($Group | Where-Object { $_ -isnot [string] -or [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) { $Failures.Add("$CaseId required_term_groups has invalid group") } }
                }
            }
            if ($Requirements.Count -ne $Inputs.Count) { $Failures.Add("$CaseId subsequent input requirement count does not match inputs") }
            if (@($Indices | Select-Object -Unique).Count -ne $Indices.Count) { $Failures.Add("$CaseId subsequent input requirement has duplicate index") }
            foreach ($ExpectedIndex in 1..$Inputs.Count) { if ($Indices -notcontains $ExpectedIndex) { $Failures.Add("$CaseId subsequent input requirement missing index: $ExpectedIndex") } }
        } elseif ($Requirements.Count -gt 0) { $Failures.Add("$CaseId has extra subsequent input requirements") }
        [void](Get-OptionalArray $Case 'required_sections')
        [void](Get-OptionalArray $Case 'required_statuses')
        [void](Get-OptionalArray $Case 'forbidden_statuses')
        [void](Get-OptionalString $Case 'expected_skill')
        [void](Get-OptionalArray $Case 'hash_checks')
        [void](Get-OptionalArray $Case 'file_checks')
        [void](Get-OptionalString $Case 'judge_overrides')
        [void](Get-OptionalString $Case 'accepted_event_pattern')
        [void](Get-OptionalBoolean $Case 'review_required')
        $StateAudit = Get-StateAssertionAudit $Case
        foreach ($StateFailure in @($StateAudit.failures)) { $Failures.Add("$CaseId state assertion error: $StateFailure") }
        [void](Test-Deterministic $Case '' '' '')
    } catch { $Failures.Add("$CaseId deterministic prepare error: $($_.Exception.Message)") }
    return [pscustomobject]@{ case_id=$CaseId; passed=($Failures.Count -eq 0); failures=@($Failures) }
}

function Get-TreeInventory([string]$Path) {
    Assert-PathChainHasNoReparsePoint -Path $Path -Purpose 'active-folder inventory'
    if (-not (Test-Path -LiteralPath $Path)) { throw "Inventory path is unavailable: $Path" }
    @(Get-ChildItem -LiteralPath $Path -Force -Recurse -File | ForEach-Object {
        [pscustomobject]@{ path = $_.FullName.Substring($Path.Length).TrimStart('\'); sha256 = Get-Sha256 -LiteralPath $_.FullName }
    } | Sort-Object path)
}

function Get-InventoryDigest([string]$Path) {
    $Json = (Get-TreeInventory $Path | ConvertTo-Json -Compress -Depth 4)
    $Bytes = [Text.Encoding]::UTF8.GetBytes($Json)
    ([Security.Cryptography.SHA256]::Create().ComputeHash($Bytes) | ForEach-Object ToString x2) -join ''
}

function Get-OfficialSkillsInventory {
    try {
        if (-not (Test-Path -LiteralPath $GlobalSkills -PathType Container) -or -not (Test-Path -LiteralPath $OfficialSystemSkills -PathType Container)) {
            return [pscustomobject]@{ available=$false; reason='official or global Skills inventory path unavailable' }
        }
        $Metadata = @(Get-ChildItem -LiteralPath $GlobalSkills -Force -Recurse | ForEach-Object {
            [pscustomobject]@{ relative_path=$_.FullName.Substring($GlobalSkills.Length).TrimStart('\'); item_type=if ($_.PSIsContainer) {'directory'} else {'file'}; length=if ($_.PSIsContainer) {$null} else {$_.Length}; last_write_utc=$_.LastWriteTimeUtc.ToString('o'); attributes=[string]$_.Attributes }
        } | Sort-Object relative_path)
        $MetadataJson = $Metadata | ConvertTo-Json -Compress -Depth 5
        $MetadataDigest = Get-StringSha256 $MetadataJson
        return [pscustomobject]@{
            available=$true
            global_skills_root=$GlobalSkills
            official_system_root=$OfficialSystemSkills
            inventory_mode='metadata-only; file contents are not read or saved'
            metadata_digest=$MetadataDigest
            metadata_item_count=$Metadata.Count
            global_decision_grill_present=(Test-Path -LiteralPath (Join-Path $GlobalSkills 'decision-grill'))
            global_grill_me_present=(Test-Path -LiteralPath (Join-Path $GlobalSkills 'grill-me'))
        }
    } catch { return [pscustomobject]@{ available=$false; reason=$_.Exception.Message } }
}

function New-DigestComparisonEvidence([string]$BeforeDigest, [string]$AfterDigest, [bool]$ComparisonExecuted = $true) {
    $BeforeDigestAvailable = -not [string]::IsNullOrWhiteSpace($BeforeDigest)
    $AfterDigestAvailable = -not [string]::IsNullOrWhiteSpace($AfterDigest)
    $DigestComparisonAvailable = $ComparisonExecuted -and $BeforeDigestAvailable -and $AfterDigestAvailable
    [pscustomobject]@{
        before_digest_available = $BeforeDigestAvailable
        after_digest_available = $AfterDigestAvailable
        digest_comparison_available = $DigestComparisonAvailable
        digest_unchanged = $(if ($DigestComparisonAvailable) { $BeforeDigest -eq $AfterDigest } else { $false })
    }
}

function New-JudgeEvidence([string]$BeforeDigest, [string]$AfterDigest, [object]$OfficialBefore, [object]$OfficialAfter, [bool]$DigestComparisonExecuted = $true, [object[]]$ConditionalInputEvidence = @()) {
    $DigestComparison = New-DigestComparisonEvidence $BeforeDigest $AfterDigest $DigestComparisonExecuted
    $OfficialBeforeAvailable = Get-OptionalBoolean $OfficialBefore 'available'
    $OfficialAfterAvailable = Get-OptionalBoolean $OfficialAfter 'available'
    $OfficialBeforeMetadataDigest = Get-OptionalString $OfficialBefore 'metadata_digest'
    $OfficialAfterMetadataDigest = Get-OptionalString $OfficialAfter 'metadata_digest'
    $OfficialBeforeDecisionGrill = Get-OptionalBoolean $OfficialBefore 'global_decision_grill_present'
    $OfficialAfterDecisionGrill = Get-OptionalBoolean $OfficialAfter 'global_decision_grill_present'
    $OfficialBeforeGrillMe = Get-OptionalBoolean $OfficialBefore 'global_grill_me_present'
    $OfficialAfterGrillMe = Get-OptionalBoolean $OfficialAfter 'global_grill_me_present'
    [pscustomobject]@{
        active_folder_inventory=[pscustomobject]@{ active_folder=$ActiveFolder; before_digest=$BeforeDigest; after_digest=$AfterDigest; before_digest_available=$DigestComparison.before_digest_available; after_digest_available=$DigestComparison.after_digest_available; digest_comparison_available=$DigestComparison.digest_comparison_available; digest_unchanged=$DigestComparison.digest_unchanged }
        conditional_input_evidence=@($ConditionalInputEvidence)
        official_skills_inventory=@{ before=$OfficialBefore; after=$OfficialAfter; before_available=($OfficialBeforeAvailable.exists -and $OfficialBeforeAvailable.value); after_available=($OfficialAfterAvailable.exists -and $OfficialAfterAvailable.value); metadata_only_inventory=((Get-OptionalString $OfficialBefore 'inventory_mode') -match 'metadata-only'); unchanged=($OfficialBeforeAvailable.exists -and $OfficialBeforeAvailable.value -and $OfficialAfterAvailable.exists -and $OfficialAfterAvailable.value -and $OfficialBeforeMetadataDigest -eq $OfficialAfterMetadataDigest -and $OfficialBeforeDecisionGrill.exists -and $OfficialBeforeDecisionGrill.value -eq $OfficialAfterDecisionGrill.value -and $OfficialBeforeGrillMe.exists -and $OfficialBeforeGrillMe.value -eq $OfficialAfterGrillMe.value); limitation='metadata-only comparison cannot prove identical file bytes with unchanged metadata' }
    }
}

function Test-ObjectiveEvidenceRequirements([object]$Case, [object]$ObjectiveEvidence) {
    $Requirements = Get-OptionalObject $Case 'objective_evidence_requirements'
    $Missing = [System.Collections.Generic.List[string]]::new()
    if ($null -eq $Requirements) { return [pscustomobject]@{ passed=$true; missing=@() } }

    $Inventory = $ObjectiveEvidence.official_skills_inventory
    foreach ($Name in $Requirements.PSObject.Properties.Name) {
        if (-not [bool]$Requirements.PSObject.Properties[$Name].Value) { continue }
        $Actual = switch ($Name) {
            'official_skills_inventory_before_available' { $Inventory.before_available }
            'official_skills_inventory_after_available' { $Inventory.after_available }
            'official_skills_inventory_unchanged' { $Inventory.unchanged }
            'metadata_only_inventory' { $Inventory.metadata_only_inventory }
            default { $false }
        }
        if (-not $Actual) { $Missing.Add($Name) }
    }
    [pscustomobject]@{ passed=($Missing.Count -eq 0); missing=@($Missing) }
}
function New-PreflightException([System.Management.Automation.ErrorRecord]$ErrorRecord, [string]$FailingCheck) {
    [pscustomobject]@{
        exception_type = $ErrorRecord.Exception.GetType().FullName
        message = $ErrorRecord.Exception.Message
        script_line = $ErrorRecord.InvocationInfo.ScriptLineNumber
        failing_check = $FailingCheck
        exact_command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\run-decision-grill-regression.ps1" -Mode DryRun'
    }
}

function Add-Check([System.Collections.Generic.List[object]]$Checks, [string]$Name, [bool]$Passed, [string]$Detail, [object]$ExceptionDetail = $null) {
    if ([string]::IsNullOrWhiteSpace($Name)) { throw 'preflight check name must be non-blank' }
    [void]$Checks.Add([pscustomobject]@{ name = $Name; passed = $Passed; detail = $Detail; exception = $ExceptionDetail })
}

function Test-PreflightCheckShape([object]$Check) {
    if ($null -eq $Check) { return 'null check item' }
    if ($Check -is [System.Collections.IEnumerable] -and $Check -isnot [string] -and $Check -isnot [pscustomobject]) { return "nested or non-check collection: $($Check.GetType().FullName)" }
    $Properties = $Check.PSObject.Properties
    if ($null -eq $Properties['name'] -or [string]::IsNullOrWhiteSpace([string]$Properties['name'].Value)) { return 'missing or blank name' }
    if ($null -eq $Properties['passed']) { return 'missing passed' }
    if ($Properties['passed'].Value -isnot [bool]) { return "passed is not Boolean: $($Properties['passed'].Value.GetType().FullName)" }
    if ($null -eq $Properties['detail']) { return 'missing detail' }
    return $null
}

function Add-CheckCollection([System.Collections.Generic.List[object]]$Checks, [object[]]$AdditionalChecks, [string]$Context = 'preflight aggregation') {
    foreach ($Check in @($AdditionalChecks)) {
        $ShapeFailure = Test-PreflightCheckShape $Check
        if ($null -ne $ShapeFailure) {
            $Type = if ($null -eq $Check) { '<null>' } else { $Check.GetType().FullName }
            Add-Check $Checks "RUNNER_INTERNAL_ERROR: malformed preflight check ($Context)" $false "$ShapeFailure; type=$Type"
            continue
        }
        [void]$Checks.Add($Check)
    }
}

function Test-CodexExecutable([string]$Path) {
    try {
        Assert-ActiveFolderSafetyRevalidation -Purpose 'discovery Codex CLI pre-call' | Out-Null
        $VersionOutput = @(& $Path --version 2>&1)
        $ExitCode = $LASTEXITCODE
        $Version = ($VersionOutput -join "`n").Trim()
        return [pscustomobject]@{ passed=($ExitCode -eq 0); version=$Version; detail="exit=$ExitCode"; exception=$null }
    } catch {
        return [pscustomobject]@{ passed=$false; version=$null; detail=$_.Exception.Message; exception=$_ }
    }
}

function Resolve-CodexCli {
    if (-not [string]::IsNullOrWhiteSpace($CodexPath)) {
        if (-not [System.IO.Path]::IsPathRooted($CodexPath)) { throw "CodexPath must be absolute: $CodexPath" }
        $Candidate = [System.IO.Path]::GetFullPath($CodexPath)
        if (-not (Test-Path -LiteralPath $Candidate -PathType Leaf)) { throw "CodexPath does not exist: $Candidate" }
        return $Candidate
    }

    $Candidates = @(
        Get-Command codex.cmd -All -ErrorAction SilentlyContinue | ForEach-Object Source
        Get-Command codex -All -ErrorAction SilentlyContinue | ForEach-Object Source
    ) | Where-Object { $_ -and $_ -notmatch '(?i)\\WindowsApps\\' } | Select-Object -Unique
    foreach ($Candidate in $Candidates) {
        $Probe = Test-CodexExecutable $Candidate
        if ($Probe.passed) { return $Candidate }
    }
    throw 'No executable non-WindowsApps Codex CLI was found.'
}

function Get-NormalizedAbsolutePath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    if (-not [System.IO.Path]::IsPathRooted($Path)) { return $null }
    $Normalized = [System.IO.Path]::GetFullPath($Path)
    $Root = [System.IO.Path]::GetPathRoot($Normalized)
    if ($Normalized.Length -gt $Root.Length) { return $Normalized.TrimEnd('\', '/') }
    return $Root
}

function Test-PathEqualOrdinalIgnoreCase([string]$Left, [string]$Right) {
    return [string]::Equals((Get-NormalizedAbsolutePath $Left), (Get-NormalizedAbsolutePath $Right), [StringComparison]::OrdinalIgnoreCase)
}

function Test-PathIsWithinDirectoryOrdinalIgnoreCase([string]$Path, [string]$Directory) {
    $NormalizedPath = Get-NormalizedAbsolutePath $Path
    $NormalizedDirectory = Get-NormalizedAbsolutePath $Directory
    if ([string]::IsNullOrWhiteSpace($NormalizedPath) -or [string]::IsNullOrWhiteSpace($NormalizedDirectory)) { return $false }
    if ([string]::Equals($NormalizedPath, $NormalizedDirectory, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    $Boundary = if ($NormalizedDirectory.EndsWith('\')) { $NormalizedDirectory } else { $NormalizedDirectory + '\' }
    return $NormalizedPath.StartsWith($Boundary, [StringComparison]::OrdinalIgnoreCase)
}

function Get-ExistingAncestorSegments([string]$Path) {
    $Normalized = Get-NormalizedAbsolutePath $Path
    if ([string]::IsNullOrWhiteSpace($Normalized)) { return @() }
    $Root = [System.IO.Path]::GetPathRoot($Normalized)
    $Segments = [System.Collections.Generic.List[string]]::new()
    if (Test-Path -LiteralPath $Root) { $Segments.Add($Root) }
    $Remainder = $Normalized.Substring($Root.Length).TrimStart('\', '/')
    $Current = $Root
    foreach ($Part in @($Remainder -split '[\\/]')) {
        if ([string]::IsNullOrWhiteSpace($Part)) { continue }
        $Current = Join-Path $Current $Part
        if (Test-Path -LiteralPath $Current) { $Segments.Add($Current) }
    }
    return @($Segments)
}

function Test-PathChainHasNoReparsePoint([string]$Path, [string]$Purpose) {
    $Normalized = Get-NormalizedAbsolutePath $Path
    if ([string]::IsNullOrWhiteSpace($Normalized)) {
        return [pscustomobject]@{ passed=$false; normalized_path=$null; offending_segment=$null; purpose=$Purpose; failures=@("$Purpose path must be absolute") }
    }
    foreach ($Segment in @(Get-ExistingAncestorSegments $Normalized)) {
        $Attributes = [System.IO.File]::GetAttributes($Segment)
        if (($Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            return [pscustomobject]@{ passed=$false; normalized_path=$Normalized; offending_segment=$Segment; purpose=$Purpose; failures=@("$Purpose path contains reparse point: $Segment") }
        }
    }
    return [pscustomobject]@{ passed=$true; normalized_path=$Normalized; offending_segment=$null; purpose=$Purpose; failures=@() }
}

function Assert-PathChainHasNoReparsePoint([string]$Path, [string]$Purpose) {
    $Check = Test-PathChainHasNoReparsePoint $Path $Purpose
    if (-not $Check.passed) { throw ($Check.failures -join '; ') }
    return $Check.normalized_path
}

function Test-ActiveFolderSafety([string]$Candidate) {
    $Failures = [System.Collections.Generic.List[string]]::new()
    $Resolved = $null
    if ([string]::IsNullOrWhiteSpace($Candidate)) { $Failures.Add('ActiveFolder is required for production modes') }
    elseif (-not [System.IO.Path]::IsPathRooted($Candidate)) { $Failures.Add('ActiveFolder must be an absolute path') }
    elseif (-not (Test-Path -LiteralPath $Candidate -PathType Container)) { $Failures.Add('ActiveFolder does not exist') }
    else {
        $Resolved = Get-NormalizedAbsolutePath $Candidate
        $ChainCheck = Test-PathChainHasNoReparsePoint $Resolved 'ActiveFolder'
        foreach ($Failure in @($ChainCheck.failures)) { $Failures.Add($Failure) }
        $Repo = Get-NormalizedAbsolutePath $RepoRoot
        $Global = Get-NormalizedAbsolutePath $GlobalSkills
        $Official = Get-NormalizedAbsolutePath $OfficialSystemSkills
        $Profile = Get-NormalizedAbsolutePath $env:USERPROFILE
        $TempRoot = Get-NormalizedAbsolutePath 'D:\temp'
        $Root = [System.IO.Path]::GetPathRoot($Resolved)
        if (Test-PathEqualOrdinalIgnoreCase $Resolved $Repo) { $Failures.Add('ActiveFolder must not be the repository root') }
        if (Test-PathEqualOrdinalIgnoreCase $Resolved $Global) { $Failures.Add('ActiveFolder must not be the global Skills root') }
        if (Test-PathEqualOrdinalIgnoreCase $Resolved $Official) { $Failures.Add('ActiveFolder must not be the official Skills root') }
        if (Test-PathEqualOrdinalIgnoreCase $Resolved $Profile) { $Failures.Add('ActiveFolder must not be the user profile root') }
        if (Test-PathEqualOrdinalIgnoreCase $Resolved $Root) { $Failures.Add('ActiveFolder must not be a drive root') }
        if (-not (Test-PathIsWithinDirectoryOrdinalIgnoreCase $Resolved $TempRoot)) { $Failures.Add('ActiveFolder must be under D:\temp') }
        if (-not (Test-PathEqualOrdinalIgnoreCase (Split-Path -Parent $Resolved) $TempRoot)) { $Failures.Add('ActiveFolder must be directly under D:\temp') }
        if (-not (Test-PathEqualOrdinalIgnoreCase $Resolved $Root) -and (Test-PathEqualOrdinalIgnoreCase (Split-Path -Parent $Resolved) $TempRoot)) {
            $Parent = Split-Path -Parent $Resolved
            $Leaf = Split-Path -Leaf $Resolved
            if ($Leaf -notmatch '^decision-grill-dg-(?:final|final2|retest|isolation)-\d{8}-\d{6,}$') {
                $Failures.Add('ActiveFolder must be an explicit Decision-Grill temp isolation folder')
            }
        }
    }
    [pscustomobject]@{ passed=($Failures.Count -eq 0); active_folder=$Resolved; failures=@($Failures) }
}

function Get-SkillHashValidation([string]$Folder) {
    $Installed = if ([string]::IsNullOrWhiteSpace($Folder)) { $null } else { Join-Path $Folder '.agents\skills\decision-grill\SKILL.md' }
    $InstalledChain = if ($Installed) { Test-PathChainHasNoReparsePoint $Installed 'project Decision-Grill Skill' } else { $null }
    if ($InstalledChain -and -not $InstalledChain.passed) {
        return [pscustomobject]@{ source_skill_path=$SourceSkill; source_skill_sha256=$null; installed_skill_path=$Installed; installed_skill_sha256=$null; hashes_match=$false; installed_skill_exists=$false; path_chain_safe=$false; offending_segment=$InstalledChain.offending_segment; path_chain_failures=@($InstalledChain.failures) }
    }
    $SourceHash = if (Test-Path -LiteralPath $SourceSkill -PathType Leaf) { Get-Sha256 -LiteralPath $SourceSkill } else { $null }
    $InstalledHash = if ($Installed -and (Test-Path -LiteralPath $Installed -PathType Leaf)) { Get-Sha256 -LiteralPath $Installed } else { $null }
    [pscustomobject]@{ source_skill_path=$SourceSkill; source_skill_sha256=$SourceHash; installed_skill_path=$Installed; installed_skill_sha256=$InstalledHash; hashes_match=(Test-SkillHashPair $SourceHash $InstalledHash); installed_skill_exists=($Installed -and (Test-Path -LiteralPath $Installed -PathType Leaf)); path_chain_safe=$true; offending_segment=$null; path_chain_failures=@() }
}

function Assert-ActiveFolderSafetyRevalidation([string]$Purpose, [string[]]$FixturePaths = @()) {
    # This deliberately composes the preflight safety functions; it does not introduce a second path-validation implementation.
    $Failures = [System.Collections.Generic.List[string]]::new()
    try { Assert-WorkingTreeIdentity -Purpose $Purpose } catch { $Failures.Add($_.Exception.Message) }
    $Current = Test-ActiveFolderSafety $ActiveFolder
    if (-not $Current.passed) { foreach ($Failure in @($Current.failures)) { $Failures.Add($Failure) } }
    if ([string]::IsNullOrWhiteSpace($script:PreflightActiveFolderCanonical)) {
        $Failures.Add('preflight ActiveFolder canonical path is unavailable')
    } elseif (-not (Test-PathEqualOrdinalIgnoreCase $Current.active_folder $script:PreflightActiveFolderCanonical)) {
        $Failures.Add("ActiveFolder canonical path changed from preflight: expected $script:PreflightActiveFolderCanonical; actual $($Current.active_folder)")
    }
    if ($Current.passed) {
        $SkillValidation = Get-SkillHashValidation $Current.active_folder
        if (-not $SkillValidation.path_chain_safe) { foreach ($Failure in @($SkillValidation.path_chain_failures)) { $Failures.Add($Failure) } }
    }
    foreach ($FixturePath in @($FixturePaths)) {
        $FixtureCheck = Test-PathChainHasNoReparsePoint $FixturePath 'fixture path'
        if (-not $FixtureCheck.passed) { foreach ($Failure in @($FixtureCheck.failures)) { $Failures.Add($Failure) } }
    }
    if ($Failures.Count -ne 0) {
        $script:RunnerInternalError = $true
        throw "SAFETY_REVALIDATION_FAILED [$Purpose]: $($Failures -join '; ')"
    }
    return $Current.active_folder
}

function Get-RevalidatedInventoryDigest([string]$Purpose) {
    Assert-ActiveFolderSafetyRevalidation -Purpose $Purpose | Out-Null
    return Get-InventoryDigest $ActiveFolder
}

function Test-SkillHashPair([string]$SourceHash, [string]$InstalledHash) {
    return -not [string]::IsNullOrWhiteSpace($SourceHash) -and -not [string]::IsNullOrWhiteSpace($InstalledHash) -and $SourceHash -eq $InstalledHash
}

function New-CodexExecutionArguments([string]$Sandbox, [string[]]$Tail = @()) {
    return @('exec','--json','--sandbox',$Sandbox,'--skip-git-repo-check','-C',$ActiveFolder) + @($Tail)
}

function Resolve-CaseFixtureTargets([object[]]$Fixtures) {
    $Root = Get-NormalizedAbsolutePath $ActiveFolder
    if ([string]::IsNullOrWhiteSpace($Root)) { throw 'ActiveFolder must be validated before resolving fixture paths' }
    $Targets = [System.Collections.Generic.List[object]]::new()
    $Seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($Fixture in @($Fixtures)) {
        $RelativePath = Get-OptionalObject $Fixture 'relative_path'
        if ($RelativePath -isnot [string] -or [string]::IsNullOrWhiteSpace($RelativePath)) { throw 'fixture relative_path must be a non-blank string' }
        if ([System.IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '^[A-Za-z]:' -or $RelativePath -match '^(?:\\\\|//)') { throw "fixture relative_path must not be rooted: $RelativePath" }
        $Segments = @($RelativePath -split '[\\/]')
        if ($Segments.Count -eq 0 -or @($Segments | Where-Object { [string]::IsNullOrWhiteSpace($_) -or $_ -eq '.' -or $_ -eq '..' }).Count -ne 0) { throw "fixture relative_path contains an invalid segment: $RelativePath" }
        $Target = Get-NormalizedAbsolutePath (Join-Path $Root $RelativePath)
        if ([string]::IsNullOrWhiteSpace($Target) -or (Test-PathEqualOrdinalIgnoreCase $Target $Root) -or -not (Test-PathIsWithinDirectoryOrdinalIgnoreCase $Target $Root)) { throw "fixture target escapes ActiveFolder: $RelativePath" }
        if (-not $Seen.Add($Target)) { throw "fixture targets must be unique after normalization: $RelativePath" }
        $Content = Get-OptionalObject $Fixture 'content'
        if ($Content -isnot [string]) { throw "fixture content must be a string: $RelativePath" }
        if (Test-Path -LiteralPath $Target) { throw "fixture target already exists: $Target" }
        $Targets.Add([pscustomobject]@{ relative_path=$RelativePath; content=$Content; target_path=$Target })
    }
    return @($Targets)
}

function Initialize-CaseFixtures([object]$Case) {
    $Fixtures = @(Get-OptionalArray $Case 'fixtures')
    $MetadataFailures = @(Test-FixtureMetadata $Case)
    if ($MetadataFailures.Count -ne 0) { throw "fixture contract validation failed: $($MetadataFailures -join '; ')" }
    $Targets = @(Resolve-CaseFixtureTargets $Fixtures)
    foreach ($Target in $Targets) {
        Assert-ActiveFolderSafetyRevalidation -Purpose 'fixture preparation prevalidation' -FixturePaths @($Target.target_path) | Out-Null
        Assert-PathChainHasNoReparsePoint -Path $Target.target_path -Purpose 'fixture path prevalidation' | Out-Null
    }
    foreach ($Target in $Targets) {
        $FixtureDirectory = Split-Path -Parent $Target.target_path
        Assert-ActiveFolderSafetyRevalidation -Purpose 'fixture directory creation' -FixturePaths @($Target.target_path) | Out-Null
        Assert-PathChainHasNoReparsePoint -Path $Target.target_path -Purpose 'fixture path before directory creation' | Out-Null
        New-Item -ItemType Directory -Force -Path $FixtureDirectory | Out-Null
        Assert-PathChainHasNoReparsePoint -Path $Target.target_path -Purpose 'fixture path after directory creation' | Out-Null
        if (Test-Path -LiteralPath $Target.target_path) { throw "fixture target already exists: $($Target.target_path)" }
        Assert-ActiveFolderSafetyRevalidation -Purpose 'fixture write' -FixturePaths @($Target.target_path) | Out-Null
        Assert-PathChainHasNoReparsePoint -Path $Target.target_path -Purpose 'fixture path before write' | Out-Null
        Write-Utf8NoBom -Path $Target.target_path -Content $Target.content -NoOverwrite
    }
    return @($Targets | ForEach-Object { $_.target_path })
}

function Invoke-Preflight {
    $Checks = [System.Collections.Generic.List[object]]::new()
    $PushedLocation = $false
    try {
        $CurrentCheck = 'ActiveFolder safety'
        $ActiveFolderSafety = Test-ActiveFolderSafety $ActiveFolder
        Add-Check $Checks 'ActiveFolder safety' $ActiveFolderSafety.passed (($ActiveFolderSafety.failures -join '; '))
        if (-not $ActiveFolderSafety.passed) { return ,$Checks }
        $script:ActiveFolder = $ActiveFolderSafety.active_folder
        $script:PreflightActiveFolderCanonical = $ActiveFolderSafety.active_folder
        $script:InstalledSkill = Join-Path $script:ActiveFolder '.agents\skills\decision-grill\SKILL.md'
        $CurrentCheck = 'source and installed Skill SHA-256'
        $SkillValidation = Get-SkillHashValidation $ActiveFolder
        $script:SkillHashValidation = $SkillValidation
        Add-Check $Checks 'project decision-grill path reparse-point safety' $SkillValidation.path_chain_safe (($SkillValidation.path_chain_failures -join '; '))
        if (-not $SkillValidation.path_chain_safe) { return ,$Checks }
        Add-Check $Checks 'source Decision-Grill Skill exists' (-not [string]::IsNullOrWhiteSpace($SkillValidation.source_skill_sha256)) $SkillValidation.source_skill_path
        Add-Check $Checks 'project decision-grill exists' $SkillValidation.installed_skill_exists $SkillValidation.installed_skill_path
        Add-Check $Checks 'source and installed Skill SHA-256 match' $SkillValidation.hashes_match ("source={0}; source_sha256={1}; installed={2}; installed_sha256={3}" -f $SkillValidation.source_skill_path,$SkillValidation.source_skill_sha256,$SkillValidation.installed_skill_path,$SkillValidation.installed_skill_sha256)
        if (-not $SkillValidation.hashes_match) { return ,$Checks }
        $CurrentCheck = 'resolved CodexPath'
        $script:ResolvedCodexPath = Resolve-CodexCli
        $script:CodexIsWindowsApps = $ResolvedCodexPath -match '(?i)\\WindowsApps\\'
        Add-Check $Checks 'resolved CodexPath' (-not [string]::IsNullOrWhiteSpace($ResolvedCodexPath)) $ResolvedCodexPath
        $CurrentCheck = 'CodexPath is not WindowsApps'
        Add-Check $Checks 'CodexPath is not WindowsApps' (-not $CodexIsWindowsApps) ([string]$CodexIsWindowsApps)
        $CurrentCheck = 'codex executable probe'
        $CodexProbe = Test-CodexExecutable $ResolvedCodexPath
        $script:CodexVersion = $CodexProbe.version
        $ProbeException = if ($CodexProbe.exception) { New-PreflightException $CodexProbe.exception $CurrentCheck } else { $null }
        Add-Check $Checks 'codex executable probe' $CodexProbe.passed $CodexProbe.detail $ProbeException
        $CurrentCheck = 'codex CLI version'
        Add-Check $Checks 'codex CLI version' (-not [string]::IsNullOrWhiteSpace($CodexVersion)) $CodexVersion
        $CurrentCheck = 'global decision-grill absent'
        Add-Check $Checks 'global decision-grill absent' (-not (Test-Path -LiteralPath (Join-Path $GlobalSkills 'decision-grill'))) $GlobalSkills
        $CurrentCheck = 'global grill-me absent'
        Add-Check $Checks 'global grill-me absent' (-not (Test-Path -LiteralPath (Join-Path $GlobalSkills 'grill-me'))) $GlobalSkills
        $CurrentCheck = 'project grill-me absent'
        Add-Check $Checks 'project grill-me absent' (-not (Test-Path -LiteralPath (Join-Path $ActiveFolder '.agents\skills\grill-me'))) $ActiveFolder
        $CurrentCheck = 'repository metadata'
        Push-Location $RepoRoot
        $PushedLocation = $true
        $Identity = Get-WorkingTreeIdentity $RepoRoot
        $Baseline = Test-WorkingTreeBaseline $Identity
        Add-Check $Checks 'repository branch' ($Identity.branch -eq $ExpectedBranch) $Identity.branch
        Add-Check $Checks 'repository HEAD' ($Identity.head -eq $ExpectedHead) $Identity.head
        Add-Check $Checks 'working-tree immutable baseline' $Baseline.passed (($Baseline.failures -join '; '))
        if (-not $Baseline.passed) { Pop-Location; $PushedLocation = $false; return ,$Checks }
        $script:WorkingTreeIdentity = $Identity
        Assert-WorkingTreeIdentity -Purpose 'preflight completion'
        Add-Check $Checks 'working-tree identity captured and revalidated' $true ("mode={0}; entries={1}" -f $Baseline.mode,@($Identity.entries).Count)
        Pop-Location
        $PushedLocation = $false
        $CurrentCheck = 'output folder under D:\temp'
        Add-Check $Checks 'output folder under D:\temp' ($OutputRoot.StartsWith('D:\temp\', [StringComparison]::OrdinalIgnoreCase) -and -not $OutputRoot.StartsWith($RepoRoot, [StringComparison]::OrdinalIgnoreCase)) $OutputRoot
    } catch {
        if ($PushedLocation) { Pop-Location }
        Add-Check $Checks "preflight exception: $CurrentCheck" $false $_.Exception.Message (New-PreflightException $_ $CurrentCheck)
    }
    return ,$Checks
}

function Get-ThreadId([string]$JsonlPath) {
    $Text = Read-Utf8NoBom $JsonlPath
    $Match = [regex]::Match($Text, '"thread_id"\s*:\s*"([^"]+)"')
    if (-not $Match.Success) { $Match = [regex]::Match($Text, '"threadId"\s*:\s*"([^"]+)"') }
    if (-not $Match.Success) { throw "No thread_id was found in $JsonlPath" }
    return $Match.Groups[1].Value
}

function Get-CaseTranscript([string[]]$JsonlPaths) {
    $Messages = [System.Collections.Generic.List[string]]::new()
    $MessageOrder = [System.Collections.Generic.List[object]]::new()
    $MessageSequence = [System.Collections.Generic.List[object]]::new()
    $InspectedFiles = [System.Collections.Generic.List[string]]::new()
    $TurnIndex = 0
    foreach ($JsonlPath in @($JsonlPaths)) {
        $TurnIndex++
        if ([string]::IsNullOrWhiteSpace($JsonlPath)) { continue }
        if (-not (Test-Path -LiteralPath $JsonlPath -PathType Leaf)) { throw "Transcript JSONL is missing: $JsonlPath" }
        $InspectedFiles.Add($JsonlPath)
        $LineNumber = 0
        foreach ($Line in ((Read-Utf8NoBom $JsonlPath) -split "`r?`n")) {
            $LineNumber++
            if ([string]::IsNullOrWhiteSpace($Line)) { continue }
            try { $Event = $Line | ConvertFrom-Json -ErrorAction Stop } catch { throw "Invalid JSONL event at $JsonlPath line ${LineNumber}: $($_.Exception.Message)" }
            if ((Get-OptionalString $Event 'type') -ne 'item.completed') { continue }
            if (-not (Test-ObjectProperty $Event 'item')) { continue }
            $Item = $Event.PSObject.Properties['item'].Value
            if ((Get-OptionalString $Item 'type') -ne 'agent_message') { continue }
            $Text = Get-OptionalString $Item 'text'
            if ([string]::IsNullOrWhiteSpace($Text)) { continue }
            $Messages.Add($Text)
            $MessageOrder.Add([pscustomobject]@{ order=$Messages.Count; jsonl_path=$JsonlPath; line=$LineNumber; length=$Text.Length; sha256=(Get-StringSha256 $Text) })
            $Origin = if ($JsonlPath -match '(?i)-resume\.jsonl$') { 'resume' } else { 'initial' }
            $MessageSequence.Add([pscustomobject]@{ message_index=$Messages.Count; turn_index=$TurnIndex; input_index=$(if ($Origin -eq 'resume') { $TurnIndex - 1 } else { 0 }); origin=$Origin; role='agent'; source_jsonl_path=$JsonlPath; source_event_line=$LineNumber; raw_text=$Text; normalized_text=(ConvertTo-NormalizedConditionText $Text) })
        }
    }
    $Transcript = $Messages -join [Environment]::NewLine
    $FinalMessage = if ($Messages.Count -gt 0) { $Messages[$Messages.Count - 1] } else { $null }
    return [pscustomobject]@{
        jsonl_files_inspected = @($InspectedFiles)
        agent_message_count = $Messages.Count
        extracted_message_order = @($MessageOrder)
        messages = @($Messages)
        message_sequence = @($MessageSequence)
        transcript = $Transcript
        final_agent_message = $FinalMessage
        final_message_length = if ($null -eq $FinalMessage) { 0 } else { $FinalMessage.Length }
        transcript_length = $Transcript.Length
        transcript_sha256 = Get-StringSha256 $Transcript
        final_message_sha256 = if ($null -eq $FinalMessage) { $null } else { Get-StringSha256 $FinalMessage }
    }
}

function New-MessageBoundaryExtraction([string]$Transcript) {
    $Text = if ($null -eq $Transcript) { '' } else { $Transcript }
    $Message = [pscustomobject]@{ message_index=1;turn_index=1;input_index=0;origin='synthetic';role='agent';source_jsonl_path='<synthetic>';source_event_line=1;raw_text=$Text;normalized_text=(ConvertTo-NormalizedConditionText $Text) }
    return [pscustomobject]@{ jsonl_files_inspected=@();agent_message_count=$(if([string]::IsNullOrWhiteSpace($Text)){0}else{1});extracted_message_order=@();messages=@($Text);message_sequence=@($Message);transcript=$Text;final_agent_message=$Text;final_message_length=$Text.Length;transcript_length=$Text.Length;transcript_sha256=(Get-StringSha256 $Text);final_message_sha256=(Get-StringSha256 $Text) }
}

function Get-TypedAcceptedEvents([object]$Extraction) {
    $Events = [System.Collections.Generic.List[object]]::new()
    foreach ($Message in @(Get-OptionalArray $Extraction 'message_sequence')) {
        $Text = Get-OptionalString $Message 'raw_text'
        if ([string]::IsNullOrWhiteSpace($Text)) { continue }
        if ($Text -match '(?m)^\s*```') { continue }
        $HeaderPattern = '(?im)^\s*(?:\*{0,2})?Ledger\s+event\b.*$'
        $Headers = [regex]::Matches($Text, $HeaderPattern)
        foreach ($Header in $Headers) {
            $NextBoundary = [regex]::Match($Text.Substring($Header.Index + $Header.Length), '(?im)^\s*(?:(?:\*{0,2})?Ledger\s+event\b|###\s+Q-\d{3}\b)')
            $End = if ($NextBoundary.Success) { $Header.Index + $Header.Length + $NextBoundary.Index } else { $Text.Length }
            $BlankBoundary = [regex]::Match($Text.Substring($Header.Index + $Header.Length, $End - ($Header.Index + $Header.Length)), '(?:\r?\n){2,}')
            if ($BlankBoundary.Success) { $End = $Header.Index + $Header.Length + $BlankBoundary.Index }
            $Record = $Text.Substring($Header.Index, $End - $Header.Index).TrimEnd()
            # Accept both Markdown field spellings: **Label**: value and **Label:** value.
            # The field remains complete, labelled, and confined to this message-local record.
            $Question = [regex]::Match($Record, '(?im)^\s*(?:[-]\s*|\*(?!\*)\s*)?(?:\*{0,2})?(?:Question\s+ID|Question)(?:\*{0,2})?\s*:\s*(?:\*{0,2})?\s*(?<value>Q-\d{3})\s*$')
            $Lifecycle = [regex]::Match($Record, '(?im)^\s*(?:[-]\s*|\*(?!\*)\s*)?(?:\*{0,2})?Lifecycle(?:\*{0,2})?\s*:\s*(?:\*{0,2})?\s*(?<value>`?(?:ANSWERED|ACCEPTED)`?|\*\*(?:ANSWERED|ACCEPTED)\*\*)\s*$')
            $Result = [regex]::Match($Record, '(?im)^\s*(?:[-]\s*|\*(?!\*)\s*)?(?:\*{0,2})?(?:Decision\s+result|Decision\s+state|Result)(?:\*{0,2})?\s*:\s*(?:\*{0,2})?\s*(?<value>\S.*?)\s*$')
            $Status = [regex]::Match($Record, '(?im)^\s*(?:[-]\s*|\*(?!\*)\s*)?(?:\*{0,2})?(?:Resulting\s+status|Status)(?:\*{0,2})?\s*:\s*(?:\*{0,2})?\s*(?<value>`?(?:ANSWERED|ACCEPTED)`?|\*\*(?:ANSWERED|ACCEPTED)\*\*)\s*$')
            if (-not $Result.Success) { $Result = [regex]::Match($Record, '(?i)\b(?:Decision\s+result|Decision\s+state|Result)\s*:\s*(?<value>\S.*?)(?=\s*(?:[.;]\s*)?(?:Resulting\s+status|Status)\s*:|$)') }
            if (-not $Status.Success) { $Status = [regex]::Match($Record, '(?i)\b(?:Resulting\s+status|Status)\s*:\s*(?<value>`?(?:ANSWERED|ACCEPTED)`?|\*\*(?:ANSWERED|ACCEPTED)\*\*)\s*(?:[.;])?\s*$') }
            $InlineMatch = [regex]::Match(($Header.Value -replace '\*\*', ''), '(?i)Q-\d{3}\s*:\s*(?<value>`?(?:ANSWERED|ACCEPTED)`?)')
            $Inline = if ($InlineMatch.Success) { ConvertTo-NormalizedTypedFieldValue $InlineMatch.Groups['value'].Value } else { $null }
            if (-not $Result.Success -and -not [string]::IsNullOrWhiteSpace($Inline)) { $Result = [regex]::Match(($Header.Value -replace '\*\*', ''), '(?i)(?:ANSWERED|ACCEPTED)\s*\.\s*(?<value>\S.*?)(?=\s*(?:[.;]\s*)?(?:Resulting\s+status|Status)\s*:)') }
            $LifecycleValue = if ($Lifecycle.Success) { ConvertTo-NormalizedTypedFieldValue $Lifecycle.Groups['value'].Value } else { $Inline }
            $StatusValue = if ($Status.Success) { ConvertTo-NormalizedTypedFieldValue $Status.Groups['value'].Value } else { $null }
            $ResultValue = if ($Result.Success) { ConvertTo-NormalizedTypedFieldValue $Result.Groups['value'].Value } else { $null }
            $Valid = -not [string]::IsNullOrWhiteSpace($LifecycleValue) -and -not [string]::IsNullOrWhiteSpace($StatusValue) -and -not [string]::IsNullOrWhiteSpace($ResultValue) -and $LifecycleValue -match '^(?:ANSWERED|ACCEPTED)$' -and $StatusValue -match '^(?:ANSWERED|ACCEPTED)$'
            $HeaderQuestion = [regex]::Match($Header.Value, '(?i)Q-\d{3}')
            $QuestionId = if ($HeaderQuestion.Success) { $HeaderQuestion.Value } elseif ($Question.Success) { $Question.Groups['value'].Value } else { $null }
            $Events.Add([pscustomobject]@{event_type='accepted_answer';question_id=$QuestionId;accepted_result=$ResultValue;resulting_status=$StatusValue;lifecycle=$LifecycleValue;message_index=$Message.message_index;turn_index=$Message.turn_index;input_index=$Message.input_index;origin=$Message.origin;source_jsonl_path=$Message.source_jsonl_path;source_event_line=$Message.source_event_line;raw_record=$Record;valid=$Valid})
        }
    }
    return @($Events)
}

function Get-TypedFactWorkRecords([object]$Extraction) {
    $Records = [System.Collections.Generic.List[object]]::new()
    foreach ($Message in @(Get-OptionalArray $Extraction 'message_sequence')) {
        $RecordIndex = -1
        foreach ($Record in @((Get-OptionalString $Message 'raw_text') -split '(?:\r?\n){2,}')) {
            $RecordIndex++
            $Fields = Get-FormalFactWorkRecordFields $Record $RecordIndex
            if ($null -eq $Fields -or ($null -eq $Fields.fact_work_status -and $null -eq $Fields.affected_decision -and $null -eq $Fields.paired_decision_state)) { continue }
            $Records.Add([pscustomobject]@{record_type='fact_work';work_status=$Fields.fact_work_status;affected_decision=$Fields.affected_decision;paired_decision_state=$Fields.paired_decision_state;message_index=$Message.message_index;turn_index=$Message.turn_index;input_index=$Message.input_index;origin=$Message.origin;record_index=$RecordIndex;source_jsonl_path=$Message.source_jsonl_path;source_event_line=$Message.source_event_line;raw_record=$Record})
        }
    }
    return @($Records)
}

function Get-MessageBoundaryEvidence([object]$Extraction) {
    if ($null -eq $Extraction -or -not (Test-ObjectProperty $Extraction 'message_sequence')) { $Extraction = New-MessageBoundaryExtraction ((Get-OptionalString $Extraction 'transcript') ) }
    return [pscustomobject]@{ message_sequence=@(Get-OptionalArray $Extraction 'message_sequence'); accepted_events=@(Get-TypedAcceptedEvents $Extraction); fact_work_records=@(Get-TypedFactWorkRecords $Extraction) }
}

function Get-StringSha256([string]$Value) {
    $Sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $Bytes = $Utf8NoBom.GetBytes($(if ($null -eq $Value) { '' } else { $Value }))
        return ((($Sha256.ComputeHash($Bytes) | ForEach-Object { $_.ToString('x2') }) -join '').ToUpperInvariant())
    } finally { $Sha256.Dispose() }
}

function Test-TranscriptComplete([object]$Extraction) {
    if ($null -eq $Extraction -or $Extraction.agent_message_count -lt 1) { return [pscustomobject]@{ passed=$false; reason='INCOMPLETE_TRANSCRIPT' } }
    if ([string]::IsNullOrWhiteSpace($Extraction.transcript)) { return [pscustomobject]@{ passed=$false; reason='INCOMPLETE_TRANSCRIPT' } }
    if ([string]::IsNullOrWhiteSpace($Extraction.final_agent_message)) { return [pscustomobject]@{ passed=$false; reason='INCOMPLETE_TRANSCRIPT' } }
    if ($Extraction.transcript.IndexOf($Extraction.final_agent_message, [StringComparison]::Ordinal) -lt 0) { return [pscustomobject]@{ passed=$false; reason='INCOMPLETE_TRANSCRIPT' } }
    return [pscustomobject]@{ passed=$true; reason=$null }
}

function Test-TranscriptExtraction {
    $SelfTestDir = Join-Path $ResultsDir 'transcript-extraction-self-test'
    New-Item -ItemType Directory -Force -Path $SelfTestDir | Out-Null
    $SinglePath = Join-Path $SelfTestDir 'single-turn.jsonl'
    $InitialPath = Join-Path $SelfTestDir 'multi-turn-001-initial.jsonl'
    $ResumePath = Join-Path $SelfTestDir 'multi-turn-002-resume.jsonl'
    $EmptyPath = Join-Path $SelfTestDir 'empty.jsonl'
    Write-Utf8NoBom $SinglePath '{"type":"item.completed","item":{"type":"agent_message","text":"single response"}}'
    Write-Utf8NoBom $InitialPath '{"type":"item.completed","item":{"type":"agent_message","text":"initial response"}}'
    Write-Utf8NoBom $ResumePath '{"type":"item.completed","item":{"type":"agent_message","text":"resume response"}}'
    Write-Utf8NoBom $EmptyPath '{"type":"turn.completed"}'
    try {
        $Single = Get-CaseTranscript @($SinglePath)
        $Multi = Get-CaseTranscript @($InitialPath, $ResumePath)
        $Empty = Get-CaseTranscript @($EmptyPath)
        $SinglePassed = $Single.agent_message_count -eq 1 -and $Single.final_agent_message -eq 'single response' -and (Test-TranscriptComplete $Single).passed
        $MultiPassed = $Multi.agent_message_count -eq 2 -and $Multi.messages[0] -eq 'initial response' -and $Multi.final_agent_message -eq 'resume response' -and (Test-TranscriptComplete $Multi).passed
        $EmptyGatePassed = -not (Test-TranscriptComplete $Empty).passed
        $Result = [pscustomobject]@{ result=($SinglePassed -and $MultiPassed -and $EmptyGatePassed); single_turn=$SinglePassed; multi_turn=$MultiPassed; empty_transcript_gate=$EmptyGatePassed; judge_called=$false }
        $Result | ConvertTo-Json -Depth 10 | ForEach-Object { Write-Utf8NoBom (Join-Path $SelfTestDir 'result.json') $_ }
        return $Result
    } catch {
        return [pscustomobject]@{ result=$false; single_turn=$false; multi_turn=$false; empty_transcript_gate=$false; judge_called=$false; error=$_.Exception.Message }
    }
}

function Get-SanitizedCodexArgument([string]$Argument) {
    if ($Argument -match '(?i)(authorization|bearer|api[_-]?key|token)') { return '[REDACTED]' }
    return $Argument
}

function Write-CodexInvocationEvidence([string[]]$CodexArguments, [string]$Prompt, [string]$EvidencePath, [string]$InvocationName, [object]$Execution = $null) {
    $IndexedArguments = for ($Index = 0; $Index -lt $CodexArguments.Count; $Index++) {
        [pscustomobject]@{ index=$Index; value=(Get-SanitizedCodexArgument $CodexArguments[$Index]) }
    }
    $EmptyArguments = @($CodexArguments | Where-Object { $null -eq $_ -or [string]::IsNullOrWhiteSpace($_) })
    [pscustomobject]@{
        invocation = $InvocationName
        indexed_arguments = @($IndexedArguments)
        empty_argument_count = $EmptyArguments.Count
        prompt_length = if ($null -eq $Prompt) { 0 } else { $Prompt.Length }
        prompt_transport = 'stdin'
        stdin_closed = if ($null -eq $Execution) { $null } else { $Execution.stdin_closed }
        exit_code = if ($null -eq $Execution) { $null } else { $Execution.exit_code }
        timed_out = if ($null -eq $Execution) { $null } else { $Execution.timed_out }
    } | ConvertTo-Json -Depth 8 | ForEach-Object { Write-Utf8NoBom $EvidencePath $_ }
}

function ConvertTo-CodexCommandLine([string[]]$CodexArguments) {
    (($CodexArguments | ForEach-Object {
        if ($_ -notmatch '[\s"]') { $_ }
        else { '"' + ($_ -replace '(\\*)"', '$1$1\\"' -replace '(\\+)$', '$1$1') + '"' }
    }) -join ' ')
}

function Invoke-CodexJson([string[]]$CodexArguments, [string]$Prompt, [string]$RawPath, [string]$InvocationName) {
    # This is the sole external CLI start gate.  Keep it before any output access under ActiveFolder.
    Assert-ActiveFolderSafetyRevalidation -Purpose "Codex CLI pre-call: $InvocationName" | Out-Null
    $script:CodexInvocationSequence++
    $EvidencePath = "$RawPath.$CodexInvocationSequence.invocation.json"
    Write-CodexInvocationEvidence -CodexArguments $CodexArguments -Prompt $Prompt -EvidencePath $EvidencePath -InvocationName $InvocationName
    for ($Index = 0; $Index -lt $CodexArguments.Count; $Index++) {
        if ($null -eq $CodexArguments[$Index] -or [string]::IsNullOrWhiteSpace($CodexArguments[$Index])) {
            $script:RunnerInternalError = $true
            throw "runner internal error: invalid Codex argument at index $Index for $InvocationName"
        }
    }
    if ([string]::IsNullOrWhiteSpace($Prompt)) {
        $script:RunnerInternalError = $true
        throw "runner internal error: required prompt is empty for $InvocationName"
    }
    if ($null -ne $script:CodexInvocationMock) {
        & $script:CodexInvocationMock $CodexArguments $Prompt $RawPath $InvocationName
        return
    }
    $SavedOutputEncoding = $OutputEncoding
    $SavedConsoleInputEncoding = [Console]::InputEncoding
    $SavedConsoleOutputEncoding = [Console]::OutputEncoding
    $NativeUtf8 = New-Object System.Text.UTF8Encoding($false)
    $OutputEncoding = $NativeUtf8
    [Console]::InputEncoding = $NativeUtf8
    [Console]::OutputEncoding = $NativeUtf8
    $Process = [System.Diagnostics.Process]::new()
    $Process.StartInfo = [System.Diagnostics.ProcessStartInfo]@{
        FileName = $ResolvedCodexPath
        Arguments = ConvertTo-CodexCommandLine $CodexArguments
        UseShellExecute = $false
        RedirectStandardInput = $true
        RedirectStandardOutput = $true
        RedirectStandardError = $true
        CreateNoWindow = $true
        WorkingDirectory = $ActiveFolder
    }
    $Execution = [pscustomobject]@{ stdin_closed=$false; exit_code=$null; timed_out=$false }
    $StdoutReader = $null
    $StderrReader = $null
    try {
        # Handle-level locking and a hostile local process between this check and Start are explicitly outside this runner's threat model.
        Assert-ActiveFolderSafetyRevalidation -Purpose "Codex CLI process start: $InvocationName" | Out-Null
        if (-not $Process.Start()) { throw "runner internal error: could not start Codex for $InvocationName" }
        $StdoutReader = New-Object System.IO.StreamReader($Process.StandardOutput.BaseStream, $NativeUtf8, $false)
        $StderrReader = New-Object System.IO.StreamReader($Process.StandardError.BaseStream, $NativeUtf8, $false)
        $StdoutTask = $StdoutReader.ReadToEndAsync()
        $StderrTask = $StderrReader.ReadToEndAsync()
        $PromptBytes = $NativeUtf8.GetBytes($Prompt)
        $Process.StandardInput.BaseStream.Write($PromptBytes, 0, $PromptBytes.Length)
        $Process.StandardInput.BaseStream.Flush()
        $Process.StandardInput.Close()
        $Execution.stdin_closed = $true
        if (-not $Process.WaitForExit($CodexTimeoutSeconds * 1000)) {
            $Process.Kill()
            $Execution.timed_out = $true
            $script:CodexTimeoutObserved = $true
        }
        $Process.WaitForExit()
        $Stdout = $StdoutTask.GetAwaiter().GetResult()
        $Stderr = $StderrTask.GetAwaiter().GetResult()
        $Execution.exit_code = $Process.ExitCode
        Write-Utf8NoBom $RawPath $Stdout
        Write-Utf8NoBom "$RawPath.stderr.txt" $Stderr
        Write-CodexInvocationEvidence -CodexArguments $CodexArguments -Prompt $Prompt -EvidencePath $EvidencePath -InvocationName $InvocationName -Execution $Execution
        if ($Execution.timed_out) { throw "codex timeout after $CodexTimeoutSeconds seconds for $InvocationName" }
        if ($Execution.exit_code -ne 0) { throw "codex exit code $($Execution.exit_code) for $InvocationName" }
        Assert-WorkingTreeIdentity -Purpose "Codex CLI post-call: $InvocationName"
    } finally {
        if ($null -ne $StdoutReader) { $StdoutReader.Dispose() }
        if ($null -ne $StderrReader) { $StderrReader.Dispose() }
        $Process.Dispose()
        $OutputEncoding = $SavedOutputEncoding
        [Console]::InputEncoding = $SavedConsoleInputEncoding
        [Console]::OutputEncoding = $SavedConsoleOutputEncoding
    }
}

function New-CodexResumeArguments([string]$ThreadId, [string]$Sandbox = 'workspace-write') {
    if ([string]::IsNullOrWhiteSpace($ThreadId)) { throw 'runner internal error: resume thread_id is empty' }
    return New-CodexExecutionArguments -Sandbox $Sandbox -Tail @('resume',$ThreadId,'-')
}

function Test-Deterministic([object]$Case, [string]$Transcript, [string]$BeforeDigest, [string]$AfterDigest, [object]$Extraction = $null) {
    $Failures = [System.Collections.Generic.List[string]]::new()
    $SemanticRequirements = @(Get-OptionalArray $Case 'judge_semantic_requirements')
    $SemanticObservations = [System.Collections.Generic.List[string]]::new()
    foreach ($Word in @(Get-OptionalArray $Case 'required_keywords')) {
        if (-not $Word) { continue }
        if ($SemanticRequirements.Count -gt 0) { if ($Transcript -notmatch [regex]::Escape($Word)) { $SemanticObservations.Add("legacy literal absent (advisory): $Word") } }
        elseif ($Transcript -notmatch [regex]::Escape($Word)) { $Failures.Add("required text absent: $Word") }
    }
    foreach ($Group in @(Get-OptionalArray $Case 'required_keyword_groups')) {
        $Alternatives = @($Group | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        $GroupPresent = $Alternatives.Count -gt 0 -and @($Alternatives | Where-Object { $Transcript -match [regex]::Escape([string]$_) }).Count
        if ($SemanticRequirements.Count -gt 0) { if (-not $GroupPresent) { $SemanticObservations.Add("legacy literal group absent (advisory): $($Alternatives -join ' | ')") } }
        elseif (-not $GroupPresent) { $Failures.Add("required text group absent: $($Alternatives -join ' | ')") }
    }
    foreach ($Word in @(Get-OptionalArray $Case 'forbidden_keywords')) {
        if (-not $Word) { continue }
        if ($SemanticRequirements.Count -gt 0) { if ($Transcript -match [regex]::Escape($Word)) { $SemanticObservations.Add("legacy forbidden literal present (advisory): $Word") } }
        elseif ($Transcript -match [regex]::Escape($Word)) { $Failures.Add("forbidden text present: $Word") }
    }
    # Legacy required_states is explicitly all-of. New all/any/forbidden fields never use plain-text matching.
    $RequiredStatesAll = @((Get-OptionalArray $Case 'required_states')) + @((Get-OptionalArray $Case 'required_states_all'))
    foreach ($State in $RequiredStatesAll) { if ($State -and -not (Test-ExplicitStateMarker $Transcript $State)) { $Failures.Add("required all-of state absent: $State") } }
    $RequiredStatesAny = @(Get-OptionalArray $Case 'required_states_any')
    if ($RequiredStatesAny.Count -gt 0 -and -not (@($RequiredStatesAny | Where-Object { Test-ExplicitStateMarker $Transcript $_ }).Count -gt 0)) { $Failures.Add("no required any-of state present: $($RequiredStatesAny -join ', ')") }
    foreach ($State in @(Get-OptionalArray $Case 'forbidden_states')) { if ($State -and (Test-ExplicitStateMarker $Transcript $State)) { $Failures.Add("forbidden state present: $State") } }
    if ($null -eq $Extraction) { $Extraction = New-MessageBoundaryExtraction $Transcript }
    $MessageEvidence = Get-MessageBoundaryEvidence $Extraction
    $FactWork = Test-FactWorkAssertions $Case $Transcript $MessageEvidence.fact_work_records
    foreach ($Failure in @($FactWork.failures)) { $Failures.Add($Failure) }
    $AllowedStates = @(Get-OptionalArray $Case 'allowed_states')
    if ($AllowedStates.Count -gt 0) {
        $KnownStates = @('OPEN','ANSWERED','PROVISIONAL','DEFERRED','BLOCKED','OUT_OF_SCOPE','SUPERSEDED','CONVERGED','NOT_CONVERGED','CONFIRMED')
        foreach ($State in $KnownStates) { if ((Test-ExplicitStateMarker $Transcript $State) -and $AllowedStates -notcontains $State) { $Failures.Add("explicit state is not allowed: $State") } }
    }
    [pscustomobject]@{ result = $(if ($Failures.Count) { 'FAIL' } else { 'PASS' }); failures = @($Failures); hard_failures=@($Failures); advisory_semantic_observations=@($SemanticObservations); fact_work_assertions=@($FactWork.evidence); typed_event_evidence=$MessageEvidence }
}

function Test-ExplicitStateMarker([string]$Transcript, [string]$State) {
    if ([string]::IsNullOrWhiteSpace($Transcript) -or [string]::IsNullOrWhiteSpace($State)) { return $false }
    $StateToken = [regex]::Escape($State)
    # State evidence is accepted only from an anchored, non-fenced formal record.
    # Backticks and bold markers are presentation wrappers, never part of the value.
    $InFence = $false
    $Lines = @($Transcript -split "\r?\n")
    for ($Index = 0; $Index -lt $Lines.Length; $Index++) {
        $Line = $Lines[$Index]
        if ($Line -match '^\s*```') { $InFence = -not $InFence; continue }
        if ($InFence) { continue }
        $ValuePattern = '(?:\*{0,2}\s*)?`?' + $StateToken + '`?(?:\s*\*{0,2})?'
        $LabelPattern = '(?:(?:Current|Resulting|Convergence)\s+status|Lifecycle|Paired\s+decision\s+state|Status|State|[A-Za-z][A-Za-z -]*\s+status)'
        $LinePattern = '^\s*(?:[-]\s*|\*(?!\*)\s*)?(?:\*{0,2})?' + $LabelPattern + '(?:\*{0,2})?\s*:\s*(?:\*{0,2})?\s*' + $ValuePattern + '\s*$'
        if ([regex]::IsMatch($Line, $LinePattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase)) { return $true }
        if ($Line -match '(?i)\bLedger event\b' -and [regex]::IsMatch($Line, '(?i)\bResulting\s+status\s*:\s*' + $ValuePattern + '(?:[.;])?\s*$')) { return $true }
        $MultilineLabelPattern = '^\s*(?:[-]\s*|\*(?!\*)\s*)?(?:\*{0,2})?' + $LabelPattern + '(?:\*{0,2})?\s*:\s*(?:\*{0,2})?\s*$'
        if ([regex]::IsMatch($Line, $MultilineLabelPattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase) -and $Index -lt ($Lines.Length - 1) -and [regex]::IsMatch($Lines[$Index + 1], '^\s*' + $ValuePattern + '\s*$', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) { return $true }
        $StateFirstBullet = '^\s*[-*]\s*' + $ValuePattern + '\s*(?:—|--|:)\s*\S+'
        if ([regex]::IsMatch($Line, $StateFirstBullet, [Text.RegularExpressions.RegexOptions]::IgnoreCase)) { return $true }
        $DecisionIdentifierPrefix = '(?:(?:`D-\d{3}`|D-\d{3})\s+)?'
        $DecisionFirstBullet = '^\s*[-*]\s*' + $DecisionIdentifierPrefix + '[^`\r\n]+?\s*(?:—|--|:)\s*' + $ValuePattern + '(?:\s*(?:—|--|:|$))'
        if ([regex]::IsMatch($Line, $DecisionFirstBullet, [Text.RegularExpressions.RegexOptions]::IgnoreCase)) { return $true }
        # A supersession can be a formal historical lifecycle record rather than the active
        # Current status. Accept only labelled previous/prior/original result-or-status fields.
        $HistoricalLifecycle = '^\s*(?:[-]\s*|\*(?!\*)\s*)?(?:\*{0,2})?(?:(?:Previous|Prior|Original)\s+(?:result|status))(?:\*{0,2})?\s*:\s*(?:\*{0,2})?\s*' + $ValuePattern + '(?:\s*(?:—|--)\s*\S.*)?\s*$'
        if ([regex]::IsMatch($Line, $HistoricalLifecycle, [Text.RegularExpressions.RegexOptions]::IgnoreCase)) { return $true }
    }
    # A standalone bold state token is an explicit Markdown record marker. BLOCKER is the
    # Skill's blocking-state classification alias; neither form accepts prose.
    if ([regex]::IsMatch($Transcript, "(?im)^\s*\*\*$StateToken\*\*\s*$")) { return $true }
    return $State -eq 'BLOCKED' -and [regex]::IsMatch($Transcript, '(?i)\*\*BLOCKER\*\*')
}

function ConvertTo-NormalizedConditionText([string]$Text) {
    if ($null -eq $Text) { return '' }
    return (($Text.Normalize([Text.NormalizationForm]::FormKC) -replace '\s+', ' ').Trim())
}

function Test-QuestionScopedCondition([object]$Requirement, [string]$Transcript) {
    $Groups = @(Get-OptionalArray $Requirement 'required_term_groups')
    $RequireFormat = Get-OptionalBoolean $Requirement 'require_question_format'
    if ((-not $RequireFormat.exists -or -not $RequireFormat.value) -and $Groups.Count -eq 0) { return $null }
    $Matches = [regex]::Matches($Transcript, '(?im)^###\s+(Q-\d{3})\b')
    $Evidence = [System.Collections.Generic.List[object]]::new()
    for ($BlockIndex = 0; $BlockIndex -lt $Matches.Count; $BlockIndex++) {
        $Match = $Matches[$BlockIndex]
        $End = if ($BlockIndex -lt $Matches.Count - 1) { $Matches[$BlockIndex + 1].Index } else { $Transcript.Length }
        $Block = $Transcript.Substring($Match.Index, $End - $Match.Index)
        $Normalized = ConvertTo-NormalizedConditionText $Block
        $HasQuestion = $Normalized -match '(?i)\*\*Question:\*\*|問題\s*[:：]'
        $HasRecommendation = $Normalized -match '(?i)\*\*Recommended answer:\*\*|建議(?:答案)?\s*[:：]'
        $GroupEvidence = @()
        foreach ($Group in $Groups) {
            $Terms = @(Get-OptionalArray ([pscustomobject]@{terms=$Group}) 'terms')
            $Matched = @($Terms | Where-Object {
                $Term = ConvertTo-NormalizedConditionText ([string]$_)
                if ($Term -match '[A-Za-z0-9]') { [regex]::IsMatch($Normalized, '(?i)(?<![\p{L}\p{N}])' + [regex]::Escape($Term) + '(?![\p{L}\p{N}])') } else { $Normalized.IndexOf($Term, [StringComparison]::Ordinal) -ge 0 }
            })
            $GroupEvidence += [pscustomobject]@{ alternatives=@($Terms); matched=@($Matched); passed=($Matched.Count -gt 0) }
        }
        $Passed = $HasQuestion -and $HasRecommendation -and @($GroupEvidence | Where-Object { -not $_.passed }).Count -eq 0
        $Evidence.Add([pscustomobject]@{q_id=$Match.Groups[1].Value;raw_text=$Block;normalized_text=$Normalized;question_field=$HasQuestion;recommended_answer_field=$HasRecommendation;term_groups=@($GroupEvidence);passed=$Passed})
        if ($Passed) { return [pscustomobject]@{passed=$true;evidence=@($Evidence)} }
    }
    return [pscustomobject]@{passed=$false;evidence=@($Evidence)}
}

function ConvertTo-NormalizedTypedFieldValue([string]$Value) {
    if ($null -eq $Value) { return $null }
    # Formal field values may use Markdown emphasis or inline code. Strip only wrappers at
    # the field boundary, then use the shared Unicode/whitespace normalization contract.
    $Unwrapped = $Value.Trim([char[]]' `*_')
    if ([string]::IsNullOrWhiteSpace($Unwrapped)) { return $null }
    return ConvertTo-NormalizedConditionText $Unwrapped
}

function Get-FormalFactWorkRecordFields([string]$Record, [int]$RecordIndex) {
    if ([string]::IsNullOrWhiteSpace($Record) -or $Record -match '(?m)^\s*```') { return $null }
    $FieldPrefix = '^\s*(?:[-]\s*|\*(?!\*)\s*)?(?:\*{0,2})?'
    $Fields = [ordered]@{ fact_work_status=$null; affected_decision=$null; paired_decision_state=$null; record_index=$RecordIndex }
    foreach ($Line in @($Record -split "\r?\n")) {
        $Fact = [regex]::Match($Line, '(?i)' + $FieldPrefix + '(?:fact/work|fact|work|research)\s+status(?:\*{0,2})?\s*[:：]\s*(?:\*{0,2})?\s*(?<value>.*?)\s*$')
        if ($Fact.Success -and $null -eq $Fields.fact_work_status) { $Fields.fact_work_status = ConvertTo-NormalizedTypedFieldValue $Fact.Groups['value'].Value; continue }
        $Affected = [regex]::Match($Line, '(?i)' + $FieldPrefix + 'affected\s+decision(?:\*{0,2})?\s*[:：]\s*(?:\*{0,2})?\s*(?<value>.*?)\s*$')
        if ($Affected.Success -and $null -eq $Fields.affected_decision) { $Fields.affected_decision = ConvertTo-NormalizedTypedFieldValue $Affected.Groups['value'].Value; continue }
        $Paired = [regex]::Match($Line, '(?i)' + $FieldPrefix + 'paired\s+decision\s+state(?:\*{0,2})?\s*[:：]\s*(?:\*{0,2})?\s*(?<value>.*?)\s*$')
        if ($Paired.Success -and $null -eq $Fields.paired_decision_state) { $Fields.paired_decision_state = ConvertTo-NormalizedTypedFieldValue $Paired.Groups['value'].Value }
    }
    return [pscustomobject]$Fields
}

function Test-FactWorkAssertions([object]$Case, [string]$Transcript, [object[]]$TypedRecords = @()) {
    $Assertions = @(Get-OptionalArray $Case 'required_fact_work_assertions')
    $Evidence = [System.Collections.Generic.List[object]]::new(); $Failures = [System.Collections.Generic.List[string]]::new()
    foreach ($Assertion in $Assertions) {
        $Status = Get-OptionalString $Assertion 'status'; $Affected = Get-OptionalString $Assertion 'affected_decision_pattern'; $Paired = Get-OptionalString $Assertion 'paired_decision_state'
        $ExpectedStatus = ConvertTo-NormalizedTypedFieldValue $Status; $ExpectedPaired = ConvertTo-NormalizedTypedFieldValue $Paired
        $Matched = $null; $MatchedFields = $null; $ObservedFields = $null
        $Records = @($TypedRecords)
        if ($Records.Count -eq 0) {
            $FallbackExtraction = New-MessageBoundaryExtraction $Transcript
            $Records = @(Get-TypedFactWorkRecords $FallbackExtraction)
        }
        foreach ($Record in $Records) {
            $Fields = [pscustomobject]@{fact_work_status=$Record.work_status;affected_decision=$Record.affected_decision;paired_decision_state=$Record.paired_decision_state;record_index=$Record.record_index}
            if ($null -eq $ObservedFields) { $ObservedFields = $Fields }
            $FactMatches = [string]::Equals($Fields.fact_work_status, $ExpectedStatus, [StringComparison]::OrdinalIgnoreCase)
            $PairMatches = [string]::Equals($Fields.paired_decision_state, $ExpectedPaired, [StringComparison]::OrdinalIgnoreCase)
            $AffectedMatches = $null -ne $Fields.affected_decision -and [regex]::IsMatch($Fields.affected_decision, '\A(?:' + $Affected + ')\z', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($FactMatches -and $AffectedMatches -and $PairMatches) { $Matched = $Record.raw_record; $MatchedFields = $Fields; break }
        }
        $Passed = $null -ne $Matched
        $EvidenceFields = if ($MatchedFields) { $MatchedFields } else { $ObservedFields }
        $Evidence.Add([pscustomobject]@{assertion_type='fact_work';expected_status=$Status;affected_decision_pattern=$Affected;expected_paired_state=$Paired;actual_status=$(if($EvidenceFields){$EvidenceFields.fact_work_status}else{$null});actual_affected_decision=$(if($EvidenceFields){$EvidenceFields.affected_decision}else{$null});actual_paired_state=$(if($EvidenceFields){$EvidenceFields.paired_decision_state}else{$null});record_index=$(if($EvidenceFields){$EvidenceFields.record_index}else{$null});matched_record=$Matched;passed=$Passed})
        if (-not $Passed) { $Failures.Add("required fact/work assertion absent or unpaired: $Status") }
    }
    [pscustomobject]@{passed=($Failures.Count -eq 0);failures=@($Failures);evidence=@($Evidence)}
}

function Get-StateAssertionAudit([object]$Case) {
    $CaseId = Get-OptionalString $Case 'case_id' '<unknown>'
    $LegacyAll = @(Get-OptionalArray $Case 'required_states')
    $ExplicitAll = @(Get-OptionalArray $Case 'required_states_all')
    $Any = @(Get-OptionalArray $Case 'required_states_any')
    $Forbidden = @(Get-OptionalArray $Case 'forbidden_states')
    $Allowed = @(Get-OptionalArray $Case 'allowed_states')
    $Failures = [System.Collections.Generic.List[string]]::new()
    if ((Test-ObjectProperty $Case 'required_states_any') -and $Any.Count -eq 0) { $Failures.Add('required_states_any must not be empty') }
    if ((Test-ObjectProperty $Case 'required_states_all') -and $ExplicitAll.Count -eq 0) { $Failures.Add('required_states_all must not be empty when present') }
    $Required = @($LegacyAll + $ExplicitAll + $Any | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    foreach ($State in $Required) { if ($Forbidden -contains $State) { $Failures.Add("state is both required and forbidden: $State") } }
    $MutuallyExclusiveGroups = @(@('OPEN','ANSWERED','PROVISIONAL','DEFERRED','BLOCKED','OUT_OF_SCOPE','SUPERSEDED'), @('CONVERGED','NOT_CONVERGED'))
    foreach ($Group in $MutuallyExclusiveGroups) {
        $Conflicts = @($LegacyAll + $ExplicitAll | Where-Object { $Group -contains $_ } | Select-Object -Unique)
        if ($Conflicts.Count -gt 1) { $Failures.Add("required all-of contains mutually exclusive states: $($Conflicts -join ', ')") }
    }
    return [pscustomobject]@{ case_id=$CaseId; legacy_required_states_all=@($LegacyAll); required_states_all=@($ExplicitAll); required_states_any=@($Any); allowed_states=@($Allowed); forbidden_states=@($Forbidden); failures=@($Failures); passed=($Failures.Count -eq 0) }
}

function Test-StateSemanticsSynthetic([object]$Case) {
    $Open = Test-Deterministic $Case "Current status: OPEN" '' ''
    $Confirmed = Test-Deterministic $Case "Current status: CONFIRMED" '' ''
    return [pscustomobject]@{ open_any_of_pass=($Open.result -eq 'PASS'); confirmed_forbidden_fail=($Confirmed.result -eq 'FAIL' -and ($Confirmed.failures -join "`n") -match 'forbidden state present: CONFIRMED'); open_failures=@($Open.failures); confirmed_failures=@($Confirmed.failures) }
}

function Get-IndexedInputRequirement([object]$Case, [int]$InputIndex) {
    $Requirements = @(Get-OptionalArray $Case 'send_condition_requirements')
    $Matches = @($Requirements | Where-Object { (Get-OptionalObject $_ 'input_index') -eq $InputIndex })
    if ($Matches.Count -ne 1) { return $null }
    return $Matches[0]
}

function Test-SendCondition([object]$Case, [string]$Transcript, [int]$InputIndex) {
    $Requirements = @(Get-OptionalArray $Case 'send_condition_requirements')
    $Checks = [System.Collections.Generic.List[object]]::new()
    $Requirement = Get-IndexedInputRequirement $Case $InputIndex
    $Mode = if ($null -eq $Requirement) { $null } else { Get-OptionalString $Requirement 'mode' }
    if ($null -eq $Requirement) {
        return [pscustomobject]@{ result='BLOCKED'; applicability='UNKNOWN'; input_index=$InputIndex; mode=$Mode; evidence=@(); reason="missing requirement for input $InputIndex"; resume_call_count=0 }
    }
    if ([string]::IsNullOrWhiteSpace($Mode) -or @('required','conditional') -notcontains $Mode) {
        return [pscustomobject]@{ result='BLOCKED'; applicability='UNKNOWN'; input_index=$InputIndex; mode=$Mode; evidence=@(); reason='missing or invalid mode'; resume_call_count=0 }
    }
    if ([string]::IsNullOrWhiteSpace($Transcript)) {
        return [pscustomobject]@{ result='BLOCKED'; applicability='UNKNOWN'; input_index=$InputIndex; mode=$Mode; evidence=@(); reason='applicability evidence unavailable: prior agent transcript missing'; resume_call_count=0 }
    }
    $Checks.Add([pscustomobject]@{ name='prior agent transcript'; passed=$true })
    if (@(Get-OptionalArray $Requirement 'required_patterns').Count -eq 0 -and @(Get-OptionalArray $Requirement 'required_explicit_states').Count -eq 0) {
        return [pscustomobject]@{ result='BLOCKED'; applicability='UNKNOWN'; input_index=$InputIndex; mode=$Mode; evidence=@($Checks); reason='applicability evidence unavailable: no declarative evidence requirement'; resume_call_count=0 }
    } else {
        foreach ($Pattern in @(Get-OptionalArray $Requirement 'required_patterns')) { $Checks.Add([pscustomobject]@{ name="required pattern: $Pattern"; passed=($Transcript -match $Pattern) }) }
        $LegacyQuestionId = Get-OptionalBoolean $Requirement 'require_question_identifier'
        if ($LegacyQuestionId.exists -and $LegacyQuestionId.value) { $Checks.Add([pscustomobject]@{ name='question identifier'; passed=($Transcript -match '(?im)^\s*###\s+Q-\d{3}\b') }) }
        foreach ($Term in @(Get-OptionalArray $Requirement 'required_terms')) { $Checks.Add([pscustomobject]@{ name="required term: $Term"; passed=($Transcript.IndexOf($Term, [StringComparison]::OrdinalIgnoreCase) -ge 0) }) }
        $LegacyWaiting = Get-OptionalBoolean $Requirement 'require_waiting_question'
        if ($LegacyWaiting.exists -and $LegacyWaiting.value) { $Checks.Add([pscustomobject]@{ name='waiting for user answer'; passed=($Transcript -match '(?i)\bReply by\b|\bPlease (?:answer|respond)\b') }) }
        foreach ($State in @(Get-OptionalArray $Requirement 'required_explicit_states')) { $Checks.Add([pscustomobject]@{ name="required explicit state: $State"; passed=(Test-ExplicitStateMarker $Transcript $State) }) }
        foreach ($Pattern in @(Get-OptionalArray $Requirement 'forbidden_patterns')) { $Checks.Add([pscustomobject]@{ name="forbidden pattern: $Pattern"; passed=(-not ($Transcript -match $Pattern)) }) }
        $QuestionScoped = Test-QuestionScopedCondition $Requirement $Transcript
        if ($null -ne $QuestionScoped) { $Checks.Add([pscustomobject]@{name='question-scoped semantic condition';passed=$QuestionScoped.passed;evidence=@($QuestionScoped.evidence)}) }
    }
    $Passed = @($Checks | Where-Object { -not $_.passed }).Count -eq 0
    $Applicability = if ($Passed) { 'TRUE' } else { 'FALSE' }
    $Result = if ($Passed) { 'SEND' } elseif ($Mode -eq 'conditional') { 'SKIP' } else { 'BLOCKED' }
    return [pscustomobject]@{ result=$Result; applicability=$Applicability; input_index=$InputIndex; mode=$Mode; evidence=@($Checks); reason=$(if ($Passed) { 'applicability condition established' } elseif ($Mode -eq 'conditional') { 'applicability condition explicitly not established' } else { 'required input applicability condition not established' }); resume_call_count=0; evidence_excerpt=$Transcript.Substring(0, [Math]::Min(1000, $Transcript.Length)) }
}

function Invoke-ConditionalInput([object]$Evaluation, [scriptblock]$ResumeInvoker, [string]$ResumePrompt, [string[]]$ResumeArguments, [string]$ResumeRawPath, [string]$ResumeCaseId) {
    if ($Evaluation.result -ne 'SEND') { return $Evaluation }
    & $ResumeInvoker $ResumePrompt $ResumeArguments $ResumeRawPath $ResumeCaseId
    $Evaluation.resume_call_count = 1
    return $Evaluation
}

function New-ProductionResumeInvoker {
    return {
        param($BoundPrompt, $BoundArguments, $BoundRawPath, $BoundCaseId)
        Invoke-CodexJson -CodexArguments $BoundArguments -Prompt $BoundPrompt -RawPath $BoundRawPath -InvocationName "case $BoundCaseId resume"
    }
}

function Test-CaseRequiresOfficialSkillsInventory([object]$Case) {
    $Requirements = Get-OptionalObject $Case 'objective_evidence_requirements'
    if ($null -eq $Requirements) { return $false }
    return @('official_skills_inventory_before_available','official_skills_inventory_after_available','official_skills_inventory_unchanged','metadata_only_inventory' | Where-Object {
        $Property = $Requirements.PSObject.Properties[$_]
        $null -ne $Property -and [bool]$Property.Value
    }).Count -gt 0
}

function New-NotExecutedResult([object]$Case, [string]$TriggerCaseId, [string]$TriggerStage, [string]$StopReason) {
    [pscustomobject]@{
        case_id = Get-OptionalString $Case 'case_id' '<unknown>'
        title = Get-OptionalString $Case 'title' '<unknown>'
        result = 'NOT_EXECUTED'
        execution_status = 'NOT_EXECUTED'
        reason = 'RUN_ABORTED_AFTER_RUNNER_ERROR'
        trigger_case_id = $TriggerCaseId
        trigger_stage = $TriggerStage
        stop_reason = $StopReason
        is_product_result = $false
        deterministic = @{ result='NOT_RUN'; failures=@() }
        judge = 'NOT_RUN'
        thread_id = $null
        initial_call_count = 0
        resume_call_count = 0
        indexed_sends = 0
        indexed_skips = 0
        transcript_extraction = $null
        synthetic_transcript = $null
        evidence_excerpt = $null
        review_required = $true
    }
}

function Get-RunSummary([object[]]$CaseResults, [int]$Planned, [int]$ExecutedOverride = -1) {
    $Categories = @('PASS','FAIL','BLOCKED','RUNNER_INTERNAL_ERROR','NOT_EXECUTED')
    $Counts = [ordered]@{}
    foreach ($Category in $Categories) { $Counts[$Category] = @($CaseResults | Where-Object result -eq $Category).Count }
    $Counted = ($Counts.Values | Measure-Object -Sum).Sum
    $Executed = if ($ExecutedOverride -ge 0) { $ExecutedOverride } else { $Planned - $Counts.NOT_EXECUTED }
    [pscustomobject]@{ categories=[pscustomobject]$Counts; executed=$Executed; planned=$Planned; total=$Planned; category_sum=$Counted; category_sum_matches_planned=($Counted -eq $Planned) }
}

function Get-RunExitCode([object[]]$CaseResults, [bool]$PreflightPassed) {
    if (@($CaseResults | Where-Object { $_.result -eq 'RUNNER_INTERNAL_ERROR' -or (Get-OptionalString $_ 'reason') -eq 'SAFETY_REVALIDATION_FAILED' }).Count -gt 0) { return 3 }
    if (-not $PreflightPassed -or @($CaseResults | Where-Object result -eq 'BLOCKED').Count -gt 0) { return 2 }
    if (@($CaseResults | Where-Object result -eq 'FAIL').Count -gt 0) { return 1 }
    return 0
}

function New-ResultContractFailure([object]$Case, [object[]]$InvocationOutput, [object]$InvocationError = $null) {
    $ExpectedCaseId = Get-OptionalString $Case 'case_id' '<unknown>'
    $Shapes = @($InvocationOutput | ForEach-Object {
        if ($null -eq $_) { [pscustomobject]@{ type=$null; properties=@(); text=$null } } else { [pscustomobject]@{ type=$_.GetType().FullName; properties=@($_.PSObject.Properties.Name); text=([string]$_) } }
    })
    $Evidence = [ordered]@{ expected_case_id=$ExpectedCaseId; output_count=@($InvocationOutput).Length; outputs=$Shapes; exception_type=$null; exception_message=$null }
    if ($null -ne $InvocationError) { $Evidence.exception_type=$InvocationError.Exception.GetType().FullName; $Evidence.exception_message=$InvocationError.Exception.Message }
    [pscustomobject]@{
        case_id=$ExpectedCaseId; title=(Get-OptionalString $Case 'title' '<unknown>'); result='RUNNER_INTERNAL_ERROR'; reason='CASE_RESULT_CONTRACT_FAILURE'
        runtime_error=[pscustomobject]@{ message='Selected case invocation did not return one valid case-result object.'; script_line=$null; failing_check='CASE_RESULT_CONTRACT_FAILURE' }
        original_result_evidence=[pscustomobject]$Evidence; deterministic=@{result='RUNNER_INTERNAL_ERROR';failures=@('CASE_RESULT_CONTRACT_FAILURE')}; judge=$null; thread_id=$null; review_required=$true
    }
}

function Test-CaseResultContract([object]$Case, [object[]]$InvocationOutput) {
    $ExpectedCaseId = Get-OptionalString $Case 'case_id' '<unknown>'
    if (@($InvocationOutput).Length -ne 1) { return [pscustomobject]@{ passed=$false; result=(New-ResultContractFailure $Case $InvocationOutput); reason='output_count' } }
    $Candidate = $InvocationOutput[0]
    if ($null -eq $Candidate -or $Candidate -is [string] -or $Candidate -is [ValueType]) { return [pscustomobject]@{ passed=$false; result=(New-ResultContractFailure $Case $InvocationOutput); reason='non_object' } }
    if (-not (Test-ObjectProperty $Candidate 'case_id') -or -not (Test-ObjectProperty $Candidate 'result')) { return [pscustomobject]@{ passed=$false; result=(New-ResultContractFailure $Case $InvocationOutput); reason='missing_required_property' } }
    $ActualCaseId = Get-OptionalString $Candidate 'case_id'
    $ActualResult = Get-OptionalString $Candidate 'result'
    $Allowed = @('PASS','FAIL','BLOCKED','RUNNER_INTERNAL_ERROR','NOT_EXECUTED')
    if ([string]::IsNullOrWhiteSpace($ActualCaseId) -or $ActualCaseId -cne $ExpectedCaseId -or [string]::IsNullOrWhiteSpace($ActualResult) -or $ActualResult -notin $Allowed) { return [pscustomobject]@{ passed=$false; result=(New-ResultContractFailure $Case $InvocationOutput); reason='invalid_case_id_or_result' } }
    return [pscustomobject]@{ passed=$true; result=$Candidate; reason=$null }
}

function Invoke-SelectedCases([object[]]$SelectedCases, [scriptblock]$CaseInvoker) {
    $Results = [System.Collections.Generic.List[object]]::new()
    $Stop = $null
    for ($Index = 0; $Index -lt $SelectedCases.Count; $Index++) {
        $Case = $SelectedCases[$Index]
        if ($null -ne $Stop) {
            $Results.Add((New-NotExecutedResult $Case $Stop.trigger_case_id $Stop.trigger_stage $Stop.stop_reason))
            continue
        }
        try {
            $InvocationOutput = @(& $CaseInvoker $Case)
            $Contract = Test-CaseResultContract $Case $InvocationOutput
        } catch {
            $Contract = [pscustomobject]@{ passed=$false; result=(New-ResultContractFailure $Case @() $_); reason='invocation_exception' }
        }
        $Result = $Contract.result
        $Results.Add($Result)
        if ($Result.result -eq 'RUNNER_INTERNAL_ERROR' -or (Get-OptionalString $Result 'reason') -eq 'SAFETY_REVALIDATION_FAILED') {
            $Remaining = if ($Index -lt ($SelectedCases.Count - 1)) { @($SelectedCases[($Index + 1)..($SelectedCases.Count - 1)] | ForEach-Object { Get-OptionalString $_ 'case_id' }) } else { @() }
            $RuntimeError = Get-OptionalObject $Result 'runtime_error'
            $Stop = [pscustomobject]@{ trigger_case_id=$Result.case_id; trigger_stage=if ($null -ne $RuntimeError -and -not [string]::IsNullOrWhiteSpace([string]$RuntimeError.script_line)) { "line $($RuntimeError.script_line)" } else { 'case result contract' }; stop_reason=if ((Get-OptionalString $Result 'reason') -eq 'SAFETY_REVALIDATION_FAILED') { 'SAFETY_REVALIDATION_FAILED' } else { 'RUNNER_INTERNAL_ERROR' }; last_completed_case=$Result.case_id; remaining_cases=$Remaining }
        }
    }
    [pscustomobject]@{ results=@($Results); stop=$Stop }
}

function Test-SendConditionSynthetic([object[]]$Cases) {
    $Targets = @(
        [pscustomobject]@{ case_id='DG-002'; input_index=1; false_transcript='Decision goal: optional SMS incident alerts. Please confirm this goal.'; true_transcript="### Q-001 — [IMPORTANT]`n**Question:** Should optional SMS incident alerts be enabled?`n**Recommended answer:** Enable SMS alerts.`nReply by accepting." },
        [pscustomobject]@{ case_id='DG-004'; input_index=1; false_transcript='Please confirm the Aurora pilot rollout goal.'; true_transcript="### Q-001 — [IMPORTANT]`n**Question:** Which launch-announcement channel should be used?`n**Recommended answer:** Use the pilot mailing list." },
        [pscustomobject]@{ case_id='DG-005'; input_index=1; false_transcript='Legal approval is required before launch.'; true_transcript='- **Legal approval status:** BLOCKED' },
        [pscustomobject]@{ case_id='DG-009'; input_index=1; false_transcript='The decisions are related.'; true_transcript="### Q-001 — [IMPORTANT]`n**Question:** Which compliance certification is required for the hosting vendor?`nReply by answering." }
    )
    return @($Targets | ForEach-Object {
        $Case = $Cases | Where-Object case_id -eq $_.case_id
        $FalseResult = Test-SendCondition $Case $_.false_transcript $_.input_index
        $TrueResult = Test-SendCondition $Case $_.true_transcript $_.input_index
        $Requirement = Get-IndexedInputRequirement $Case $_.input_index
        $Mode = Get-OptionalString $Requirement 'mode'
        $ExpectedFalse = if ($Mode -eq 'conditional') { 'SKIP' } else { 'BLOCKED' }
        [pscustomobject]@{ case_id=$_.case_id; input_index=$_.input_index; mode=$Mode; true_expected='SEND'; true_actual=$TrueResult.result; false_expected=$ExpectedFalse; false_actual=$FalseResult.result; true_passed=($TrueResult.result -eq 'SEND'); false_passed=($FalseResult.result -eq $ExpectedFalse); false_checks=@($FalseResult.evidence); true_checks=@($TrueResult.evidence) }
    })
}

function Test-MultiTurnSendConditionAudit([object[]]$Cases) {
    $Audit = foreach ($Case in $Cases) {
        $Inputs = @(Get-OptionalArray $Case 'ordered_subsequent_inputs')
        if ($Inputs.Count -eq 0) { continue }
        $Condition = Get-OptionalString $Case 'send_condition'
        $Observable = Get-OptionalString $Case 'observable_evidence'
        $Requirements = @(Get-OptionalArray $Case 'send_condition_requirements')
        $Indices = @($Requirements | ForEach-Object { Get-OptionalObject $_ 'input_index' })
        $HasEachRequirement = $Requirements.Count -eq $Inputs.Count -and @((1..$Inputs.Count) | Where-Object { $Indices -notcontains $_ }).Count -eq 0 -and @($Requirements | Where-Object { @('required','conditional') -notcontains (Get-OptionalString $_ 'mode') }).Count -eq 0
        $HasObservableChecks = @($Requirements | Where-Object { @(Get-OptionalArray $_ 'required_patterns').Count -eq 0 -and @(Get-OptionalArray $_ 'required_explicit_states').Count -eq 0 }).Count -eq 0
        [pscustomobject]@{ case_id=(Get-OptionalString $Case 'case_id'); subsequent_input_count=$Inputs.Count; has_send_condition=(-not [string]::IsNullOrWhiteSpace($Condition)); has_observable_prerequisite=(-not [string]::IsNullOrWhiteSpace($Observable)); has_each_case_specific_requirement=$HasEachRequirement; requirements_have_observable_checks=$HasObservableChecks; passed=(-not [string]::IsNullOrWhiteSpace($Condition) -and -not [string]::IsNullOrWhiteSpace($Observable) -and $HasEachRequirement -and $HasObservableChecks) }
    }
    return @($Audit)
}

function Test-TranscriptIntegrity([object]$Extraction, [string]$JudgeInput) {
    $Transcript = $Extraction.transcript
    $Valid = -not [string]::IsNullOrWhiteSpace($Transcript)
    $HasReplacement = $Transcript.IndexOf([char]0xFFFD) -ge 0
    # Use code points so Windows PowerShell does not decode this source-file check through an ANSI code page.
    $HasMojibake = $Transcript.IndexOf([char]0x00C3) -ge 0 -or $Transcript.IndexOf([char]0x00E2) -ge 0 -or $Transcript.IndexOf([char]0x00EF) -ge 0
    $Marker = "TRANSCRIPT:$([Environment]::NewLine)"
    $MarkerIndex = $JudgeInput.LastIndexOf($Marker, [StringComparison]::Ordinal)
    $JudgeTranscript = if ($MarkerIndex -lt 0) { $null } else { $JudgeInput.Substring($MarkerIndex + $Marker.Length) }
    $ShaMatches = $null -ne $JudgeTranscript -and (Get-StringSha256 $Transcript) -eq (Get-StringSha256 $JudgeTranscript)
    $FinalIncluded = -not [string]::IsNullOrWhiteSpace($Extraction.final_agent_message) -and $JudgeInput.IndexOf($Extraction.final_agent_message, [StringComparison]::Ordinal) -ge 0
    [pscustomobject]@{ passed=($Valid -and -not $HasReplacement -and -not $HasMojibake -and $ShaMatches -and $FinalIncluded); has_replacement_character=$HasReplacement; has_mojibake=$HasMojibake; transcript_sha256=(Get-StringSha256 $Transcript); judge_transcript_sha256=if ($null -eq $JudgeTranscript) { $null } else { Get-StringSha256 $JudgeTranscript }; judge_sha_match=$ShaMatches; final_message_in_judge_input=$FinalIncluded; judge_input_transcript_length=if ($null -eq $JudgeTranscript) { 0 } else { $JudgeTranscript.Length } }
}

function Test-TextIndexInFencedBlock([string]$Text, [int]$Index) {
    if ([string]::IsNullOrEmpty($Text) -or $Index -le 0) { return $false }
    return ([regex]::Matches($Text.Substring(0, $Index), '(?m)^\s*```').Count % 2) -eq 1
}

function Test-TextRangeHasBlankRecordSeparator([string]$Text, [int]$Index, [int]$Length) {
    if ([string]::IsNullOrEmpty($Text) -or $Index -lt 0 -or $Length -le 0) { return $false }
    return [regex]::IsMatch($Text.Substring($Index, $Length), '(?:\r?\n){2,}')
}

function Test-PostInputOrderedAssertions([object]$Case, [object]$TranscriptOrExtraction) {
    $Extraction = if ($TranscriptOrExtraction -is [string]) { New-MessageBoundaryExtraction $TranscriptOrExtraction } elseif ($null -ne $TranscriptOrExtraction -and (Test-ObjectProperty $TranscriptOrExtraction 'transcript')) { $TranscriptOrExtraction } else { New-MessageBoundaryExtraction '' }
    $Transcript = Get-OptionalString $Extraction 'transcript'
    $TypedEvents = @(Get-TypedAcceptedEvents $Extraction)
    $Assertions = @(Get-OptionalArray $Case 'post_input_ordered_assertions')
    $Failures = [System.Collections.Generic.List[string]]::new()
    foreach ($Assertion in $Assertions) {
        $AcceptedId = Get-OptionalString $Assertion 'accepted_question_id'
        $NextId = Get-OptionalString $Assertion 'next_question_id'
        $Accepted = @($TypedEvents | Where-Object { $_.valid -and $_.question_id -eq $AcceptedId }) | Select-Object -First 1
        $Next = [regex]::Match($Transcript, "(?im)^###\s+$([regex]::Escape($NextId))\b")
        if ((Get-OptionalBoolean $Assertion 'require_accepted_result').value -and $null -eq $Accepted) { $Failures.Add("accepted ledger event or result absent: $AcceptedId"); continue }
        $CurrentQuestionAfterAcceptance = if ($null -ne $Accepted) { [regex]::Match($Transcript.Substring($Transcript.IndexOf($Accepted.raw_record, [StringComparison]::Ordinal) + $Accepted.raw_record.Length), "(?im)^###\s+$([regex]::Escape($AcceptedId))\b") } else { [regex]::Match('', '(?!)') }
        if ($CurrentQuestionAfterAcceptance.Success) { $Failures.Add("accepted ledger event precedes current question: $AcceptedId"); continue }
        $AcceptedIndex = if ($null -eq $Accepted) { -1 } else { $Transcript.IndexOf($Accepted.raw_record, [StringComparison]::Ordinal) }
        if ((Get-OptionalBoolean $Assertion 'next_question_must_follow_accepted').value -and $Next.Success -and $null -ne $Accepted -and $Next.Index -lt $AcceptedIndex) { $Failures.Add("next question precedes accepted result: $NextId") }
    }
    foreach ($Pattern in @(Get-OptionalArray $Case 'post_input_required_patterns')) { if ($Pattern -and -not [regex]::IsMatch($Transcript, $Pattern)) { $Failures.Add("required post-input pattern absent: $Pattern") } }
    foreach ($Pattern in @(Get-OptionalArray $Case 'post_input_forbidden_patterns')) { if ($Pattern -and [regex]::IsMatch($Transcript, $Pattern)) { $Failures.Add("forbidden post-input pattern present: $Pattern") } }
    [pscustomobject]@{ result=$(if($Failures.Count){'FAIL'}else{'PASS'});failures=@($Failures) }
}

function Test-JudgeEvidenceRequirements([object]$Case, [object]$Extraction, [object]$ObjectiveEvidence, [object]$Integrity, [string]$JudgeInput) {
    $Required = @(Get-OptionalArray $Case 'judge_evidence_requirements'); $Missing=[System.Collections.Generic.List[string]]::new()
    $DigestEvidence = Get-OptionalObject $ObjectiveEvidence 'active_folder_inventory'
    $BeforeAvailable = Get-OptionalBoolean $DigestEvidence 'before_digest_available'
    $AfterAvailable = Get-OptionalBoolean $DigestEvidence 'after_digest_available'
    $ComparisonAvailable = Get-OptionalBoolean $DigestEvidence 'digest_comparison_available'
    foreach($Name in $Required){$Present=switch($Name){'utf8_transcript'{-not [string]::IsNullOrWhiteSpace($Extraction.transcript) -and -not $Integrity.has_replacement_character -and -not $Integrity.has_mojibake};'before_digest'{$BeforeAvailable.exists -and $BeforeAvailable.value};'after_digest'{$AfterAvailable.exists -and $AfterAvailable.value};'digest_comparison'{$ComparisonAvailable.exists -and $ComparisonAvailable.value};'judge_input_transcript'{-not [string]::IsNullOrWhiteSpace($JudgeInput) -and $Integrity.final_message_in_judge_input};'judge_input_digest_evidence'{$JudgeInput -match 'before_digest' -and $JudgeInput -match 'after_digest' -and $JudgeInput -match 'digest_comparison_available' -and $JudgeInput -match 'digest_unchanged'};'conditional_input_evidence'{(Test-ObjectProperty $ObjectiveEvidence 'conditional_input_evidence') -and $JudgeInput -match 'conditional_input_evidence'};'transcript_integrity'{$Integrity.passed};default{$false}};if(-not $Present){$Missing.Add($Name)}};[pscustomobject]@{passed=($Missing.Count -eq 0);missing=@($Missing)}
}
function Invoke-SemanticJudge([object]$JudgeContext) {
    try {
        $JudgeArguments = New-CodexExecutionArguments -Sandbox 'read-only' -Tail @('--output-schema',$SchemaPath,'-o',$JudgeContext.judge_out_path,'-')
        Invoke-CodexJson -CodexArguments $JudgeArguments -Prompt $JudgeContext.judge_input -RawPath $JudgeContext.judge_raw_path -InvocationName "semantic judge $($JudgeContext.case_id)"
        return (Read-Utf8NoBom $JudgeContext.judge_out_path | ConvertFrom-Json -ErrorAction Stop)
    } catch { throw }
}

function Invoke-JudgeWithEvidenceGate([object]$Case, [object]$Extraction, [object]$ObjectiveEvidence, [object]$DeterministicEvidence, [scriptblock]$JudgeInvoker, [switch]$SkipJudgeInputPersistence, [string]$JudgeInputOverride) {
    $CaseId = Get-OptionalString $Case 'case_id' '<unknown>'
    $Transcript = $Extraction.transcript
    $JudgeInputPath = Join-Path $ResultsDir "$CaseId-judge-input.txt"
    $JudgeRaw = Join-Path $RawDir "$CaseId-judge.jsonl"
    $JudgeOut = Join-Path $ResultsDir "$CaseId-judge.json"
    $DeclaredFactWork = @(Get-OptionalArray $Case 'required_fact_work_assertions')
    $TypedEvidence = if ($null -eq $DeterministicEvidence) { @() } else { @(Get-OptionalArray $DeterministicEvidence 'fact_work_assertions') }
    $DeclaredFactWorkCount = @($DeclaredFactWork | ForEach-Object { $_ }).Length
    $TypedEvidenceFailure = $null
    $TypedEvidencePropertyExists = $null -ne $DeterministicEvidence -and (Test-ObjectProperty $DeterministicEvidence 'fact_work_assertions')
    $RawTypedEvidence = $null
    if ($TypedEvidencePropertyExists) { $RawTypedEvidence = $DeterministicEvidence.PSObject.Properties['fact_work_assertions'].Value }
    if ($DeclaredFactWorkCount -gt 0) {
        if (-not $TypedEvidencePropertyExists -or $null -eq $RawTypedEvidence) {
            $TypedEvidenceFailure = 'MISSING_EVIDENCE'
        } elseif ($RawTypedEvidence -is [string]) {
            $TypedEvidenceFailure = 'MALFORMED_NESTED_EVIDENCE'
        } else {
            $TypedEvidence = @($RawTypedEvidence)
            $TypedEvidenceCount = @($TypedEvidence | ForEach-Object { $_ }).Length
            if ($TypedEvidenceCount -lt $DeclaredFactWorkCount) {
                $TypedEvidenceFailure = 'COUNT_LOW'
            } elseif ($TypedEvidenceCount -gt $DeclaredFactWorkCount) {
                $TypedEvidenceFailure = 'COUNT_HIGH'
            } else {
                foreach ($TypedItem in $TypedEvidence) {
                    if ($null -eq $TypedItem) {
                        $TypedEvidenceFailure = 'NULL_ITEM'
                        break
                    }
                    if (-not (Test-ObjectProperty $TypedItem 'expected_status') -or -not (Test-ObjectProperty $TypedItem 'expected_paired_state') -or -not (Test-ObjectProperty $TypedItem 'passed') -or [string]::IsNullOrWhiteSpace([string](Get-OptionalObject $TypedItem 'expected_status')) -or [string]::IsNullOrWhiteSpace([string](Get-OptionalObject $TypedItem 'expected_paired_state'))) {
                        $TypedEvidenceFailure = 'MISSING_FIELD'
                        break
                    }
                    if ((Get-OptionalObject $TypedItem 'passed') -isnot [bool]) {
                        $TypedEvidenceFailure = 'NON_BOOLEAN_PASSED'
                        break
                    }
                }
            }
        }
        if ($null -ne $TypedEvidenceFailure) { return [pscustomobject]@{case_id=$CaseId;result='BLOCKED';confidence=0;satisfied_conditions=@();violated_conditions=@('FACT_WORK_TYPED_EVIDENCE_INVALID',$TypedEvidenceFailure);evidence=@();review_required=$true;reason='RUNNER_CONTRACT_FAILURE';judge_not_executed=$true;typed_evidence_failure=$TypedEvidenceFailure} }
    }
    $JudgeInput = if ($PSBoundParameters.ContainsKey('JudgeInputOverride')) { $JudgeInputOverride } else { @("JUDGE INSTRUCTIONS:", (Read-Utf8NoBom $JudgePromptPath), "CASE:", ($Case | ConvertTo-Json -Depth 10), "OBJECTIVE EVIDENCE:", ($ObjectiveEvidence | ConvertTo-Json -Depth 12), "DETERMINISTIC EVIDENCE:", ([pscustomobject]@{result=if($null -eq $DeterministicEvidence){$null}else{$DeterministicEvidence.result};hard_failures=if($null -eq $DeterministicEvidence){@()}else{@($DeterministicEvidence.hard_failures)};advisory_semantic_observations=if($null -eq $DeterministicEvidence){@()}else{@($DeterministicEvidence.advisory_semantic_observations)};fact_work_assertions=@($TypedEvidence);typed_event_evidence=if($null -eq $DeterministicEvidence){$null}else{$DeterministicEvidence.typed_event_evidence}} | ConvertTo-Json -Depth 12), "TRANSCRIPT:", $Transcript) -join [Environment]::NewLine }
    if ($DeclaredFactWorkCount -gt 0) {
        $DeterministicInputSection = if ($JudgeInput -match '(?s)DETERMINISTIC EVIDENCE:\s*(.*?)\s*TRANSCRIPT:') { $Matches[1] } else { '' }
        $TypedEvidenceSerialized = $DeterministicInputSection -match '"fact_work_assertions"\s*:'
        foreach ($TypedItem in $TypedEvidence) {
            $StatusPattern = '"expected_status"\s*:\s*"' + [regex]::Escape([string]$TypedItem.expected_status) + '"'
            $StatePattern = '"expected_paired_state"\s*:\s*"' + [regex]::Escape([string]$TypedItem.expected_paired_state) + '"'
            $PassedText = if ($TypedItem.passed) { 'true' } else { 'false' }
            $PassedPattern = '"passed"\s*:\s*' + $PassedText
            if ($DeterministicInputSection -notmatch $StatusPattern -or $DeterministicInputSection -notmatch $StatePattern -or $DeterministicInputSection -notmatch $PassedPattern) { $TypedEvidenceSerialized = $false }
        }
        if (-not $TypedEvidenceSerialized) { return [pscustomobject]@{case_id=$CaseId;result='BLOCKED';confidence=0;satisfied_conditions=@();violated_conditions=@('FACT_WORK_TYPED_EVIDENCE_INVALID','SERIALIZATION_LOSS');evidence=@();review_required=$true;reason='RUNNER_CONTRACT_FAILURE';judge_not_executed=$true;typed_evidence_failure='SERIALIZATION_LOSS'} }
    }
    if (-not $SkipJudgeInputPersistence) { Write-Utf8NoBom $JudgeInputPath $JudgeInput }
    $Integrity = Test-TranscriptIntegrity $Extraction $JudgeInput
    $EvidenceGate = Test-JudgeEvidenceRequirements $Case $Extraction $ObjectiveEvidence $Integrity $JudgeInput
    $EvidenceReference = if ($SkipJudgeInputPersistence) { 'synthetic judge input' } else { $JudgeInputPath }
    if (-not $EvidenceGate.passed) { return [pscustomobject]@{ case_id=$CaseId; result='BLOCKED'; confidence=0; satisfied_conditions=@(); violated_conditions=@($EvidenceGate.missing); evidence=@($EvidenceReference); review_required=$true; reason='JUDGE_EVIDENCE_INCOMPLETE'; judge_not_executed=$true; judge_input_transcript_length=$Integrity.judge_input_transcript_length; transcript_integrity=$Integrity } }
    if (-not $Integrity.passed) { return [pscustomobject]@{ case_id=$CaseId; result='BLOCKED'; confidence=0; satisfied_conditions=@(); violated_conditions=@('TRANSCRIPT_ENCODING_ERROR'); evidence=@($EvidenceReference); review_required=$true; reason='TRANSCRIPT_ENCODING_ERROR'; judge_not_executed=$true; judge_input_transcript_length=$Integrity.judge_input_transcript_length; transcript_integrity=$Integrity } }
    if ($null -eq $JudgeInvoker) { $JudgeInvoker = { param($Context) Invoke-SemanticJudge $Context } }
    $JudgeContext = [pscustomobject]@{ case=$Case; case_id=$CaseId; extraction=$Extraction; objective_evidence=$ObjectiveEvidence; judge_input=$JudgeInput; judge_input_path=$JudgeInputPath; judge_raw_path=$JudgeRaw; judge_out_path=$JudgeOut }
    try {
        if (-not [string]::IsNullOrWhiteSpace($script:PreflightActiveFolderCanonical)) { Assert-ActiveFolderSafetyRevalidation -Purpose "Judge pre-call: $CaseId" | Out-Null }
        $JudgeResult = & $JudgeInvoker $JudgeContext
        $JudgeResult | Add-Member -NotePropertyName judge_input_transcript_length -NotePropertyValue $Integrity.judge_input_transcript_length -Force
        $JudgeResult | Add-Member -NotePropertyName transcript_integrity -NotePropertyValue $Integrity -Force
        return $JudgeResult
    } catch {
        return [pscustomobject]@{ case_id=$CaseId; result='BLOCKED'; confidence=0; satisfied_conditions=@(); violated_conditions=@('semantic judge unavailable'); evidence=@($JudgeRaw); review_required=$true; reason=$_.Exception.Message; judge_input_transcript_length=$Integrity.judge_input_transcript_length; transcript_integrity=$Integrity }
    }
}

function Merge-AcceptanceResult([object]$DeterministicEvidence, [object]$JudgeResult, [bool]$JudgeRequired = $true) {
    $HardFailures = @(Get-OptionalArray $DeterministicEvidence 'hard_failures')
    if ($HardFailures.Count -eq 0) { $HardFailures = @(Get-OptionalArray $DeterministicEvidence 'failures') }
    if ($HardFailures.Count -gt 0 -or (Get-OptionalString $DeterministicEvidence 'result') -eq 'FAIL') { return [pscustomobject]@{result='FAIL';reason='DETERMINISTIC_HARD_GATE_FAILURE';judge_required=$JudgeRequired} }
    if (-not $JudgeRequired) { return [pscustomobject]@{result='PASS';reason=$null;judge_required=$false} }
    if ($null -eq $JudgeResult -or (Get-OptionalString $JudgeResult 'result') -eq 'BLOCKED') { return [pscustomobject]@{result='BLOCKED';reason='JUDGE_EVIDENCE_OR_EXECUTION_UNAVAILABLE';judge_required=$true} }
    if ((Get-OptionalString $JudgeResult 'result') -eq 'PASS') { return [pscustomobject]@{result='PASS';reason=$null;judge_required=$true} }
    return [pscustomobject]@{result='FAIL';reason='JUDGE_SEMANTIC_FAILURE';judge_required=$true}
}

function Invoke-AcceptanceDecision([object]$Case, [object]$Extraction, [object]$ObjectiveEvidence, [object]$DeterministicEvidence, [scriptblock]$JudgeInvoker, [switch]$SkipJudgeInputPersistence) {
    $JudgeRequired = @(Get-OptionalArray $Case 'judge_semantic_requirements').Count -gt 0
    $HardFailure = @(Get-OptionalArray $DeterministicEvidence 'hard_failures').Count -gt 0 -or $DeterministicEvidence.result -eq 'FAIL'
    $CaseId = Get-OptionalString $Case 'case_id' '<unknown>'
    $Judge = if ($HardFailure) { [pscustomobject]@{case_id=$CaseId;result='NOT_EXECUTED';reason='DETERMINISTIC_HARD_GATE_FAILURE';judge_not_executed=$true;review_required=$false;judge_input_transcript_length=0} } elseif ($JudgeRequired) { Invoke-JudgeWithEvidenceGate -Case $Case -Extraction $Extraction -ObjectiveEvidence $ObjectiveEvidence -DeterministicEvidence $DeterministicEvidence -JudgeInvoker $JudgeInvoker -SkipJudgeInputPersistence:$SkipJudgeInputPersistence } else { [pscustomobject]@{case_id=$CaseId;result='NOT_REQUIRED';reason=$null;judge_not_executed=$true;review_required=$false;judge_input_transcript_length=0} }
    return [pscustomobject]@{judge=$Judge;merge=(Merge-AcceptanceResult $DeterministicEvidence $Judge $JudgeRequired);judge_required=$JudgeRequired}
}

function Test-ExplicitSkillAdapter([string]$RawPath = (Join-Path $RawDir 'cli-explicit-skill-adapter.jsonl')) {
    try {
        $ExplicitPrompt = @('$decision-grill', 'State your Decision-Grill scope in one sentence. Do not modify files, call tools, or begin an interview.', 'Begin the sentence with "Decision-Grill:".') -join "`n"
        $ExplicitArguments = New-CodexExecutionArguments -Sandbox 'read-only' -Tail @('-')
        Invoke-CodexJson -CodexArguments $ExplicitArguments -Prompt $ExplicitPrompt -RawPath $RawPath -InvocationName 'explicit decision-grill discovery'
        $Raw = Read-Utf8NoBom $RawPath
        $HasThreadStarted = $Raw -match 'thread\.started'
        $HasFinalAgentMessage = $Raw -match 'agent_message'
        $SkillLoaded = $Raw -match '(?i)Decision-Grill:'
        $UsedTool = $Raw -match 'function_call|command_execution'
        if ($HasThreadStarted -and $HasFinalAgentMessage -and $SkillLoaded -and -not $UsedTool) { return 'PASS' }
        return "BLOCKED: discovery evidence thread.started=$HasThreadStarted final_agent_message=$HasFinalAgentMessage skill_loaded=$SkillLoaded tool_used=$UsedTool"
    } catch { return "BLOCKED: $($_.Exception.Message)" }
}

function Test-ResumeTransport {
    $TurnOneRaw = 'D:\temp\decision-grill-resume-probe-turn-1.jsonl'
    $TurnTwoRaw = 'D:\temp\decision-grill-resume-probe-turn-2.jsonl'
    try {
        $TurnOnePrompt = 'Reply with exactly: thread created. Do not modify files, call tools, or run commands.'
        $TurnOneArguments = New-CodexExecutionArguments -Sandbox 'read-only' -Tail @('-')
        Invoke-CodexJson -CodexArguments $TurnOneArguments -Prompt $TurnOnePrompt -RawPath $TurnOneRaw -InvocationName 'resume transport probe turn 1'
        $ThreadId = Get-ThreadId $TurnOneRaw
        $TurnTwoPrompt = 'Reply with exactly: thread resumed. Do not modify files, call tools, or run commands.'
        $TurnTwoArguments = New-CodexResumeArguments -ThreadId $ThreadId -Sandbox 'read-only'
        Invoke-CodexJson -CodexArguments $TurnTwoArguments -Prompt $TurnTwoPrompt -RawPath $TurnTwoRaw -InvocationName 'resume transport probe turn 2'
        $Raw = Read-Utf8NoBom $TurnTwoRaw
        $HasTurnStarted = $Raw -match 'turn\.started'
        $HasTurnCompleted = $Raw -match 'turn\.completed'
        $HasFinalAgentMessage = $Raw -match 'agent_message'
        $UsedTool = $Raw -match 'function_call|command_execution'
        if ($HasTurnStarted -and $HasTurnCompleted -and $HasFinalAgentMessage -and -not $UsedTool) { return 'PASS' }
        return "BLOCKED: resume evidence turn.started=$HasTurnStarted turn.completed=$HasTurnCompleted final_agent_message=$HasFinalAgentMessage tool_used=$UsedTool"
    } catch { return "BLOCKED: $($_.Exception.Message)" }
}

function Test-UnicodeRoundTrip {
    $RawPath = Join-Path $RawDir 'unicode-roundtrip-probe.jsonl'
    $TranscriptPath = Join-Path $TurnsDir 'unicode-roundtrip-probe.md'
    try {
        $Apostrophe = [char]0x2019
        $Chinese = -join @([char]0x6C7A, [char]0x7B56, [char]0x6E2C, [char]0x8A66)
        $ProbeText = "UTF8_OK|can${Apostrophe}t|$Chinese"
        $Prompt = "Reply with only this exact text: $ProbeText"
        $Arguments = New-CodexExecutionArguments -Sandbox 'read-only' -Tail @('-')
        Invoke-CodexJson -CodexArguments $Arguments -Prompt $Prompt -RawPath $RawPath -InvocationName 'Unicode round-trip probe'
        $Extraction = Get-CaseTranscript @($RawPath)
        Write-Utf8NoBom $TranscriptPath $Extraction.final_agent_message
        $RoundTripText = Read-Utf8NoBom $TranscriptPath
        foreach ($Line in ((Read-Utf8NoBom $RawPath) -split "`r?`n")) { if (-not [string]::IsNullOrWhiteSpace($Line)) { [void]($Line | ConvertFrom-Json -ErrorAction Stop) } }
        $Exact = $RoundTripText -ceq $ProbeText
        $ApostrophePreserved = $RoundTripText.IndexOf([char]0x2019) -ge 0
        $ChinesePreserved = $RoundTripText.IndexOf($Chinese, [StringComparison]::Ordinal) -ge 0
        $ReplacementFound = $RoundTripText.IndexOf([char]0xFFFD) -ge 0
        $QuestionMarkFound = $RoundTripText.IndexOf('?') -ge 0
        return [pscustomobject]@{ result=($Exact -and $ApostrophePreserved -and $ChinesePreserved -and -not $ReplacementFound -and -not $QuestionMarkFound); exact_text=$ProbeText; extracted_text=$RoundTripText; stdin_utf8=$true; stdout_utf8=$true; stderr_utf8=$true; u2019_preserved=$ApostrophePreserved; chinese_preserved=$ChinesePreserved; replacement_character_found=$ReplacementFound; question_mark_found=$QuestionMarkFound; jsonl_parse=$true }
    } catch { return [pscustomobject]@{ result=$false; stdin_utf8=$false; stdout_utf8=$false; stderr_utf8=$false; error=$_.Exception.Message } }
}

function Invoke-Case([object]$Case) {
    $CaseId = Get-OptionalString $Case 'case_id' '<unknown>'
    $Title = Get-OptionalString $Case 'title' '<unknown>'
    $FixturePaths = @()
    $BeforeDigest = $null; $AfterDigest = $null; $ThreadId = $null; $OfficialBefore = $null; $OfficialAfter = $null; $CaseResult = $null; $InventoryFailure = $null
    try {
        $FixturePaths = @(Initialize-CaseFixtures $Case)
        $BeforeDigest = Get-RevalidatedInventoryDigest 'before digest'
        if (Test-CaseRequiresOfficialSkillsInventory $Case) {
            $OfficialBefore = Get-OfficialSkillsInventory
            Write-Utf8NoBom (Join-Path $ResultsDir "$CaseId-official-skills-before.json") ($OfficialBefore | ConvertTo-Json -Depth 10)
        }
        $TurnJsonlPaths = [System.Collections.Generic.List[string]]::new()
        $RawPath = Join-Path $RawDir "$CaseId-turn-001-initial.jsonl"
        $TurnPath = Join-Path $TurnsDir "$CaseId.md"
        $ExtractionPath = Join-Path $ResultsDir "$CaseId-transcript-extraction.json"
        $InitialPrompt = Get-OptionalString $Case 'cli_initial_input'
        $CaseArguments = New-CodexExecutionArguments -Sandbox 'workspace-write' -Tail @('-')
        Invoke-CodexJson -CodexArguments $CaseArguments -Prompt $InitialPrompt -RawPath $RawPath -InvocationName "case $CaseId initial input"
        $TurnJsonlPaths.Add($RawPath)
        $ThreadId = Get-ThreadId $RawPath
        $TurnNumber = 1
        $SendConditionEvidence = [System.Collections.Generic.List[object]]::new()
        $PostInputFailures = [System.Collections.Generic.List[string]]::new()
        foreach ($SubsequentPrompt in @(Get-OptionalArray $Case 'ordered_subsequent_inputs')) {
            $PreResumeExtraction = Get-CaseTranscript @($TurnJsonlPaths)
            $SendConditionResult = Test-SendCondition $Case $PreResumeExtraction.transcript $TurnNumber
            $SendConditionEvidence.Add($SendConditionResult)
            if ($SendConditionResult.result -eq 'BLOCKED') {
                $PreResumeExtraction | Select-Object jsonl_files_inspected,agent_message_count,extracted_message_order,final_message_length,transcript_length,transcript_sha256,final_message_sha256 | ConvertTo-Json -Depth 12 | ForEach-Object { Write-Utf8NoBom $ExtractionPath $_ }
                Write-Utf8NoBom $TurnPath $PreResumeExtraction.transcript
                $AfterDigest = Get-RevalidatedInventoryDigest 'after digest'
                $CaseResult = [pscustomobject]@{ case_id=$CaseId; title=$Title; active_folder=$ActiveFolder; fixture_paths=@($FixturePaths); result='BLOCKED'; reason='SEND_CONDITION_NOT_MET'; deterministic=@{result='BLOCKED';failures=@('SEND_CONDITION_NOT_MET')}; judge=$null; thread_id=$ThreadId; evidence_excerpt=$SendConditionResult.evidence_excerpt; transcript_extraction=$PreResumeExtraction; send_condition_evidence=@($SendConditionEvidence); judge_input_transcript_length=0; before_hash=$BeforeDigest; after_hash=$AfterDigest; review_required=$true }
                break
            }
            if ($SendConditionResult.result -eq 'SKIP') { $TurnNumber++; continue }
            $TurnNumber++
            $RawPath = Join-Path $RawDir ("{0}-turn-{1:D3}-resume.jsonl" -f $CaseId, $TurnNumber)
            $ResumeArguments = New-CodexResumeArguments -ThreadId $ThreadId
            $ResumePrompt = [string]$SubsequentPrompt
            $ResumeInvoker = New-ProductionResumeInvoker
            $SendConditionResult = Invoke-ConditionalInput $SendConditionResult $ResumeInvoker $ResumePrompt $ResumeArguments $RawPath $CaseId
            $TurnJsonlPaths.Add($RawPath)
            $ResumeOnlyExtraction = Get-CaseTranscript @($RawPath)
            $PostInputResult = Test-PostInputOrderedAssertions $Case $ResumeOnlyExtraction
            foreach ($Failure in @($PostInputResult.failures)) { $PostInputFailures.Add("input ${TurnNumber}: $Failure") }
        }
        if ($null -ne $CaseResult) { return $CaseResult }
        $Extraction = Get-CaseTranscript @($TurnJsonlPaths)
        $Extraction | Select-Object jsonl_files_inspected,agent_message_count,extracted_message_order,final_message_length,transcript_length,transcript_sha256,final_message_sha256 | ConvertTo-Json -Depth 12 | ForEach-Object { Write-Utf8NoBom $ExtractionPath $_ }
        $TranscriptGate = Test-TranscriptComplete $Extraction
        if (-not $TranscriptGate.passed) {
            $AfterDigest = Get-RevalidatedInventoryDigest 'after digest'
            $CaseResult = [pscustomobject]@{ case_id=$CaseId; title=$Title; active_folder=$ActiveFolder; fixture_paths=@($FixturePaths); result='BLOCKED'; reason='INCOMPLETE_TRANSCRIPT'; deterministic=@{result='BLOCKED';failures=@('INCOMPLETE_TRANSCRIPT')}; judge=$null; thread_id=$ThreadId; evidence_excerpt='Transcript completeness gate blocked Judge execution.'; transcript_extraction=$Extraction; judge_input_transcript_length=0; before_hash=$BeforeDigest; after_hash=$AfterDigest; review_required=$true }
            return $CaseResult
        }
        $Transcript = $Extraction.transcript
        Write-Utf8NoBom $TurnPath $Transcript
        $AfterDigest = Get-RevalidatedInventoryDigest 'after digest'
        if ($null -ne $OfficialBefore) {
            $OfficialAfter = Get-OfficialSkillsInventory
            Write-Utf8NoBom (Join-Path $ResultsDir "$CaseId-official-skills-after.json") ($OfficialAfter | ConvertTo-Json -Depth 10)
        }
        $Deterministic = Test-Deterministic $Case $Transcript $BeforeDigest $AfterDigest $Extraction
        foreach ($Failure in $PostInputFailures) { $Deterministic.failures += $Failure; $Deterministic.result = 'FAIL' }
        $ObjectiveEvidence = New-JudgeEvidence $BeforeDigest $AfterDigest $OfficialBefore $OfficialAfter $true @($SendConditionEvidence)
        Write-Utf8NoBom (Join-Path $ResultsDir "$CaseId-objective-evidence.json") ($ObjectiveEvidence | ConvertTo-Json -Depth 12)
        $ObjectiveEvidenceGate = Test-ObjectiveEvidenceRequirements $Case $ObjectiveEvidence
        if (-not $ObjectiveEvidenceGate.passed) {
            $CaseResult = [pscustomobject]@{ case_id=$CaseId; title=$Title; active_folder=$ActiveFolder; fixture_paths=@($FixturePaths); result='BLOCKED'; reason='OBJECTIVE_EVIDENCE_REQUIREMENTS_NOT_MET'; deterministic=@{result='BLOCKED';failures=@($ObjectiveEvidenceGate.missing)}; judge=$null; thread_id=$ThreadId; evidence_excerpt=('Missing required objective evidence: ' + ($ObjectiveEvidenceGate.missing -join ', ')); transcript_extraction=$Extraction; send_condition_evidence=@($SendConditionEvidence); judge_input_transcript_length=0; before_hash=$BeforeDigest; after_hash=$AfterDigest; objective_evidence=$ObjectiveEvidence; objective_evidence_requirements=$ObjectiveEvidenceGate; missing_objective_evidence=@($ObjectiveEvidenceGate.missing); review_required=$true }
            return $CaseResult
        }
        $Acceptance = Invoke-AcceptanceDecision $Case $Extraction $ObjectiveEvidence $Deterministic $null
        $Judge = $Acceptance.judge
        $Merge = $Acceptance.merge
        $Final = $Merge.result
        $JudgeReviewRequired = Get-OptionalBoolean $Judge 'review_required'
        $ResultReason = if ($Judge.result -eq 'BLOCKED' -and (Get-OptionalString $Judge 'reason') -eq 'TRANSCRIPT_ENCODING_ERROR') { 'TRANSCRIPT_ENCODING_ERROR' } else { $Merge.reason }
        $CaseResult = [pscustomobject]@{ case_id=$CaseId; title=$Title; active_folder=$ActiveFolder; fixture_paths=@($FixturePaths); result=$Final; reason=$ResultReason; merge=$Merge; deterministic=$Deterministic; typed_evidence=$Deterministic.typed_event_evidence; judge=$Judge; thread_id=$ThreadId; evidence_excerpt=$Transcript.Substring(0, [Math]::Min(1000, $Transcript.Length)); transcript_extraction=$Extraction; send_condition_evidence=@($SendConditionEvidence); judge_input_transcript_length=$Judge.judge_input_transcript_length; before_hash=$BeforeDigest; after_hash=$AfterDigest; review_required=($Final -eq 'BLOCKED' -or ($JudgeReviewRequired.exists -and $JudgeReviewRequired.value)) }
    } catch {
        $script:RunnerInternalError = $true
        try { $AfterDigest = if (Test-Path -LiteralPath $ActiveFolder) { Get-RevalidatedInventoryDigest 'after digest during error handling' } else { $null } } catch { $AfterDigest = $null }
        $RuntimeError = Get-RunnerException $_ $CaseId
        $SafetyFailure = $RuntimeError.message -match 'SAFETY_REVALIDATION_FAILED'
        $CaseResult = [pscustomobject]@{ case_id=$CaseId; title=$Title; active_folder=$ActiveFolder; fixture_paths=@($FixturePaths); result='RUNNER_INTERNAL_ERROR'; reason=$(if ($SafetyFailure) { 'SAFETY_REVALIDATION_FAILED' } else { 'RUNNER_INTERNAL_ERROR' }); runtime_error=$RuntimeError; deterministic=@{result='RUNNER_INTERNAL_ERROR';failures=@($(if ($SafetyFailure) { 'SAFETY_REVALIDATION_FAILED' } else { 'RUNNER_INTERNAL_ERROR' }))}; judge=$null; thread_id=$ThreadId; evidence_excerpt=$RuntimeError.message; before_hash=$BeforeDigest; after_hash=$AfterDigest; review_required=$true }
    } finally {
        $BeforeAvailable = Get-OptionalBoolean $OfficialBefore 'available'
        if ($BeforeAvailable.exists -and $BeforeAvailable.value) {
            try {
                if ($null -eq $OfficialAfter) {
                    $OfficialAfter = Get-OfficialSkillsInventory
                    Write-Utf8NoBom (Join-Path $ResultsDir "$CaseId-official-skills-after.json") ($OfficialAfter | ConvertTo-Json -Depth 10)
                }
                $OfficialEvidence = New-JudgeEvidence $BeforeDigest $AfterDigest $OfficialBefore $OfficialAfter $true
                if (-not $OfficialEvidence.official_skills_inventory.unchanged) { throw 'official Skills metadata inventory changed or after inventory is unavailable' }
            } catch { $InventoryFailure = Get-RunnerException $_ $CaseId }
            if ($null -ne $InventoryFailure) {
                $script:RunnerInternalError = $true
                $Secondary = if ($null -ne $CaseResult -and $null -ne $CaseResult.PSObject.Properties['runtime_error']) { $CaseResult.runtime_error } else { $null }
                if ($null -eq $CaseResult) { $CaseResult = [pscustomobject]@{ case_id=$CaseId; title=$Title; active_folder=$ActiveFolder; fixture_paths=@($FixturePaths); before_hash=$BeforeDigest; after_hash=$AfterDigest } }
                $CaseResult | Add-Member -NotePropertyName result -NotePropertyValue 'RUNNER_INTERNAL_ERROR' -Force
                $CaseResult | Add-Member -NotePropertyName reason -NotePropertyValue 'SAFETY_REVALIDATION_FAILED' -Force
                $CaseResult | Add-Member -NotePropertyName runtime_error -NotePropertyValue $InventoryFailure -Force
                $CaseResult | Add-Member -NotePropertyName secondary_runtime_error -NotePropertyValue $Secondary -Force
                $CaseResult | Add-Member -NotePropertyName deterministic -NotePropertyValue @{result='RUNNER_INTERNAL_ERROR';failures=@('SAFETY_REVALIDATION_FAILED')} -Force
                $CaseResult | Add-Member -NotePropertyName judge -NotePropertyValue $null -Force
                $CaseResult | Add-Member -NotePropertyName review_required -NotePropertyValue $true -Force
            }
        }
    }
    return $CaseResult
}

function Invoke-StaticTest {
    $Cases = Read-Utf8NoBom $CasesPath | ConvertFrom-Json
    $Results = [System.Collections.Generic.List[object]]::new()
    function Add-Static([string]$Name, [bool]$Passed, [string]$Detail) { $Results.Add([pscustomobject]@{name=$Name;passed=$Passed;detail=$Detail}) }
    function Add-StaticSelection([string]$Name, [string]$Declaration, [bool]$Required, [bool]$ExpectedPassed, [string]$ExpectedIds = '') {
        $Selection = Resolve-CaseSelection $Cases $Declaration -Required:$Required
        $ActualIds = $Selection.selected_case_ids -join ','
        Add-Static $Name ($Selection.passed -eq $ExpectedPassed -and ($ExpectedIds -eq '' -or $ActualIds -eq $ExpectedIds)) ("passed={0}; ids={1}; failures={2}" -f $Selection.passed,$ActualIds,($Selection.failures -join '|'))
    }
    Add-StaticSelection 'selection single valid case' 'DG-003' $true $true 'DG-003'
    Add-StaticSelection 'selection multiple declaration order' 'DG-009,DG-001,DG-005' $true $true 'DG-001,DG-005,DG-009'
    Add-StaticSelection 'selection trims and canonicalizes case IDs' ' dg-003 , DG-001 ' $true $true 'DG-001,DG-003'
    Add-StaticSelection 'selection blank input rejected' ' ' $true $false
    Add-StaticSelection 'selection blank token rejected' 'DG-001,,DG-003' $true $false
    Add-StaticSelection 'selection duplicate exact rejected' 'DG-001,DG-001' $true $false
    Add-StaticSelection 'selection duplicate case-insensitive rejected' 'DG-001,dg-001' $true $false
    Add-StaticSelection 'selection unknown ID rejected' 'DG-999' $true $false
    Add-StaticSelection 'selection malformed ID rejected' 'DG-1' $true $false
    Add-StaticSelection 'selection wildcard and range rejected' 'DG-00*,DG-001-DG-003' $true $false
    $TargetedMissing = Test-ModeCaseSelectionContract 'Targeted' $null $Cases
    $CoreWithIds = Test-ModeCaseSelectionContract 'Core' 'DG-001' $Cases
    $FullWithIds = Test-ModeCaseSelectionContract 'Full' 'DG-001' $Cases
    $DryRunWithIds = Test-ModeCaseSelectionContract 'DryRun' 'DG-003,DG-001' $Cases
    $DryRunWithoutIds = Test-ModeCaseSelectionContract 'DryRun' $null $Cases
    Add-Static 'Targeted missing CaseIds rejected' (-not $TargetedMissing.passed) ($TargetedMissing.failures -join '; ')
    Add-Static 'Core and Full CaseIds rejected' (-not $CoreWithIds.passed -and -not $FullWithIds.passed) (($CoreWithIds.failures + $FullWithIds.failures) -join '; ')
    Add-Static 'DryRun CaseIds optional selection' ($DryRunWithIds.passed -and ($DryRunWithIds.selection.selected_case_ids -join ',') -eq 'DG-001,DG-003' -and $DryRunWithoutIds.passed -and $DryRunWithoutIds.selection.selected_case_ids.Count -eq 0) 'valid selection accepted; omitted selection preserves DryRun'
    $StaticSelection = Resolve-CaseSelection $Cases 'DG-009,DG-001,DG-005' -Required
    $StaticSelectionCalls = [System.Collections.Generic.List[string]]::new()
    $StaticSelectionRun = Invoke-SelectedCases $StaticSelection.selected_cases { param($Case) $StaticSelectionCalls.Add($Case.case_id); [pscustomobject]@{case_id=$Case.case_id;result='PASS';reason=$null} }
    Add-Static 'selection invokes only selected catalog cases in order' (($StaticSelectionCalls -join ',') -eq 'DG-001,DG-005,DG-009' -and @($StaticSelectionRun.results).Count -eq 3 -and @($StaticSelectionRun.results | Where-Object { $_.case_id -notin $StaticSelection.selected_case_ids }).Count -eq 0) 'shared selected-case loop; unselected cases absent'
    $StaticFailSelection = Resolve-CaseSelection $Cases 'DG-009,DG-001,DG-005' -Required
    $StaticFailCalls = [System.Collections.Generic.List[string]]::new()
    $StaticFailRun = Invoke-SelectedCases $StaticFailSelection.selected_cases { param($Case) $StaticFailCalls.Add($Case.case_id); if ($Case.case_id -eq 'DG-001') { [pscustomobject]@{case_id=$Case.case_id;result='RUNNER_INTERNAL_ERROR';reason='RUNNER_INTERNAL_ERROR';runtime_error=@{script_line=1}} } else { [pscustomobject]@{case_id=$Case.case_id;result='PASS';reason=$null} } }
    $StaticFailSummary = Get-RunSummary @($StaticFailRun.results) $StaticFailSelection.selected_cases.Count
    Add-Static 'selection fail-fast only marks selected remainder NOT_EXECUTED' (($StaticFailCalls -join ',') -eq 'DG-001' -and @($StaticFailRun.results | Where-Object result -eq 'NOT_EXECUTED').Count -eq 2 -and @($StaticFailRun.results).Count -eq 3 -and $StaticFailSummary.executed -eq 1 -and $StaticFailSummary.category_sum_matches_planned) 'selected-only fail-fast and aggregate totals'
    $ResultContractCase = @($Cases | Where-Object case_id -eq 'DG-001')[0]
    foreach ($Scenario in @(
        [pscustomobject]@{name='valid PASS result';output=@([pscustomobject]@{case_id='DG-001';result='PASS'});pass=$true},
        [pscustomobject]@{name='valid FAIL result';output=@([pscustomobject]@{case_id='DG-001';result='FAIL'});pass=$true},
        [pscustomobject]@{name='valid BLOCKED result';output=@([pscustomobject]@{case_id='DG-001';result='BLOCKED'});pass=$true},
        [pscustomobject]@{name='valid runner error result';output=@([pscustomobject]@{case_id='DG-001';result='RUNNER_INTERNAL_ERROR'});pass=$true},
        [pscustomobject]@{name='null result';output=@();pass=$false},
        [pscustomobject]@{name='missing result';output=@([pscustomobject]@{case_id='DG-001'});pass=$false},
        [pscustomobject]@{name='blank result';output=@([pscustomobject]@{case_id='DG-001';result=''});pass=$false},
        [pscustomobject]@{name='unknown result';output=@([pscustomobject]@{case_id='DG-001';result='MAYBE'});pass=$false},
        [pscustomobject]@{name='missing case ID';output=@([pscustomobject]@{result='PASS'});pass=$false},
        [pscustomobject]@{name='mismatched case ID';output=@([pscustomobject]@{case_id='DG-002';result='PASS'});pass=$false},
        [pscustomobject]@{name='multiple pipeline outputs';output=@([pscustomobject]@{case_id='DG-001';result='PASS'},[pscustomobject]@{case_id='DG-001';result='PASS'});pass=$false},
        [pscustomobject]@{name='scalar result';output=@('PASS');pass=$false}
    )) {
        $Contract = Test-CaseResultContract $ResultContractCase @($Scenario.output)
        $EvidencePresent = $Contract.passed -or ($Contract.result.result -eq 'RUNNER_INTERNAL_ERROR' -and $null -ne $Contract.result.original_result_evidence)
        Add-Static ('result contract ' + $Scenario.name) ($Contract.passed -eq $Scenario.pass -and $EvidencePresent) 'production result-contract validator'
    }
    $ContractCalls = [System.Collections.Generic.List[string]]::new()
    $ContractRunCases = @($Cases | Where-Object case_id -in @('DG-001','DG-003','DG-005'))
    $ContractRun = Invoke-SelectedCases $ContractRunCases { param($Case) $ContractCalls.Add($Case.case_id); if ($Case.case_id -eq 'DG-001') { return }; [pscustomobject]@{case_id=$Case.case_id;result='PASS'} }
    $ContractSummary = Get-RunSummary @($ContractRun.results) $ContractRunCases.Count
    Add-Static 'result contract malformed trigger persists selected remainder and evidence' (($ContractCalls -join ',') -eq 'DG-001' -and $ContractRun.results[0].result -eq 'RUNNER_INTERNAL_ERROR' -and @($ContractRun.results | Where-Object result -eq 'NOT_EXECUTED').Count -eq 2 -and $ContractSummary.category_sum_matches_planned -and $ContractRun.results[0].original_result_evidence.output_count -eq 0) 'generic malformed trigger, evidence, and selected-only fail-fast'
    $ContractPersistenceRoot = Join-Path 'D:\temp' ('decision-grill-static-result-contract-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $ContractPersistenceRoot -Force | Out-Null
    try {
        $ContractAggregatePath = Join-Path $ContractPersistenceRoot 'aggregate.json'
        $ContractMarkdownPath = Join-Path $ContractPersistenceRoot 'report.md'
        Write-Utf8NoBom $ContractAggregatePath (([pscustomobject]@{summary=$ContractSummary;cases=@($ContractRun.results)}) | ConvertTo-Json -Depth 12)
        Write-Utf8NoBom $ContractMarkdownPath ("RUNNER_INTERNAL_ERROR: {0}`nNOT_EXECUTED: {1}" -f $ContractSummary.categories.RUNNER_INTERNAL_ERROR,$ContractSummary.categories.NOT_EXECUTED)
        Add-Static 'result contract aggregate and Markdown persistence' ((Test-Path -LiteralPath $ContractAggregatePath) -and (Test-Path -LiteralPath $ContractMarkdownPath) -and (Read-Utf8NoBom $ContractAggregatePath) -match 'original_result_evidence') 'malformed result evidence remains persistable'
    } finally { if (Test-Path -LiteralPath $ContractPersistenceRoot) { Remove-Item -LiteralPath $ContractPersistenceRoot -Recurse -Force } }
    $DG001 = $Cases | Where-Object case_id -eq 'DG-001'
    $ValidPre = "### Q-001 — [IMPORTANT]`n**Recommended answer:** Launch"
    $EarlyQ2 = "$ValidPre`n### Q-002 — [IMPORTANT]"
    Add-Static 'DG-001 valid pre-input gate' ((Test-SendCondition $DG001 $ValidPre 1).result -eq 'SEND') 'Q-001 and recommendation present'
    Add-Static 'DG-001 premature Q-002 blocked' ((Test-SendCondition $DG001 $EarlyQ2 1).result -eq 'BLOCKED') 'Q-002 is forbidden before resume'
    $StaticRequired = [pscustomobject]@{ case_id='STATIC-required'; send_condition_requirements=@([pscustomobject]@{input_index=1;mode='required';required_patterns=@('ASK')}); ordered_subsequent_inputs=@('response') }
    $StaticConditional = [pscustomobject]@{ case_id='STATIC-conditional'; send_condition_requirements=@([pscustomobject]@{input_index=1;mode='conditional';required_patterns=@('ASK')}); ordered_subsequent_inputs=@('skipped response') }
    $RequiredSend = Test-SendCondition $StaticRequired 'ASK' 1
    $RequiredBlocked = Test-SendCondition $StaticRequired 'NO QUESTION' 1
    $ConditionalSend = Test-SendCondition $StaticConditional 'ASK' 1
    $ConditionalSkip = Test-SendCondition $StaticConditional 'NO QUESTION' 1
    $ConditionalUnknown = Test-SendCondition $StaticConditional '' 1
    $ConditionalMissingEvidence = Test-SendCondition ([pscustomobject]@{ case_id='STATIC-missing-evidence'; send_condition_requirements=@([pscustomobject]@{input_index=1;mode='conditional'}); ordered_subsequent_inputs=@('response') }) 'agent response' 1
    $script:StaticResumeCalls = 0
    $RequiredSend = Invoke-ConditionalInput $RequiredSend { $script:StaticResumeCalls++ }
    Add-Static 'required true sends once' ($RequiredSend.result -eq 'SEND' -and $RequiredSend.resume_call_count -eq 1 -and $script:StaticResumeCalls -eq 1) 'result=SEND; resume_call_count=1'
    Add-Static 'required false blocks without resume' ($RequiredBlocked.result -eq 'BLOCKED' -and $RequiredBlocked.resume_call_count -eq 0) 'result=BLOCKED; resume_call_count=0'
    $ConditionalSend = Invoke-ConditionalInput $ConditionalSend { $script:StaticResumeCalls++ }
    Add-Static 'conditional true sends once' ($ConditionalSend.result -eq 'SEND' -and $ConditionalSend.resume_call_count -eq 1 -and $script:StaticResumeCalls -eq 2) 'result=SEND; resume_call_count=1'
    Add-Static 'conditional false skips without resume' ($ConditionalSkip.result -eq 'SKIP' -and $ConditionalSkip.resume_call_count -eq 0) 'result=SKIP; resume_call_count=0'
    Add-Static 'conditional unknown blocks without resume' ($ConditionalUnknown.result -eq 'BLOCKED' -and $ConditionalUnknown.applicability -eq 'UNKNOWN' -and $ConditionalUnknown.resume_call_count -eq 0) 'result=BLOCKED; resume_call_count=0'
    Add-Static 'conditional evidence missing blocks without resume' ($ConditionalMissingEvidence.result -eq 'BLOCKED' -and $ConditionalMissingEvidence.resume_call_count -eq 0) 'result=BLOCKED; resume_call_count=0'
    $ParserCases = @(
        [pscustomobject]@{name='plain labelled';text='Status: BLOCKED';expected=$true},
        [pscustomobject]@{name='inline code labelled';text='- Status: `BLOCKED`';expected=$true},
        [pscustomobject]@{name='bold labelled';text='**Current status:** **OPEN**';expected=$true;state='OPEN'},
        [pscustomobject]@{name='incidental prose';text='This is BLOCKED only as prose.';expected=$false},
        [pscustomobject]@{name='negation';text='Status: not BLOCKED';expected=$false},
        [pscustomobject]@{name='unlabelled token';text='BLOCKED';expected=$false},
        [pscustomobject]@{name='fenced sample';text=('```text' + [Environment]::NewLine + 'Status: BLOCKED' + [Environment]::NewLine + '```');expected=$false}
    )
    foreach ($ParserCase in $ParserCases) {
        $State = 'BLOCKED'
        if ($null -ne $ParserCase.PSObject.Properties.Item('state')) { $State = $ParserCase.state }
        Add-Static ('state parser ' + $ParserCase.name) ((Test-ExplicitStateMarker $ParserCase.text $State) -eq $ParserCase.expected) ('state=' + $State)
    }
    $EmptyPromptCase = ($DG001 | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
    $EmptyPromptCase.ordered_subsequent_inputs = @(' ')
    $EmptyPromptValidation = Test-CaseContract $EmptyPromptCase
    Add-Static 'prepare rejects empty declared subsequent prompt' (-not $EmptyPromptValidation.passed) 'empty ordered_subsequent_inputs is invalid'
    $SyntheticCases = @([pscustomobject]@{case_id='STATIC-001';title='first'},[pscustomobject]@{case_id='STATIC-002';title='second'},[pscustomobject]@{case_id='STATIC-003';title='third'})
    $script:StaticSelectedCalls = [System.Collections.Generic.List[string]]::new()
    $ProductCaseInvoker = {
        param($Case)
        $script:StaticSelectedCalls.Add($Case.case_id)
        if ($Case.case_id -eq 'STATIC-001') { $SyntheticResult = 'FAIL' } else { $SyntheticResult = 'PASS' }
        [pscustomobject]@{case_id=$Case.case_id;result=$SyntheticResult;reason=$null}
    }
    $ProductFailRun = Invoke-SelectedCases -SelectedCases $SyntheticCases -CaseInvoker $ProductCaseInvoker
    Add-Static 'product FAIL continues selected cases' ($script:StaticSelectedCalls.Count -eq 3 -and $ProductFailRun.stop -eq $null) 'all selected cases invoked'
    $script:StaticSelectedCalls.Clear()
    $RunnerCaseInvoker = {
        param($Case)
        $script:StaticSelectedCalls.Add($Case.case_id)
        if ($Case.case_id -eq 'STATIC-001') { return [pscustomobject]@{case_id=$Case.case_id;title=$Case.title;result='RUNNER_INTERNAL_ERROR';reason='RUNNER_INTERNAL_ERROR';runtime_error=@{script_line=1}} }
        return [pscustomobject]@{case_id=$Case.case_id;result='PASS';reason=$null}
    }
    $RunnerFailRun = Invoke-SelectedCases -SelectedCases $SyntheticCases -CaseInvoker $RunnerCaseInvoker
    Add-Static 'runner error stops selected cases and persists NOT_EXECUTED' ($script:StaticSelectedCalls.Count -eq 1 -and @($RunnerFailRun.results | Where-Object result -eq 'NOT_EXECUTED').Count -eq 2 -and @($RunnerFailRun.results | Where-Object result -eq 'NOT_EXECUTED' | Where-Object { $_.deterministic.result -eq 'NOT_RUN' -and $_.judge -eq 'NOT_RUN' -and $_.thread_id -eq $null -and $_.resume_call_count -eq 0 }).Count -eq 2) 'no later case invoker, thread, resume, or Judge'
    $RunnerSummary = Get-RunSummary @($RunnerFailRun.results) 3
    Add-Static 'runner summary counts planned and executed' ($RunnerSummary.categories.RUNNER_INTERNAL_ERROR -eq 1 -and $RunnerSummary.categories.NOT_EXECUTED -eq 2 -and $RunnerSummary.executed -eq 1 -and $RunnerSummary.category_sum_matches_planned) 'summary is aggregate-derived'
    $DryRunSelectionSummary = Get-RunSummary @() 6 0
    Add-Static 'DryRun selected cases report zero product executions' ($DryRunSelectionSummary.planned -eq 6 -and $DryRunSelectionSummary.executed -eq 0 -and $DryRunSelectionSummary.categories.PASS -eq 0) 'selection is validated without product-case execution'
    Add-Static 'runner exit precedence' ((Get-RunExitCode @($RunnerFailRun.results) $true) -eq 3) 'runner error wins over product categories'
    Add-Static 'runner exit aggregation accepts result without optional reason' ((Get-RunExitCode @([pscustomobject]@{case_id='STATIC';result='PASS'}) $true) -eq 0) 'optional reason is safely absent'
    $StaticSkipTranscript = 'initial real agent response'
    $StaticSkipEvidence = @([pscustomobject]@{input_index=1;mode=$ConditionalSkip.mode;applicability=$ConditionalSkip.applicability;result=$ConditionalSkip.result;evidence=@($ConditionalSkip.evidence);reason=$ConditionalSkip.reason;resume_call_count=0})
    $StaticSkipObjective = New-JudgeEvidence 'same' 'same' $null $null $true $StaticSkipEvidence
    $StaticSkipCase = [pscustomobject]@{case_id='STATIC-skip';required_keywords=@('initial real agent response');judge_evidence_requirements=@('conditional_input_evidence')}
    $StaticSkipExtraction = [pscustomobject]@{transcript=$StaticSkipTranscript;final_agent_message=$StaticSkipTranscript}
    $script:StaticSkipJudgeCalls = 0
    $StaticSkipJudge = Invoke-JudgeWithEvidenceGate -Case $StaticSkipCase -Extraction $StaticSkipExtraction -ObjectiveEvidence $StaticSkipObjective -SkipJudgeInputPersistence -JudgeInvoker { param($Context) $script:StaticSkipJudgeCalls++; [pscustomobject]@{case_id=$Context.case_id;result='PASS';confidence=1;satisfied_conditions=@();violated_conditions=@();evidence=@();review_required=$false} }
    Add-Static 'SKIP preserves transcript and deterministic continuation' ((Test-Deterministic $StaticSkipCase $StaticSkipTranscript '' '').result -eq 'PASS' -and $StaticSkipTranscript -notmatch 'skipped response') 'deterministic executed; skipped input absent'
    Add-Static 'SKIP preserves Judge continuation and conditional evidence' ($StaticSkipJudge.result -eq 'PASS' -and $script:StaticSkipJudgeCalls -eq 1 -and $StaticSkipJudge.transcript_integrity.passed) 'Judge called once; conditional evidence included independently'
    $StaticIndexTwo = Test-SendCondition ([pscustomobject]@{case_id='STATIC-index';send_condition_requirements=@([pscustomobject]@{input_index=1;mode='conditional';required_patterns=@('FIRST')},[pscustomobject]@{input_index=2;mode='required';required_patterns=@('SECOND')});ordered_subsequent_inputs=@('skip','send')}) 'SECOND' 2
    Add-Static 'SKIP preserves next declarative input index' ($ConditionalSkip.input_index -eq 1 -and $StaticIndexTwo.input_index -eq 2 -and $StaticIndexTwo.result -eq 'SEND') 'input 2 independently evaluated at original index'
    $PrepareScenarios = @(
        [pscustomobject]@{name='missing mode'; requirements=@([pscustomobject]@{input_index=1;required_patterns=@('ASK')}); inputs=@('response'); token='missing mode'},
        [pscustomobject]@{name='unknown mode'; requirements=@([pscustomobject]@{input_index=1;mode='optional';required_patterns=@('ASK')}); inputs=@('response'); token='unknown mode'},
        [pscustomobject]@{name='duplicate index'; requirements=@([pscustomobject]@{input_index=1;mode='required';required_patterns=@('ASK')},[pscustomobject]@{input_index=1;mode='required';required_patterns=@('SECOND')}); inputs=@('one','two'); token='duplicate index'},
        [pscustomobject]@{name='missing requirement'; requirements=@(); inputs=@('response'); token='count does not match'},
        [pscustomobject]@{name='extra index'; requirements=@([pscustomobject]@{input_index=2;mode='required';required_patterns=@('ASK')}); inputs=@('response'); token='invalid input_index'},
        [pscustomobject]@{name='out-of-range index'; requirements=@([pscustomobject]@{input_index=0;mode='required';required_patterns=@('ASK')}); inputs=@('response'); token='invalid input_index'}
    )
    foreach ($Scenario in $PrepareScenarios) {
        $Candidate = ($DG001 | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
        $Candidate.ordered_subsequent_inputs = $Scenario.inputs
        $Candidate.send_condition_requirements = $Scenario.requirements
        $Validation = Test-CaseContract $Candidate
        $ValidationDetail = $Validation.failures -join '; '
        Add-Static ('prepare rejects ' + $Scenario.name) ((-not $Validation.passed) -and ($ValidationDetail -match $Scenario.token)) $ValidationDetail
    }
    foreach ($Scenario in @(
        [pscustomobject]@{name='accepted before Q-002';text="**Ledger event:**`n- Question ID: Q-001`n- Lifecycle: ANSWERED`n- Decision result: Launch`n- Resulting status: ANSWERED`n`n### Q-002 — [IMPORTANT]";pass=$true},
        [pscustomobject]@{name='Q-002 before accepted';text="Q-001 opened.`n### Q-002 — [IMPORTANT]`n**Ledger event:**`n- Question ID: Q-001`n- Lifecycle: ANSWERED`n- Decision result: Launch";pass=$false},
        [pscustomobject]@{name='accepted missing';text="Q-001 opened.`n### Q-002 — [IMPORTANT]";pass=$false},
        [pscustomobject]@{name='accepted without Q-002';text="**Ledger event:**`n- Question ID: Q-001`n- Lifecycle: ANSWERED`n- Decision result: Launch`n- Resulting status: ANSWERED";pass=$true},
        [pscustomobject]@{name='accepted em-dash ledger event';text='**Ledger event — Q-001:** ANSWERED. Launch requires the jointly confirmed go/no-go checklist. Status: ANSWERED.';pass=$true}
    )) { $Actual=(Test-PostInputOrderedAssertions $DG001 $Scenario.text).result -eq 'PASS'; Add-Static "DG-001 $($Scenario.name)" ($Actual -eq $Scenario.pass) "actual=$Actual" }
    foreach ($Scenario in @(
        [pscustomobject]@{name='DG001_ATTEMPT4_STRUCTURED_LEDGER';text=('**Ledger event — Q-001:** `ANSWERED`' + [Environment]::NewLine + 'Decision result: Launch with joint sign-off.' + [Environment]::NewLine + 'Resulting status: `ANSWERED`');pass=$true},
        [pscustomobject]@{name='DG001_INLINE_CODE_LEDGER';text=('**Ledger event — Q-001:** `ANSWERED`' + [Environment]::NewLine + 'Decision result: Launch.' + [Environment]::NewLine + 'Resulting status: `ANSWERED`');pass=$true},
        [pscustomobject]@{name='DG001_BOLD_LEDGER';text=('**Ledger event — Q-001:** **ANSWERED**' + [Environment]::NewLine + 'Decision result: Launch.' + [Environment]::NewLine + 'Resulting status: **ANSWERED**');pass=$true},
        [pscustomobject]@{name='DG001_MISSING_LEDGER_REJECTED';text=('Decision result: Launch.' + [Environment]::NewLine + 'Resulting status: ANSWERED');pass=$false},
        [pscustomobject]@{name='DG001_INCIDENTAL_ANSWERED_REJECTED';text='The team answered a different question yesterday.';pass=$false},
        [pscustomobject]@{name='DG001_NEGATED_ANSWERED_REJECTED';text=('**Ledger event — Q-001:** not ANSWERED' + [Environment]::NewLine + 'Decision result: Launch.' + [Environment]::NewLine + 'Resulting status: not ANSWERED');pass=$false},
        [pscustomobject]@{name='DG001_FENCED_LEDGER_REJECTED';text=('```markdown' + [Environment]::NewLine + '**Ledger event — Q-001:** `ANSWERED`' + [Environment]::NewLine + 'Decision result: Launch.' + [Environment]::NewLine + 'Resulting status: `ANSWERED`' + [Environment]::NewLine + '```');pass=$false},
        [pscustomobject]@{name='DG001_UNRELATED_RESULTING_STATUS_REJECTED';text=('**Ledger event — Q-002:** `ANSWERED`' + [Environment]::NewLine + 'Decision result: Other decision.' + [Environment]::NewLine + 'Resulting status: `ANSWERED`');pass=$false}
    )) { $Actual=(Test-PostInputOrderedAssertions $DG001 $Scenario.text).result -eq 'PASS'; Add-Static $Scenario.name ($Actual -eq $Scenario.pass) "actual=$Actual" }
    foreach ($Scenario in @(
        [pscustomobject]@{name='DG001_ATTEMPT6_MISSING_BOUNDARY_REPLAY';text=("### Q-001 — [BLOCKER]`n**Recommended answer:** Launch only when ready.`n### Q-002 — [BLOCKER]`n**Recommended answer:** Set a deadline.");pass=$false},
        [pscustomobject]@{name='DG001_WRONG_QID_REJECTED';text=('**Ledger event — Q-002:** `ANSWERED`' + [Environment]::NewLine + 'Decision result: Other decision.' + [Environment]::NewLine + 'Resulting status: `ANSWERED`' + [Environment]::NewLine + '### Q-002 — [BLOCKER]');pass=$false},
        [pscustomobject]@{name='DG001_PREINPUT_LEDGER_REJECTED';text=('**Ledger event — Q-001:** `ANSWERED`' + [Environment]::NewLine + 'Decision result: Launch.' + [Environment]::NewLine + 'Resulting status: `ANSWERED`' + [Environment]::NewLine + '### Q-001 — [BLOCKER]' + [Environment]::NewLine + '**Recommended answer:** Launch.');pass=$false},
        [pscustomobject]@{name='DG001_FUTURE_PROMISE_REJECTED';text='After you answer, I will record a Q-001 accepted ledger event with Resulting status: ANSWERED.';pass=$false},
        [pscustomobject]@{name='DG001_CROSS_SEGMENT_REJECTED';text=('**Ledger event — Q-001:** `ANSWERED`' + [Environment]::NewLine + [Environment]::NewLine + 'Decision result: Launch.' + [Environment]::NewLine + [Environment]::NewLine + 'Resulting status: `ANSWERED`');pass=$false}
    )) { $Actual=(Test-PostInputOrderedAssertions $DG001 $Scenario.text).result -eq 'PASS'; Add-Static $Scenario.name ($Actual -eq $Scenario.pass) "actual=$Actual" }
    $DG001Attempt7Replay = ('**Ledger event — Q-001**' + [Environment]::NewLine + 'Lifecycle: `ANSWERED`' + [Environment]::NewLine + 'Decision result: Launch requires joint approval.' + [Environment]::NewLine + 'Resulting status: `ANSWERED`' + [Environment]::NewLine + [Environment]::NewLine + '### Q-002 — [BLOCKER]')
    $DG001Attempt7Extraction = New-MessageBoundaryExtraction $DG001Attempt7Replay
    $DG001Attempt7Events = @(Get-TypedAcceptedEvents $DG001Attempt7Extraction)
    Add-Static 'DG001_ATTEMPT7_TRAILING_BLANK_REPLAY' ((Test-PostInputOrderedAssertions $DG001 $DG001Attempt7Extraction).result -eq 'PASS' -and $DG001Attempt7Events.Count -eq 1 -and $DG001Attempt7Events[0].question_id -eq 'Q-001' -and $DG001Attempt7Events[0].resulting_status -eq 'ANSWERED') 'message-boundary accepted event survives trailing blank record separator'
    $SplitAcceptedExtraction = [pscustomobject]@{ transcript=('**Ledger event — Q-001**' + [Environment]::NewLine + 'Lifecycle: ANSWERED' + [Environment]::NewLine + 'Decision result: Launch' + [Environment]::NewLine + [Environment]::NewLine + 'Resulting status: ANSWERED'); message_sequence=@([pscustomobject]@{message_index=1;turn_index=1;input_index=1;origin='resume';role='agent';source_jsonl_path='<one>';source_event_line=1;raw_text=('**Ledger event — Q-001**' + [Environment]::NewLine + 'Lifecycle: ANSWERED' + [Environment]::NewLine + 'Decision result: Launch');normalized_text=''},[pscustomobject]@{message_index=2;turn_index=2;input_index=2;origin='resume';role='agent';source_jsonl_path='<two>';source_event_line=1;raw_text='Resulting status: ANSWERED';normalized_text=''}) }
    Add-Static 'DG001_NO_CROSS_MESSAGE_OR_RECORD_ASSEMBLY' (@(Get-TypedAcceptedEvents $SplitAcceptedExtraction | Where-Object valid).Count -eq 0 -and (Test-PostInputOrderedAssertions $DG001 $SplitAcceptedExtraction).result -eq 'FAIL') 'fields must be complete in one message-local formal record'
    $DG001FinalFullReplay = ('**Ledger event — Q-001:** `ANSWERED`' + [Environment]::NewLine + '**Decision result:** Accept the four minimum hard launch gates; if any is unmet, delay the pilot.' + [Environment]::NewLine + '**Resulting status:** `ANSWERED`' + [Environment]::NewLine + [Environment]::NewLine + '### Q-002 — [BLOCKER]')
    $DG001FinalFullExtraction = New-MessageBoundaryExtraction $DG001FinalFullReplay
    $DG001FinalFullEvent = @(Get-TypedAcceptedEvents $DG001FinalFullExtraction | Where-Object valid) | Select-Object -First 1
    Add-Static 'DG001_FINAL_FULL_BOLD_COLON_REPLAY' ((Test-PostInputOrderedAssertions $DG001 $DG001FinalFullExtraction).result -eq 'PASS' -and $null -ne $DG001FinalFullEvent -and $DG001FinalFullEvent.question_id -eq 'Q-001' -and $DG001FinalFullEvent.resulting_status -eq 'ANSWERED' -and $DG001FinalFullEvent.message_index -eq 1 -and $DG001FinalFullEvent.input_index -eq 0) 'formal event is extracted from one message with Q-ID, result, and resulting status'
    $DG008 = $Cases | Where-Object case_id -eq 'DG-008'
    $DG008Objective = New-JudgeEvidence 'same' 'same' $null $null $true
    function Invoke-StaticDG008Decision([string]$Transcript, [string]$JudgeResult) {
        $Extraction = New-MessageBoundaryExtraction $Transcript
        $Deterministic = Test-Deterministic $DG008 $Transcript 'same' 'same' $Extraction
        $Capture = [pscustomobject]@{ calls=0; input=$null }
        $Decision = Invoke-AcceptanceDecision $DG008 $Extraction $DG008Objective $Deterministic {
            param($Context)
            $Capture.calls = $Capture.calls + 1
            $Capture.input = $Context.judge_input
            [pscustomobject]@{ case_id=$Context.case_id; result=$JudgeResult; confidence=1; satisfied_conditions=@('supersession_dependency_explained'); violated_conditions=@(); evidence=@('static DG-008 Judge evidence'); review_required=($JudgeResult -ne 'PASS') }
        } -SkipJudgeInputPersistence
        return [pscustomobject]@{ extraction=$Extraction; deterministic=$Deterministic; capture=$Capture; decision=$Decision }
    }
    $DG008FormalTranscript = ('Lifecycle: `SUPERSEDED`' + [Environment]::NewLine + 'Support capacity status: `BLOCKED`')
    $DG008Formal = Invoke-StaticDG008Decision $DG008FormalTranscript 'PASS'
    Add-Static 'DG008_FORMAL_LIFECYCLE_ASSOCIATION_POSITIVE' ($DG008Formal.deterministic.result -eq 'PASS' -and (Test-ExplicitStateMarker $DG008FormalTranscript 'SUPERSEDED') -and $DG008Formal.capture.calls -eq 1 -and $DG008Formal.decision.merge.result -eq 'PASS') ('deterministic={0}; calls={1}; merge={2}' -f $DG008Formal.deterministic.result,$DG008Formal.capture.calls,$DG008Formal.decision.merge.result)
    $DG008GenericTranscript = ('- Prior status: **SUPERSEDED** -- staged rollout replaces full rollout.' + [Environment]::NewLine + 'Support capacity status: BLOCKED')
    Add-Static 'DG008_GENERIC_HISTORICAL_SURFACE_POSITIVE' ((Test-Deterministic $DG008 $DG008GenericTranscript 'same' 'same').result -eq 'PASS' -and (Test-ExplicitStateMarker $DG008GenericTranscript 'SUPERSEDED')) 'generic Prior status surface is accepted by the production lifecycle parser'
    $DG008WrongDecisionTranscript = ('Previous result: `SUPERSEDED` — unrelated migration is withdrawn.' + [Environment]::NewLine + 'Support capacity status: BLOCKED')
    $DG008WrongDecision = Invoke-StaticDG008Decision $DG008WrongDecisionTranscript 'FAIL'
    Add-Static 'DG008_WRONG_DECISION_JUDGE_FAIL' ($DG008WrongDecision.deterministic.result -eq 'PASS' -and $DG008WrongDecision.capture.calls -eq 1 -and $DG008WrongDecision.capture.input.IndexOf($DG008WrongDecisionTranscript,[StringComparison]::Ordinal) -ge 0 -and $DG008WrongDecision.decision.judge.result -eq 'FAIL' -and $DG008WrongDecision.decision.merge.result -eq 'FAIL') ('deterministic={0}; calls={1}; judge={2}; merge={3}' -f $DG008WrongDecision.deterministic.result,$DG008WrongDecision.capture.calls,$DG008WrongDecision.decision.judge.result,$DG008WrongDecision.decision.merge.result)
    $DG008Incidental = 'The historical document mentions SUPERSEDED as an example.'
    Add-Static 'DG008_INCIDENTAL_SUPERSEDED_DETERMINISTIC_REJECTED' ((Test-Deterministic $DG008 $DG008Incidental 'same' 'same').result -eq 'FAIL' -and -not (Test-ExplicitStateMarker $DG008Incidental 'SUPERSEDED')) 'incidental lifecycle prose does not satisfy the actual required state'
    $DG008Negated = 'Previous result: not SUPERSEDED — the original remains active.'
    Add-Static 'DG008_HISTORICAL_LIFECYCLE_NEGATION_DETERMINISTIC_REJECTED' ((Test-Deterministic $DG008 $DG008Negated 'same' 'same').result -eq 'FAIL' -and -not (Test-ExplicitStateMarker $DG008Negated 'SUPERSEDED')) 'negated lifecycle prose does not satisfy the actual required state'
    $DG008Fenced = ('```markdown' + [Environment]::NewLine + 'Previous result: SUPERSEDED — example only.' + [Environment]::NewLine + '```')
    Add-Static 'DG008_FENCED_SUPERSEDED_DETERMINISTIC_REJECTED' ((Test-Deterministic $DG008 $DG008Fenced 'same' 'same').result -eq 'FAIL' -and -not (Test-ExplicitStateMarker $DG008Fenced 'SUPERSEDED')) 'fenced lifecycle example is not formal evidence'
    $DG008MissingLabel = 'SUPERSEDED — staged rollout replaces full rollout and support changes.'
    Add-Static 'DG008_MISSING_FORMAL_LIFECYCLE_LABEL_REJECTED' ((Test-Deterministic $DG008 $DG008MissingLabel 'same' 'same').result -eq 'FAIL' -and -not (Test-ExplicitStateMarker $DG008MissingLabel 'SUPERSEDED')) 'bare lifecycle token has no actual-contract formal label'

    $DG012 = $Cases | Where-Object case_id -eq 'DG-012'
    $DG012Prompt = @((Get-OptionalArray $DG012 'ordered_subsequent_inputs'))[0]
    function Invoke-StaticDG012Condition([string]$Transcript) {
        $Evaluation = Test-SendCondition $DG012 $Transcript 1
        $Capture = [pscustomobject]@{ calls=0; prompt=$null; arguments=$null; raw_path=$null; case_id=$null }
        $After = Invoke-ConditionalInput $Evaluation {
            param($Prompt,$Arguments,$RawPath,$CaseId)
            $Capture.calls = $Capture.calls + 1
            $Capture.prompt = $Prompt
            $Capture.arguments = @($Arguments)
            $Capture.raw_path = $RawPath
            $Capture.case_id = $CaseId
        } $DG012Prompt @('static-resume') '<static-resume-raw>' $DG012.case_id
        return [pscustomobject]@{ evaluation=$After; capture=$Capture }
    }
    $DG012Standard = Invoke-StaticDG012Condition ("### Q-777 — [BLOCKER]`n**Question:** Is launch blocked?`nStatus: BLOCKED")
    Add-Static 'DG012_SEND_STANDARD_ONCE' ($DG012Standard.evaluation.result -eq 'SEND' -and $DG012Standard.evaluation.mode -eq 'required' -and $DG012Standard.evaluation.resume_call_count -eq 1 -and $DG012Standard.capture.calls -eq 1) ('result={0}; evaluation_calls={1}; adapter_calls={2}' -f $DG012Standard.evaluation.result,$DG012Standard.evaluation.resume_call_count,$DG012Standard.capture.calls)
    Add-Static 'DG012_SEND_EXACT_CATALOG_PROMPT' ($DG012Standard.capture.prompt -ceq $DG012Prompt -and -not [string]::IsNullOrWhiteSpace($DG012Standard.capture.prompt) -and $DG012Standard.capture.case_id -eq $DG012.case_id) ('prompt={0}; case={1}' -f $DG012Standard.capture.prompt,$DG012Standard.capture.case_id)
    $DG012Inline = Invoke-StaticDG012Condition (('### Q-123 — [BLOCKER]' + [Environment]::NewLine + '**Question:** Is launch blocked?' + [Environment]::NewLine + 'Status: ' + [char]0x60 + 'BLOCKED' + [char]0x60))
    Add-Static 'DG012_SEND_INLINE_CODE_ONCE' ($DG012Inline.evaluation.result -eq 'SEND' -and $DG012Inline.evaluation.resume_call_count -eq 1 -and $DG012Inline.capture.calls -eq 1) ('result={0}; calls={1}' -f $DG012Inline.evaluation.result,$DG012Inline.capture.calls)
    $DG012Bold = Invoke-StaticDG012Condition ("### Q-456 — [BLOCKER]`n**Question:** Is launch blocked?`n**Status:** **BLOCKED**")
    Add-Static 'DG012_SEND_BOLD_LEDGER_ONCE' ($DG012Bold.evaluation.result -eq 'SEND' -and $DG012Bold.evaluation.resume_call_count -eq 1 -and $DG012Bold.capture.calls -eq 1) ('result={0}; calls={1}' -f $DG012Bold.evaluation.result,$DG012Bold.capture.calls)
    $DG012NonSendScenarios = @(
        [pscustomobject]@{ name='DG012_MISSING_BLOCKED_ADAPTER_ZERO'; text="### Q-001 — [BLOCKER]`n**Question:** Is launch blocked?" },
        [pscustomobject]@{ name='DG012_MISSING_Q_HEADING_ADAPTER_ZERO'; text='Status: BLOCKED' },
        [pscustomobject]@{ name='DG012_EMPTY_TRANSCRIPT_ADAPTER_ZERO'; text='' },
        [pscustomobject]@{ name='DG012_MALFORMED_Q_HEADING_ADAPTER_ZERO'; text="## Q-001`nStatus: BLOCKED" },
        [pscustomobject]@{ name='DG012_INCIDENTAL_BLOCKED_ADAPTER_ZERO'; text="### Q-001 — [BLOCKER]`nThe launch could be BLOCKED if approval is absent." },
        [pscustomobject]@{ name='DG012_NEGATED_BLOCKED_ADAPTER_ZERO'; text="### Q-001 — [BLOCKER]`nStatus: not BLOCKED" },
        [pscustomobject]@{ name='DG012_FENCED_BLOCKED_ADAPTER_ZERO'; text=('### Q-001 — [BLOCKER]' + [Environment]::NewLine + (-join @([char]0x60,[char]0x60,[char]0x60)) + 'markdown' + [Environment]::NewLine + 'Status: BLOCKED' + [Environment]::NewLine + (-join @([char]0x60,[char]0x60,[char]0x60))) }
    )
    $DG012NonSendResults = foreach ($Scenario in $DG012NonSendScenarios) {
        $ScenarioResult = Invoke-StaticDG012Condition $Scenario.text
        Add-Static $Scenario.name ($ScenarioResult.evaluation.result -eq 'BLOCKED' -and $ScenarioResult.evaluation.mode -eq 'required' -and $ScenarioResult.evaluation.resume_call_count -eq 0 -and $ScenarioResult.capture.calls -eq 0) ('result={0}; calls={1}; reason={2}' -f $ScenarioResult.evaluation.result,$ScenarioResult.capture.calls,$ScenarioResult.evaluation.reason)
        $ScenarioResult
    }
    Add-Static 'DG012_REQUIRED_NEVER_SKIP' (@($DG012NonSendResults | Where-Object { $_.evaluation.result -eq 'SKIP' }).Count -eq 0) 'actual required declaration returns BLOCKED for false, unknown, and missing applicability evidence'

    $DG020 = $Cases | Where-Object case_id -eq 'DG-020'
    $DG020Objective = New-JudgeEvidence 'same' 'same' $null $null $true
    function Invoke-StaticDG020Decision([string]$Transcript, [string]$JudgeResult) {
        $Extraction = New-MessageBoundaryExtraction $Transcript
        $Deterministic = Test-Deterministic $DG020 $Transcript 'same' 'same' $Extraction
        $Capture = [pscustomobject]@{ calls=0; input=$null }
        $Decision = Invoke-AcceptanceDecision $DG020 $Extraction $DG020Objective $Deterministic {
            param($Context)
            $Capture.calls = $Capture.calls + 1
            $Capture.input = $Context.judge_input
            [pscustomobject]@{ case_id=$Context.case_id; result=$JudgeResult; confidence=1; satisfied_conditions=@('confirmation_only_semantics'); violated_conditions=@(); evidence=@('static DG-020 Judge evidence'); review_required=($JudgeResult -ne 'PASS') }
        } -SkipJudgeInputPersistence
        return [pscustomobject]@{ extraction=$Extraction; deterministic=$Deterministic; capture=$Capture; decision=$Decision }
    }
    $DG020EnglishTranscript = ('Convergence status: NOT_CONVERGED' + [Environment]::NewLine + 'Explicit confirmation is the sole remaining condition.')
    $DG020JudgePass = Invoke-StaticDG020Decision $DG020EnglishTranscript 'PASS'
    Add-Static 'DG020_JUDGE_PASS_ADAPTER_ONCE' ($DG020JudgePass.deterministic.result -eq 'PASS' -and $DG020JudgePass.capture.calls -eq 1 -and $DG020JudgePass.decision.judge.result -eq 'PASS' -and $DG020JudgePass.decision.merge.result -eq 'PASS') ('deterministic={0}; calls={1}; merge={2}' -f $DG020JudgePass.deterministic.result,$DG020JudgePass.capture.calls,$DG020JudgePass.decision.merge.result)
    Add-Static 'DG020_JUDGE_INPUT_EVIDENCE' ($null -ne $DG020JudgePass.capture.input -and $DG020JudgePass.capture.input.IndexOf($DG020EnglishTranscript,[StringComparison]::Ordinal) -ge 0 -and $DG020JudgePass.capture.input -match 'OBJECTIVE EVIDENCE:' -and $DG020JudgePass.capture.input -match 'DETERMINISTIC EVIDENCE:' -and $DG020JudgePass.capture.input -match 'confirmation_only_semantics') 'production Judge input contains transcript, objective evidence, deterministic evidence, and case-owned semantic requirement'
    $DG020JudgeFail = Invoke-StaticDG020Decision $DG020EnglishTranscript 'FAIL'
    Add-Static 'DG020_JUDGE_FAIL_ADAPTER_ONCE' ($DG020JudgeFail.deterministic.result -eq 'PASS' -and $DG020JudgeFail.capture.calls -eq 1 -and $DG020JudgeFail.decision.judge.result -eq 'FAIL' -and $DG020JudgeFail.decision.merge.result -eq 'FAIL' -and $DG020JudgeFail.decision.merge.reason -eq 'JUDGE_SEMANTIC_FAILURE') ('calls={0}; judge={1}; merge={2}; reason={3}' -f $DG020JudgeFail.capture.calls,$DG020JudgeFail.decision.judge.result,$DG020JudgeFail.decision.merge.result,$DG020JudgeFail.decision.merge.reason)
    $DG020MixedTranscript = ('Status: NOT_CONVERGED' + [Environment]::NewLine + '尚待 explicit confirmation，這是唯一剩餘條件。')
    $DG020Mixed = Invoke-StaticDG020Decision $DG020MixedTranscript 'PASS'
    Add-Static 'DG020_JUDGE_MIXED_SURFACE_PASS' ($DG020Mixed.deterministic.result -eq 'PASS' -and $DG020Mixed.capture.calls -eq 1 -and $DG020Mixed.decision.merge.result -eq 'PASS') ('deterministic={0}; calls={1}; merge={2}' -f $DG020Mixed.deterministic.result,$DG020Mixed.capture.calls,$DG020Mixed.decision.merge.result)
    $DG020Premature = Invoke-StaticDG020Decision 'Convergence status: CONVERGED' 'PASS'
    Add-Static 'DG020_PREMATURE_CONVERGED_SKIPS_JUDGE' ($DG020Premature.deterministic.result -eq 'FAIL' -and $DG020Premature.capture.calls -eq 0 -and $DG020Premature.decision.judge.result -eq 'NOT_EXECUTED' -and $DG020Premature.decision.merge.result -eq 'FAIL') ('deterministic={0}; calls={1}; merge={2}' -f $DG020Premature.deterministic.result,$DG020Premature.capture.calls,$DG020Premature.decision.merge.result)
    foreach ($Scenario in @(
        [pscustomobject]@{name='DG020_INCIDENTAL_CONVERGED_NOT_FORMAL';text=('Convergence status: NOT_CONVERGED' + [Environment]::NewLine + 'The document mentions CONVERGED as an example.')},
        [pscustomobject]@{name='DG020_NEGATED_CONVERGED_NOT_FORMAL';text=('Convergence status: NOT_CONVERGED' + [Environment]::NewLine + 'Convergence status: not CONVERGED')},
        [pscustomobject]@{name='DG020_FENCED_CONVERGED_NOT_FORMAL';text=('Convergence status: NOT_CONVERGED' + [Environment]::NewLine + '```markdown' + [Environment]::NewLine + 'Convergence status: CONVERGED' + [Environment]::NewLine + '```')}
    )) { Add-Static $Scenario.name ((Test-Deterministic $DG020 $Scenario.text 'same' 'same').result -eq 'PASS' -and -not (Test-ExplicitStateMarker $Scenario.text 'CONVERGED')) 'incidental, negated, or fenced CONVERGED is not a formal convergence state' }
    $DG020PassDeterministic = Test-Deterministic $DG020 $DG020EnglishTranscript 'same' 'same'
    $DG020MissingTranscriptCapture = [pscustomobject]@{ calls=0 }
    $DG020MissingTranscriptJudge = Invoke-JudgeWithEvidenceGate $DG020 (New-MessageBoundaryExtraction '') $DG020Objective $DG020PassDeterministic {
        param($Context)
        $DG020MissingTranscriptCapture.calls = $DG020MissingTranscriptCapture.calls + 1
        [pscustomobject]@{case_id=$Context.case_id;result='PASS'}
    } -SkipJudgeInputPersistence
    Add-Static 'DG020_MISSING_TRANSCRIPT_BLOCKS_ADAPTER_ZERO' ($DG020MissingTranscriptJudge.result -eq 'BLOCKED' -and $DG020MissingTranscriptCapture.calls -eq 0 -and $DG020MissingTranscriptJudge.reason -eq 'TRANSCRIPT_ENCODING_ERROR') ('result={0}; calls={1}; reason={2}' -f $DG020MissingTranscriptJudge.result,$DG020MissingTranscriptCapture.calls,$DG020MissingTranscriptJudge.reason)
    $DG020MissingInputCapture = [pscustomobject]@{ calls=0 }
    $DG020MissingInputJudge = Invoke-JudgeWithEvidenceGate $DG020 (New-MessageBoundaryExtraction $DG020EnglishTranscript) $DG020Objective $DG020PassDeterministic {
        param($Context)
        $DG020MissingInputCapture.calls = $DG020MissingInputCapture.calls + 1
        [pscustomobject]@{case_id=$Context.case_id;result='PASS'}
    } -SkipJudgeInputPersistence -JudgeInputOverride 'OBJECTIVE EVIDENCE: {}'
    Add-Static 'DG020_MISSING_JUDGE_INPUT_BLOCKS_ADAPTER_ZERO' ($DG020MissingInputJudge.result -eq 'BLOCKED' -and $DG020MissingInputCapture.calls -eq 0 -and $DG020MissingInputJudge.reason -eq 'TRANSCRIPT_ENCODING_ERROR') ('result={0}; calls={1}; reason={2}' -f $DG020MissingInputJudge.result,$DG020MissingInputCapture.calls,$DG020MissingInputJudge.reason)
    $DG020MalformedCapture = [pscustomobject]@{ calls=0 }
    $DG020MalformedJudge = Invoke-AcceptanceDecision $DG020 (New-MessageBoundaryExtraction $DG020EnglishTranscript) $DG020Objective $DG020PassDeterministic {
        param($Context)
        $DG020MalformedCapture.calls = $DG020MalformedCapture.calls + 1
        [pscustomobject]@{case_id=$Context.case_id}
    } -SkipJudgeInputPersistence
    Add-Static 'DG020_MALFORMED_JUDGE_RESPONSE_NOT_PASS' ($DG020MalformedCapture.calls -eq 1 -and $DG020MalformedJudge.merge.result -ne 'PASS' -and $DG020MalformedJudge.merge.reason -eq 'JUDGE_SEMANTIC_FAILURE') ('calls={0}; merge={1}; reason={2}' -f $DG020MalformedCapture.calls,$DG020MalformedJudge.merge.result,$DG020MalformedJudge.merge.reason)
    $DG020ExceptionCapture = [pscustomobject]@{ calls=0 }
    $DG020ExceptionJudge = Invoke-AcceptanceDecision $DG020 (New-MessageBoundaryExtraction $DG020EnglishTranscript) $DG020Objective $DG020PassDeterministic {
        param($Context)
        $DG020ExceptionCapture.calls = $DG020ExceptionCapture.calls + 1
        throw 'static DG-020 Judge adapter exception'
    } -SkipJudgeInputPersistence
    Add-Static 'DG020_JUDGE_EXCEPTION_BLOCKED' ($DG020ExceptionCapture.calls -eq 1 -and $DG020ExceptionJudge.judge.result -eq 'BLOCKED' -and $DG020ExceptionJudge.merge.result -eq 'BLOCKED') ('calls={0}; judge={1}; merge={2}; reason={3}' -f $DG020ExceptionCapture.calls,$DG020ExceptionJudge.judge.result,$DG020ExceptionJudge.merge.result,$DG020ExceptionJudge.judge.reason)

    $DG010 = $Cases | Where-Object case_id -eq 'DG-010'
    $DG010ConfirmationTranscript = ('# Decision-Grill Summary' + [Environment]::NewLine + 'Convergence status: NOT_CONVERGED' + [Environment]::NewLine + '## 8. Recommended Next Action' + [Environment]::NewLine + 'Explicit confirmation is the sole remaining condition. Please explicitly confirm this decision summary.')
    $DG010ConfirmationPostInput = Test-PostInputOrderedAssertions $DG010 (New-MessageBoundaryExtraction $DG010ConfirmationTranscript)
    $DG010SemanticRequirement = @((Get-OptionalArray $DG010 'judge_semantic_requirements') | Where-Object { (Get-OptionalString $_ 'id') -eq 'confirmation_only_explained' })
    $DG010HardSemanticPattern = @((Get-OptionalArray $DG010 'post_input_required_patterns') | Where-Object { $_ -match '(?i)only|sole' })
    Add-Static 'DG010_CONFIRMATION_ONLY_JUDGE_OWNED_POST_INPUT_PATH' ($DG010ConfirmationPostInput.result -eq 'PASS' -and $DG010SemanticRequirement.Count -eq 1 -and $DG010HardSemanticPattern.Count -eq 0) 'actual DG-010 declaration keeps explicit confirmation structural while its sole-condition meaning is Judge-owned'
    $DG010MissingConfirmation = Test-PostInputOrderedAssertions $DG010 (New-MessageBoundaryExtraction ('# Decision-Grill Summary' + [Environment]::NewLine + 'Convergence status: NOT_CONVERGED' + [Environment]::NewLine + '## 8. Recommended Next Action' + [Environment]::NewLine + 'The summary remains available.'))
    Add-Static 'DG010_MISSING_EXPLICIT_CONFIRMATION_REJECTED' ($DG010MissingConfirmation.result -eq 'FAIL') 'production post-input evaluator still rejects an absent explicit confirmation request'

    function Test-StaticFourCaseMatrixAggregate([string[]]$RequiredNames, [object[]]$ObservedResults) {
        $Missing = [System.Collections.Generic.List[string]]::new()
        $Duplicate = [System.Collections.Generic.List[string]]::new()
        foreach ($RequiredName in $RequiredNames) {
            $MatchingResults = @($ObservedResults | Where-Object { $_.name -eq $RequiredName })
            if ($MatchingResults.Count -eq 0) { $Missing.Add($RequiredName) }
            if ($MatchingResults.Count -ne 1) { $Duplicate.Add($RequiredName) }
        }
        $Failed = @($ObservedResults | Where-Object { $_.name -in $RequiredNames -and -not $_.passed } | ForEach-Object { $_.name })
        return [pscustomobject]@{ passed=($Missing.Count -eq 0 -and $Duplicate.Count -eq 0 -and $Failed.Count -eq 0 -and @($ObservedResults | Where-Object { $_.name -in $RequiredNames }).Count -eq $RequiredNames.Count); missing=@($Missing); duplicate=@($Duplicate); failed=@($Failed); observed=@($ObservedResults | Where-Object { $_.name -in $RequiredNames }).Count; required=$RequiredNames.Count }
    }
    $FourCaseProductionGateNames = @(
        'DG-001 Q-002 before accepted','DG001_FINAL_FULL_BOLD_COLON_REPLAY','DG001_ATTEMPT7_TRAILING_BLANK_REPLAY','DG001_NO_CROSS_MESSAGE_OR_RECORD_ASSEMBLY','DG001_MISSING_LEDGER_REJECTED','DG001_WRONG_QID_REJECTED','DG001_CROSS_SEGMENT_REJECTED','DG001_INCIDENTAL_ANSWERED_REJECTED','DG001_NEGATED_ANSWERED_REJECTED',
        'DG008_FORMAL_LIFECYCLE_ASSOCIATION_POSITIVE','DG008_GENERIC_HISTORICAL_SURFACE_POSITIVE','DG008_WRONG_DECISION_JUDGE_FAIL','DG008_INCIDENTAL_SUPERSEDED_DETERMINISTIC_REJECTED','DG008_HISTORICAL_LIFECYCLE_NEGATION_DETERMINISTIC_REJECTED','DG008_FENCED_SUPERSEDED_DETERMINISTIC_REJECTED','DG008_MISSING_FORMAL_LIFECYCLE_LABEL_REJECTED',
        'DG012_SEND_STANDARD_ONCE','DG012_SEND_EXACT_CATALOG_PROMPT','DG012_SEND_INLINE_CODE_ONCE','DG012_SEND_BOLD_LEDGER_ONCE','DG012_MISSING_BLOCKED_ADAPTER_ZERO','DG012_MISSING_Q_HEADING_ADAPTER_ZERO','DG012_EMPTY_TRANSCRIPT_ADAPTER_ZERO','DG012_MALFORMED_Q_HEADING_ADAPTER_ZERO','DG012_INCIDENTAL_BLOCKED_ADAPTER_ZERO','DG012_NEGATED_BLOCKED_ADAPTER_ZERO','DG012_FENCED_BLOCKED_ADAPTER_ZERO','DG012_REQUIRED_NEVER_SKIP',
        'DG020_JUDGE_PASS_ADAPTER_ONCE','DG020_JUDGE_INPUT_EVIDENCE','DG020_JUDGE_FAIL_ADAPTER_ONCE','DG020_JUDGE_MIXED_SURFACE_PASS','DG020_PREMATURE_CONVERGED_SKIPS_JUDGE','DG020_INCIDENTAL_CONVERGED_NOT_FORMAL','DG020_NEGATED_CONVERGED_NOT_FORMAL','DG020_FENCED_CONVERGED_NOT_FORMAL','DG020_MISSING_TRANSCRIPT_BLOCKS_ADAPTER_ZERO','DG020_MISSING_JUDGE_INPUT_BLOCKS_ADAPTER_ZERO','DG020_MALFORMED_JUDGE_RESPONSE_NOT_PASS','DG020_JUDGE_EXCEPTION_BLOCKED'
    )
    $FourCaseProductionGateResults = @($Results | Where-Object { $_.name -in $FourCaseProductionGateNames })
    $FourCaseMatrixAggregate = Test-StaticFourCaseMatrixAggregate $FourCaseProductionGateNames $FourCaseProductionGateResults
    Add-Static 'FOUR_CASE_PRODUCTION_PATH_REGRESSION_GATE' $FourCaseMatrixAggregate.passed ('required={0}; observed={1}; missing={2}; duplicate={3}; failed={4}' -f $FourCaseMatrixAggregate.required,$FourCaseMatrixAggregate.observed,($FourCaseMatrixAggregate.missing -join '|'),($FourCaseMatrixAggregate.duplicate -join '|'),($FourCaseMatrixAggregate.failed -join '|'))
    $FourCaseMissingProbe = Test-StaticFourCaseMatrixAggregate $FourCaseProductionGateNames @($FourCaseProductionGateResults | Where-Object { $_.name -ne $FourCaseProductionGateNames[0] })
    $FourCaseFalseProbe = @($FourCaseProductionGateResults | ForEach-Object { [pscustomobject]@{ name=$_.name; passed=$(if ($_.name -eq $FourCaseProductionGateNames[1]) { $false } else { $_.passed }) } })
    $FourCaseFalseAggregate = Test-StaticFourCaseMatrixAggregate $FourCaseProductionGateNames $FourCaseFalseProbe
    Add-Static 'FOUR_CASE_MATRIX_COMPLETENESS_UNIQUENESS_FAILURE_SENSITIVITY' (-not $FourCaseMissingProbe.passed -and $FourCaseMissingProbe.missing -contains $FourCaseProductionGateNames[0] -and -not $FourCaseFalseAggregate.passed -and $FourCaseFalseAggregate.failed -contains $FourCaseProductionGateNames[1]) 'aggregate rejects a missing required assertion and a false required assertion from the same result collection'
    $ExpectedCatalogIds = @(1..20 | ForEach-Object { 'DG-{0:D3}' -f $_ })
    $ActualCatalogIds = @($Cases | ForEach-Object { $_.case_id })
    $CatalogContracts = @($Cases | ForEach-Object { Test-CaseContract $_ })
    $CatalogContractsPass = @($CatalogContracts | Where-Object { -not $_.passed }).Count -eq 0
    Add-Static '20_CASE_CATALOG_CONTRACT_GATE' ($ActualCatalogIds.Count -eq 20 -and ($ActualCatalogIds -join ',') -eq ($ExpectedCatalogIds -join ',') -and $CatalogContractsPass) 'exact DG-001 through DG-020 catalog order and production Test-CaseContract validation; this is not a Full replay'
    $StaticRunnerClaims = Read-Utf8NoBom $PSCommandPath
    $StaticReadmeClaims = Read-Utf8NoBom (Join-Path $RepoRoot 'tests\automation\README.md')
    $StaticRemediationClaims = Read-Utf8NoBom $RemediationSpecPath
    $MisleadingReplayGateToken = 'LATEST' + '_FULL_20_CASE_REPLAY_CATALOG_GATE'
    Add-Static 'MISLEADING_20_CASE_REPLAY_GATE_ABSENT' (-not (($StaticRunnerClaims + $StaticReadmeClaims + $StaticRemediationClaims).Contains($MisleadingReplayGateToken))) 'runner and authorized acceptance documentation contain no catalog-only Full replay gate claim'
    $HistoricalEvidenceScopeDocumented = $StaticReadmeClaims -match '16 PASS / 3 FAIL / 1 BLOCKED' -and
        $StaticReadmeClaims -match 'not a real product Full PASS' -and
        $StaticRemediationClaims -match 'not a replay closure'
    Add-Static 'HISTORICAL_EVIDENCE_PRESERVATION_NOT_CLOSURE' $HistoricalEvidenceScopeDocumented 'immutable 20260801 Full evidence is classified as 16 PASS / 3 FAIL / 1 BLOCKED; StaticTest does not infer a 20-case Full result'
    $OwnershipComplete = @($Cases | Where-Object { @(Get-OptionalArray $_ 'judge_semantic_requirements').Count -eq 0 }).Count -eq 0
    $StaticDG009 = @($Cases | Where-Object case_id -eq 'DG-009')[0]
    $DG009Ownership = @($StaticDG009.required_keywords).Count -eq 0 -and @(Get-OptionalArray $StaticDG009 'judge_semantic_requirements').Count -eq 2
    Add-Static '20_CASE_OWNERSHIP_MIGRATION_COMPLETE' ($OwnershipComplete -and $DG009Ownership) 'all cases declare J requirements; DG-009 has no authoritative English keyword gate'
    $HardDeterministic = [pscustomobject]@{result='FAIL';hard_failures=@('STRUCTURAL')}
    $PassDeterministic = [pscustomobject]@{result='PASS';hard_failures=@()}
    $JudgePass = [pscustomobject]@{result='PASS'}; $JudgeFail=[pscustomobject]@{result='FAIL'}; $JudgeBlocked=[pscustomobject]@{result='BLOCKED'}
    Add-Static 'MERGE_PRECEDENCE_MATRIX' ((Merge-AcceptanceResult $HardDeterministic $JudgePass $true).result -eq 'FAIL' -and (Merge-AcceptanceResult $PassDeterministic $JudgePass $true).result -eq 'PASS' -and (Merge-AcceptanceResult $PassDeterministic $JudgeFail $true).result -eq 'FAIL' -and (Merge-AcceptanceResult $PassDeterministic $JudgeBlocked $true).result -eq 'BLOCKED') 'hard structural/typed gates win; Judge decides semantic PASS/FAIL; unavailable Judge blocks'
    $DG009ChineseReplay = ('- D-001 Hosting decision: `BLOCKED`' + [Environment]::NewLine + '- D-002 Certification decision: `BLOCKED`' + [Environment]::NewLine + '這兩項決策形成相依循環，必須先決定上游合規基準。')
    $DG009Extraction = New-MessageBoundaryExtraction $DG009ChineseReplay
    $DG009Deterministic = Test-Deterministic $StaticDG009 $DG009ChineseReplay 'same' 'same' $DG009Extraction
    $DG009Objective = New-JudgeEvidence 'same' 'same' $null $null $true
    $DG009Capture = [pscustomobject]@{calls=0;input=$null}
    $DG009Decision = Invoke-AcceptanceDecision $StaticDG009 $DG009Extraction $DG009Objective $DG009Deterministic { param($Context) $DG009Capture.calls++; $DG009Capture.input=$Context.judge_input; [pscustomobject]@{case_id=$Context.case_id;result='PASS';confidence=1;satisfied_conditions=@('cycle_dependency_explained','upstream_blocker_explained');violated_conditions=@();evidence=@('這兩項決策形成相依循環');review_required=$false} } -SkipJudgeInputPersistence
    Add-Static 'DG009_LANGUAGE_NEUTRAL_JUDGE_INPUT' ($DG009Deterministic.result -eq 'PASS' -and $DG009Capture.calls -eq 1 -and $DG009Decision.merge.result -eq 'PASS' -and $DG009Capture.input -match 'cycle_dependency_explained' -and $DG009Capture.input -match 'circular dependency') 'case-owned semantic requirements reach the independent Judge without English keyword hard gate'
    $DG009HardCapture = [pscustomobject]@{calls=0}
    $DG009HardDecision = Invoke-AcceptanceDecision $StaticDG009 (New-MessageBoundaryExtraction 'no formal state') $DG009Objective ([pscustomobject]@{result='FAIL';hard_failures=@('required all-of state absent: BLOCKED');failures=@('required all-of state absent: BLOCKED');fact_work_assertions=@()}) { param($Context) $DG009HardCapture.calls++; [pscustomobject]@{case_id=$Context.case_id;result='PASS'} } -SkipJudgeInputPersistence
    Add-Static 'STRUCTURAL_HARD_FAILURE_SKIPS_JUDGE_ADAPTER' ($DG009HardCapture.calls -eq 0 -and $DG009HardDecision.judge.result -eq 'NOT_EXECUTED' -and $DG009HardDecision.merge.result -eq 'FAIL') 'production acceptance wrapper preserves S/T authority before Judge invocation'
    Add-Static 'DG009_WRAPPER_STRUCTURAL_HARD_FAILURE_REASON' ($DG009HardDecision.merge.reason -eq 'DETERMINISTIC_HARD_GATE_FAILURE' -and @($DG009HardDecision.judge.reason) -contains 'DETERMINISTIC_HARD_GATE_FAILURE') 'missing formal BLOCKED state remains a deterministic hard failure'
    function Invoke-StaticDG009WrapperScenario([object]$Scenario) {
        $ScenarioExtraction = New-MessageBoundaryExtraction $Scenario.transcript
        $ScenarioDeterministic = Test-Deterministic $StaticDG009 $Scenario.transcript 'same' 'same' $ScenarioExtraction
        $Capture = [pscustomobject]@{ calls=0; input=$null }
        $ScenarioDecision = Invoke-AcceptanceDecision $StaticDG009 $ScenarioExtraction $DG009Objective $ScenarioDeterministic {
            param($Context)
            $Capture.calls++
            $Capture.input = $Context.judge_input
            [pscustomobject]@{
                case_id = $Context.case_id
                result = $Scenario.judge_result
                confidence = 1
                satisfied_conditions = @($Scenario.satisfied_conditions)
                violated_conditions = @($Scenario.violated_conditions)
                evidence = @($Scenario.evidence_text)
                review_required = ($Scenario.judge_result -ne 'PASS')
            }
        } -SkipJudgeInputPersistence
        $Prefix = [string]$Scenario.name
        $RequirementsPresent = $null -ne $Capture.input -and
            $Capture.input.IndexOf($Scenario.transcript, [StringComparison]::Ordinal) -ge 0 -and
            $Capture.input -match 'cycle_dependency_explained' -and
            $Capture.input -match 'upstream_blocker_explained' -and
            $Capture.input -match [regex]::Escape('The response explains the circular dependency without requiring specific English wording.') -and
            $Capture.input -match [regex]::Escape('The response explains how an unresolved upstream or prerequisite decision or input blocks the current decision.')
        $NoLegacyLiteralFailure = @($ScenarioDeterministic.hard_failures | Where-Object { $_ -match 'required text absent|forbidden text present' }).Count -eq 0
        $JudgeShapeValid = $ScenarioDecision.judge.case_id -eq 'DG-009' -and
            $ScenarioDecision.judge.result -eq $Scenario.judge_result -and
            ($ScenarioDecision.judge.confidence -is [double] -or
            $ScenarioDecision.judge.confidence -is [int])
        Add-Static ($Prefix + '_HARD_GATES_PASS') ($ScenarioDeterministic.result -eq 'PASS' -and @($ScenarioDeterministic.hard_failures).Count -eq 0 -and $NoLegacyLiteralFailure) ('deterministic={0}; hard_failures={1}' -f $ScenarioDeterministic.result,(@($ScenarioDeterministic.hard_failures) -join '|'))
        Add-Static ($Prefix + '_ADAPTER_ONCE') ($Capture.calls -eq 1) ('calls={0}' -f $Capture.calls)
        Add-Static ($Prefix + '_TRANSCRIPT_PRESENT') ($null -ne $Capture.input -and $Capture.input.IndexOf($Scenario.transcript, [StringComparison]::Ordinal) -ge 0) 'captured production Judge input contains exact scenario transcript'
        Add-Static ($Prefix + '_REQUIREMENTS_PRESENT') $RequirementsPresent 'captured production Judge input contains DG-009 requirement IDs and descriptions'
        Add-Static ($Prefix + '_JUDGE_RESULT') $JudgeShapeValid ('judge={0}; expected={1}' -f $ScenarioDecision.judge.result,$Scenario.judge_result)
        Add-Static ($Prefix + '_SEMANTIC_CONDITIONS') ((@($ScenarioDecision.judge.satisfied_conditions) -join '|') -eq (@($Scenario.satisfied_conditions) -join '|') -and ((@($ScenarioDecision.judge.violated_conditions) -join '|') -eq (@($Scenario.violated_conditions) -join '|')) -and @($ScenarioDecision.judge.evidence) -contains $Scenario.evidence_text) ('satisfied={0}; violated={1}' -f (@($ScenarioDecision.judge.satisfied_conditions) -join '|'),(@($ScenarioDecision.judge.violated_conditions) -join '|'))
        Add-Static ($Prefix + '_FINAL_' + $Scenario.expected_final) ($ScenarioDecision.merge.result -eq $Scenario.expected_final) ('merge={0}; reason={1}' -f $ScenarioDecision.merge.result,$ScenarioDecision.merge.reason)
    }
    $DG009WrapperScenarios = @(
        [pscustomobject]@{ name='DG009_WRAPPER_CHINESE_POSITIVE'; transcript=('- D-001 Hosting decision: `BLOCKED`' + [Environment]::NewLine + '- D-002 Certification decision: `BLOCKED`' + [Environment]::NewLine + '兩項決策互相依賴形成閉環；尚未決定的上游合規基準使目前的主機決策無法前進。'); judge_result='PASS'; satisfied_conditions=@('cycle_dependency_explained','upstream_blocker_explained'); violated_conditions=@(); evidence_text='兩項決策互相依賴形成閉環'; expected_final='PASS' },
        [pscustomobject]@{ name='DG009_WRAPPER_ENGLISH_POSITIVE'; transcript=('- D-001 Hosting decision: `BLOCKED`' + [Environment]::NewLine + '- D-002 Certification decision: `BLOCKED`' + [Environment]::NewLine + 'The decisions form a circular dependency, and the unresolved prerequisite compliance decision prevents the hosting decision from progressing.'); judge_result='PASS'; satisfied_conditions=@('cycle_dependency_explained','upstream_blocker_explained'); violated_conditions=@(); evidence_text='circular dependency'; expected_final='PASS' },
        [pscustomobject]@{ name='DG009_WRAPPER_MIXED_POSITIVE'; transcript=('- D-001 Hosting decision: `BLOCKED`' + [Environment]::NewLine + '- D-002 Certification decision: `BLOCKED`' + [Environment]::NewLine + 'Hosting 與 certification 彼此相依；尚未完成的 prerequisite decision 阻塞目前的 hosting 選擇。'); judge_result='PASS'; satisfied_conditions=@('cycle_dependency_explained','upstream_blocker_explained'); violated_conditions=@(); evidence_text='彼此相依'; expected_final='PASS' },
        [pscustomobject]@{ name='DG009_WRAPPER_STATE_ONLY_NO_EXPLANATION'; transcript=('- D-001 Hosting decision: `BLOCKED`' + [Environment]::NewLine + '- D-002 Certification decision: `BLOCKED`'); judge_result='FAIL'; satisfied_conditions=@(); violated_conditions=@('cycle_dependency_explained','upstream_blocker_explained'); evidence_text='Hosting decision: `BLOCKED`'; expected_final='FAIL' },
        [pscustomobject]@{ name='DG009_WRAPPER_CIRCULAR_ONLY_MISSING_UPSTREAM_IMPACT'; transcript=('- D-001 Hosting decision: `BLOCKED`' + [Environment]::NewLine + '- D-002 Certification decision: `BLOCKED`' + [Environment]::NewLine + 'The decisions form a circular dependency.'); judge_result='FAIL'; satisfied_conditions=@('cycle_dependency_explained'); violated_conditions=@('upstream_blocker_explained'); evidence_text='circular dependency'; expected_final='FAIL' },
        [pscustomobject]@{ name='DG009_WRAPPER_UPSTREAM_ONLY_MISSING_CIRCULAR_DEPENDENCY'; transcript=('- D-001 Hosting decision: `BLOCKED`' + [Environment]::NewLine + '- D-002 Certification decision: `BLOCKED`' + [Environment]::NewLine + 'The unresolved prerequisite certification decision prevents the hosting decision from progressing.'); judge_result='FAIL'; satisfied_conditions=@('upstream_blocker_explained'); violated_conditions=@('cycle_dependency_explained'); evidence_text='prerequisite certification decision'; expected_final='FAIL' },
        [pscustomobject]@{ name='DG009_WRAPPER_INCIDENTAL_TERMS_WITHOUT_EXPLANATION'; transcript=('- D-001 Hosting decision: `BLOCKED`' + [Environment]::NewLine + '- D-002 Certification decision: `BLOCKED`' + [Environment]::NewLine + 'Cycle and upstream are labels in this report.'); judge_result='FAIL'; satisfied_conditions=@(); violated_conditions=@('cycle_dependency_explained','upstream_blocker_explained'); evidence_text='Cycle and upstream are labels'; expected_final='FAIL' },
        [pscustomobject]@{ name='DG009_WRAPPER_NEGATED_OR_DENIED_DEPENDENCY'; transcript=('- D-001 Hosting decision: `BLOCKED`' + [Environment]::NewLine + '- D-002 Certification decision: `BLOCKED`' + [Environment]::NewLine + 'There is no circular dependency, and no upstream prerequisite is blocking the hosting decision.'); judge_result='FAIL'; satisfied_conditions=@(); violated_conditions=@('cycle_dependency_explained','upstream_blocker_explained'); evidence_text='There is no circular dependency'; expected_final='FAIL' }
    )
    foreach ($Scenario in $DG009WrapperScenarios) { Invoke-StaticDG009WrapperScenario $Scenario }
    $DG009EvidenceUnavailableCapture = [pscustomobject]@{ calls=0; input=$null }
    $DG009EvidenceUnavailable = Invoke-AcceptanceDecision $StaticDG009 (New-MessageBoundaryExtraction $DG009WrapperScenarios[0].transcript) $DG009Objective (Test-Deterministic $StaticDG009 $DG009WrapperScenarios[0].transcript 'same' 'same') {
        param($Context)
        $DG009EvidenceUnavailableCapture.calls++
        $DG009EvidenceUnavailableCapture.input = $Context.judge_input
        throw 'synthetic semantic evidence unavailable'
    } -SkipJudgeInputPersistence
    Add-Static 'DG009_WRAPPER_JUDGE_EVIDENCE_UNAVAILABLE_ADAPTER_ONCE' ($DG009EvidenceUnavailableCapture.calls -eq 1 -and $DG009EvidenceUnavailableCapture.input -match 'cycle_dependency_explained') ('calls={0}' -f $DG009EvidenceUnavailableCapture.calls)
    Add-Static 'DG009_WRAPPER_JUDGE_EVIDENCE_UNAVAILABLE_BLOCKED' ($DG009EvidenceUnavailable.judge.result -eq 'BLOCKED' -and $DG009EvidenceUnavailable.merge.result -eq 'BLOCKED' -and $DG009EvidenceUnavailable.judge.reason -eq 'synthetic semantic evidence unavailable') 'semantic evidence unavailable is BLOCKED, not product FAIL'
    $DG009InvalidShapeCapture = [pscustomobject]@{ calls=0; input=$null }
    $DG009InvalidShape = Invoke-AcceptanceDecision $StaticDG009 (New-MessageBoundaryExtraction $DG009WrapperScenarios[0].transcript) $DG009Objective (Test-Deterministic $StaticDG009 $DG009WrapperScenarios[0].transcript 'same' 'same') {
        param($Context)
        $DG009InvalidShapeCapture.calls++
        $DG009InvalidShapeCapture.input = $Context.judge_input
        return @()
    } -SkipJudgeInputPersistence
    Add-Static 'DG009_WRAPPER_INVALID_JUDGE_SHAPE_ADAPTER_ONCE' ($DG009InvalidShapeCapture.calls -eq 1 -and $DG009InvalidShapeCapture.input -match 'upstream_blocker_explained') ('calls={0}' -f $DG009InvalidShapeCapture.calls)
    Add-Static 'DG009_WRAPPER_INVALID_JUDGE_SHAPE_BLOCKED' ($null -eq $DG009InvalidShape.judge -and $DG009InvalidShape.merge.result -eq 'BLOCKED') 'zero-output invalid Judge result shape is BLOCKED, not product FAIL'
    $NoSemanticCase = [pscustomobject]@{ case_id='STATIC-NO-SEMANTIC'; judge_semantic_requirements=@() }
    $NoSemanticCapture = [pscustomobject]@{ calls=0 }
    $NoSemanticDecision = Invoke-AcceptanceDecision $NoSemanticCase (New-MessageBoundaryExtraction 'Status: `BLOCKED`') $DG009Objective ([pscustomobject]@{result='PASS';hard_failures=@();failures=@();fact_work_assertions=@()}) { param($Context) $NoSemanticCapture.calls++; [pscustomobject]@{case_id=$Context.case_id;result='PASS'} } -SkipJudgeInputPersistence
    Add-Static 'DG009_WRAPPER_NON_APPLICABLE_NO_FABRICATED_SEMANTICS' ($NoSemanticCapture.calls -eq 0 -and $NoSemanticDecision.judge.result -eq 'NOT_REQUIRED' -and $NoSemanticDecision.merge.result -eq 'PASS') 'no J declaration does not call adapter or fabricate semantic evidence'
    foreach ($Scenario in @(
        [pscustomobject]@{name='STATE_RESULTING_LEDGER_INLINE';text='**Ledger event — Q-001:** ANSWERED. Decision result: launch. Resulting status: `ANSWERED`.';state='ANSWERED';pass=$true},
        [pscustomobject]@{name='STATE_CANONICAL_MULTILINE';text=('**Current status:**' + [Environment]::NewLine + [char]0x60 + 'BLOCKED' + [char]0x60);state='BLOCKED';pass=$true},
        [pscustomobject]@{name='STATE_STRUCTURED_STATE_FIRST';text='- `BLOCKED` — Legal approval is unavailable for the launch decision.';state='BLOCKED';pass=$true},
        [pscustomobject]@{name='STATE_STRUCTURED_DECISION_FIRST';text='- Hosting vendor — `BLOCKED`: certification remains unresolved.';state='BLOCKED';pass=$true},
        [pscustomobject]@{name='STATE_INCIDENTAL_REJECTED';text='The launch could be BLOCKED if legal approval is absent.';state='BLOCKED';pass=$false},
        [pscustomobject]@{name='STATE_NEGATION_REJECTED';text='Status: not BLOCKED';state='BLOCKED';pass=$false},
        [pscustomobject]@{name='STATE_FENCED_EXAMPLE_REJECTED';text=('```markdown' + [Environment]::NewLine + 'Status: BLOCKED' + [Environment]::NewLine + '```');state='BLOCKED';pass=$false}
    )) { $Actual=Test-ExplicitStateMarker $Scenario.text $Scenario.state; Add-Static $Scenario.name ($Actual -eq $Scenario.pass) "actual=$Actual" }
    foreach ($Scenario in @(
        [pscustomobject]@{name='STATE_DECISION_ID_UNWRAPPED_POSITIVE';text='- D-001 Hosting vendor — BLOCKED: certification remains unresolved.';pass=$true},
        [pscustomobject]@{name='STATE_DECISION_ID_CODE_WRAPPED_POSITIVE';text='- `D-001` Hosting vendor — `BLOCKED`: certification remains unresolved.';pass=$true},
        [pscustomobject]@{name='STATE_DECISION_ID_INLINE_STATE_POSITIVE';text='- D-001 Hosting vendor — `BLOCKED`: certification remains unresolved.';pass=$true},
        [pscustomobject]@{name='STATE_DECISION_ID_PROSE_REJECTED';text='The `D-001` Hosting vendor decision is BLOCKED.';pass=$false},
        [pscustomobject]@{name='STATE_DECISION_ID_FENCED_REJECTED';text=('```markdown' + [Environment]::NewLine + '- `D-001` Hosting vendor — `BLOCKED`:' + [Environment]::NewLine + '```');pass=$false},
        [pscustomobject]@{name='STATE_DECISION_ID_MALFORMED_BACKTICK_REJECTED';text='- `D-001 Hosting vendor — `BLOCKED`:';pass=$false},
        [pscustomobject]@{name='STATE_DECISION_ID_WRONG_SHAPE_REJECTED';text='- `X-001` Hosting vendor — `BLOCKED`:';pass=$false},
        [pscustomobject]@{name='STATE_DECISION_ID_CROSS_RECORD_REJECTED';text=('- `D-001` Hosting vendor —' + [Environment]::NewLine + '`BLOCKED`: certification remains unresolved.');pass=$false}
    )) { $Actual=Test-ExplicitStateMarker $Scenario.text 'BLOCKED'; Add-Static $Scenario.name ($Actual -eq $Scenario.pass) "actual=$Actual" }
    $DG015 = $Cases | Where-Object case_id -eq 'DG-015'
    $ValidExtraction = [pscustomobject]@{ transcript='message'; final_agent_message='message' }
    function Invoke-StaticJudgeScenario([object]$Scenario) {
        $MockState = [pscustomobject]@{ call_count=0 }
        $MockInvoker = {
            param($JudgeContext)
            $MockState.call_count++
            if ($Scenario.mock_throws) { throw 'synthetic Judge invoker failure' }
            [pscustomobject]@{ case_id=$JudgeContext.case_id; result='PASS'; confidence=1; satisfied_conditions=@('synthetic judge result'); violated_conditions=@(); evidence=@('synthetic judge evidence'); review_required=$false; marker='mock-valid-result' }
        }
        $Arguments = @{ Case=$DG015; Extraction=$Scenario.extraction; ObjectiveEvidence=$Scenario.evidence; JudgeInvoker=$MockInvoker; SkipJudgeInputPersistence=$true }
        if ($null -ne $Scenario.judge_input_override) { $Arguments.JudgeInputOverride = $Scenario.judge_input_override }
        $Judge = Invoke-JudgeWithEvidenceGate @Arguments
        $ExpectedResult = if ($Scenario.blocked) { 'BLOCKED' } else { 'PASS' }
        $ExpectedCalls = $Scenario.expected_calls
        $Propagated = -not $Scenario.blocked -and $Judge.marker -eq 'mock-valid-result'
        $JudgeReason = Get-OptionalString $Judge 'reason'
        $ExceptionHandled = $Scenario.mock_throws -and $Judge.result -eq 'BLOCKED' -and $JudgeReason -eq 'synthetic Judge invoker failure'
        $AdditionalAssertion = if ($Scenario.mock_throws) { $ExceptionHandled } elseif ($Scenario.blocked) { $true } else { $Propagated }
        $Passed = $Judge.result -eq $ExpectedResult -and $MockState.call_count -eq $ExpectedCalls -and $AdditionalAssertion
        Add-Static "Judge wrapper $($Scenario.name)" $Passed ("result={0}; call_count={1}; missing={2}; reason={3}" -f $Judge.result,$MockState.call_count,($Judge.violated_conditions -join ','),$JudgeReason)
    }
    $InvalidTranscript = "message$([char]0xFFFD)"
    $JudgeScenarios = @(
        [pscustomobject]@{name='complete evidence'; extraction=$ValidExtraction; evidence=(New-JudgeEvidence 'same' 'same' $null $null $true); judge_input_override=$null; blocked=$false; expected_calls=1; mock_throws=$false},
        [pscustomobject]@{name='transcript missing'; extraction=[pscustomobject]@{transcript='';final_agent_message=''}; evidence=(New-JudgeEvidence 'same' 'same' $null $null $true); judge_input_override=$null; blocked=$true; expected_calls=0; mock_throws=$false},
        [pscustomobject]@{name='before digest missing'; extraction=$ValidExtraction; evidence=(New-JudgeEvidence '' 'after' $null $null $true); judge_input_override=$null; blocked=$true; expected_calls=0; mock_throws=$false},
        [pscustomobject]@{name='after digest missing'; extraction=$ValidExtraction; evidence=(New-JudgeEvidence 'before' '' $null $null $true); judge_input_override=$null; blocked=$true; expected_calls=0; mock_throws=$false},
        [pscustomobject]@{name='digest comparison unavailable'; extraction=$ValidExtraction; evidence=(New-JudgeEvidence 'before' 'after' $null $null $false); judge_input_override=$null; blocked=$true; expected_calls=0; mock_throws=$false},
        [pscustomobject]@{name='Judge input digest evidence missing'; extraction=$ValidExtraction; evidence=(New-JudgeEvidence 'same' 'same' $null $null $true); judge_input_override=("TRANSCRIPT:$([Environment]::NewLine)message"); blocked=$true; expected_calls=0; mock_throws=$false},
        [pscustomobject]@{name='UTF-8 integrity invalid'; extraction=[pscustomobject]@{transcript=$InvalidTranscript;final_agent_message=$InvalidTranscript}; evidence=(New-JudgeEvidence 'same' 'same' $null $null $true); judge_input_override=$null; blocked=$true; expected_calls=0; mock_throws=$false},
        [pscustomobject]@{name='mock exception handling'; extraction=$ValidExtraction; evidence=(New-JudgeEvidence 'same' 'same' $null $null $true); judge_input_override=$null; blocked=$true; expected_calls=1; mock_throws=$true}
    )
    foreach ($Scenario in $JudgeScenarios) { Invoke-StaticJudgeScenario $Scenario }
    # K2: production DG-003 question-scoped matrix, always using the catalog declaration.
    $DG003 = $Cases | Where-Object case_id -eq 'DG-003'
    function New-StaticQuestion([string]$Body, [bool]$Recommendation = $true, [bool]$Heading = $true) {
        $Prefix = if ($Heading) { "### Q-001 — [IMPORTANT]`n" } else { '' }
        $RecommendationText = if ($Recommendation) { "`n**Recommended answer:** Enable it." } else { '' }
        return $Prefix + "**Question:**`n" + $Body + $RecommendationText
    }
    $Dg003ChineseQuestion =
        (-join @(
            [char]0x662F
            [char]0x5426
            [char]0x555F
            [char]0x7528
        )) +
        ' SMS ' +
        (-join @(
            [char]0x4E8B
            [char]0x4EF6
            [char]0x544A
            [char]0x8B66
            [char]0xFF1F
        ))
    $Dg003MixedNormalizedQuestion =
        '  sms' +
        [char]0x3000 +
        (-join @(
            [char]0x4E8B
            [char]0x4EF6
        )) +
        '  ' +
        (-join @(
            [char]0x8B66
            [char]0x793A
            [char]0xFF1F
        )) +
        ' '
    $DG003Scenarios = @(
        [pscustomobject]@{name='DG003_ENGLISH_POSITIVE';text=(New-StaticQuestion 'Should SMS event alerts be enabled?');pass=$true},
        [pscustomobject]@{name='DG003_ATTEMPT3_INCIDENT_POSITIVE';text=(New-StaticQuestion 'Should optional SMS incident alerts be enabled?');pass=$true},
        [pscustomobject]@{name='DG003_CHINESE_POSITIVE';text=(New-StaticQuestion $Dg003ChineseQuestion);pass=$true},
        [pscustomobject]@{name='DG003_MIXED_NORMALIZED_POSITIVE';text=(New-StaticQuestion $Dg003MixedNormalizedQuestion);pass=$true},
        [pscustomobject]@{name='DG003_SMS_ONLY_REJECTED';text=(New-StaticQuestion 'Should SMS be enabled?');pass=$false},
        [pscustomobject]@{name='DG003_ALERT_ONLY_REJECTED';text=(New-StaticQuestion 'Should event alerts be enabled?');pass=$false},
        [pscustomobject]@{name='DG003_MISSING_SMS_REJECTED';text=(New-StaticQuestion 'Should event alerts be enabled?');pass=$false},
        [pscustomobject]@{name='DG003_CROSS_Q_REJECTED';text=((New-StaticQuestion 'Should SMS be enabled?') + "`n### Q-002 — [IMPORTANT]`n**Question:** event alerts?`n**Recommended answer:** yes");pass=$false},
        [pscustomobject]@{name='DG003_SUMMARY_ONLY_REJECTED';text='Summary: SMS event alerts.';pass=$false},
        [pscustomobject]@{name='DG003_LEDGER_ONLY_REJECTED';text='- Status: SMS event alerts';pass=$false},
        [pscustomobject]@{name='DG003_NON_QUESTION_REJECTED';text='SMS event alerts are enabled.';pass=$false},
        [pscustomobject]@{name='DG003_MISSING_RECOMMENDATION_REJECTED';text=(New-StaticQuestion 'Should SMS event alerts be enabled?' $false);pass=$false},
        [pscustomobject]@{name='DG003_MISSING_Q_HEADING_REJECTED';text=(New-StaticQuestion 'Should SMS event alerts be enabled?' $true $false);pass=$false},
        [pscustomobject]@{name='DG003_LATIN_SUBSTRING_REJECTED';text=(New-StaticQuestion 'Should SMStone event alerting be enabled?');pass=$false}
    )
    foreach ($Scenario in $DG003Scenarios) {
        $Actual = Test-SendCondition $DG003 $Scenario.text 1
        $Scoped = Test-QuestionScopedCondition (Get-IndexedInputRequirement $DG003 1) $Scenario.text
        $ExpectedOutcome = if ($Scenario.pass) { 'SEND' } else { 'BLOCKED' }

        $ScopedEvidence = @(Get-OptionalArray $Scoped 'evidence')
        $EvidenceCount = @($ScopedEvidence | ForEach-Object { $_ }).Length
        $ScopedQIds = @(
            foreach ($EvidenceItem in $ScopedEvidence) {
                $EvidenceQId = Get-OptionalString $EvidenceItem 'q_id'
                if (-not [string]::IsNullOrWhiteSpace($EvidenceQId)) {
                    $EvidenceQId
                }
            }
        )

        $AssertionPassed =
            ($Actual.result -eq $ExpectedOutcome) -and
            ($Scoped.passed -eq $Scenario.pass)

        $AssertionDetail =
            'result={0}; q={1}; evidence={2}' -f
            $Actual.result,
            ($ScopedQIds -join ','),
            $EvidenceCount

        Add-Static $Scenario.name $AssertionPassed $AssertionDetail
    }
    $Dg003UnicodeExpected =
        (-join @(
            [char]0x662F
            [char]0x5426
            [char]0x555F
            [char]0x7528
        )) +
        ' SMS ' +
        (-join @(
            [char]0x4E8B
            [char]0x4EF6
            [char]0x544A
            [char]0x8B66
            [char]0xFF1F
        ))
    $Dg003UnicodeScoped = Test-QuestionScopedCondition (Get-IndexedInputRequirement $DG003 1) (New-StaticQuestion $Dg003ChineseQuestion)
    $Dg003MixedScoped = Test-QuestionScopedCondition (Get-IndexedInputRequirement $DG003 1) (New-StaticQuestion $Dg003MixedNormalizedQuestion)
    Add-Static 'DG003_UNICODE_FIDELITY' ($Dg003ChineseQuestion -ceq $Dg003UnicodeExpected -and $Dg003ChineseQuestion.IndexOf([char]0xFF1F) -ge 0 -and $Dg003MixedNormalizedQuestion.IndexOf([char]0x3000) -ge 0 -and $Dg003MixedNormalizedQuestion.IndexOf([char]0xFF1F) -ge 0 -and $Dg003UnicodeScoped.passed -and $Dg003MixedScoped.passed) 'Chinese SMS event-alert question, U+3000, and U+FF1F use production question-scoped evaluation'
    # K2 production typed Judge plumbing and gate checks.
    $DG007 = $Cases | Where-Object case_id -eq 'DG-007'
    $TypedTranscript = @(
        'Fact/work status: `RESEARCH_REQUIRED`'
        'Affected decision: Aurora''s release decision'
        'Paired decision state: `BLOCKED`'
    ) -join [Environment]::NewLine
    $TypedDeterministic = Test-Deterministic $DG007 $TypedTranscript 'same' 'same'
    function New-StaticFactWorkRecord([string]$Decision, [string]$Status = 'RESEARCH_REQUIRED', [string]$PairedState = 'BLOCKED') {
        return @(
            ('Fact/work status: `{0}`' -f $Status)
            ('Affected decision: {0}' -f $Decision)
            ('Paired decision state: `{0}`' -f $PairedState)
        ) -join [Environment]::NewLine
    }
    $DG007TypedScenarios = @(
        [pscustomobject]@{name='DG007_ASCII_CANONICAL_DECISION_POSITIVE';text=(New-StaticFactWorkRecord "Aurora's release decision");pass=$true},
        [pscustomobject]@{name='DG007_CURLY_CANONICAL_DECISION_POSITIVE';text=(New-StaticFactWorkRecord ('Aurora' + [char]0x2019 + 's release decision'));pass=$true},
        [pscustomobject]@{name='DG007_ATTEMPT5_AUTHORIZATION_POSITIVE';text=(New-StaticFactWorkRecord 'Aurora release authorization');pass=$true},
        [pscustomobject]@{name='DG007_ATTEMPT6_APPROVAL_POSITIVE';text=(New-StaticFactWorkRecord 'Aurora release approval');pass=$true},
        [pscustomobject]@{name='DG007_COMPLIANCE_APPROVAL_POSITIVE';text=(New-StaticFactWorkRecord 'Aurora release compliance approval');pass=$true},
        [pscustomobject]@{name='DG007_BARE_RELEASE_POSITIVE';text=(New-StaticFactWorkRecord 'Aurora release');pass=$true},
        [pscustomobject]@{name='DG007_MARKDOWN_FIELD_NORMALIZATION_POSITIVE';text=(('Fact/work status: **RESEARCH_REQUIRED**' + [Environment]::NewLine + 'Affected decision: **Aurora release approval**' + [Environment]::NewLine + 'Paired decision state: **BLOCKED**'));pass=$true},
        [pscustomobject]@{name='DG007_CASE_WHITESPACE_NORMALIZATION_POSITIVE';text=(New-StaticFactWorkRecord 'aUrOrA''s   RELEASE   decision');pass=$true},
        [pscustomobject]@{name='DG007_COMPLIANCE_REQUIREMENT_REJECTED';text=(New-StaticFactWorkRecord 'Aurora release compliance requirement');pass=$false},
        [pscustomobject]@{name='DG007_RELEASE_REQUIREMENT_REJECTED';text=(New-StaticFactWorkRecord 'Aurora release requirement');pass=$false},
        [pscustomobject]@{name='DG007_RELEASE_FACT_REJECTED';text=(New-StaticFactWorkRecord 'Aurora release fact');pass=$false},
        [pscustomobject]@{name='DG007_RELEASE_READINESS_REJECTED';text=(New-StaticFactWorkRecord 'Aurora release readiness');pass=$false},
        [pscustomobject]@{name='DG007_RELEASE_RESEARCH_REJECTED';text=(New-StaticFactWorkRecord 'Aurora release research');pass=$false},
        [pscustomobject]@{name='DG007_APPROVAL_PROCESS_REJECTED';text=(New-StaticFactWorkRecord 'Aurora release approval process');pass=$false},
        [pscustomobject]@{name='DG007_AUTHORIZATION_WITHOUT_IDENTITY_REJECTED';text=(New-StaticFactWorkRecord 'release authorization');pass=$false},
        [pscustomobject]@{name='DG007_CROSS_RECORD_REJECTED';text=(('Fact/work status: `RESEARCH_REQUIRED`' + [Environment]::NewLine + 'Affected decision: Aurora''s release decision' + [Environment]::NewLine + [Environment]::NewLine + 'Paired decision state: `BLOCKED`'));pass=$false},
        [pscustomobject]@{name='DG007_EMPTY_AFFECTED_FIELD_REJECTED';text=(('Fact/work status: `RESEARCH_REQUIRED`' + [Environment]::NewLine + 'Affected decision:' + [Environment]::NewLine + 'Paired decision state: `BLOCKED`'));pass=$false},
        [pscustomobject]@{name='DG007_MISSING_RESEARCH_STATUS_REJECTED';text=(('Affected decision: Aurora''s release decision' + [Environment]::NewLine + 'Paired decision state: `BLOCKED`'));pass=$false},
        [pscustomobject]@{name='DG007_MISSING_BLOCKED_REJECTED';text=(('Fact/work status: `RESEARCH_REQUIRED`' + [Environment]::NewLine + 'Affected decision: Aurora''s release decision'));pass=$false},
        [pscustomobject]@{name='DG007_WRONG_PAIRED_STATE_REJECTED';text=(New-StaticFactWorkRecord "Aurora's release decision" 'RESEARCH_REQUIRED' 'OPEN');pass=$false},
        [pscustomobject]@{name='DG007_RESEARCH_AS_DECISION_STATE_REJECTED';text=(('Decision state: `RESEARCH_REQUIRED`' + [Environment]::NewLine + 'Affected decision: Aurora''s release decision' + [Environment]::NewLine + 'Paired decision state: `BLOCKED`'));pass=$false},
        [pscustomobject]@{name='DG007_INCIDENTAL_PROSE_REJECTED';text='The sample says Fact/work status: `RESEARCH_REQUIRED`; Affected decision: Aurora''s release decision; Paired decision state: `BLOCKED`.';pass=$false},
        [pscustomobject]@{name='DG007_FENCED_RECORD_REJECTED';text=('```markdown' + [Environment]::NewLine + (New-StaticFactWorkRecord "Aurora's release decision") + [Environment]::NewLine + '```');pass=$false},
        [pscustomobject]@{name='DG007_NEGATED_RECORD_REJECTED';text=(('Do not record Fact/work status: `RESEARCH_REQUIRED`' + [Environment]::NewLine + 'Affected decision: Aurora''s release decision' + [Environment]::NewLine + 'Paired decision state: `BLOCKED`'));pass=$false},
        [pscustomobject]@{name='DG007_PARTIAL_DECISION_SURFACE_REJECTED';text=(New-StaticFactWorkRecord 'Aurora''s release');pass=$false}
    )
    foreach ($Scenario in $DG007TypedScenarios) {
        $Deterministic = Test-Deterministic $DG007 $Scenario.text 'same' 'same'
        $Evidence = @($Deterministic.fact_work_assertions)
        $EvidenceItem = if ($Evidence.Length -eq 1) { $Evidence[0] } else { $null }
        $Actual = $Deterministic.result -eq 'PASS'
        $TypedEvidenceMatches = $null -ne $EvidenceItem -and (($Scenario.pass -and $EvidenceItem.passed -eq $true -and $null -ne $EvidenceItem.matched_record -and $EvidenceItem.actual_status -is [string] -and $EvidenceItem.actual_affected_decision -is [string] -and $EvidenceItem.actual_paired_state -is [string] -and $EvidenceItem.record_index -eq 0) -or ((-not $Scenario.pass) -and $EvidenceItem.passed -eq $false -and $null -eq $EvidenceItem.matched_record))
        Add-Static $Scenario.name (($Actual -eq $Scenario.pass) -and $TypedEvidenceMatches) ("result={0}; typed_passed={1}; matched={2}; affected={3}" -f $Deterministic.result,$EvidenceItem.passed,($null -ne $EvidenceItem.matched_record),$EvidenceItem.actual_affected_decision)
    }
    $TypedExtraction = [pscustomobject]@{transcript=$TypedTranscript;final_agent_message=$TypedTranscript}
    $TypedObjective = New-JudgeEvidence 'same' 'same' $null $null $true
    $script:K2JudgeCalls = 0; $script:K2JudgeInput = $null
    $TypedJudge = Invoke-JudgeWithEvidenceGate -Case $DG007 -Extraction $TypedExtraction -ObjectiveEvidence $TypedObjective -DeterministicEvidence $TypedDeterministic -SkipJudgeInputPersistence -JudgeInvoker { param($Context) $script:K2JudgeCalls++; $script:K2JudgeInput=$Context.judge_input; [pscustomobject]@{case_id=$Context.case_id;result='PASS';confidence=1;satisfied_conditions=@();violated_conditions=@();evidence=@();review_required=$false} }
    $TypedPassAssertions = [ordered]@{
        'JUDGE_TYPED_PASS_ADAPTER_CALLED_ONCE'       = ($script:K2JudgeCalls -eq 1)
        'JUDGE_TYPED_PASS_SECTION_PRESENT'           = ($script:K2JudgeInput -match '"fact_work_assertions"\s*:')
        'JUDGE_TYPED_PASS_STATUS_PRESENT'            = ($script:K2JudgeInput -match 'RESEARCH_REQUIRED')
        'JUDGE_TYPED_PASS_AFFECTED_DECISION_PRESENT' = ($script:K2JudgeInput -match 'Aurora')
        'JUDGE_TYPED_PASS_PAIRED_STATE_PRESENT'      = ($script:K2JudgeInput -match 'BLOCKED')
        'JUDGE_TYPED_PASS_MATCHED_RECORD_PRESENT'    = ($script:K2JudgeInput -match '"matched_record"\s*:')
        'JUDGE_TYPED_PASS_BOOLEAN_PRESENT'           = ($script:K2JudgeInput -match '"passed"\s*:\s*true')
        'JUDGE_TYPED_PASS_UNICODE_PRESERVED'         = ($script:K2JudgeInput -match 'RESEARCH_REQUIRED')
    }
    foreach ($AssertionName in $TypedPassAssertions.Keys) {
        Add-Static $AssertionName ($TypedPassAssertions[$AssertionName] -eq $true) 'captured production Judge input'
    }
    function Invoke-StaticTypedFailScenario([object]$Scenario) {
        $Deterministic = Test-Deterministic $DG007 $Scenario.transcript 'same' 'same'
        $Capture = [pscustomobject]@{calls=0;input=$null}
        $Judge = Invoke-JudgeWithEvidenceGate -Case $DG007 -Extraction ([pscustomobject]@{transcript=$Scenario.transcript;final_agent_message=$Scenario.transcript}) -ObjectiveEvidence $TypedObjective -DeterministicEvidence $Deterministic -SkipJudgeInputPersistence -JudgeInvoker { param($Context) $Capture.calls++; $Capture.input=$Context.judge_input; [pscustomobject]@{case_id=$Context.case_id;result='PASS';confidence=1;satisfied_conditions=@();violated_conditions=@();evidence=@();review_required=$false} }
        $EvidenceItems = @($Deterministic.fact_work_assertions)
        $EvidenceItem = if ($EvidenceItems.Length -eq 1) { $EvidenceItems[0] } else { $null }
        $MergedResult = if ($Judge.result -eq 'BLOCKED') { 'BLOCKED' } elseif ($Deterministic.result -eq 'FAIL') { 'FAIL' } elseif ($Judge.result -ne $Deterministic.result) { 'BLOCKED' } else { $Judge.result }
        $Passed = $Deterministic.result -eq 'FAIL' -and $EvidenceItems.Length -eq 1 -and $null -ne $EvidenceItem -and $EvidenceItem.passed -eq $false -and -not [string]::IsNullOrWhiteSpace([string]$EvidenceItem.expected_status) -and -not [string]::IsNullOrWhiteSpace([string]$EvidenceItem.expected_paired_state) -and $null -eq $EvidenceItem.matched_record -and @($Deterministic.failures).Length -gt 0 -and $Capture.calls -eq 1 -and $Judge.result -eq 'PASS' -and $MergedResult -eq 'FAIL' -and $Capture.input -match '"fact_work_assertions"\s*:' -and $Capture.input -match '"passed"\s*:\s*false'
        Add-Static $Scenario.name $Passed ("deterministic={0}; adapter_calls={1}; judge={2}; merged={3}; failures={4}" -f $Deterministic.result,$Capture.calls,$Judge.result,$MergedResult,(@($Deterministic.failures) -join '|'))
    }
    $TypedFailScenarios = @(
        [pscustomobject]@{name='JUDGE_TYPED_FAIL_MISSING_STATUS';transcript=('Affected decision: Aurora''s release decision' + [Environment]::NewLine + 'Paired decision state: `BLOCKED`')},
        [pscustomobject]@{name='JUDGE_TYPED_FAIL_WRONG_DECISION';transcript=('Fact/work status: `RESEARCH_REQUIRED`' + [Environment]::NewLine + 'Affected decision: Nebula''s release decision' + [Environment]::NewLine + 'Paired decision state: `BLOCKED`')},
        [pscustomobject]@{name='JUDGE_TYPED_FAIL_WRONG_PAIRED_STATE';transcript=('Fact/work status: `RESEARCH_REQUIRED`' + [Environment]::NewLine + 'Affected decision: Aurora''s release decision' + [Environment]::NewLine + 'Paired decision state: `OPEN`')}
    )
    foreach ($Scenario in $TypedFailScenarios) { Invoke-StaticTypedFailScenario $Scenario }
    $DG007FactWorkDeclaration = @(Get-OptionalArray $DG007 'required_fact_work_assertions')[0]
    $StaticTypedEvidenceItem = [pscustomobject]@{assertion_type='fact_work';expected_status='RESEARCH_REQUIRED';affected_decision_pattern=(Get-OptionalString $DG007FactWorkDeclaration 'affected_decision_pattern');expected_paired_state='BLOCKED';matched_record='Aurora''s release decision: BLOCKED';passed=$true}
    function Invoke-StaticTypedGateScenario([object]$Scenario) {
        $Capture = [pscustomobject]@{calls=0}
        $Arguments = @{ Case=$DG007; Extraction=$TypedExtraction; ObjectiveEvidence=$TypedObjective; DeterministicEvidence=$Scenario.deterministic; SkipJudgeInputPersistence=$true; JudgeInvoker={ param($Context) $Capture.calls++; [pscustomobject]@{case_id=$Context.case_id;result='PASS';confidence=1;satisfied_conditions=@();violated_conditions=@();evidence=@();review_required=$false} } }
        if ($null -ne $Scenario.judge_input_override) { $Arguments.JudgeInputOverride=$Scenario.judge_input_override }
        $Gate = Invoke-JudgeWithEvidenceGate @Arguments
        $Passed = $Gate.result -eq 'BLOCKED' -and $Gate.judge_not_executed -eq $true -and $Gate.reason -eq 'RUNNER_CONTRACT_FAILURE' -and $Capture.calls -eq 0 -and @($Gate.violated_conditions) -contains 'FACT_WORK_TYPED_EVIDENCE_INVALID' -and @($Gate.violated_conditions) -contains $Scenario.subtype -and (Get-OptionalString $Gate 'typed_evidence_failure') -eq $Scenario.subtype
        Add-Static $Scenario.name $Passed ("result={0}; calls={1}; reason={2}; subtype={3}" -f $Gate.result,$Capture.calls,$Gate.reason,(Get-OptionalString $Gate 'typed_evidence_failure'))
    }
    $StaticEmptyTypedEvidence = [System.Collections.Generic.List[object]]::new()
    $StaticNullTypedEvidence = [System.Collections.Generic.List[object]]::new()
    [void]$StaticNullTypedEvidence.Add($null)
    $TypedGateScenarios = @(
        [pscustomobject]@{name='JUDGE_GATE_MISSING_EVIDENCE';subtype='MISSING_EVIDENCE';deterministic=[pscustomobject]@{result='FAIL';failures=@()};judge_input_override=$null},
        [pscustomobject]@{name='JUDGE_GATE_COUNT_LOW';subtype='COUNT_LOW';deterministic=[pscustomobject]@{result='FAIL';failures=@();fact_work_assertions=$StaticEmptyTypedEvidence};judge_input_override=$null},
        [pscustomobject]@{name='JUDGE_GATE_COUNT_HIGH';subtype='COUNT_HIGH';deterministic=[pscustomobject]@{result='FAIL';failures=@();fact_work_assertions=@($StaticTypedEvidenceItem,$StaticTypedEvidenceItem)};judge_input_override=$null},
        [pscustomobject]@{name='JUDGE_GATE_NULL_ITEM';subtype='NULL_ITEM';deterministic=[pscustomobject]@{result='FAIL';failures=@();fact_work_assertions=$StaticNullTypedEvidence};judge_input_override=$null},
        [pscustomobject]@{name='JUDGE_GATE_MISSING_FIELD';subtype='MISSING_FIELD';deterministic=[pscustomobject]@{result='FAIL';failures=@();fact_work_assertions=@([pscustomobject]@{expected_paired_state='BLOCKED';passed=$false})};judge_input_override=$null},
        [pscustomobject]@{name='JUDGE_GATE_NON_BOOLEAN_PASSED';subtype='NON_BOOLEAN_PASSED';deterministic=[pscustomobject]@{result='FAIL';failures=@();fact_work_assertions=@([pscustomobject]@{expected_status='RESEARCH_REQUIRED';expected_paired_state='BLOCKED';passed='false'})};judge_input_override=$null},
        [pscustomobject]@{name='JUDGE_GATE_MALFORMED_NESTED_EVIDENCE';subtype='MALFORMED_NESTED_EVIDENCE';deterministic=[pscustomobject]@{result='FAIL';failures=@();fact_work_assertions='not-a-collection'};judge_input_override=$null},
        [pscustomobject]@{name='JUDGE_GATE_SERIALIZATION_LOSS';subtype='SERIALIZATION_LOSS';deterministic=[pscustomobject]@{result='FAIL';failures=@();fact_work_assertions=@($StaticTypedEvidenceItem)};judge_input_override='TRANSCRIPT: serialization probe'}
    )
    foreach ($Scenario in $TypedGateScenarios) { Invoke-StaticTypedGateScenario $Scenario }
    $NonApplicableCase = $Cases | Where-Object case_id -eq 'DG-005'
    $NonApplicableTranscript = 'Status: `BLOCKED`'
    $NonApplicableDeterministic = Test-Deterministic $NonApplicableCase $NonApplicableTranscript 'same' 'same'
    $NonApplicableCapture = [pscustomobject]@{calls=0;input=$null}
    $NonApplicableJudge = Invoke-JudgeWithEvidenceGate -Case $NonApplicableCase -Extraction ([pscustomobject]@{transcript=$NonApplicableTranscript;final_agent_message=$NonApplicableTranscript}) -ObjectiveEvidence $TypedObjective -DeterministicEvidence $NonApplicableDeterministic -SkipJudgeInputPersistence -JudgeInvoker { param($Context) $NonApplicableCapture.calls++; $NonApplicableCapture.input=$Context.judge_input; [pscustomobject]@{case_id=$Context.case_id;result='PASS';confidence=1;satisfied_conditions=@();violated_conditions=@();evidence=@();review_required=$false} }
    Add-Static 'JUDGE_TYPED_NON_APPLICABLE_CASE' (-not (Test-ObjectProperty $NonApplicableCase 'required_fact_work_assertions') -and @($NonApplicableDeterministic.fact_work_assertions).Length -eq 0 -and $NonApplicableCapture.calls -eq 1 -and $NonApplicableJudge.result -eq 'PASS' -and $NonApplicableCapture.input -match 'DETERMINISTIC EVIDENCE:') 'non-applicable catalog case reaches Judge without fabricated fact/work evidence'
    $DG017 = $Cases | Where-Object case_id -eq 'DG-017'
    function New-StaticObjectiveEvidence([object]$Before, [object]$After) {
        New-JudgeEvidence 'before-digest' 'after-digest' $Before $After
    }
    $InventoryBefore = [pscustomobject]@{available=$true;inventory_mode='metadata-only; file contents are not read or saved';metadata_digest='same';global_decision_grill_present=$true;global_grill_me_present=$true}
    $InventoryAfterSame = [pscustomobject]@{available=$true;inventory_mode='metadata-only; file contents are not read or saved';metadata_digest='same';global_decision_grill_present=$true;global_grill_me_present=$true}
    $InventoryAfterChanged = [pscustomobject]@{available=$true;inventory_mode='metadata-only; file contents are not read or saved';metadata_digest='changed';global_decision_grill_present=$true;global_grill_me_present=$true}
    $InventoryBeforeNoMetadata = [pscustomobject]@{available=$true;metadata_digest='same';global_decision_grill_present=$true;global_grill_me_present=$true}
    $InventoryAfterNoMetadata = [pscustomobject]@{available=$true;inventory_mode='full-content';metadata_digest='same';global_decision_grill_present=$true;global_grill_me_present=$true}
    $ObjectiveTests = @(
        [pscustomobject]@{name='before and after available, unchanged, metadata-only'; evidence=(New-StaticObjectiveEvidence $InventoryBefore $InventoryAfterSame); passed=$true},
        [pscustomobject]@{name='before missing'; evidence=(New-StaticObjectiveEvidence $null $InventoryAfterSame); passed=$false},
        [pscustomobject]@{name='after missing'; evidence=(New-StaticObjectiveEvidence $InventoryBefore $null); passed=$false},
        [pscustomobject]@{name='inventory changed'; evidence=(New-StaticObjectiveEvidence $InventoryBefore $InventoryAfterChanged); passed=$false},
        [pscustomobject]@{name='metadata-only missing or false'; evidence=@((New-StaticObjectiveEvidence $InventoryBeforeNoMetadata $InventoryAfterSame), (New-StaticObjectiveEvidence $InventoryBefore $InventoryAfterNoMetadata)); passed=$false}
    )
    foreach ($Scenario in $ObjectiveTests) { $Gates = @($Scenario.evidence | ForEach-Object { Test-ObjectiveEvidenceRequirements $DG017 $_ }); $Actual = @($Gates | Where-Object passed).Count -eq $Gates.Count; Add-Static "DG-017 $($Scenario.name)" ($Actual -eq $Scenario.passed) ((@($Gates | ForEach-Object { $_.missing -join ',' }) -join ';')) }
    $Multi=@($Cases|Where-Object {@(Get-OptionalArray $_ 'ordered_subsequent_inputs').Length -gt 0});$Audit=@($Multi|ForEach-Object {$CaseUnderAudit=$_;$R=@(Get-OptionalArray $CaseUnderAudit 'send_condition_requirements');$I=@($R|ForEach-Object {Get-OptionalObject $_ 'input_index'});$InputCount=@(Get-OptionalArray $CaseUnderAudit 'ordered_subsequent_inputs').Length;$R.Length -eq $InputCount -and $I.Length -eq @($I|Select-Object -Unique).Length -and @($I|Where-Object {$_ -lt 1 -or $_ -gt $InputCount}).Length -eq 0});Add-Static '14-case requirements audit' ($Audit.Length -eq 14 -and -not ($Audit -contains $false)) 'indexed one-to-one'
    $FixtureCatalog = @($Cases | ForEach-Object { [pscustomobject]@{ case_id=$_.case_id; fixtures=@(Get-OptionalArray $_ 'fixtures') } })
    $FixtureCase = $Cases | Where-Object case_id -eq 'DG-006'
    $ExpectedFixturePath = 'fixture-data/release-fact.txt'
    $ExpectedFixtureContent = 'Aurora pilot launch date: 2026-10-01'
    Add-Static 'all 20 cases own required fixtures' ($FixtureCatalog.Count -eq 20 -and @($FixtureCatalog | Where-Object { $_.fixtures.Count -lt 0 }).Count -eq 0 -and @($Cases | Where-Object { -not (Test-ObjectProperty $_ 'fixtures') }).Count -eq 0) 'fixtures property present for every case'
    Add-Static 'DG-006 exact declarative fixture' (@($FixtureCase.fixtures).Count -eq 1 -and $FixtureCase.fixtures[0].relative_path -eq $ExpectedFixturePath -and $FixtureCase.fixtures[0].content -ceq $ExpectedFixtureContent) 'one exact fixture declaration'
    Add-Static 'other 19 cases declare empty fixtures' (@($Cases | Where-Object { $_.case_id -ne 'DG-006' -and @(Get-OptionalArray $_ 'fixtures').Count -ne 0 }).Count -eq 0) 'empty arrays only'
    foreach ($Scenario in @(
        [pscustomobject]@{name='missing fixtures';case=[pscustomobject]@{case_id='STATIC-fixture'};token='fixtures'},
        [pscustomobject]@{name='non-array fixtures';case=[pscustomobject]@{case_id='STATIC-fixture';fixtures='invalid'};token='fixtures must be an array'},
        [pscustomobject]@{name='null fixtures';case=[pscustomobject]@{case_id='STATIC-fixture';fixtures=$null};token='fixtures must be an array'},
        [pscustomobject]@{name='missing relative_path';case=[pscustomobject]@{case_id='STATIC-fixture';fixtures=@([pscustomobject]@{content='x'})};token='relative_path'},
        [pscustomobject]@{name='blank relative_path';case=[pscustomobject]@{case_id='STATIC-fixture';fixtures=@([pscustomobject]@{relative_path=' ';content='x'})};token='relative_path'},
        [pscustomobject]@{name='missing content';case=[pscustomobject]@{case_id='STATIC-fixture';fixtures=@([pscustomobject]@{relative_path='a.txt'})};token='content'},
        [pscustomobject]@{name='non-string content';case=[pscustomobject]@{case_id='STATIC-fixture';fixtures=@([pscustomobject]@{relative_path='a.txt';content=1})};token='content'},
        [pscustomobject]@{name='unsupported fixture property';case=[pscustomobject]@{case_id='STATIC-fixture';fixtures=@([pscustomobject]@{relative_path='a.txt';content='x';unexpected='x'})};token='unsupported property'}
    )) { $Failures=@(Test-FixtureMetadata $Scenario.case); Add-Static "fixture metadata $($Scenario.name) rejected" (($Failures -join '; ') -match $Scenario.token) ($Failures -join '; ') }
    Add-Static '20-case prepare validation' (@($Cases|ForEach-Object {Test-CaseContract $_}|Where-Object {-not $_.passed}).Count -eq 0) 'case contracts'
    $Source=Read-Utf8NoBom $PSCommandPath;$CatalogToken='Get-Indexed'+'SendConditionRequirements';Add-Static 'runner catalog absent' (-not ($Source -match $CatalogToken)) 'no case-specific catalog';$EvaluatorSource=$Source.Substring($Source.IndexOf('function Test-SendCondition'),$Source.IndexOf('function Invoke-ConditionalInput')-$Source.IndexOf('function Test-SendCondition'));Add-Static 'generic evaluator has no DG-xxx branch' (-not ($EvaluatorSource -match 'DG-\d{3}|case_id')) 'no case-specific evaluator branch';$FixtureSource=$Source.Substring($Source.IndexOf('function Resolve-CaseFixtureTargets'),$Source.IndexOf('function Invoke-Preflight')-$Source.IndexOf('function Resolve-CaseFixtureTargets'));$InvokeCaseSource=$Source.Substring($Source.IndexOf('function Invoke-Case'),$Source.IndexOf('function Invoke-StaticTest')-$Source.IndexOf('function Invoke-Case'));Add-Static 'generic fixture processor has no case selection' (-not ($FixtureSource -match 'DG-\d{3}|case_id|switch\s*\(') -and -not ($InvokeCaseSource -match '(?is)(?:if|switch)\s*\(\s*\$CaseId.*?(?:fixture|initialize)')) 'fixture production functions are data-driven';Add-Static 'DG-017 metadata-only safety' (($Source -match 'metadata-only') -and -not ($Source -match 'Get-InventoryDigest \$GlobalSkills')) 'no Skill content hashing'
    $StaticSkillSource = Read-Utf8NoBom $SourceSkill
    Add-Static 'Source Skill mandatory accepted-result invariant' ($StaticSkillSource -match '(?is)When the response accepts.*?MUST first record.*?formal acceptance ledger event.*?MUST NOT ask another question.*?Coverage Scan.*?summary.*?end the session' -and $StaticSkillSource -match '(?is)Accept recommendation:.*?MUST be recorded before any next question.*?Coverage Scan.*?summary.*?session end' -and $StaticSkillSource -notmatch 'DG-\d{3}') 'generic mandatory post-input ordering without case labels'
    Add-Static 'Source Skill accepted provisional decision invariant' ($StaticSkillSource -match '(?is)When the user accepts, selects, or says to use a provisional option.*?complete provisional decision.*?Status: PROVISIONAL.*?Do not leave the status conditional.*?do not advance to another question' -and $StaticSkillSource -notmatch 'DG-\d{3}') 'generic accepted provisional-decision record without case labels'
    Add-Static 'Source Skill formal supersession lifecycle invariant' ($StaticSkillSource -match 'Lifecycle: SUPERSEDED' -and $StaticSkillSource -match 'Do not put `SUPERSEDED` only in explanatory prose' -and $StaticSkillSource -notmatch 'DG-\d{3}') 'generic supersession output remains a labelled formal lifecycle record'
    $AggregationZero = [System.Collections.Generic.List[object]]::new()
    Add-CheckCollection $AggregationZero $null
    Add-Static 'production check aggregation handles null output' ($AggregationZero.Count -eq 0) 'null is no additional check'
    Add-CheckCollection $AggregationZero @()
    Add-Static 'production check aggregation handles zero checks' ($AggregationZero.Count -eq 0) 'empty collection preserves zero checks'
    $AggregationOne = [System.Collections.Generic.List[object]]::new()
    $AggregationOneCheck = [pscustomobject]@{ name='one'; passed=$true; detail='one' }
    Add-CheckCollection $AggregationOne @($AggregationOneCheck)
    Add-Static 'production check aggregation handles one check' ($AggregationOne.Count -eq 1 -and $AggregationOne[0] -eq $AggregationOneCheck) 'one check appended to typed List[object]'
    $AggregationMany = [System.Collections.Generic.List[object]]::new()
    $AggregationFirst = [pscustomobject]@{ name='first'; passed=$true; detail='first' }
    $AggregationSecond = [pscustomobject]@{ name='second'; passed=$false; detail='second' }
    $AggregationThird = [pscustomobject]@{ name='third'; passed=$true; detail='third' }
    Add-CheckCollection $AggregationMany @($AggregationFirst,$AggregationSecond,$AggregationThird)
    Add-Static 'production check aggregation preserves order' ($AggregationMany.Count -eq 3 -and $AggregationMany[0] -eq $AggregationFirst -and $AggregationMany[1] -eq $AggregationSecond -and $AggregationMany[2] -eq $AggregationThird) 'first, second, third'
    $MalformedChecks = [System.Collections.Generic.List[object]]::new()
    Add-CheckCollection $MalformedChecks @($null,[pscustomobject]@{name=' ';passed=$true;detail='x'},[pscustomobject]@{name='nonboolean';passed='true';detail='x'},[pscustomobject]@{branch='identity';head='identity'},@([pscustomobject]@{name='nested';passed=$true;detail='x'})) 'static malformed contract'
    Add-Static 'malformed preflight items become named internal checks' ($MalformedChecks.Count -eq 5 -and @($MalformedChecks | Where-Object { $_.name -like 'RUNNER_INTERNAL_ERROR:*' -and -not $_.passed }).Count -eq 5) 'null, blank, non-Boolean, identity, nested'
    $SyntheticModes = Test-SendConditionSynthetic $Cases
    Add-Static 'mode-aware synthetic gates use production evaluator outcomes' (@($SyntheticModes | Where-Object { -not $_.true_passed -or -not $_.false_passed }).Count -eq 0 -and @($SyntheticModes | Where-Object { $_.mode -eq 'conditional' -and $_.false_actual -ne 'SKIP' }).Count -eq 0) (($SyntheticModes | ForEach-Object { "$($_.case_id)/$($_.input_index) $($_.mode): false $($_.false_expected)/$($_.false_actual)" }) -join '; ')
    $StaticGitRoot = Join-Path 'D:\temp' ('decision-grill-static-git-' + [guid]::NewGuid().ToString('N'))
    $SavedExpectedBranch = $script:ExpectedBranch; $SavedExpectedHead = $script:ExpectedHead
    try {
        New-Item -ItemType Directory -Force -Path $StaticGitRoot | Out-Null
        [void](Invoke-GitText $StaticGitRoot @('init','-q'))
        [void](Invoke-GitText $StaticGitRoot @('config','user.email','decision-grill-static@example.invalid'))
        [void](Invoke-GitText $StaticGitRoot @('config','user.name','Decision Grill Static'))
        foreach ($Entry in @($AuthorizedDirtyWorkingTree | Where-Object { $_.xy -eq ' M' })) { $Path=Join-Path $StaticGitRoot ($Entry.path -replace '/','\\');New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path)|Out-Null;Write-Utf8NoBom $Path 'baseline' }
        [void](Invoke-GitText $StaticGitRoot @('add','.')); [void](Invoke-GitText $StaticGitRoot @('commit','-qm','baseline'))
        $script:ExpectedBranch = Invoke-GitText $StaticGitRoot @('branch','--show-current'); $script:ExpectedHead = Invoke-GitText $StaticGitRoot @('rev-parse','HEAD')
        $CleanIdentity = Get-WorkingTreeIdentity $StaticGitRoot
        Add-Static 'working-tree production clean baseline' (Test-WorkingTreeBaseline $CleanIdentity).passed 'clean identity accepted'
        foreach ($Entry in @($AuthorizedDirtyWorkingTree | Where-Object { $_.xy -eq ' M' })) { [IO.File]::AppendAllText((Join-Path $StaticGitRoot ($Entry.path -replace '/','\\')),'-dirty',$Utf8NoBom) }
        foreach ($Entry in @($AuthorizedDirtyWorkingTree | Where-Object { $_.xy -eq '??' })) { $Path=Join-Path $StaticGitRoot ($Entry.path -replace '/','\\');New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path)|Out-Null;Write-Utf8NoBom $Path 'untracked' }
        $DirtyIdentity = Get-WorkingTreeIdentity $StaticGitRoot
        Add-Static 'working-tree exact authorized dirty baseline including product spec' (Test-WorkingTreeBaseline $DirtyIdentity).passed 'all ten entries accepted'
        [IO.File]::AppendAllText((Join-Path $StaticGitRoot 'specs\SPEC-001-decision-grill-v0.1.md'),'-mutated',$Utf8NoBom)
        Add-Static 'working-tree tracked SHA mutation detected' (-not (Compare-WorkingTreeIdentity $DirtyIdentity (Get-WorkingTreeIdentity $StaticGitRoot)).passed) 'status remains M; raw SHA changes'
        $DirtyIdentity = Get-WorkingTreeIdentity $StaticGitRoot
        [IO.File]::AppendAllText((Join-Path $StaticGitRoot 'tests\automation\README.md'),'-mutated',$Utf8NoBom)
        Add-Static 'working-tree untracked SHA mutation detected' (-not (Compare-WorkingTreeIdentity $DirtyIdentity (Get-WorkingTreeIdentity $StaticGitRoot)).passed) 'status remains ??; raw SHA changes'
        Write-Utf8NoBom (Join-Path $StaticGitRoot 'extra.txt') 'extra'
        Add-Static 'working-tree extra path rejected' (-not (Test-WorkingTreeBaseline (Get-WorkingTreeIdentity $StaticGitRoot)).passed) 'extra untracked path'
        Remove-Item -LiteralPath (Join-Path $StaticGitRoot 'extra.txt') -Force
        Remove-Item -LiteralPath (Join-Path $StaticGitRoot 'tests\automation\decision-grill-result.schema.json') -Force
        Add-Static 'working-tree missing authorized path rejected' (-not (Test-WorkingTreeBaseline (Get-WorkingTreeIdentity $StaticGitRoot)).passed) 'partial dirty baseline'
        Write-Utf8NoBom (Join-Path $StaticGitRoot 'tests\automation\decision-grill-result.schema.json') 'untracked'
        [void](Invoke-GitText $StaticGitRoot @('add','docs/productivity/decision-grill.md'))
        Add-Static 'working-tree staged entry rejected' (-not (Test-WorkingTreeBaseline (Get-WorkingTreeIdentity $StaticGitRoot)).passed) 'staged status is not allowed'
        [void](Invoke-GitText $StaticGitRoot @('reset','-q','HEAD','--','docs/productivity/decision-grill.md'))
        $RawConflict = [Text.Encoding]::UTF8.GetBytes("UU docs/productivity/decision-grill.md`0")
        $ConflictEntry = (ConvertFrom-GitPorcelainV1Z $RawConflict $StaticGitRoot)[0]
        $SyntheticConflict = [pscustomobject]@{ repository=$StaticGitRoot; branch=$script:ExpectedBranch; head=$script:ExpectedHead; entries=@([pscustomobject]@{path=$ConflictEntry.path;xy=$ConflictEntry.xy;original_path=$null;exists=$true;item_type='file';length=1;sha256='A';path_chain_safe=$true}) }
        Add-Static 'working-tree conflict and invalid status rejected' (-not (Test-WorkingTreeBaseline $SyntheticConflict).passed) 'UU status rejected by production validator'
        $RawCollision = [Text.Encoding]::UTF8.GetBytes("?? tests/automation/README.md`0?? tests\\automation\\readme.md`0")
        $CollisionBlocked=$false;try{ConvertFrom-GitPorcelainV1Z $RawCollision $StaticGitRoot|Out-Null}catch{$CollisionBlocked=$true}
        Add-Static 'working-tree normalized path collision rejected' $CollisionBlocked 'case-insensitive normalized identity'
        $HeadChanged = ($DirtyIdentity | ConvertTo-Json -Depth 8 | ConvertFrom-Json); $HeadChanged.head='0000000000000000000000000000000000000000'
        Add-Static 'working-tree branch and HEAD identity mutation detected' (-not (Compare-WorkingTreeIdentity $DirtyIdentity $HeadChanged).passed) 'HEAD delta detected'
    } catch { Add-Static 'working-tree production identity scenarios available' $false $_.Exception.Message }
    finally { $script:ExpectedBranch=$SavedExpectedBranch; $script:ExpectedHead=$SavedExpectedHead; try { if(Test-Path -LiteralPath $StaticGitRoot){Remove-Item -LiteralPath $StaticGitRoot -Recurse -Force} } catch { Add-Static 'working-tree static git cleanup' $false $_.Exception.Message } }
    $StaticActiveFolder = Join-Path 'D:\temp' ('decision-grill-dg-final-' + (Get-Date -Format 'yyyyMMdd-HHmmssfff'))
    New-Item -ItemType Directory -Force -Path (Join-Path $StaticActiveFolder '.agents\skills\decision-grill') | Out-Null
    Copy-Item -LiteralPath $SourceSkill -Destination (Join-Path $StaticActiveFolder '.agents\skills\decision-grill\SKILL.md') -Force
    $StaticMarkerStamp = Get-Date -Format 'yyyyMMdd-HHmmssfff'
    $StaticFinal2Folder = Join-Path 'D:\temp' ('decision-grill-dg-final2-' + $StaticMarkerStamp)
    $StaticRetestFolder = Join-Path 'D:\temp' ('decision-grill-dg-retest-' + $StaticMarkerStamp)
    $StaticIsolationFolder = Join-Path 'D:\temp' ('decision-grill-dg-isolation-' + $StaticMarkerStamp)
    $StaticConfusingFolders = @(
        (Join-Path 'D:\temp' ('decision-grill-dg-prefinal2-' + $StaticMarkerStamp)),
        (Join-Path 'D:\temp' ('decision-grill-dg-final2evil-' + $StaticMarkerStamp)),
        (Join-Path 'D:\temp' ('decision-grill-dg-final20-' + $StaticMarkerStamp))
    )
    $StaticMarkerParent = Join-Path 'D:\temp' ('decision-grill-dg-final2-parent-' + $StaticMarkerStamp)
    $StaticInvalidMarkerLeaf = Join-Path $StaticMarkerParent 'not-a-decision-grill-isolation-folder'
    New-Item -ItemType Directory -Force -Path (@($StaticFinal2Folder,$StaticRetestFolder,$StaticIsolationFolder) + @($StaticConfusingFolders) + @($StaticInvalidMarkerLeaf)) | Out-Null
    $ActiveFolderChecks = @(
        [pscustomobject]@{ name='explicit valid ActiveFolder'; value=$StaticActiveFolder; expected=$true },
        [pscustomobject]@{ name='exact final2 ActiveFolder'; value=$StaticFinal2Folder; expected=$true },
        [pscustomobject]@{ name='existing retest ActiveFolder'; value=$StaticRetestFolder; expected=$true },
        [pscustomobject]@{ name='existing isolation ActiveFolder'; value=$StaticIsolationFolder; expected=$true },
        [pscustomobject]@{ name='prefinal2 ActiveFolder rejected'; value=$StaticConfusingFolders[0]; expected=$false },
        [pscustomobject]@{ name='final2evil ActiveFolder rejected'; value=$StaticConfusingFolders[1]; expected=$false },
        [pscustomobject]@{ name='final20 ActiveFolder rejected'; value=$StaticConfusingFolders[2]; expected=$false },
        [pscustomobject]@{ name='marker parent does not validate child leaf'; value=$StaticInvalidMarkerLeaf; expected=$false },
        [pscustomobject]@{ name='missing ActiveFolder'; value=$null; expected=$false },
        [pscustomobject]@{ name='relative ActiveFolder'; value='decision-grill-dg-final-relative'; expected=$false },
        [pscustomobject]@{ name='drive-root ActiveFolder'; value='D:\'; expected=$false },
        [pscustomobject]@{ name='repository-root ActiveFolder'; value=$RepoRoot; expected=$false },
        [pscustomobject]@{ name='global-Skills-root ActiveFolder'; value=$GlobalSkills; expected=$false },
        [pscustomobject]@{ name='official-Skills-root ActiveFolder'; value=$OfficialSystemSkills; expected=$false },
        [pscustomobject]@{ name='user-profile-root ActiveFolder'; value=$env:USERPROFILE; expected=$false }
    )
    foreach ($Scenario in $ActiveFolderChecks) { $Actual = (Test-ActiveFolderSafety $Scenario.value).passed; Add-Static $Scenario.name ($Actual -eq $Scenario.expected) "actual=$Actual" }
    $StaticReparseRoot = Join-Path 'D:\temp' ('decision-grill-static-reparse-' + [guid]::NewGuid().ToString('N'))
    $StaticReparseLinks = [System.Collections.Generic.List[string]]::new()
    $StaticBenignTarget = Join-Path $StaticReparseRoot 'benign-junction-target'
    $StaticSafeLeaf = 'decision-grill-dg-isolation-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
    $StaticSafeFolder = Join-Path 'D:\temp' $StaticSafeLeaf
    $SavedActiveFolderForReparseTest = $script:ActiveFolder
    $SavedPreflightActiveFolderForReparseTest = $script:PreflightActiveFolderCanonical
    $SavedCodexInvocationMockForReparseTest = $script:CodexInvocationMock
    try {
        New-Item -ItemType Directory -Force -Path $StaticReparseRoot, $StaticBenignTarget, (Join-Path $StaticBenignTarget $StaticSafeLeaf), $StaticSafeFolder | Out-Null
        $BenignBefore = Get-InventoryDigest $StaticBenignTarget
        function New-StaticJunction([string]$Link, [string]$Target) {
            New-Item -ItemType Junction -Path $Link -Target $Target -ErrorAction Stop | Out-Null
            $StaticReparseLinks.Add($Link)
            if ((([System.IO.File]::GetAttributes($Link)) -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) { throw "junction was not created as a reparse point: $Link" }
        }
        function Restore-StaticSafeActiveFolder {
            if ((Test-Path -LiteralPath $StaticSafeFolder) -and (([System.IO.File]::GetAttributes($StaticSafeFolder) -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) { [System.IO.Directory]::Delete($StaticSafeFolder, $false) }
            New-Item -ItemType Directory -Force -Path (Join-Path $StaticSafeFolder '.agents\skills\decision-grill') | Out-Null
            Copy-Item -LiteralPath $SourceSkill -Destination (Join-Path $StaticSafeFolder '.agents\skills\decision-grill\SKILL.md') -Force
            $script:ActiveFolder = $StaticSafeFolder
            $script:PreflightActiveFolderCanonical = $StaticSafeFolder
        }
        function Replace-StaticActiveFolderWithJunction {
            if (Test-Path -LiteralPath $StaticSafeFolder) { [System.IO.Directory]::Delete($StaticSafeFolder, $true) }
            New-StaticJunction $StaticSafeFolder $StaticBenignTarget
        }
        Restore-StaticSafeActiveFolder
        $script:StaticMockCallCount = 0
        $script:CodexInvocationMock = { param($Arguments, $MockPrompt, $MockRawPath, $MockInvocationName) $script:StaticMockCallCount++ }
        Invoke-CodexJson -CodexArguments (New-CodexExecutionArguments -Sandbox 'read-only' -Tail @('-')) -Prompt 'static mock normal path' -RawPath (Join-Path $StaticSafeFolder 'static-normal.jsonl') -InvocationName 'static discovery Codex CLI'
        Add-Static 'normal revalidation permits CLI mock' ($script:StaticMockCallCount -eq 1) "call_count=$script:StaticMockCallCount"
        $ExpectedResumePrompts = @($Cases | Where-Object { @(Get-OptionalArray $_ 'ordered_subsequent_inputs').Count -gt 0 } | ForEach-Object { @(Get-OptionalArray $_ 'ordered_subsequent_inputs') })
        $CapturedResumeCalls = [System.Collections.Generic.List[object]]::new()
        $script:CodexInvocationMock = { param($Arguments, $MockPrompt, $MockRawPath, $MockInvocationName) $CapturedResumeCalls.Add([pscustomobject]@{arguments=@($Arguments);prompt=$MockPrompt;raw_path=$MockRawPath;name=$MockInvocationName}) }
        $PromptIndex = 0
        foreach ($ExpectedResumePrompt in $ExpectedResumePrompts) {
            $PromptIndex++
            $StaticResumeEvaluation = [pscustomobject]@{result='SEND';resume_call_count=0}
            $StaticResumeArguments = New-CodexResumeArguments -ThreadId ("static-thread-{0}" -f $PromptIndex) -Sandbox 'read-only'
            $StaticResumeRawPath = Join-Path $StaticSafeFolder ("static-resume-{0}.jsonl" -f $PromptIndex)
            $StaticResumeResult = Invoke-ConditionalInput $StaticResumeEvaluation (New-ProductionResumeInvoker) $ExpectedResumePrompt $StaticResumeArguments $StaticResumeRawPath 'STATIC'
            if ($StaticResumeResult.resume_call_count -ne 1) { break }
        }
        $PromptBytesMatch = $CapturedResumeCalls.Count -eq $ExpectedResumePrompts.Count
        for ($CaptureIndex = 0; $PromptBytesMatch -and $CaptureIndex -lt $CapturedResumeCalls.Count; $CaptureIndex++) {
            $Captured = $CapturedResumeCalls[$CaptureIndex]
            $Expected = [string]$ExpectedResumePrompts[$CaptureIndex]
            $PromptBytesMatch = $Captured.prompt -ceq $Expected -and (($Utf8NoBom.GetBytes($Captured.prompt) -join ',') -eq ($Utf8NoBom.GetBytes($Expected) -join ',')) -and $Captured.arguments[-1] -eq '-' -and $Captured.name -eq 'case STATIC resume'
        }
        $MultiTurnFixtureCount = @($Cases | Where-Object { @(Get-OptionalArray $_ 'ordered_subsequent_inputs').Count -gt 0 }).Count
        Add-Static 'all 14 multi-turn fixtures use production resume closure' ($PromptBytesMatch -and $MultiTurnFixtureCount -eq 14 -and $CapturedResumeCalls.Count -eq 17) "fixtures=$MultiTurnFixtureCount; prompts=$($CapturedResumeCalls.Count); exact UTF-8 prompt bytes and resume arguments"
        $AutomaticInputPattern = [regex]::Escape('$') + '(?:[Ii]nput)\b'
        Add-Static 'production flow has no automatic Input variable collision' (-not ($Source -match $AutomaticInputPattern)) 'no automatic prompt-variable identifier remains'
        $script:StaticMockCallCount = 1
        $script:CodexInvocationMock = { param($Arguments, $MockPrompt, $MockRawPath, $MockInvocationName) $script:StaticMockCallCount++ }
        Replace-StaticActiveFolderWithJunction
        try { Invoke-CodexJson -CodexArguments @('exec') -Prompt 'blocked initial' -RawPath (Join-Path $StaticSafeFolder 'blocked-initial.jsonl') -InvocationName 'static initial Codex CLI' } catch { }
        Add-Static 'ActiveFolder replacement before initial blocks CLI mock' ($script:StaticMockCallCount -eq 1) "initial_call_count=0; total_call_count=$script:StaticMockCallCount"
        Restore-StaticSafeActiveFolder
        Invoke-CodexJson -CodexArguments (New-CodexExecutionArguments -Sandbox 'read-only' -Tail @('-')) -Prompt 'initial before resume replacement' -RawPath (Join-Path $StaticSafeFolder 'static-initial.jsonl') -InvocationName 'static initial Codex CLI'
        $ResumeCountBefore = $script:StaticMockCallCount
        Replace-StaticActiveFolderWithJunction
        try { Invoke-CodexJson -CodexArguments @('resume','synthetic-thread','-') -Prompt 'blocked resume' -RawPath (Join-Path $StaticSafeFolder 'blocked-resume.jsonl') -InvocationName 'static resume Codex CLI' } catch { }
        Add-Static 'ActiveFolder replacement before resume blocks CLI mock' ($script:StaticMockCallCount -eq $ResumeCountBefore) "resume_call_count=0; total_call_count=$script:StaticMockCallCount"
        Restore-StaticSafeActiveFolder
        $JudgeCountBefore = $script:StaticMockCallCount
        Replace-StaticActiveFolderWithJunction
        try { Invoke-CodexJson -CodexArguments @('exec','--sandbox','read-only') -Prompt 'blocked Judge' -RawPath (Join-Path $StaticSafeFolder 'blocked-judge.jsonl') -InvocationName 'static Judge Codex CLI' } catch { }
        Add-Static 'ActiveFolder replacement before Judge blocks CLI mock' ($script:StaticMockCallCount -eq $JudgeCountBefore) "judge_call_count=0; total_call_count=$script:StaticMockCallCount"
        Restore-StaticSafeActiveFolder
        Replace-StaticActiveFolderWithJunction
        $DigestBlocked = $false
        try { Get-RevalidatedInventoryDigest 'static before digest replacement' | Out-Null } catch { $DigestBlocked = $_.Exception.Message -match 'SAFETY_REVALIDATION_FAILED' }
        Add-Static 'ActiveFolder replacement before digest blocks digest' $DigestBlocked 'digest_not_executed=true'
        Restore-StaticSafeActiveFolder
        Add-Static 'normal physical isolation folder' (Test-ActiveFolderSafety $StaticSafeFolder).passed $StaticSafeFolder
        Add-Static 'normalized dot-dot isolation folder' (Test-ActiveFolderSafety (Join-Path (Join-Path $StaticSafeFolder '..') $StaticSafeLeaf)).passed 'normalized path remains inside the exact D:\temp boundary'
        Add-Static 'Ordinal directory boundary accepts child' (Test-PathIsWithinDirectoryOrdinalIgnoreCase $StaticSafeFolder 'D:\temp') $StaticSafeFolder
        Add-Static 'Ordinal directory boundary rejects similar prefix' (-not (Test-PathIsWithinDirectoryOrdinalIgnoreCase 'D:\tempish\decision-grill-dg-final-20260730-000000' 'D:\temp')) 'D:\tempish is not beneath D:\temp'
        $StaticActiveLink = Join-Path 'D:\temp' ('decision-grill-dg-final-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        New-StaticJunction $StaticActiveLink $StaticBenignTarget
        $ActiveLinkCheck = Test-ActiveFolderSafety $StaticActiveLink
        Add-Static 'ActiveFolder junction blocked' (-not $ActiveLinkCheck.passed -and $ActiveLinkCheck.failures -match [regex]::Escape($StaticActiveLink)) ($ActiveLinkCheck.failures -join '; ')
        $StaticAncestorLink = Join-Path 'D:\temp' ('decision-grill-static-ancestor-' + [guid]::NewGuid().ToString('N'))
        New-StaticJunction $StaticAncestorLink $StaticBenignTarget
        $AncestorLinkCheck = Test-ActiveFolderSafety (Join-Path $StaticAncestorLink $StaticSafeLeaf)
        Add-Static 'ActiveFolder ancestor junction blocked' (-not $AncestorLinkCheck.passed -and $AncestorLinkCheck.failures -match [regex]::Escape($StaticAncestorLink)) ($AncestorLinkCheck.failures -join '; ')
        $StaticAgentsLink = Join-Path $StaticSafeFolder '.agents'
        [System.IO.Directory]::Delete($StaticAgentsLink, $true)
        New-StaticJunction $StaticAgentsLink $StaticBenignTarget
        $SkillLinkCheck = Get-SkillHashValidation $StaticSafeFolder
        Add-Static 'installed Skill ancestor junction blocked' (-not $SkillLinkCheck.path_chain_safe -and $SkillLinkCheck.offending_segment -eq $StaticAgentsLink) ($SkillLinkCheck.path_chain_failures -join '; ')
        [System.IO.Directory]::Delete($StaticAgentsLink, $false)
        [void]$StaticReparseLinks.Remove($StaticAgentsLink)
        Restore-StaticSafeActiveFolder
        $StaticFixtureLink = Join-Path $StaticSafeFolder 'fixture-data'
        New-StaticJunction $StaticFixtureLink $StaticBenignTarget
        $script:ActiveFolder = $StaticSafeFolder
        $script:PreflightActiveFolderCanonical = $StaticSafeFolder
        $FixtureBlocked = $false
        $ReparseFixtureCase = [pscustomobject]@{case_id='STATIC-fixture-reparse';fixtures=@([pscustomobject]@{relative_path='fixture-data\release-fact.txt';content='reparse test'})}
        try { Initialize-CaseFixtures $ReparseFixtureCase | Out-Null } catch { $FixtureBlocked = $_.Exception.Message -match [regex]::Escape($StaticFixtureLink) }
        Add-Static 'fixture-data junction blocked before write' $FixtureBlocked $StaticFixtureLink
        $PrefixParent = Join-Path $StaticReparseRoot 'temp-prefix-similar'
        $PrefixCandidate = Join-Path $PrefixParent $StaticSafeLeaf
        New-Item -ItemType Directory -Force -Path $PrefixCandidate | Out-Null
        Add-Static 'prefix-similar parent outside boundary blocked' (-not (Test-ActiveFolderSafety $PrefixCandidate).passed) $PrefixCandidate
        $BenignAfter = Get-InventoryDigest $StaticBenignTarget
        Add-Static 'benign junction target unchanged' ($BenignBefore -eq $BenignAfter) 'junction rejection performed without target writes'
    } catch {
        Add-Static 'junction scenarios available' $false $_.Exception.Message
    } finally {
        $script:ActiveFolder = $SavedActiveFolderForReparseTest
        $script:PreflightActiveFolderCanonical = $SavedPreflightActiveFolderForReparseTest
        $script:CodexInvocationMock = $SavedCodexInvocationMockForReparseTest
        $CleanupFailures = [System.Collections.Generic.List[string]]::new()
        foreach ($Link in @($StaticReparseLinks | Sort-Object Length -Descending)) {
            try { if ((Test-Path -LiteralPath $Link) -and (([System.IO.File]::GetAttributes($Link) -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) { [System.IO.Directory]::Delete($Link, $false) } } catch { $CleanupFailures.Add("${Link}: $($_.Exception.Message)") }
        }
        try { if (Test-Path -LiteralPath $StaticSafeFolder) { [System.IO.Directory]::Delete($StaticSafeFolder, $true) } } catch { $CleanupFailures.Add("${StaticSafeFolder}: $($_.Exception.Message)") }
        try { if (Test-Path -LiteralPath $StaticReparseRoot) { [System.IO.Directory]::Delete($StaticReparseRoot, $true) } } catch { $CleanupFailures.Add("${StaticReparseRoot}: $($_.Exception.Message)") }
        Add-Static 'junction test cleanup' ($CleanupFailures.Count -eq 0) ($CleanupFailures -join '; ')
    }
    $SavedActiveFolder = $script:ActiveFolder
    $SavedPreflightActiveFolder = $script:PreflightActiveFolderCanonical
    $script:ActiveFolder = $StaticActiveFolder
    $script:PreflightActiveFolderCanonical = $StaticActiveFolder
    try {
        $InitialArguments = New-CodexExecutionArguments -Sandbox 'workspace-write' -Tail @('-')
        $ResumeArguments = New-CodexResumeArguments -ThreadId 'synthetic-thread' -Sandbox 'read-only'
        $InitialFolder = $InitialArguments[([array]::IndexOf($InitialArguments, '-C') + 1)]
        $ResumeFolder = $ResumeArguments[([array]::IndexOf($ResumeArguments, '-C') + 1)]
        Add-Static 'explicit valid ActiveFolder fully propagated' ($InitialFolder -eq $StaticActiveFolder -and $ResumeFolder -eq $StaticActiveFolder) 'initial and resume -C use ActiveFolder'
        $EmptyFixtureCase = [pscustomobject]@{case_id='STATIC-fixture-empty';fixtures=[System.Collections.ArrayList]@()}
        $EmptyPaths = @(Initialize-CaseFixtures $EmptyFixtureCase)
        Add-Static 'empty fixtures create no files' ($EmptyPaths.Count -eq 0 -and -not (Test-Path -LiteralPath (Join-Path $StaticActiveFolder 'fixture-data'))) 'no-op'
        $ZeroFixtureCase = [pscustomobject]@{case_id='STATIC-fixture-zero';fixtures=@([pscustomobject]@{relative_path='fixture-data\empty.txt';content=''})}
        $ZeroPaths = @(Initialize-CaseFixtures $ZeroFixtureCase)
        Add-Static 'empty content writes zero-byte UTF-8 file' ($ZeroPaths.Count -eq 1 -and (Get-Item -LiteralPath $ZeroPaths[0]).Length -eq 0) $ZeroPaths[0]
        $SingleFixtureCase = [pscustomobject]@{case_id='STATIC-fixture-single';fixtures=@([pscustomobject]@{relative_path='fixture-data\release-fact.txt';content=$ExpectedFixtureContent})}
        $SinglePaths = @(Initialize-CaseFixtures $SingleFixtureCase)
        Add-Static 'single fixture writes exact path' ($SinglePaths.Count -eq 1 -and $SinglePaths[0] -eq (Join-Path $StaticActiveFolder $ExpectedFixturePath)) $SinglePaths[0]
        $ExpectedBytes = $Utf8NoBom.GetBytes($ExpectedFixtureContent)
        Add-Static 'single fixture exact raw content' (([System.IO.File]::ReadAllBytes($SinglePaths[0]) -join ',') -eq ($ExpectedBytes -join ',')) 'no BOM or newline'
        $MultiFixtureCase = [pscustomobject]@{case_id='STATIC-fixture-multiple';fixtures=@([pscustomobject]@{relative_path='fixture-data\first.txt';content='first'},[pscustomobject]@{relative_path='fixture-data\second.txt';content='second'})}
        $MultiPaths = @(Initialize-CaseFixtures $MultiFixtureCase)
        Add-Static 'multiple fixtures preserve declaration order' ($MultiPaths.Count -eq 2 -and (Split-Path -Leaf $MultiPaths[0]) -eq 'first.txt' -and (Split-Path -Leaf $MultiPaths[1]) -eq 'second.txt') ($MultiPaths -join ',')
        foreach ($Scenario in @('C:\escape.txt','\\server\share\escape.txt','..\escape.txt','.\escape.txt','fixture-data\\empty.txt','fixture-data\..\escape.txt')) { $Blocked=$false; try { Resolve-CaseFixtureTargets @([pscustomobject]@{relative_path=$Scenario;content='x'}) | Out-Null } catch { $Blocked=$true }; Add-Static "fixture path rejected $Scenario" $Blocked 'pre-write validation' }
        $DuplicateBlocked=$false; try { Initialize-CaseFixtures ([pscustomobject]@{case_id='STATIC-fixture-duplicate';fixtures=@([pscustomobject]@{relative_path='fixture-data\duplicate.txt';content='one'},[pscustomobject]@{relative_path='fixture-data/duplicate.txt';content='two'})}) | Out-Null } catch { $DuplicateBlocked=$true }
        Add-Static 'duplicate normalized fixture targets reject before write' ($DuplicateBlocked -and -not (Test-Path -LiteralPath (Join-Path $StaticActiveFolder 'fixture-data\duplicate.txt'))) 'no partial fixture write'
        $ExistingPath=Join-Path $StaticActiveFolder 'fixture-data\existing.txt';Write-Utf8NoBom $ExistingPath 'original';$ExistingBlocked=$false;try{Initialize-CaseFixtures ([pscustomobject]@{case_id='STATIC-fixture-existing';fixtures=@([pscustomobject]@{relative_path='fixture-data\existing.txt';content='replacement'})})|Out-Null}catch{$ExistingBlocked=$true};Add-Static 'existing fixture target refuses overwrite' ($ExistingBlocked -and (Read-Utf8NoBom $ExistingPath) -eq 'original') 'original content preserved'
    } finally { $script:ActiveFolder = $SavedActiveFolder; $script:PreflightActiveFolderCanonical = $SavedPreflightActiveFolder }
    $StaticSkillValidation = Get-SkillHashValidation $StaticActiveFolder
    Add-Static 'installed Skill missing blocks validation' (-not (Get-SkillHashValidation (Join-Path $StaticActiveFolder 'missing')).installed_skill_exists) 'missing installed Skill is not accepted'
    Add-Static 'source and installed Skill hash mismatch blocks validation' (-not (Test-SkillHashPair 'A' 'B')) 'different raw-byte hashes'
    Add-Static 'source and installed Skill hash match passes validation' $StaticSkillValidation.hashes_match ("source={0}; installed={1}" -f $StaticSkillValidation.source_skill_sha256,$StaticSkillValidation.installed_skill_sha256)
    Remove-Item -LiteralPath (@($StaticActiveFolder,$StaticFinal2Folder,$StaticRetestFolder,$StaticIsolationFolder) + @($StaticConfusingFolders) + @($StaticMarkerParent)) -Recurse -Force
    $OldIsolationPath = 'D:\temp\decision-grill-dg-' + 'retest-20260729-233153165'
    Add-Static 'production path has no old isolation literal' (-not $Source.Contains($OldIsolationPath)) 'old path absent'
    $HashToken = '$Expected' + 'SkillHash'
    Add-Static 'hard-coded expected Skill SHA absent' (-not $Source.Contains($HashToken)) 'no expected Skill hash variable'
    Add-Static 'StaticTest does not require ActiveFolder' (-not $PSBoundParameters.ContainsKey('ActiveFolder')) 'StaticTest exits before production preflight'
    $ProductSpecSha256 = if (Test-Path -LiteralPath $ProductSpecPath -PathType Leaf) { Get-Sha256 -LiteralPath $ProductSpecPath } else { $null }
    $RemediationSpecSha256 = if (Test-Path -LiteralPath $RemediationSpecPath -PathType Leaf) { Get-Sha256 -LiteralPath $RemediationSpecPath } else { $null }
    Add-Static 'product spec raw-byte SHA-256' ($ProductSpecSha256 -eq $ExpectedProductSpecSha256) ("path={0}; sha256={1}" -f $ProductSpecPath,$ProductSpecSha256)
    Add-Static 'remediation spec raw-byte SHA-256' ($RemediationSpecSha256 -eq $ExpectedRemediationSpecSha256) ("path={0}; sha256={1}" -f $RemediationSpecPath,$RemediationSpecSha256)
    $AmbiguousSpecHashLabel = 'authoritative' + ' spec SHA'
    Add-Static 'spec hash report labels explicit' (($Source -notmatch $AmbiguousSpecHashLabel) -and ($Source -match 'product_spec_path') -and ($Source -match 'product_spec_sha256') -and ($Source -match 'remediation_spec_path') -and ($Source -match 'remediation_spec_sha256')) 'product and remediation spec fields are distinct'
    $Results|ForEach-Object { Write-Output ("{0}: {1} — {2}" -f $_.name, $(if($_.passed){'PASS'}else{'FAIL'}), $_.detail) };if(@($Results|Where-Object {-not $_.passed}).Count){exit 1};exit 0
}

if ($Mode -eq 'StaticTest') { Invoke-StaticTest }

$Cases = Read-Utf8NoBom $CasesPath | ConvertFrom-Json
$ModeSelectionContract = Test-ModeCaseSelectionContract $Mode $CaseIds $Cases
if (-not $ModeSelectionContract.passed) {
    Write-Error ("CASE_SELECTION_BLOCKED: " + ($ModeSelectionContract.failures -join '; '))
    exit 2
}
New-OutputLayout
$Checks = Invoke-Preflight
$PreflightPassed = @($Checks | Where-Object { -not $_.passed }).Count -eq 0
$RequiredIds = 1..20 | ForEach-Object { 'DG-{0:D3}' -f $_ }
$CaseContracts = @($Cases | ForEach-Object { Test-CaseContract $_ })
$StateAssertionAudit = @($Cases | ForEach-Object { Get-StateAssertionAudit $_ })
$StateAuditFailures = @($StateAssertionAudit | Where-Object { -not $_.passed })
$StateAuditPath = Join-Path $ResultsDir 'state-semantics-audit.json'
$StateAssertionAudit | ConvertTo-Json -Depth 12 | ForEach-Object { Write-Utf8NoBom $StateAuditPath $_ }
$DG002 = $Cases | Where-Object case_id -eq 'DG-002'
$StateSynthetic = Test-StateSemanticsSynthetic $DG002
$MultiTurnSendAudit = Test-MultiTurnSendConditionAudit $Cases
$MultiTurnSendAuditFailures = @($MultiTurnSendAudit | Where-Object { -not $_.passed })
$SendConditionAuditPath = Join-Path $ResultsDir 'send-condition-audit.json'
$MultiTurnSendAudit | ConvertTo-Json -Depth 12 | ForEach-Object { Write-Utf8NoBom $SendConditionAuditPath $_ }
$SendConditionSynthetic = Test-SendConditionSynthetic $Cases
$ContractFailures = @($CaseContracts | Where-Object { -not $_.passed })
$ContractFailureDetail = if ($ContractFailures.Count) { (($ContractFailures | ForEach-Object { $_.failures }) -join '; ') } else { 'all 20 cases passed required-property and deterministic prepare validation' }
$CatalogChecks = @(
    [pscustomobject]@{ name='cases count'; passed=(@($Cases).Count -eq 20); detail=@($Cases).Count },
    [pscustomobject]@{ name='case IDs complete'; passed=(((($CaseContracts.case_id | Sort-Object) -join ',') -eq (($RequiredIds | Sort-Object) -join ','))); detail=($CaseContracts.case_id -join ',') },
    [pscustomobject]@{ name='required case-property audit'; passed=($ContractFailures.Count -eq 0); detail=$ContractFailureDetail },
    [pscustomobject]@{ name='20-case deterministic prepare validation'; passed=($CaseContracts.Count -eq 20 -and $ContractFailures.Count -eq 0); detail=$ContractFailureDetail },
    [pscustomobject]@{ name='desktop and CLI input present'; passed=($ContractFailures.Count -eq 0); detail='validated by required case-property audit' },
    [pscustomobject]@{ name='20-case state-semantics audit'; passed=($StateAuditFailures.Count -eq 0); detail=if ($StateAuditFailures.Count) { ($StateAuditFailures | ForEach-Object { "$($_.case_id): $($_.failures -join '; ')" }) -join ' | ' } else { 'all state assertions explicitly classified; legacy required_states=all-of' } },
    [pscustomobject]@{ name='DG-002 state any-of synthetic OPEN'; passed=$StateSynthetic.open_any_of_pass; detail=if ($StateSynthetic.open_any_of_pass) { 'OPEN explicit marker satisfies any-of' } else { $StateSynthetic.open_failures -join '; ' } },
    [pscustomobject]@{ name='DG-002 forbidden CONFIRMED synthetic'; passed=$StateSynthetic.confirmed_forbidden_fail; detail=if ($StateSynthetic.confirmed_forbidden_fail) { 'CONFIRMED explicit marker fails' } else { $StateSynthetic.confirmed_failures -join '; ' } },
    [pscustomobject]@{ name='all multi-turn cases send-condition audit'; passed=($MultiTurnSendAuditFailures.Count -eq 0); detail=if ($MultiTurnSendAuditFailures.Count) { ($MultiTurnSendAuditFailures.case_id -join ', ') } else { "$($MultiTurnSendAudit.Count) multi-turn cases have send condition and observable prerequisite" } },
    [pscustomobject]@{ name='send-condition synthetic gates'; passed=(@($SendConditionSynthetic | Where-Object { -not $_.true_passed -or -not $_.false_passed }).Count -eq 0); detail=($SendConditionSynthetic | ForEach-Object { "case=$($_.case_id); index=$($_.input_index); mode=$($_.mode); true expected=$($_.true_expected) actual=$($_.true_actual); false expected=$($_.false_expected) actual=$($_.false_actual)" }) -join '; ' }
)
Add-CheckCollection $Checks $CatalogChecks 'catalog checks'
if ($Mode -in @('Targeted','DryRun') -and -not [string]::IsNullOrWhiteSpace($CaseIds)) {
    Add-Check $Checks 'generic case selection' ($ModeSelectionContract.selection.selected_cases.Count -gt 0) ("selected={0}; order={1}" -f $ModeSelectionContract.selection.selected_cases.Count,($ModeSelectionContract.selection.selected_case_ids -join ','))
}
$TranscriptSelfTest = Test-TranscriptExtraction
$TranscriptSelfTestDetail = if ($TranscriptSelfTest.result) { 'single-turn, multi-turn, and empty transcript gate passed; Judge not called' } elseif (Test-ObjectProperty $TranscriptSelfTest 'error') { $TranscriptSelfTest.error } else { 'transcript extraction self-test failed' }
$TranscriptChecks = @(
    [pscustomobject]@{ name='transcript extraction self-test'; passed=$TranscriptSelfTest.result; detail=$TranscriptSelfTestDetail },
    [pscustomobject]@{ name='single-turn extraction'; passed=$TranscriptSelfTest.single_turn; detail='one item.completed agent_message extracted' },
    [pscustomobject]@{ name='multi-turn extraction'; passed=$TranscriptSelfTest.multi_turn; detail='initial and resume agent messages extracted in supplied turn order' },
    [pscustomobject]@{ name='empty transcript gate'; passed=$TranscriptSelfTest.empty_transcript_gate; detail='empty transcript blocked before Judge invocation' }
)
Add-CheckCollection $Checks $TranscriptChecks 'transcript checks'
$PreflightPassed = @($Checks | Where-Object { -not $_.passed }).Count -eq 0
$UnicodeRoundTripResult = [pscustomobject]@{ result=$null }
if ($PreflightPassed -and $Mode -eq 'DryRun') {
    $UnicodeRoundTripResult = Test-UnicodeRoundTrip
    $UnicodeDetail = if ($UnicodeRoundTripResult.result) { 'exact UTF-8 stdin/stdout/transcript round-trip passed' } elseif (Test-ObjectProperty $UnicodeRoundTripResult 'error') { $UnicodeRoundTripResult.error } else { 'Unicode round-trip validation failed' }
    $UnicodeU2019 = Get-OptionalBoolean $UnicodeRoundTripResult 'u2019_preserved'
    $UnicodeChinese = Get-OptionalBoolean $UnicodeRoundTripResult 'chinese_preserved'
    $UnicodeJsonl = Get-OptionalBoolean $UnicodeRoundTripResult 'jsonl_parse'
    $UnicodeChecks = @(
        [pscustomobject]@{ name='Unicode round-trip probe'; passed=$UnicodeRoundTripResult.result; detail=$UnicodeDetail },
        [pscustomobject]@{ name='Unicode U+2019 preserved'; passed=($UnicodeU2019.exists -and $UnicodeU2019.value); detail='U+2019' },
        [pscustomobject]@{ name='Unicode Chinese preserved'; passed=($UnicodeChinese.exists -and $UnicodeChinese.value); detail='Chinese test text' },
        [pscustomobject]@{ name='Unicode JSONL parse'; passed=($UnicodeJsonl.exists -and $UnicodeJsonl.value); detail='all JSONL events parsed' }
    )
    Add-CheckCollection $Checks $UnicodeChecks 'Unicode checks'
    $PreflightPassed = @($Checks | Where-Object { -not $_.passed }).Count -eq 0
}
$Results = [System.Collections.Generic.List[object]]::new()
$RunStop = $null
$ExplicitSkillResult = 'NOT_RUN'
$ResumeProbeResult = 'NOT_RUN'
$Utf8TransportResult = 'NOT_RUN'
if (-not $PreflightPassed) {
    $Results.Add([pscustomobject]@{ case_id='PREFLIGHT'; title='Required environment checks'; result='BLOCKED'; deterministic=@{result='BLOCKED';failures=@($Checks | Where-Object {-not $_.passed} | ForEach-Object {$_.name})}; judge=$null; thread_id=$null; evidence_excerpt='No case executed.'; before_hash=$null; after_hash=$null; review_required=$true })
} elseif ($Mode -eq 'Discovery') {
    $ExplicitSkillResult = Test-ExplicitSkillAdapter 'D:\temp\decision-grill-cli-probe.jsonl'
    if ($ExplicitSkillResult -notmatch '^PASS') {
        $Results.Add([pscustomobject]@{ case_id='DISCOVERY'; title='Explicit Skill discovery'; result='BLOCKED'; deterministic=@{result='BLOCKED';failures=@($ExplicitSkillResult)}; judge=$null; thread_id=$null; evidence_excerpt=$ExplicitSkillResult; before_hash=$null; after_hash=$null; review_required=$true })
    }
} elseif ($Mode -eq 'ResumeProbe') {
    $ResumeProbeResult = Test-ResumeTransport
    if ($ResumeProbeResult -notmatch '^PASS') {
        $Results.Add([pscustomobject]@{ case_id='RESUME_PROBE'; title='Resume transport probe'; result='BLOCKED'; deterministic=@{result='BLOCKED';failures=@($ResumeProbeResult)}; judge=$null; thread_id=$null; evidence_excerpt=$ResumeProbeResult; before_hash=$null; after_hash=$null; review_required=$true })
    }
} elseif ($Mode -eq 'Utf8Probe') {
    $Utf8TransportResult = Test-UnicodeRoundTrip
    if (-not $Utf8TransportResult.result) {
        $Results.Add([pscustomobject]@{ case_id='UTF8_PROBE'; title='UTF-8 transport probe'; result='BLOCKED'; deterministic=@{result='BLOCKED';failures=@($Utf8TransportResult)}; judge=$null; thread_id=$null; evidence_excerpt=$Utf8TransportResult; before_hash=$null; after_hash=$null; review_required=$true })
    }
} elseif ($Mode -eq 'DryRun') {
    $ExplicitSkillResult = Test-ExplicitSkillAdapter
    if ($ExplicitSkillResult -notmatch '^PASS') {
        $Results.Add([pscustomobject]@{ case_id='DRYRUN_DISCOVERY'; title='Explicit Skill discovery'; result='BLOCKED'; deterministic=@{result='BLOCKED';failures=@($ExplicitSkillResult)}; judge=$null; thread_id=$null; evidence_excerpt=$ExplicitSkillResult; before_hash=$null; after_hash=$null; review_required=$true })
    }
} else {
    # A separate fresh thread proves the explicit CLI adapter before pilot cases begin.
    $ExplicitSkillResult = Test-ExplicitSkillAdapter
    if ($ExplicitSkillResult -notmatch '^PASS') {
        $AdapterBlockedCases = if ($Mode -eq 'Targeted') { @($ModeSelectionContract.selection.selected_cases) } elseif ($Mode -eq 'Core') { @($Cases | Where-Object case_id -in @('DG-016','DG-011','DG-002')) } else { @() }
        foreach ($BlockedCase in $AdapterBlockedCases) { $Results.Add([pscustomobject]@{ case_id=$BlockedCase.case_id; title=$BlockedCase.title; result='BLOCKED'; deterministic=@{result='BLOCKED';failures=@($ExplicitSkillResult)}; judge=$null; thread_id=$null; evidence_excerpt=$ExplicitSkillResult; before_hash=$null; after_hash=$null; review_required=$true }) }
    } else {
    $Selection = if ($Mode -eq 'Core') { @('DG-016','DG-011','DG-002') } elseif ($Mode -eq 'Targeted') { @($ModeSelectionContract.selection.selected_case_ids) } else { $RequiredIds }
    $SelectedCases = @($Selection | ForEach-Object { $Cases | Where-Object case_id -eq $_ })
    $SelectionRun = Invoke-SelectedCases $SelectedCases { param($SelectedCase) Invoke-Case $SelectedCase }
    $RunStop = $SelectionRun.stop
    foreach ($Result in @($SelectionRun.results)) {
        $Results.Add($Result)
        $Result | ConvertTo-Json -Depth 15 | ForEach-Object { Write-Utf8NoBom (Join-Path $ResultsDir "$($Result.case_id).json") $_ }
    }
    }
}
$ProductSpecSha256 = if (Test-Path -LiteralPath $ProductSpecPath -PathType Leaf) { Get-Sha256 -LiteralPath $ProductSpecPath } else { $null }
$RemediationSpecSha256 = if (Test-Path -LiteralPath $RemediationSpecPath -PathType Leaf) { Get-Sha256 -LiteralPath $RemediationSpecPath } else { $null }
$SpecHashVerification = [pscustomobject]@{ product_spec_path=$ProductSpecPath; product_spec_sha256=$ProductSpecSha256; product_spec_sha256_expected=$ExpectedProductSpecSha256; product_spec_sha256_verified=($ProductSpecSha256 -eq $ExpectedProductSpecSha256); remediation_spec_path=$RemediationSpecPath; remediation_spec_sha256=$RemediationSpecSha256; remediation_spec_sha256_expected=$ExpectedRemediationSpecSha256; remediation_spec_sha256_verified=($RemediationSpecSha256 -eq $ExpectedRemediationSpecSha256) }
Assert-WorkingTreeIdentity -Purpose 'before results and report persistence'
$Planned = if ($Mode -eq 'Core') { 3 } elseif ($Mode -eq 'Full') { 20 } elseif ($Mode -eq 'Targeted') { $ModeSelectionContract.selection.selected_cases.Count } elseif ($Mode -eq 'DryRun' -and -not [string]::IsNullOrWhiteSpace($CaseIds)) { $ModeSelectionContract.selection.selected_cases.Count } else { $Results.Count }
$ExecutedOverride = if ($Mode -eq 'DryRun' -and -not [string]::IsNullOrWhiteSpace($CaseIds)) { 0 } else { -1 }
$Summary = Get-RunSummary @($Results) $Planned $ExecutedOverride
$Aggregate = [pscustomobject]@{ mode=$Mode; case_selection=$ModeSelectionContract.selection; generated_at=(Get-Date).ToString('o'); output_root=$OutputRoot; active_folder=$ActiveFolder; skill_hash_validation=$SkillHashValidation; codex=@{ resolved_path=$ResolvedCodexPath; version=$CodexVersion; is_windowsapps=$CodexIsWindowsApps }; spec_hash_verification=$SpecHashVerification; preflight=$Checks; run_stop=$RunStop; summary=$Summary; state_semantics_audit_path=$StateAuditPath; state_semantics_audit=@($StateAssertionAudit); state_semantics_synthetic=$StateSynthetic; send_condition_audit_path=$SendConditionAuditPath; send_condition_audit=@($MultiTurnSendAudit); send_condition_synthetic=$SendConditionSynthetic; transcript_extraction_self_test=$TranscriptSelfTest; unicode_round_trip_probe=$UnicodeRoundTripResult; cli_explicit_skill_invocation=$ExplicitSkillResult; resume_transport_probe=$ResumeProbeResult; utf8_transport_probe=$Utf8TransportResult; cases=@($Results) }
$Aggregate | ConvertTo-Json -Depth 20 | ForEach-Object { Write-Utf8NoBom (Join-Path $OutputRoot 'decision-grill-regression-results.json') $_ }
$StopReasonText = if ($null -eq $RunStop) { 'none' } else { $RunStop.stop_reason }
$TriggerCaseText = if ($null -eq $RunStop) { 'none' } else { $RunStop.trigger_case_id }
$TriggerStageText = if ($null -eq $RunStop) { 'none' } else { $RunStop.trigger_stage }
$LastCompletedText = if ($null -eq $RunStop) { 'none' } else { $RunStop.last_completed_case }
$RemainingCasesText = if ($null -eq $RunStop) { 'none' } else { $RunStop.remaining_cases -join ', ' }
$Md = @("# Decision-Grill Regression Report", "", "Mode: $Mode", "", "## Case Selection", "", "- declaration: $CaseIds", "- selected canonical order: $($ModeSelectionContract.selection.selected_case_ids -join ', ')", "- selected count: $($ModeSelectionContract.selection.selected_cases.Count)", "", "## ActiveFolder and Skill Validation", "", "- ActiveFolder: $ActiveFolder", "- source Skill path: $($SkillHashValidation.source_skill_path)", "- source Skill SHA-256: $($SkillHashValidation.source_skill_sha256)", "- installed Skill path: $($SkillHashValidation.installed_skill_path)", "- installed Skill SHA-256: $($SkillHashValidation.installed_skill_sha256)", "- hashes match: $($SkillHashValidation.hashes_match)", "", "## Spec Hash Verification", "", "- product spec path: $($SpecHashVerification.product_spec_path)", "- product spec SHA-256: $($SpecHashVerification.product_spec_sha256)", "- product spec SHA-256 expected: $($SpecHashVerification.product_spec_sha256_expected)", "- remediation spec path: $($SpecHashVerification.remediation_spec_path)", "- remediation spec SHA-256: $($SpecHashVerification.remediation_spec_sha256)", "- remediation spec SHA-256 expected: $($SpecHashVerification.remediation_spec_sha256_expected)", "- remediation spec SHA-256 verified: $($SpecHashVerification.remediation_spec_sha256_verified)", "", "## Codex CLI", "", "- resolved CodexPath: $ResolvedCodexPath", "- CLI version: $CodexVersion", "- WindowsApps: $CodexIsWindowsApps", "", "## Preflight", "") + ($Checks | ForEach-Object {
    $Line = "- $($_.name): $(if ($_.passed) {'PASS'} else {'BLOCKED'}) — $($_.detail)"
    $ExceptionProperty = $_.PSObject.Properties['exception']
    $ExceptionDetail = if ($ExceptionProperty) { $ExceptionProperty.Value } else { $null }
    if ($ExceptionDetail) {
        $Line += "`n  - exception type: $($ExceptionDetail.exception_type)`n  - message: $($ExceptionDetail.message)`n  - script line: $($ExceptionDetail.script_line)`n  - failing check: $($ExceptionDetail.failing_check)`n  - exact command: $($ExceptionDetail.exact_command)"
    }
    $Line
}) + @("", "## Run Summary", "", "- PASS: $($Summary.categories.PASS)", "- FAIL: $($Summary.categories.FAIL)", "- BLOCKED: $($Summary.categories.BLOCKED)", "- RUNNER_INTERNAL_ERROR: $($Summary.categories.RUNNER_INTERNAL_ERROR)", "- NOT_EXECUTED: $($Summary.categories.NOT_EXECUTED)", "- Executed: $($Summary.executed)", "- Planned: $($Summary.planned)", "- Total: $($Summary.total)", "- Category sum matches Planned: $($Summary.category_sum_matches_planned)", "", "## Run Stop", "", "- stop reason: $StopReasonText", "- trigger case: $TriggerCaseText", "- trigger stage: $TriggerStageText", "- last completed case: $LastCompletedText", "- remaining cases: $RemainingCasesText", "", "## Cases", "") + ($Results | ForEach-Object { "- $($_.case_id) — $($_.result)" })
Write-Utf8NoBom (Join-Path $OutputRoot 'decision-grill-regression-report.md') ($Md -join [Environment]::NewLine)
Assert-WorkingTreeIdentity -Purpose 'run completion'
$Exit = Get-RunExitCode @($Results) $PreflightPassed
exit $Exit
