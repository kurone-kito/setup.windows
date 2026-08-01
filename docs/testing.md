# Testing PowerShell scripts

This repository uses [Pester](https://pester.dev/) to test PowerShell
logic that has clear inputs and outputs (parsers, generators, pure
decision functions), as opposed to imperative installer scripts. Static
analysis (PSScriptAnalyzer) catches style problems; Pester catches
"does this return the right output for this input" problems that
static analysis cannot.

## When to add a test

Add a test alongside any new script under `libs/` or `scripts/` whose
logic is pure enough to unit-test: parsing, generation, or a decision
function with clear inputs and outputs. Imperative installer scripts
(package installs, registry writes) generally don't need one — there's
nothing to assert against without a real Windows machine.

## Where tests live

Test files live under `tests/powershell/` and follow Pester's
`<Name>.Tests.ps1` naming convention, mirroring the path of the file
under test where practical (e.g. `libs/os-guard.ps1` is tested by
`tests/powershell/os-guard.Tests.ps1`).

## Pester version

CI and local development both pin `Pester 6.0.1` (`Install-Module
-Name Pester -RequiredVersion 6.0.1 -Force -Scope CurrentUser
-Repository PSGallery`, matching the existing `PSScriptAnalyzer`
job's `-RequiredVersion` pattern in `.github/workflows/lint.yml`).
An explicit version was chosen over an unpinned `Install-Module` so
that a new Pester major release can't silently change test syntax or
behavior underneath CI; bump `-RequiredVersion` deliberately when
upgrading.

## Running tests locally

```powershell
Invoke-Pester -Path ./tests/powershell -CI
```

`-CI` enables a non-zero exit code on failure (`Run.Exit = $true`), so
it's the same invocation `pre-push-validate` / `post-fix-validate` and
CI use. It also writes `testResults.xml` to the working directory
(gitignored) — delete it or ignore it, it's not meaningful outside the
run that produced it.

## Mocking Windows-only cmdlets on a non-Windows runner

CI's `pester` job runs on `ubuntu-latest`, and local development in
this repository may also happen on Linux. Cmdlets that ship only in
Windows-specific modules — `Get-CimInstance` (module `CimCmdlets`)
being the recurring example — don't exist there, and Pester's `Mock`
requires the target command to exist before it can be mocked.

The fix is a global placeholder function declared before the file
under test is dot-sourced:

```powershell
BeforeAll {
  function global:Get-CimInstance { }
  . (Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..', 'libs', 'os-guard.ps1')
}
```

`Mock Get-CimInstance { ... }` then replaces this placeholder for the
duration of the test, exactly as it would replace the real cmdlet on
Windows. See `tests/powershell/os-guard.Tests.ps1` for a complete
example, including `-ForEach`-driven boundary-value cases and
`Should -Invoke` assertions that confirm the mock was actually called
(a mock that silently fails to intercept produces a confusing
downstream assertion failure instead of a clear error).

Cmdlets that exist cross-platform but whose target doesn't (e.g.
`Get-ItemProperty` against an `HKLM:` path, which is Windows-only) need
no placeholder — they mock normally, since the command itself is real.

## What CI runs

`.github/workflows/lint.yml`'s `pester` job runs `Invoke-Pester -Path
./tests/powershell -CI` on every push and pull request, same as the
`powershell-analyzer` job. A red Pester run blocks the same way a red
PSScriptAnalyzer run does.
