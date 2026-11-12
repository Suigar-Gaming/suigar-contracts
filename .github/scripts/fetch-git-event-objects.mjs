#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const objectId = /^(?:[a-f0-9]{40}|[a-f0-9]{64})$/i;
const zeroId = /^0+$/;

function requireObjectId(value, role, allowZero = false) {
  if (
    typeof value !== "string" ||
    ![40, 64].includes(value.length) ||
    !objectId.test(value) ||
    (!allowZero && zeroId.test(value))
  )
    throw new Error(`Invalid ${role} object ID.`);
  return value;
}

function git(args, { cwd, env }, timeout = 15_000) {
  return spawnSync("git", args, {
    cwd,
    env,
    encoding: "utf8",
    timeout,
    maxBuffer: 8 * 1024 * 1024,
  });
}

function hasCommitObject(sha, context) {
  return git(["cat-file", "-e", `${sha}^{commit}`], context).status === 0;
}

/** Credentials stay in the fetch subprocess environment, never Git config or command arguments. */
export function fetchEnvironment(origin, env) {
  const child = { ...env, GIT_TERMINAL_PROMPT: "0", GCM_INTERACTIVE: "Never" };
  for (const name of [
    "GIT_TRACE",
    "GIT_TRACE_CURL",
    "GIT_CURL_VERBOSE",
    "GIT_TRACE_PACKET",
    "GIT_TRACE2",
    "GIT_TRACE2_EVENT",
    "GIT_TRACE2_PERF",
  ])
    child[name] = "0";
  const token = env.GITHUB_TOKEN;
  if (!token && env.GITHUB_ACTIONS !== "true") return child;
  if (!token)
    throw new Error("A read-only GitHub token is required to fetch missing event objects.");
  let server, remote;
  try {
    server = new URL(env.GITHUB_SERVER_URL);
    remote = new URL(origin);
  } catch {
    throw new Error("Cannot verify the GitHub repository origin for authenticated fetch.");
  }
  const repository = env.GITHUB_REPOSITORY;
  if (
    !repository ||
    !repository
      .split("/")
      .every((part) => /^[a-z0-9_.-]+$/i.test(part) && ![".", ".."].includes(part)) ||
    repository.split("/").length !== 2 ||
    server.protocol !== "https:" ||
    server.pathname !== "/" ||
    server.username ||
    server.password ||
    server.search ||
    server.hash ||
    remote.protocol !== "https:" ||
    remote.origin !== server.origin ||
    remote.username ||
    remote.password ||
    remote.search ||
    remote.hash ||
    remote.pathname
      .replace(/\/$/, "")
      .replace(/\.git$/i, "")
      .toLowerCase() !== `/${repository}`.toLowerCase()
  )
    throw new Error("Authenticated fetch origin does not match this GitHub repository.");
  const count = Number(child.GIT_CONFIG_COUNT ?? 0);
  if (!Number.isInteger(count) || count < 0 || count > 100)
    throw new Error("Invalid transient Git configuration.");
  const entries = [
    ["credential.helper", ""],
    ["http.followRedirects", "false"],
    [
      `http.${remote.href.replace(/\/$/, "")}.extraheader`,
      `AUTHORIZATION: basic ${Buffer.from(`x-access-token:${token}`).toString("base64")}`,
    ],
  ];
  for (const [offset, [key, value]] of entries.entries()) {
    child[`GIT_CONFIG_KEY_${count + offset}`] = key;
    child[`GIT_CONFIG_VALUE_${count + offset}`] = value;
  }
  child.GIT_CONFIG_COUNT = String(count + entries.length);
  return child;
}

export function ensureEventObjects(base, head, { cwd = process.cwd(), env = process.env } = {}) {
  requireObjectId(base, "base", true);
  requireObjectId(head, "head");
  const context = { cwd, env: { ...env, GIT_NO_LAZY_FETCH: "1", GIT_TERMINAL_PROMPT: "0" } };
  const shallow = git(["rev-parse", "--is-shallow-repository"], context);
  if (shallow.status !== 0 || shallow.stdout.trim() !== "false")
    throw new Error("Event identity validation requires a complete, non-shallow checkout.");
  const requested = [...new Set([...(zeroId.test(base) ? [] : [base]), head])];
  const missing = requested.filter((sha) => !hasCommitObject(sha, context));
  if (!missing.length) return { fetched: 0 };
  const origin = git(["remote", "get-url", "origin"], context);
  if (origin.status !== 0 || !origin.stdout.trim())
    throw new Error("Repository origin is unavailable.");
  const fetchContext = { cwd, env: fetchEnvironment(origin.stdout.trim(), env) };
  for (const sha of missing) {
    // Fetch only the event's pinned object and ancestry. No branch, tag or FETCH_HEAD is written.
    const fetched = git(
      [
        "fetch",
        "--no-tags",
        "--no-write-fetch-head",
        "--no-recurse-submodules",
        "--filter=blob:none",
        "origin",
        sha,
      ],
      fetchContext,
      60_000,
    );
    if (fetched.error || fetched.status !== 0 || !hasCommitObject(sha, context))
      throw new Error(
        `Cannot fetch the pinned ${sha === head ? "head" : "base"} event object; identity validation remains blocked.`,
      );
  }
  return { fetched: missing.length };
}

export function main(args = process.argv.slice(2)) {
  if (args.length !== 2) throw new Error("Usage: fetch-git-event-objects.mjs BASE_SHA HEAD_SHA");
  const result = ensureEventObjects(args[0], args[1]);
  console.log(`[git-event-objects] Pinned comparison objects ready (${result.fetched} fetched).`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  try {
    main();
  } catch (error) {
    // Never relay Git/provider stderr: it may contain credentials or private identity values.
    console.error(`[git-event-objects] ${error.message}`);
    process.exitCode = 1;
  }
}
