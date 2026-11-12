import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { ensureEventObjects, fetchEnvironment } from "./fetch-git-event-objects.mjs";

const script = fileURLToPath(new URL("./fetch-git-event-objects.mjs", import.meta.url));
const validator = fileURLToPath(new URL("./validate-git-identities.mjs", import.meta.url));
const approved = { name: "FakieSui", email: "4931583+FakieSui@users.noreply.github.com" };
const privateEmail = "synthetic-legacy@example.invalid";

function fixture() {
  const directory = mkdtempSync(join(tmpdir(), "git-event-objects-"));
  const remote = join(directory, "origin.git");
  const source = join(directory, "source");
  const clone = join(directory, "clone");
  const env = {
    ...process.env,
    GITHUB_ACTIONS: "",
    GITHUB_TOKEN: "",
    GIT_AUTHOR_NAME: approved.name,
    GIT_AUTHOR_EMAIL: approved.email,
    GIT_COMMITTER_NAME: approved.name,
    GIT_COMMITTER_EMAIL: approved.email,
    GIT_TERMINAL_PROMPT: "0",
  };
  function git(cwd, args, overrides = {}) {
    const p = spawnSync("git", args, {
      cwd,
      env: { ...env, ...overrides },
      encoding: "utf8",
      timeout: 15_000,
    });
    assert.equal(p.status, 0, p.stderr);
    return p.stdout.trim();
  }
  git(directory, ["init", "--bare", "--quiet", remote]);
  git(directory, ["init", "--quiet", source]);
  for (const key of ["commit.gpgsign", "tag.gpgsign"]) git(source, ["config", key, "false"]);
  git(source, ["config", "core.hooksPath", "/dev/null"]);
  git(source, ["checkout", "-q", "-b", "test"]);
  git(source, ["commit", "--allow-empty", "-q", "-m", "baseline"]);
  const base = git(source, ["rev-parse", "HEAD"]);
  git(source, ["commit", "--allow-empty", "-q", "-m", "same content"], {
    GIT_AUTHOR_EMAIL: privateEmail,
  });
  const orphan = git(source, ["rev-parse", "HEAD"]);
  git(source, ["remote", "add", "origin", remote]);
  git(source, ["push", "-q", "origin", "HEAD:refs/heads/test"]);
  git(source, ["reset", "--hard", base]);
  git(source, ["commit", "--allow-empty", "-q", "-m", "same content"]);
  const head = git(source, ["rev-parse", "HEAD"]);
  git(source, ["push", "-q", "--force-with-lease", "origin", "HEAD:refs/heads/test"]);
  git(directory, [
    "clone",
    "--quiet",
    "--no-local",
    "--no-tags",
    "--branch",
    "test",
    remote,
    clone,
  ]);
  function invoke(baseSha, headSha, overrides = {}) {
    return spawnSync(process.execPath, [script, baseSha, headSha], {
      cwd: clone,
      env: { ...env, ...overrides },
      encoding: "utf8",
      timeout: 20_000,
    });
  }
  return {
    directory,
    remote,
    source,
    clone,
    base,
    orphan,
    head,
    git,
    env,
    invoke,
    cleanup: () => rmSync(directory, { recursive: true, force: true }),
  };
}

test("fetches an unadvertised pre-rewrite base into a fresh clone without restoring a ref", () => {
  const f = fixture();
  try {
    assert.notEqual(
      spawnSync("git", ["cat-file", "-e", `${f.orphan}^{commit}`], { cwd: f.clone }).status,
      0,
    );
    const refs = f.git(f.clone, ["show-ref"]);
    const result = f.invoke(f.orphan, f.head);
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /1 fetched/);
    assert.ok(!`${result.stdout}${result.stderr}`.includes(privateEmail));
    assert.equal(f.git(f.clone, ["show-ref"]), refs);
    assert.equal(f.git(f.clone, ["rev-parse", "refs/remotes/origin/test"]), f.head);
    assert.throws(() => readFileSync(join(f.clone, ".git", "FETCH_HEAD")));
    const validation = spawnSync(process.execPath, [validator, "--range", f.orphan, f.head], {
      cwd: f.clone,
      env: f.env,
      encoding: "utf8",
    });
    assert.equal(validation.status, 0, validation.stderr);
    assert.match(validation.stdout, /OK \(1 commits/);
    // The old private identity is a comparison boundary, never an exemption or an incoming commit.
    const all = spawnSync(process.execPath, [validator, "--all"], {
      cwd: f.clone,
      env: f.env,
      encoding: "utf8",
    });
    assert.equal(all.status, 0); // unreferenced orphan does not enter --all refs
  } finally {
    f.cleanup();
  }
});

test("unavailable base fails closed without changing refs or leaking provider errors", () => {
  const f = fixture();
  try {
    const refs = f.git(f.clone, ["show-ref"]);
    const result = f.invoke("f".repeat(40), f.head);
    assert.equal(result.status, 1);
    assert.match(
      result.stderr,
      /Cannot fetch the pinned base event object; identity validation remains blocked/,
    );
    assert.ok(!result.stderr.includes(f.remote));
    assert.equal(f.git(f.clone, ["show-ref"]), refs);
  } finally {
    f.cleanup();
  }
});

test("zero base is skipped, but an annotated tag head is fetched and its tagger still checked", () => {
  const f = fixture();
  try {
    assert.equal(f.invoke("0".repeat(40), f.head).status, 0);
    f.git(f.source, ["tag", "-a", "release", "-m", "release"]);
    const tag = f.git(f.source, ["rev-parse", "refs/tags/release"]);
    f.git(f.source, ["push", "-q", "origin", "refs/tags/release"]);
    const refs = f.git(f.clone, ["show-ref"]);
    const result = f.invoke(f.base, tag);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(f.git(f.clone, ["show-ref"]), refs);
    const validation = spawnSync(process.execPath, [validator, "--range", f.base, tag], {
      cwd: f.clone,
      env: f.env,
      encoding: "utf8",
    });
    assert.equal(validation.status, 0, validation.stderr);
    assert.match(validation.stdout, /1 annotated tags/);
  } finally {
    f.cleanup();
  }
});

test("rejects option/ref injection and a deleted or malformed head before any Git operation", () => {
  for (const [base, head] of [
    ["--upload-pack=malicious", "a".repeat(40)],
    ["a".repeat(40), "refs/heads/test"],
    ["a".repeat(40), "0".repeat(40)],
    ["a".repeat(40), "b".repeat(40) + "\n"],
    ["a".repeat(40), `a${"\n"}${"b".repeat(40)}`],
  ])
    assert.throws(
      () => ensureEventObjects(base, head, { cwd: "/nonexistent" }),
      /Invalid (?:base|head) object ID/,
    );
});

test("rejects shallow checkouts instead of silently omitting earlier incoming commits", () => {
  const f = fixture();
  try {
    f.git(f.directory, [
      "clone",
      "-q",
      "--depth=1",
      "--branch",
      "test",
      `file://${f.remote}`,
      join(f.directory, "shallow"),
    ]);
    assert.throws(
      () => ensureEventObjects(f.base, f.head, { cwd: join(f.directory, "shallow"), env: f.env }),
      /non-shallow checkout/,
    );
  } finally {
    f.cleanup();
  }
});

test("authenticated fetch requires the exact trusted repository and leaves credentials only in child env", () => {
  const token = "synthetic-token-never-print";
  const parent = {
    GITHUB_ACTIONS: "true",
    GITHUB_TOKEN: token,
    GITHUB_SERVER_URL: "https://github.com",
    GITHUB_REPOSITORY: "Suigar-Gaming/suigar",
    GIT_TRACE_CURL: "/private/log",
  };
  const child = fetchEnvironment("https://github.com/Suigar-Gaming/suigar.git", parent);
  assert.equal(child.GIT_CONFIG_COUNT, "3");
  assert.equal(child.GIT_CONFIG_KEY_0, "credential.helper");
  assert.equal(child.GIT_CONFIG_VALUE_0, "");
  assert.equal(child.GIT_CONFIG_KEY_1, "http.followRedirects");
  assert.equal(child.GIT_CONFIG_VALUE_1, "false");
  assert.equal(
    child.GIT_CONFIG_KEY_2,
    "http.https://github.com/Suigar-Gaming/suigar.git.extraheader",
  );
  assert.equal(
    child.GIT_CONFIG_VALUE_2,
    `AUTHORIZATION: basic ${Buffer.from(`x-access-token:${token}`).toString("base64")}`,
  );
  assert.equal(child.GIT_TRACE_CURL, "0");
  assert.equal(parent.GIT_CONFIG_COUNT, undefined);
  for (const origin of [
    "https://github.com.attacker.invalid/Suigar-Gaming/suigar.git",
    "https://github.com/attacker/suigar.git",
    "https://user@github.com/Suigar-Gaming/suigar.git",
    "https://github.com/Suigar-Gaming/suigar.git?redirect=evil",
    "file:///private/origin",
    "git@github.com:Suigar-Gaming/suigar.git",
  ])
    assert.throws(() => fetchEnvironment(origin, parent), /origin/);
  assert.throws(
    () =>
      fetchEnvironment("https://github.com/Suigar-Gaming/suigar.git", {
        ...parent,
        GITHUB_TOKEN: "",
      }),
    /token is required/,
  );
});

test("privacy workflow checks incoming objects with read-only ephemeral authentication", () => {
  const workflow = readFileSync(
    new URL("../workflows/publication-privacy.yaml", import.meta.url),
    "utf8",
  );
  const event = readFileSync(new URL("./check-publication-event.mjs", import.meta.url), "utf8");
  assert.match(workflow, /persist-credentials: false/);
  assert.match(workflow, /permissions:\n  contents: read/);
  assert.match(workflow, /GITHUB_TOKEN: \$\{\{ github\.token \}\}/);
  assert.match(workflow, /node (?:\.github\/)?scripts\/check-publication-event\.mjs/);
  const prepare = event.search(/ensureEventObjects\(pr\.base\.sha,\s*pr\.head\.sha\)/);
  const verify = event.search(
    /main\(\[\s*['"]--range['"],\s*pr\.base\.sha,\s*pr\.head\.sha,?\s*\]\)/,
  );
  assert.ok(prepare >= 0 && prepare < verify);
});

test("privacy job never installs dependencies, publishes packages or requests write permission", () => {
  const workflow = readFileSync(
    new URL("../workflows/publication-privacy.yaml", import.meta.url),
    "utf8",
  );
  assert.doesNotMatch(workflow, /(?:contents|actions|pull-requests|id-token): write/);
  assert.doesNotMatch(workflow, /pnpm install|npm install|pnpm run release|changeset publish/);
  assert.match(workflow, /fetch-depth: 0/);
  assert.match(workflow, /timeout-minutes: 5/);
});
