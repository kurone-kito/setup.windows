@{
  # Packages pinned via `winget pin add` (libs/winget-pin-sync.ps1,
  # applied by boxstarter.ps1 after package installation) so a manual
  # `winget upgrade --all` -- or any other bulk-upgrade path that goes
  # through winget itself -- does not silently move a version-sensitive
  # package out from under this repo's other declared state. Pinning is
  # machine-local winget state, not part of the DSC/import files
  # themselves, which is exactly why it needs its own declaration here:
  # see docs/dsc-migration-notes.md's "Declaring winget pins (issue #75)"
  # section for the full rationale, the pin-type decision, and this
  # mechanism's documented limits (Unity Hub's own self-update, and
  # msstore-sourced packages).
  #
  # Each entry:
  #   Id      - winget package identifier (must match its
  #             configurations/packages*.dsc.yaml entry)
  #   Source  - winget source name (almost always 'winget'; msstore
  #             packages can be listed too, but pin coverage there is
  #             unverified -- see docs/dsc-migration-notes.md)
  #   PinType - one of 'Pinning' | 'Blocking' | 'Gating', matching
  #             winget's own three pin types exactly (case-sensitive).
  #             'Gating' entries must also set VersionRange.
  #   Reason  - why this package is pinned, i.e. what breaks if it
  #             silently upgrades. A pin with no reason can't later be
  #             judged safe to remove.
  Pins = @(
    @{
      Id      = 'Unity.UnityHub'
      Source  = 'winget'
      PinType = 'Blocking'
      Reason  = @'
Unity Hub drives Unity Editor installation (libs/unity-editor-installer.ps1)
and VRChat Creator Companion depends on it recognizing the installed Editor
(configurations/runtime-versions.psd1's Unity entry). An unplanned Hub
upgrade risks changing that recognition behavior or the Hub CLI surface
underneath a pinned Editor version, so this uses Blocking (not the default
Pinning) -- an operator typing `winget upgrade Unity.UnityHub` by name
should not silently succeed either. This still only closes the
winget-upgrade path: Hub self-updates outside winget entirely, which no pin
type can stop -- see docs/dsc-migration-notes.md.
'@
    }
  )
}
