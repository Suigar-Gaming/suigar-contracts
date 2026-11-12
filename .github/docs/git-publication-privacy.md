# Publication privacy

Only the exact public name/contact pairs in `.github/publication-identities.json` may be used for new authors, committers, annotated taggers and attribution trailers. Personal contacts and civil names are kept out of this policy and public diagnostics. Any additional contributor identity requires owner approval; never add an exemption to admit a private identity.

Use the Node version from `.github/.node-version`, then install the local hooks with `git config --local core.hooksPath .github/hooks`. The hooks check the effective identity, commit messages and every incoming commit in a push, including an older unsafe commit followed by a clean latest commit. Existing hooks remain in place. Refresh remote refs before pushing a new branch.

The `Publication privacy` workflow checks incoming PR commits, PR title/body, push ranges and annotated taggers. All changes are inspected as raw Git objects; a mailmap does not remove old metadata. Missing comparison objects are fetched from the verified repository using read-only ephemeral credentials; unavailable history fails closed without disclosing values. Manual dispatch checks the selected branch delta against main. Existing third-party history common to the base is preserved; `--all` is an explicit historical audit and is not the incremental gate.

Before making `publication-privacy` required on main, verify a successful ordinary PR and any token-created version PR. The required check must come from GitHub Actions. Protect the workflow and allowlist through normal owner review; a caller does not choose an arbitrary publication identity or disable checks. A successful guard does not erase retained Git objects, old PR refs, forks, caches or published provenance.

Tests use synthetic identities and local Git fixtures only:

```sh
node --test .github/scripts/validate-git-identities.test.mjs .github/scripts/fetch-git-event-objects.test.mjs
node .github/scripts/validate-git-identities.mjs --config
```

This workflow and its optional hooks validate Git publication metadata only. They neither build nor test, publish, upgrade or restrict manual maintenance of Move packages. Package source, manifests, deployment records and deployment scripts are outside this change. Existing pseudonymous noreply pairs are retained only after owner review; no private contact or civil-name fingerprint is added.
