@{
  # Analysis targets boxstarter.ps1 / libs/ (.ps1 / .psm1) at repository root
  # via -Path . -Recurse; there is no t/ directory or boxstarter.min.ps1 after
  # the DSC migration (issue #63) -- the "min" profile is now data
  # (configurations/packages.min.dsc.yaml / .min.import.json), not a parallel
  # script.
  ExcludeRules = @(
    # Boxstarter/setup scripts are interactive by design: Write-Host (and
    # [Console]::WriteLine) is the intended direct-to-console channel here, not
    # accidental pipeline pollution.
    'PSAvoidUsingWriteHost',

    # The flagged function (libs/.lib.psm1's Write-SkippedMessage) takes a
    # single pipeline value by design (callers pipe one item at a time via
    # ForEach-Object). Adding a process {} block would require relocating its
    # trailing comment-based help ahead of param() to keep Get-Help working --
    # mechanical churn for no behavior change.
    'PSUseProcessBlockForPipelineCommand',

    # The flagged names (libs/.lib.psm1's Invoke-SelfWithPrivileges,
    # Join-PSOptions; libs/post-install.ps1's Test-CommandExists) have no
    # call sites anywhere in this repository as of the DSC migration (issue
    # #63) -- libs/.lib.psm1 itself is currently dead code (tracked
    # separately for #70's cleanup pass), and Test-CommandExists is a
    # private helper used only within its own file. Renaming them is
    # out of scope for this lint/CI-infrastructure issue regardless.
    'PSUseSingularNouns'

    # PSAvoidUsingInvokeExpression is intentionally NOT excluded here (flagged
    # by review): a global ExcludeRules entry would also silence any new
    # Invoke-Expression call added later under libs/. The one existing
    # occurrence (fnm's `fnm env --use-on-cd | Out-String | Invoke-Expression`
    # in libs/post-install.ps1) is suppressed at the file scope instead via
    # [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute], so the rule
    # stays enabled for every other analyzed file.
  )
}
