@{
  # Analysis targets boxstarter.ps1 / libs/ / t/ (.ps1 / .psm1). boxstarter.min.ps1
  # is a hand-maintained minimal-install variant of boxstarter.ps1 (identical
  # 341 lines, a handful of Install-WingetApps/choco calls commented out), not
  # a generated/minified artifact, and is not excluded by path: PSScriptAnalyzer
  # has no path-exclusion setting or parameter (-Path accepts a single string;
  # ExcludeRules/IncludeRules only select rules, not files). It is still scanned,
  # but every rule it would otherwise trip (PSUseSingularNouns,
  # PSAvoidUsingInvokeExpression) is already excluded below for boxstarter.ps1's
  # sake, so it independently reaches zero findings. It therefore gets no
  # analysis coverage beyond what these excluded rules would have caught.
  ExcludeRules = @(
    # Boxstarter/setup scripts are interactive by design: Write-Host (and
    # [Console]::WriteLine) is the intended direct-to-console channel here, not
    # accidental pipeline pollution.
    'PSAvoidUsingWriteHost',

    # All flagged functions take a single pipeline value by design (callers pipe
    # one item at a time via ForEach-Object; see e.g. libs/.lib.psm1's
    # Add-Link/Add-Links). Adding process {} blocks would require relocating
    # each function's trailing comment-based help ahead of param() to keep
    # Get-Help working -- mechanical churn for no behavior change. One
    # occurrence (t/deploy.ps1) is additionally moot: issue #63 deletes that
    # file outright.
    'PSUseProcessBlockForPipelineCommand',

    # The flagged names (libs/.lib.psm1's Add-Links, Invoke-SelfWithPrivileges,
    # Join-PSOptions; boxstarter.ps1's Install-WingetApps) are exported /
    # widely dot-sourced; renaming is a breaking API change for anything that
    # calls them, out of scope for this lint/CI-infrastructure issue.
    'PSUseSingularNouns',

    # Both occurrences in boxstarter.ps1 are the tools' own documented
    # install/init incantations (fnm's `fnm env --use-on-cd | Out-String |
    # Invoke-Expression`, Scoop's `Invoke-WebRequest -useb get.scoop.sh |
    # Invoke-Expression`). Rewriting would break the installs, not just satisfy
    # the linter.
    'PSAvoidUsingInvokeExpression'
  )
}
