# General

- English first: all code, comments, identifiers, and internal docs in English.
- Grow the system in layers. Start with the smallest end-to-end change that works, then add capabilities without leaving the product in a partially migrated state.
- Keep components modular and concerns clearly separated.
- Prefer established, well-maintained libraries when they reduce overall complexity or improve reliability.
- Check existing dependencies, their documentation, and their types before reimplementing a capability or adding a package.
- Make architectural decisions for the long term; do not introduce deliberate throwaway paths.
- Study proven macOS products and platform conventions before inventing a new interaction or architecture.

# Fork maintenance

- This is an independent fork of `lwouis/alt-tab-macos`. Keep the official repository as the read-only `upstream` remote and never push to it.
- Review upstream changes explicitly. Prefer cherry-picking self-contained fixes or porting understood changes; do not merge `upstream/master` wholesale by default.
- Keep `UPSTREAM.md` current after every upstream review, including when changes are intentionally skipped.
- Preserve upstream authorship, Git history, copyright notices, the GPL license, and third-party attributions.
- Do not publish a build that uses upstream update feeds, licensing endpoints, signing identities, funding links, analytics credentials, or release infrastructure.
- Do not claim automatic security updates or upstream parity. State the last reviewed upstream revision and validate every integrated change locally.

# macOS development

- Don't use xcode directly to develop
- Use pure swift 5.8 code to make the app. No interface builder. No SwiftUI.
- Aim for compact code. Within methods, don't have groups of statements separated with newlines. No inline comments for simple code. Instead, split statements into sub-methods.
- Use guard closes as much as possible to separate the happy-path under them
- Organize source files into folders. Folders should group files that change together, at the same pace (e.g. one feature)
- When possible, follow the triad pattern: specs in *Specs.md, unit-tests in *Tests.swift, and *swift for the implementation. Document features and their edge-cases this way
- Favor low latency and responsiveness. Reuse objects, avoid wasting memory or I/O. Use observer APIs; don't poll.

# Workflow

- Compile: `ai/build.sh`. Interactive Debug/QA: only `scripts/run_debug.sh` — never open DerivedData. Everyday local Release install: `scripts/install_local.sh`. Details: `docs/building-and-troubleshooting.md`.
- Git commit messages must respect our pre-hook conventions, and must be clear and high-level, written for end-users (changelog). Merges to `main` do not rewrite `changelog.md`. Versioned sections and `altab-v*` tags are created only on an intentional maintainer cut (`workflow_dispatch` on Release notes; see `cliff.toml`, `scripts/changelog_milestone.sh`, and `docs/releasing.md`). Do not hand-edit versioned entries the cut owns.

# Release identity and unrestricted features

- Before the first public fork release, replace the inherited upstream Developer ID, Team ID, and bundle ID with fork-owned values. Do not ship with upstream identity.
- After the first public fork release, keep the Developer ID, Team ID, and bundle ID stable. macOS permissions, preferences, login items, and update continuity depend on that identity; plan and test a migration before any later rotation.
- Every locally implemented user-facing feature must remain available without a license, trial, account, purchase, expiry, network response, or paid-access state.
- Do not add access-based preference fallbacks, downgrades, resets, locks, badges, prompts, or telemetry. User preferences still decide how included features behave.
- Do not delete legacy license Keychain items at runtime. They are inert historical data and are not part of AlTab's active architecture.
