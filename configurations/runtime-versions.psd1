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

  # Unity CLI (`unity` binary, libs/unity-cli-installer.ps1) -- not the
  # Unity Editor itself. Pinned because the CLI is still experimental
  # (Unity's own docs: "The features and documentation might change in
  # an upcoming release.").
  #
  # Target is passed to install.ps1's -Target; Channel is passed to
  # -Channel / $env:UNITY_CLI_CHANNEL, though install.ps1's own source
  # shows -Channel only affects "latest" resolution -- once Target is a
  # pinned version (not "latest"), install.ps1 fetches that version's
  # own manifest directly and Channel has no functional effect. Kept
  # here anyway to record which channel this pinned version came from.
  UnityCli  = @{
    Target       = '1.0.0-beta.3'
    Channel      = 'beta'
    Reason       = 'CLI is experimental; the stable/GA manifest returns HTTP 404 (no stable release published yet) as of VerifiedDate -- beta is not merely preferred, it is the only channel with any build.'
    VerifiedDate = '2026-08-02'
    Sources      = @(
      # The stable/GA manifest itself, confirming no build exists yet.
      'https://public-cdn.cloud.unity3d.com/hub/prod/cli/latest.json (Unity CDN, HTTP 404 as of VerifiedDate)'
      # The beta manifest, confirming the pinned version and its availability.
      'https://public-cdn.cloud.unity3d.com/hub/prod/cli/latest-beta.json (Unity CDN, HTTP 200, version 1.0.0-beta.3 as of VerifiedDate)'
    )
  }
}
