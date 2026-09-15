import assert from "node:assert/strict";
import test from "node:test";

import { runDelegate } from "../.github/idd/critique-delegate.mjs";

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
