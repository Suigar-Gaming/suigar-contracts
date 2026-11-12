#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { inspectMessage, main } from "./validate-git-identities.mjs";
import { ensureEventObjects } from "./fetch-git-event-objects.mjs";

try {
  const event = JSON.parse(readFileSync(process.env.GITHUB_EVENT_PATH, "utf8"));
  const pr = event.pull_request;
  if (pr) {
    if (inspectMessage(`${pr.title ?? ""}\n\n${pr.body ?? ""}`).length) {
      throw new Error("Unapproved publication identity in PR title/body. Values withheld.");
    }
    ensureEventObjects(pr.base.sha, pr.head.sha);
    main(["--range", pr.base.sha, pr.head.sha]);
  } else if (process.env.GITHUB_EVENT_NAME === "push") {
    if (event.deleted) {
      console.log("[git-identities] Deleted ref has no incoming objects.");
      process.exit(0);
    }
    ensureEventObjects(event.before, event.after);
    let base = event.before;
    if (/^0+$/.test(base)) {
      // A new branch/tag must not rescan the unrelated legacy history already on main.
      base = execFileSync("git", ["merge-base", "origin/main", `${event.after}^{commit}`], {
        encoding: "utf8",
      }).trim();
    }
    main(["--range", base, event.after]);
  } else if (process.env.GITHUB_EVENT_NAME === "workflow_dispatch") {
    const head = execFileSync("git", ["rev-parse", "HEAD"], { encoding: "utf8" }).trim();
    // Manual version-PR checks inspect the branch delta; historical source needs a separate scrub.
    const base = execFileSync("git", ["merge-base", "origin/main", head], {
      encoding: "utf8",
    }).trim();
    ensureEventObjects(base, head);
    main(["--range", base, head]);
  } else {
    throw new Error("Unsupported publication event.");
  }
} catch {
  console.error(
    "[git-identities] Publication check failed. Fix author/committer, attribution and PR metadata using .github/publication-identities.json. Values withheld.",
  );
  process.exitCode = 1;
}
