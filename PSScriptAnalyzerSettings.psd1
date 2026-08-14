@{
  # Analysis targets boxstarter.ps1 / libs/ (.ps1) at repository root via
  # -Path . -Recurse; there is no t/ directory, boxstarter.min.ps1, or
  # libs/*.psm1 file after the DSC migration (issue #63) and dead-code
  # cleanup (issue #70) -- the "min" profile is now data
  # (configurations/packages.min.dsc.yaml / .min.import.json), not a
  # parallel script, and libs/.lib.psm1 (unreferenced anywhere) was
  # deleted outright rather than kept around unused.
  ExcludeRules = @(
    # Boxstarter/setup scripts are interactive by design: Write-Host (and
    # [Console]::WriteLine) is the intended direct-to-console channel here, not
    # accidental pipeline pollution.
    'PSAvoidUsingWriteHost',

    # libs/post-install.ps1's Test-CommandExists is a private helper used
    # only within its own file; renaming it is out of scope for this
    # lint/CI-infrastructure issue.
    'PSUseSingularNouns'

    # PSAvoidUsingInvokeExpression is intentionally NOT excluded here (flagged
    # by review): a global ExcludeRules entry would also silence any new
    # Invoke-Expression call added later under libs/. There is no current
    # occurrence to suppress (the one that existed, fnm's env-init
    # incantation in libs/post-install.ps1, was removed with fnm itself --
    # issue #108); if a future occurrence needs one, suppress it at the file
    # scope via [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute]
    # instead, so the rule stays enabled for every other analyzed file.
  )
}
