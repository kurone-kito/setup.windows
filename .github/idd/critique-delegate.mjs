import { spawnSync } from "node:child_process";
import { pathToFileURL } from "node:url";

const commandName = (name, platform) => {
  if (platform !== "win32") {
    return name;
  }

  if (name === "npx") {
    return "npx.cmd";
  }

  return `${name}.exe`;
};

function exitForResult(result, command) {
  if (result.error) {
    console.error(`${command} failed to start: ${result.error.message}`);
    process.exit(1);
  }

  if (result.status !== 0) {
    if (result.stderr) {
      process.stderr.write(result.stderr);
    }
    process.exit(result.status ?? 1);
  }
}

export function runDelegate({
  env = process.env,
  platform = process.platform,
  spawn = spawnSync,
} = {}) {
  const git = commandName("git", platform);
  const npx = commandName("npx", platform);
  const pwsh = commandName("pwsh", platform);

  function collectChangedPaths(args) {
    const separatorIndex = args.indexOf("--");
    const nulArgs = separatorIndex === -1
      ? [...args, "-z"]
      : [
          ...args.slice(0, separatorIndex),
          "-z",
          ...args.slice(separatorIndex),
        ];
    const result = spawn(git, nulArgs, {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
    exitForResult(result, `${git} ${nulArgs.join(" ")}`);

    return result.stdout
      .split("\0")
      .filter(Boolean);
  }

  function run(command, args) {
    const isWindowsBatchShim = platform === "win32" && command === "npx.cmd";
    const actualCommand = isWindowsBatchShim
      ? env.ComSpec ?? "cmd.exe"
      : command;
    const actualArgs = isWindowsBatchShim
      ? ["/d", "/s", "/c", command, ...args]
      : args;
    const result = spawn(actualCommand, actualArgs, {
      stdio: "inherit",
    });
    exitForResult(result, `${actualCommand} ${actualArgs.join(" ")}`);
  }

  const changedPaths = [
    ...collectChangedPaths([
      "diff",
      "--no-renames",
      "--name-only",
      "HEAD",
      "--",
    ]),
    ...collectChangedPaths([
      "diff",
      "--no-renames",
      "--name-only",
      "origin/master...HEAD",
      "--",
    ]),
    ...collectChangedPaths(["ls-files", "--others", "--exclude-standard"]),
  ];

  const hasPowerShellChange = changedPaths.some((path) =>
    /\.(ps1|psd1|psm1)$/i.test(path),
  );

  run(npx, ["-y", "markdownlint-cli2", "**/*.md"]);
  run(npx, ["-y", "cspell", "lint", "**", "--no-progress"]);

  if (hasPowerShellChange) {
    run(pwsh, [
      "-c",
      "Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -EnableExit",
    ]);
    run(pwsh, ["-c", "Invoke-Pester -Path ./tests/powershell -CI"]);
  }

  return { changedPaths, hasPowerShellChange };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  runDelegate();
}
