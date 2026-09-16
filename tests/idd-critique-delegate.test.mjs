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
const doubleQuoteEscapes = new Set(["$", "`", '"', "\\", "\n"]);

function shouldEscapeNext(quote, nextCharacter) {
  return quote === null
    || (quote === '"' && doubleQuoteEscapes.has(nextCharacter));
}

function splitPipeline(command) {
  const stages = [];
  let stage = "";
  let quote = null;
  let escaped = false;

  for (let index = 0; index < command.length; index += 1) {
    const character = command[index];
    if (escaped) {
      stage += character;
      escaped = false;
      continue;
    }

    if (character === "\\" && shouldEscapeNext(quote, command[index + 1])) {
      stage += character;
      escaped = true;
      continue;
    }

    if (quote) {
      if (character === quote) {
        quote = null;
      }
      stage += character;
      continue;
    }

    if (character === '"' || character === "'") {
      quote = character;
      stage += character;
      continue;
    }

    if (command.slice(index, index + 2) === "&&") {
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

function splitShellWords(stage) {
  const words = [];
  let word = "";
  let quote = null;
  let hasContent = false;

  const pushWord = () => {
    if (hasContent) {
      words.push(word);
      word = "";
      hasContent = false;
    }
  };

  const text = stage.trim();
  for (let index = 0; index < text.length; index += 1) {
    const character = text[index];
    if (character === "\\" && shouldEscapeNext(quote, text[index + 1])) {
      const nextCharacter = text[index + 1];
      if (nextCharacter === "\n") {
        index += 1;
        continue;
      }
      if (nextCharacter === undefined) {
        word += character;
      } else {
        word += nextCharacter;
        index += 1;
      }
      hasContent = true;
      continue;
    }

    if (quote) {
      if (character === quote) {
        quote = null;
      } else {
        word += character;
      }
      hasContent = true;
      continue;
    }

    if (character === '"' || character === "'") {
      quote = character;
      hasContent = true;
      continue;
    }

    if (/\s/.test(character)) {
      pushWord();
      continue;
    }

    word += character;
    hasContent = true;
  }

  assert.equal(quote, null, `unclosed quote in configured stage: ${stage}`);
  pushWord();
  return words;
}

const knownDispatches = new Map([
  [JSON.stringify(["npx", "-y", "markdownlint-cli2", "**/*.md"]), {
    command: "npx",
    args: ["-y", "markdownlint-cli2", "**/*.md"],
  }],
  [JSON.stringify(["npx", "-y", "cspell", "lint", "**", "--no-progress"]), {
    command: "npx",
    args: ["-y", "cspell", "lint", "**", "--no-progress"],
  }],
  [JSON.stringify([
    "pwsh",
    "-c",
    "Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -EnableExit",
  ]), {
    command: "pwsh",
    args: [
      "-c",
      "Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -EnableExit",
    ],
  }],
  [JSON.stringify(["pwsh", "-c", "Invoke-Pester -Path ./tests/powershell -CI"]), {
    command: "pwsh",
    args: ["-c", "Invoke-Pester -Path ./tests/powershell -CI"],
  }],
]);

function canonicalDispatches() {
  const configured = policy.commands?.["pre-push-validate"];
  assert.equal(typeof configured, "string");

  return splitPipeline(configured).map((stage, index) => {
    const tokens = splitShellWords(stage);
    const dispatch = knownDispatches.get(JSON.stringify(tokens));
    assert.ok(
      dispatch,
      `pre-push-validate stage ${index + 1} is not covered by the delegate: ${tokens.join(" ")}`,
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
    platform: "linux",
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

test("preserves shell token boundaries while parsing policy stages", () => {
  assert.notDeepEqual(
    splitShellWords('npx -y markdownlint-cli2 "**/*.md"'),
    splitShellWords('"npx -y markdownlint-cli2 **/*.md"'),
  );
});

test("preserves non-escaping backslashes inside double quotes", () => {
  const stage = String.raw`pwsh -c "Invoke\-ScriptAnalyzer"`;

  assert.deepEqual(splitShellWords(stage), [
    "pwsh",
    "-c",
    String.raw`Invoke\-ScriptAnalyzer`,
  ]);
});
