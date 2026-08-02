@{
  # Node.js versions installed via fnm (libs/post-install.ps1).
  #
  # Source of truth for each entry's Status/Eol: the official Node.js
  # release schedule (https://github.com/nodejs/Release, schedule.json).
  # Re-check that file when reviewing this list -- do not hand-roll EOL
  # dates from memory, since that is exactly how this list went stale
  # before (issue #73).
  Node      = @{
    # Default is the version `fnm default` selects. Kept as its own key
    # (not "first entry wins") so removing/reordering Versions can't
    # silently change the default.
    Default  = 24
    Versions = @(
      @{
        Version = 22
        Status  = 'Maintenance LTS'
        Eol     = '2027-04-30'
        Reason  = 'Still under maintenance support; kept for projects pinned to v22 while v24 is the default for new work.'
      }
      @{
        Version = 24
        Status  = 'Active LTS'
        Eol     = '2028-04-30'
        Reason  = 'Current Active LTS release; the default version for new work.'
      }
    )
  }

  # Unity Editor version installed via Unity Hub CLI (libs/post-install.ps1).
  #
  # The changeset must match the version exactly, or Unity Hub's
  # `install -v <version> -c <changeset>` fails. When updating Version,
  # update Changeset from the same source in the same change -- never
  # independently.
  Unity     = @{
    Version      = '2022.3.22f1'
    Changeset    = '887be4894c44'
    Reason       = 'Required by VRChat SDK / VCC (VRChat Creator Companion).'
    VerifiedDate = '2026-08-02'
    Sources      = @(
      # VRChat's own current-version page; states the version only, no changeset.
      'https://creators.vrchat.com/sdk/upgrade/current-unity-version/ (VRChat, page last updated 2025-10-03; still names 2022.3.22f1 as of this verification)'
      # Unity's own release API; confirms the version/changeset pairing above.
      'https://services.api.unity.com/unity/editor/release/v1/releases?version=2022.3.22f1 (Unity, confirms download URL contains changeset 887be4894c44)'
    )
  }
}
