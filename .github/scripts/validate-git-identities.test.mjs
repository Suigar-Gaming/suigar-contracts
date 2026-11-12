import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { allowedIdentity, inspectMessage } from "./validate-git-identities.mjs";

const scanner = fileURLToPath(new URL("./validate-git-identities.mjs", import.meta.url));
const safe = { name: "FakieSui", email: "4931583+FakieSui@users.noreply.github.com" };
const role = { name: "Furbor", email: "355990620+Furbor@users.noreply.github.com" };
const personal = { name: "Synthetic Private Name", email: "synthetic@example.invalid" };

function fixture() {
  const cwd = mkdtempSync(path.join(tmpdir(), "git-publication-"));
  const env = {
    ...process.env,
    GIT_AUTHOR_NAME: safe.name,
    GIT_AUTHOR_EMAIL: safe.email,
    GIT_COMMITTER_NAME: safe.name,
    GIT_COMMITTER_EMAIL: safe.email,
  };
  function git(args, overrides = {}) {
    const result = spawnSync("git", args, { cwd, env: { ...env, ...overrides }, encoding: "utf8" });
    assert.equal(result.status, 0, result.stderr);
    return result.stdout.trim();
  }
  git(["init", "--quiet"]);
  git(["config", "commit.gpgsign", "false"]);
  git(["config", "tag.gpgsign", "false"]);
  git(["config", "core.hooksPath", "/dev/null"]);
  function commit(message = "test", overrides = {}) {
    git(["commit", "--allow-empty", "--quiet", "-m", message], overrides);
    return git(["rev-parse", "HEAD"]);
  }
  function scan(args, input, overrides = {}) {
    return spawnSync(process.execPath, [scanner, ...args], {
      cwd,
      env: { ...env, ...overrides },
      encoding: "utf8",
      input,
    });
  }
  return { cwd, git, commit, scan, cleanup: () => rmSync(cwd, { recursive: true, force: true }) };
}

function redacted(result) {
  assert.equal(result.status, 1);
  assert.ok(!`${result.stdout}${result.stderr}`.includes(personal.name));
  assert.ok(!`${result.stdout}${result.stderr}`.includes(personal.email));
}

void test("requires an approved name/email pair, including for noreply addresses", () => {
  assert.equal(allowedIdentity(safe.name, safe.email), true);
  assert.equal(allowedIdentity(personal.name, safe.email), false);
  assert.equal(allowedIdentity(safe.name, personal.email), false);
  assert.equal(allowedIdentity(safe.name, "1+unapproved@users.noreply.github.com"), false);
});

void test("recognizes attribution trailers anywhere in the message", () => {
  for (const field of ["Co-authored-by", "Signed-off-by", "Reviewed-by", "Acked-by"]) {
    assert.ok(
      inspectMessage(`test\n\n${field}: ${personal.name} <${personal.email}>\n\nmore`).includes(
        "unapproved identity trailer",
      ),
    );
    assert.deepEqual(inspectMessage(`${field}: ${safe.name} <${safe.email}>`), []);
    assert.equal(inspectMessage(`${field}: malformed`).length, 1);
  }
});

void test("scans every incoming commit even when the newest author is safe", () => {
  const f = fixture();
  try {
    const base = f.commit();
    f.commit("bad historical author", {
      GIT_AUTHOR_NAME: personal.name,
      GIT_AUTHOR_EMAIL: personal.email,
    });
    const head = f.commit("safe latest");
    const result = f.scan(["--range", base, head]);
    redacted(result);
    assert.match(result.stderr, /unapproved author/);
  } finally {
    f.cleanup();
  }
});

void test("checks committers independently and keeps existing historical violations outside the incoming range", () => {
  const f = fixture();
  try {
    const base = f.commit("legacy", {
      GIT_AUTHOR_NAME: personal.name,
      GIT_AUTHOR_EMAIL: personal.email,
    });
    const head = f.commit();
    assert.equal(f.scan(["--range", base, head]).status, 0);
    const bad = f.commit("committer", {
      GIT_COMMITTER_NAME: personal.name,
      GIT_COMMITTER_EMAIL: personal.email,
    });
    const result = f.scan(["--range", head, bad]);
    redacted(result);
    assert.match(result.stderr, /unapproved committer/);
    redacted(f.scan(["--all"]));
  } finally {
    f.cleanup();
  }
});

void test("checks effective Git identity including environment overrides", () => {
  const f = fixture();
  try {
    assert.equal(f.scan(["--config"]).status, 0);
    redacted(f.scan(["--config"], undefined, { GIT_COMMITTER_EMAIL: personal.email }));
  } finally {
    f.cleanup();
  }
});

void test("pre-push handles new branches, deletion, unsafe trailers and annotated taggers", () => {
  const f = fixture();
  try {
    const base = f.commit();
    const zeros = "0".repeat(40);
    assert.equal(
      f.scan(["--pre-push"], `refs/heads/test ${base} refs/heads/test ${zeros}\n`).status,
      0,
    );
    assert.equal(
      f.scan(["--pre-push"], `refs/heads/test ${zeros} refs/heads/test ${base}\n`).status,
      0,
    );
    const bad = f.commit(`trailer\n\nCo-authored-by: ${personal.name} <${personal.email}>`);
    redacted(f.scan(["--pre-push"], `refs/heads/test ${bad} refs/heads/test ${base}\n`));
    f.git(["tag", "-a", "test", base, "-m", "tag"], {
      GIT_COMMITTER_NAME: personal.name,
      GIT_COMMITTER_EMAIL: personal.email,
    });
    const tag = f.git(["rev-parse", "refs/tags/test"]);
    const result = f.scan(["--pre-push"], `refs/tags/test ${tag} refs/tags/test ${zeros}\n`);
    redacted(result);
    assert.match(result.stderr, /unapproved tagger/);
  } finally {
    f.cleanup();
  }
});

void test("fails closed on missing history and rejects Git option injection", () => {
  const f = fixture();
  try {
    const head = f.commit();
    assert.equal(f.scan(["--range", "1".repeat(40), head]).status, 1);
    assert.equal(f.scan(["--range", "--all", head]).status, 1);
  } finally {
    f.cleanup();
  }
});

void test("checks nested squash attribution and private email copied into prose", () => {
  for (const message of [
    `Squash title\n\n* Imported change\n\nCo-authored-by: ${personal.name} <${personal.email}>\n\nFinal note`,
    `> Co-authored-by: ${personal.name} <${personal.email}>`,
    `* Signed-off-by: ${personal.name} <${personal.email}>`,
    `Co-authored-by:\n  ${personal.name} <${personal.email}>`,
    `Please contact ${personal.email} about this change.`,
  ]) {
    assert.ok(inspectMessage(message).length > 0);
  }
  assert.deepEqual(inspectMessage(`Co-authored-by: ${safe.name} <${safe.email}>\n\nSafe note`), []);
  assert.deepEqual(inspectMessage(`Approved contact: \`${safe.email}\` or **${safe.email}**.`), []);
  assert.deepEqual(
    inspectMessage(
      "Co-authored-by: github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>",
    ),
    [],
  );
});

void test("commit-msg rejects unsafe data before the local commit", () => {
  const f = fixture();
  try {
    const messageFile = path.join(f.cwd, "message");
    writeFileSync(messageFile, `test\n\nCo-authored-by: ${personal.name} <${personal.email}>`);
    redacted(f.scan(["--message", messageFile]));
    writeFileSync(messageFile, "Safe commit message");
    assert.equal(f.scan(["--message", messageFile]).status, 0);
  } finally {
    f.cleanup();
  }
});

void test("PR metadata-only event checks title/body without executing it or echoing values", () => {
  const f = fixture();
  try {
    const base = f.commit();
    const head = f.commit();
    const eventFile = path.join(f.cwd, "event.json");
    const marker = path.join(f.cwd, "must-not-exist");
    const ci = fileURLToPath(new URL("./check-publication-event.mjs", import.meta.url));
    function event(body, title = "Feature") {
      writeFileSync(
        eventFile,
        JSON.stringify({
          action: "edited",
          pull_request: { title, body, base: { sha: base }, head: { sha: head } },
        }),
      );
      return spawnSync(process.execPath, [ci], {
        cwd: f.cwd,
        env: { ...process.env, GITHUB_EVENT_NAME: "pull_request", GITHUB_EVENT_PATH: eventFile },
        encoding: "utf8",
      });
    }
    redacted(event(`Co-authored-by: ${personal.name} <${personal.email}>`));
    redacted(event("", `Review ${personal.email}`));
    assert.equal(event(`Literal $(touch ${marker}) and \`touch ${marker}\``).status, 0);
    assert.equal(event(`Co-authored-by: ${safe.name} <${safe.email}>`).status, 0);
    assert.equal(existsSync(marker), false);
  } finally {
    f.cleanup();
  }
});

void test("new branch/tag CI inspects the delta and tagger without rejecting legacy main authors", () => {
  const f = fixture();
  try {
    const base = f.commit("legacy base", {
      GIT_AUTHOR_NAME: personal.name,
      GIT_AUTHOR_EMAIL: personal.email,
    });
    f.git(["update-ref", "refs/remotes/origin/main", base]);
    const head = f.commit();
    const eventFile = path.join(f.cwd, "event.json");
    const ci = fileURLToPath(new URL("./check-publication-event.mjs", import.meta.url));
    function push(sha) {
      writeFileSync(
        eventFile,
        JSON.stringify({ before: "0".repeat(40), after: sha, deleted: false }),
      );
      return spawnSync(process.execPath, [ci], {
        cwd: f.cwd,
        env: { ...process.env, GITHUB_EVENT_NAME: "push", GITHUB_EVENT_PATH: eventFile },
        encoding: "utf8",
      });
    }
    assert.equal(push(head).status, 0);
    f.git(["tag", "-a", "unsafe", head, "-m", "tag"], {
      GIT_COMMITTER_NAME: personal.name,
      GIT_COMMITTER_EMAIL: personal.email,
    });
    redacted(push(f.git(["rev-parse", "refs/tags/unsafe"])));
    const bad = f.commit("new private author", {
      GIT_AUTHOR_NAME: personal.name,
      GIT_AUTHOR_EMAIL: personal.email,
    });
    redacted(push(bad));
  } finally {
    f.cleanup();
  }
});

test("publication policy retires identity exemptions and approves the exact role pair", () => {
  const policy = JSON.parse(
    readFileSync(new URL("../publication-identities.json", import.meta.url), "utf8"),
  );
  assert.deepEqual(policy.identityExemptions ?? [], []);
  assert.equal(allowedIdentity(role.name, role.email), true);
  assert.equal(allowedIdentity(role.name, role.email.toUpperCase()), true);
  assert.equal(allowedIdentity(role.name, safe.email), false);
  assert.equal(allowedIdentity(safe.name, role.email), false);
});

test("accepts the approved role for authors, committers, trailers and annotated taggers", () => {
  const f = fixture();
  try {
    const base = f.commit();
    f.commit("approved author", { GIT_AUTHOR_NAME: role.name, GIT_AUTHOR_EMAIL: role.email });
    f.commit("approved committer", {
      GIT_COMMITTER_NAME: role.name,
      GIT_COMMITTER_EMAIL: role.email,
    });
    const message = ["Co-authored-by", "Signed-off-by", "Reviewed-by", "Acked-by"]
      .map((field) => `${field}: ${role.name} <${role.email}>`)
      .join("\n");
    const head = f.commit(`approved trailers\n\n${message}`);
    assert.equal(f.scan(["--range", base, head]).status, 0);
    assert.equal(
      f.scan(["--config"], undefined, {
        GIT_AUTHOR_NAME: role.name,
        GIT_AUTHOR_EMAIL: role.email,
        GIT_COMMITTER_NAME: role.name,
        GIT_COMMITTER_EMAIL: role.email,
      }).status,
      0,
    );
    f.git(["tag", "-a", "approved-role", head, "-m", "approved tag"], {
      GIT_COMMITTER_NAME: role.name,
      GIT_COMMITTER_EMAIL: role.email,
    });
    const tag = f.git(["rev-parse", "refs/tags/approved-role"]);
    assert.equal(
      f.scan(
        ["--pre-push"],
        `refs/tags/approved-role ${tag} refs/tags/approved-role ${"0".repeat(40)}\n`,
      ).status,
      0,
    );
  } finally {
    f.cleanup();
  }
});

test("rejects every private trailer in an older incoming commit and withholds its values", () => {
  const f = fixture();
  try {
    for (const field of ["Co-authored-by", "Signed-off-by", "Reviewed-by", "Acked-by"]) {
      const base = f.commit();
      f.commit(`private attribution\n\n${field}: ${personal.name} <${personal.email}>`);
      const head = f.commit("approved latest", {
        GIT_AUTHOR_NAME: role.name,
        GIT_AUTHOR_EMAIL: role.email,
      });
      const range = f.scan(["--range", base, head]);
      redacted(range);
      assert.match(range.stderr, /unapproved identity trailer/);
      redacted(f.scan(["--pre-push"], `refs/heads/test ${head} refs/heads/test ${base}\n`));
    }
  } finally {
    f.cleanup();
  }
});
