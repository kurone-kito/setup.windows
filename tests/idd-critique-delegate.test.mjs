import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { runDelegate } from "../.github/idd/critique-delegate.mjs";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const policy = JSON.parse(readFileSync(
  resolve(repositoryRoot, ".github/idd/config.json"),
  "utf8",
));

function splitPipeline(command) {
  const stages = [];
  let stage = "";
  let inDoubleQuotes = false;

  for (let index = 0; index < command.length; index += 1) {
    const character = command[index];
    if (character === '"' && command[index - 1] !== "\\") {
      inDoubleQuotes = !inDoubleQuotes;
    }

    if (!inDoubleQuotes && command.slice(index, index + 2) === "&&") {
      stages.push(stage.trim());
      stage = "";
      index += 1;
      continue;
    }

    stage += character;
  }

  stages.push(stage.trim());
  return stages;
}

function normalizeConfiguredStage(stage) {
  return stage.replace(/"([^"]*)"/g, "$1").replace(/\s+/g, " ").trim();
}

const knownDispatches = new Map([
  ["npx -y markdownlint-cli2 **/*.md", {
    command: "npx",
    args: ["-y", "markdownlint-cli2", "**/*.md"],
  }],
  ["npx -y cspell lint ** --no-progress", {
    command: "npx",
    args: ["-y", "cspell", "lint", "**", "--no-progress"],
  }],
  ["pwsh -c Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -EnableExit", {
    command: "pwsh",
    args: [
      "-c",
      "Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -EnableExit",
    ],
  }],
  ["pwsh -c Invoke-Pester -Path ./tests/powershell -CI", {
    command: "pwsh",
    args: ["-c", "Invoke-Pester -Path ./tests/powershell -CI"],
  }],
]);

function canonicalDispatches() {
  const configured = policy.commands?.["pre-push-validate"];
  assert.equal(typeof configured, "string");

  return splitPipeline(configured).map((stage, index) => {
    const normalized = normalizeConfiguredStage(stage);
    const dispatch = knownDispatches.get(normalized);
    assert.ok(
      dispatch,
      `pre-push-validate stage ${index + 1} is not covered by the delegate: ${normalized}`,
    );
    return dispatch;
  });
}

function createStubSpawn(pathOutputs) {
  const calls = [];
  let gitCall = 0;

  const spawn = (command, args, options) => {
    calls.push({ command, args, options });
    if (command === "git" || command === "git.exe") {
      return {
        error: null,
        status: 0,
        stderr: "",
        stdout: pathOutputs[gitCall++] ?? "",
      };
    }
    return { error: null, status: 0, stderr: "" };
  };

  return { calls, spawn };
}

function runWithPaths(pathOutputs, options = {}) {
  const stubs = createStubSpawn(pathOutputs);
  const result = runDelegate({
    env: { ComSpec: "C:\\Windows\\System32\\cmd.exe" },
    spawn: stubs.spawn,
    ...options,
  });
  return { calls: stubs.calls, result };
}

test("skips PowerShell checks for a Markdown-only change", () => {
  const { calls, result } = runWithPaths([
    "docs/working.md\0",
    "docs/committed.md\0",
    "notes.txt\0",
  ]);

  assert.equal(result.hasPowerShellChange, false);
  assert.deepEqual(
    calls.slice(3).map(({ command }) => command),
    ["npx", "npx"],
  );
  assert.equal(calls[0].args[calls[0].args.indexOf("--") - 1], "-z");
});

for (const extension of ["ps1", "psd1", "psm1"]) {
  test(`runs PowerShell checks for a .${extension} change`, () => {
    const { calls, result } = runWithPaths([
      `scripts/changed.${extension}\0`,
      "docs/committed.md\0",
      "notes.txt\0",
    ]);

    assert.equal(result.hasPowerShellChange, true);
    assert.deepEqual(
      calls.slice(3).map(({ command }) => command),
      ["npx", "npx", "pwsh", "pwsh"],
    );
  });
}

test("launches npx.cmd through ComSpec on Windows", () => {
  const { calls } = runWithPaths([
    "docs/working.md\0",
    "docs/committed.md\0",
    "notes.txt\0",
  ], { platform: "win32" });

  assert.equal(calls[0].command, "git.exe");
  assert.deepEqual(calls[3].args.slice(0, 4), [
    "/d",
    "/s",
    "/c",
    "npx.cmd",
  ]);
  assert.equal(calls[3].command, "C:\\Windows\\System32\\cmd.exe");
});

test("keeps validation dispatch synchronized with pre-push policy", () => {
  const { calls } = runWithPaths([
    "scripts/changed.ps1\0",
    "docs/committed.md\0",
    "notes.txt\0",
  ]);

  assert.deepEqual(
    calls.slice(3).map(({ command, args }) => ({ command, args })),
    canonicalDispatches(),
  );
});
