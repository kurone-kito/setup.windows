import { spawnSync } from "node:child_process";

const commandName = (name) => {
  if (process.platform !== "win32") {
    return name;
  }

  if (name === "npx") {
    return "npx.cmd";
  }

  return `${name}.exe`;
};

const git = commandName("git");
const npx = commandName("npx");
const pwsh = commandName("pwsh");

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

function collectChangedPaths(args) {
  const result = spawnSync(git, args, {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
  exitForResult(result, `${git} ${args.join(" ")}`);

  return result.stdout
    .split(/\r?\n/)
    .map((path) => path.trim())
    .filter(Boolean);
}

function run(command, args) {
  const isWindowsBatchShim = process.platform === "win32" && command === "npx.cmd";
  const actualCommand = isWindowsBatchShim
    ? process.env.ComSpec ?? "cmd.exe"
    : command;
  const actualArgs = isWindowsBatchShim
    ? ["/d", "/s", "/c", command, ...args]
    : args;
  const result = spawnSync(actualCommand, actualArgs, {
    stdio: "inherit",
  });
  exitForResult(result, `${actualCommand} ${actualArgs.join(" ")}`);
}

const changedPaths = [
  ...collectChangedPaths(["diff", "--no-renames", "--name-only", "HEAD", "--"]),
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
