#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const policy = JSON.parse(
  readFileSync(new URL("../publication-identities.json", import.meta.url), "utf8"),
);
const oid = /^(?:[a-f0-9]{40}|[a-f0-9]{64})$/i;
const zero = /^0+$/;

export function allowedIdentity(name, email, identities = policy.identities) {
  return identities.some(
    (entry) => entry.name === name && entry.email.toLowerCase() === email.toLowerCase(),
  );
}

export function inspectIdentityLine(line, identities = policy.identities) {
  const match = /^(.*?) <([^<>\r\n]+)>(?: \d+ [+-]\d{4})?$/.exec(line);
  return Boolean(match && allowedIdentity(match[1], match[2], identities));
}

export function inspectMessage(message, identities = policy.identities) {
  const problems = [];
  for (const line of message.split("\n")) {
    const trailer =
      /^\s*(?:>\s*|[-*]\s+)*(co-authored-by|signed-off-by|reviewed-by|acked-by):\s*(.*)$/i.exec(
        line,
      );
    if (trailer && !inspectIdentityLine(trailer[2], identities)) {
      problems.push("unapproved identity trailer");
    }
  }
  // Squash messages may quote author information in prose rather than a trailer.
  for (const email of message.match(
    /[a-z0-9][a-z0-9.!#$%&'*+/=?^_{|}~[\]-]*@[a-z0-9.-]+\.[a-z]{2,}/gi,
  ) ?? []) {
    if (!identities.some((entry) => entry.email.toLowerCase() === email.toLowerCase())) {
      problems.push("unapproved email in message");
    }
  }
  return [...new Set(problems)];
}

function git(args) {
  const result = spawnSync("git", args, { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  // Git's stderr can contain local paths and identities. Never relay it.
  if (result.error || result.status !== 0) {
    throw new Error("Git inspection failed; check that the requested objects are fetched locally.");
  }
  return result.stdout;
}

function requireOid(value) {
  if (!oid.test(value ?? "")) {
    throw new Error("Expected a full Git object ID.");
  }
  return value;
}

export function checkObjects(commits, tags = []) {
  const problems = [];
  for (const sha of new Set(commits)) {
    const raw = git(["cat-file", "commit", requireOid(sha)]);
    const split = raw.indexOf("\n\n");
    const headers = raw.slice(0, split).split("\n");
    for (const field of ["author", "committer"]) {
      const value = headers.find((line) => line.startsWith(`${field} `))?.slice(field.length + 1);
      if (!value || !inspectIdentityLine(value)) {
        problems.push({ sha, reason: `unapproved ${field} identity` });
      }
    }
    for (const reason of inspectMessage(raw.slice(split + 2))) {
      problems.push({ sha, reason });
    }
  }
  for (const sha of new Set(tags)) {
    const raw = git(["cat-file", "tag", requireOid(sha)]);
    const split = raw.indexOf("\n\n");
    const tagger = raw
      .slice(0, split)
      .split("\n")
      .find((line) => line.startsWith("tagger "))
      ?.slice(7);
    if (!tagger || !inspectIdentityLine(tagger)) {
      problems.push({ sha, reason: "unapproved tagger identity" });
    }
    for (const reason of inspectMessage(raw.slice(split + 2))) {
      problems.push({ sha, reason });
    }
  }
  return problems;
}

function listCommits(args) {
  return git(["rev-list", ...args])
    .trim()
    .split("\n")
    .filter(Boolean);
}

function tagObjects(sha, output) {
  let current = sha;
  while (git(["cat-file", "-t", requireOid(current)]).trim() === "tag") {
    output.push(current);
    current = git(["cat-file", "tag", current]).split("\n")[0].slice("object ".length);
  }
}

export function main(args = process.argv.slice(2)) {
  let commits = [];
  const tags = [];
  if (args[0] === "--config" && args.length === 1) {
    for (const field of ["AUTHOR", "COMMITTER"]) {
      if (!inspectIdentityLine(git(["var", `GIT_${field}_IDENT`]).trim())) {
        throw new Error(
          `Unapproved effective ${field.toLowerCase()} identity. Set a publication identity from .github/publication-identities.json.`,
        );
      }
    }
  } else if (args[0] === "--message" && args.length === 2) {
    if (inspectMessage(readFileSync(args[1], "utf8")).length) {
      throw new Error("Unapproved publication identity in commit message. Values withheld.");
    }
  } else if (args[0] === "--range" && args.length === 3) {
    const base = requireOid(args[1]);
    const head = requireOid(args[2]);
    commits = listCommits(zero.test(base) ? [head] : [head, `^${base}`]);
    tagObjects(head, tags);
  } else if (args[0] === "--pre-push" && args.length === 1) {
    for (const line of readFileSync(0, "utf8").split("\n").filter(Boolean)) {
      const fields = line.split(/\s+/);
      if (fields.length !== 4) {
        throw new Error("Invalid pre-push input.");
      }
      const local = requireOid(fields[1]);
      const remote = requireOid(fields[3]);
      if (zero.test(local)) {
        continue;
      }
      // New refs inspect every object not already reachable through fetched remotes.
      commits.push(
        ...listCommits(zero.test(remote) ? [local, "--not", "--remotes"] : [local, `^${remote}`]),
      );
      tagObjects(local, tags);
    }
  } else if (args[0] === "--all" && args.length === 1) {
    commits = listCommits(["--all"]);
    for (const sha of git(["for-each-ref", "refs/tags", "--format=%(objectname)"])
      .trim()
      .split("\n")
      .filter(Boolean)) {
      tagObjects(sha, tags);
    }
  } else {
    throw new Error(
      "Usage: validate-git-identities.mjs --config | --message FILE | --range BASE_SHA HEAD_SHA | --pre-push | --all",
    );
  }
  const problems = checkObjects(commits, tags);
  for (const item of problems) {
    console.error(`[git-identities] ${item.sha.slice(0, 12)}: ${item.reason}`);
  }
  if (problems.length) {
    throw new Error(
      `${problems.length} identity violation(s). Values withheld. See .github/docs/git-publication-privacy.md.`,
    );
  }
  console.log(
    `[git-identities] OK (${new Set(commits).size} commits, ${new Set(tags).size} annotated tags).`,
  );
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  try {
    main();
  } catch (error) {
    console.error(
      `[git-identities] ${error.code ? "Unable to read publication input. Values withheld." : error.message}`,
    );
    process.exitCode = 1;
  }
}
