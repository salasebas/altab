# Source-first compatibility, security, and compliance audit

**Issue:** [#10](https://github.com/salasebas/altab/issues/10)  
**Audit date:** 2026-08-07  
**Auditor environment:** local maintainer workstation (not CI)  
**Recommendation:** **Ready** for the first source-only milestone ([#11](https://github.com/salasebas/altab/issues/11))

## Scope

This audit validates AlTab as a **source-first** product: users clone and build locally; the maintainer does not publish official application binaries, Developer ID/notarization tickets, or an in-app updater. Gatekeeper, Sparkle, and hosted binary release infrastructure are out of scope as release deliverables.

**Dependencies (all closed before this audit):**

| Issue | Title | State |
| --- | --- | --- |
| #16 | Harden optional local self-signed setup | Closed |
| #17 | Document clone/build/run/permissions/source updates | Closed |
| #18 | Source-first local Release workflow | Closed |
| #19 | Replace the bundled SF Pro subset | Closed |
| #20 | Decouple optional GPL packaging from source validation | Closed |

**Non-goals (not evaluated as blockers):** publishing `.app`/DMG/installer; maintainer Developer ID signing or notarization; Sparkle or any hosted updater; claiming immediate upstream/security parity.

## Audited revision

| Field | Value |
| --- | --- |
| Product revision audited | `7f109d012e270cb51799731695e840704a2859ff` |
| Subject (product tip) | `docs: document clone-to-running AlTab workflow (#29)` |
| Milestone tip | The Git commit that introduces this report (docs-only delta on top of the product revision) |
| Upstream remote | `https://github.com/lwouis/alt-tab-macos.git` (read-only) |
| Upstream last reviewed | `081f3ee4014e03557c2ab39e9e168dac308fa49b` (`v11.4.4`) — recorded in `UPSTREAM.md` |
| Upstream lag at audit | None: `upstream/master` equals last reviewed commit |
| Fork identity | Bundle ID `dev.salasebas.AlTab` (Release), `dev.salasebas.AlTabDev` (Debug) |

Evidence below was collected against the product tree at `7f109d01…`. The commit that introduces this report adds documentation only (no product code) and is the intended tip for the source-only milestone once #11 tags it.

## Environment

| Item | Value |
| --- | --- |
| Hardware | Mac16,1 (Apple M4), `arm64` |
| macOS | 26.5.2 (25F84) |
| Kernel | Darwin 25.5.0 |
| Xcode | 26.3 (17C529), selected via `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` |
| macOS SDK | 26.2 |
| Swift | 5.8 (`SWIFT_VERSION` from Release settings) |
| Deployment target | 10.13 |
| Default developer dir without override | Command Line Tools only — full Xcode required as documented |

Intel native hardware was not available. Universal binaries containing `x86_64` and `arm64` were produced and verified with `lipo` on Apple Silicon as the accepted equivalent for architecture coverage.

## Commands and results

All build/test commands used:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

### Automated guards and structural checks

| Command | Result |
| --- | --- |
| `scripts/check_source_compliance.sh` | **Pass** (includes service isolation, unrestricted features, symbol assets) |
| `scripts/check_legacy_preferences_import.sh` | **Pass** |
| `scripts/check_local_codesign_setup.sh` | **Pass** |
| `scripts/check_release_packaging.sh` | **Pass** |
| `scripts/check_local_build.sh` | **Pass** (fixture-based; negative fixtures intentionally fail inner guards) |
| `pnpm audit --prod` | **Pass** — no known vulnerabilities |
| `pnpm run format:check` | **Pass** |

### Builds

| Command | Result |
| --- | --- |
| `scripts/build_local.sh` | **Pass** — native `arm64` Release, ad hoc, `dev.salasebas.AlTab` |
| `scripts/build_local.sh --universal` | **Pass** — `arm64 x86_64`, ad hoc, same bundle ID |
| `xcodebuild … -scheme Debug -configuration Debug -derivedDataPath DerivedData/DebugAudit build` | **Pass** — `AlTab Dev.app` / `dev.salasebas.AlTabDev` |

Default local Release product path:

```text
DerivedData/Local/Build/Products/Release/AlTab.app
```

Release bundle observations:

- Signature: ad hoc + hardened runtime (`flags=0x10002(adhoc,runtime)`)
- Team ID: not set
- Entitlements: App Sandbox **off**; `com.apple.security.cs.disable-library-validation` **true** (expected for private framework / flexible loading patterns used by this class of app)
- No `.otf` / `.ttf` / `SF-Pro*` files in source `resources/` or in the built bundle
- Post-build guards on the real app: service isolation, unrestricted features, symbol assets — all **Pass**

### Tests

| Command | Result |
| --- | --- |
| `scripts/run_tests.sh DerivedData/TestAudit` | **Pass** — **523** tests, **0** failures |

`run_tests.sh` also rebuilt Debug and universal Release products and re-ran bundle guards against both apps — all **Pass**.

Representative suites with product-model relevance:

- `IncludedFeaturesTests` — unrestricted feature surface and per-configuration overrides
- `LegacyPreferencesImporterTests` — one-time AltTab import; bans license/login/permission/service keys; does not write source domain
- `SearchTests` / `SearchModeResolverTests` — Search and Search on Release
- `AppearanceTests` — titles/icons/auto size wiring
- Symbol catalog / brand asset tests — redistributable symbols and fork branding

### Runtime network probe

```bash
open DerivedData/Local/Build/Products/Release/AlTab.app
# after ~4s
lsof -nP -iTCP -a -p "$(pgrep -x AlTab | head -1)"
lsof -nP -iUDP -a -p "$(pgrep -x AlTab | head -1)"
```

| Observation | Result |
| --- | --- |
| TCP sockets owned by `AlTab` | None |
| UDP sockets owned by `AlTab` | None |
| Quit | Clean exit via AppleScript / process termination |

Open files during the probe were system frameworks, fonts shipped by macOS (e.g. `/System/Library/Fonts/SFNS.ttf`), and local preference/logging caches — not outbound network endpoints.

### Side-by-side with official AltTab

On the audit machine, official AltTab defaults domains remained present and readable after launching AlTab:

- `com.lwouis.alt-tab-macos` (still present; AppCenter migration keys from historical upstream installs unchanged)
- `com.lwouis.alt-tab-macos.license` (still present)

No AlTab code path writes those domains. Import logic only **reads** the source domain into missing AlTab keys and records completion only in AlTab’s own domain (`LegacyPreferencesImporter`).

## Build and compatibility matrix

| Matrix item | Status | Evidence |
| --- | --- | --- |
| Clean clone with full Xcode selected | **Pass** | Documented path in README; builds succeed with `DEVELOPER_DIR` when CLT is default |
| Default optimized local Release without Apple account | **Pass** | `scripts/build_local.sh` — ad hoc, Team ID empty |
| Optional stable local self-signed build | **Pass (structure)** | `scripts/check_local_codesign_setup.sh`; scripts under `scripts/codesign/`; live Keychain install **not** executed (mutates user Keychain — accepted limitation) |
| Debug build for contributors | **Pass** | Debug scheme build + `run_tests.sh` Debug product |
| Native architecture mode | **Pass** | Native arm64 local Release |
| Universal architecture mode | **Pass** | `--universal` and test Release product; `lipo` verifies `arm64` + `x86_64` |
| Intel native hardware | **Accepted limitation** | No Intel Mac available; universal `x86_64` slice verified on Apple Silicon |
| First launch and relaunch | **Pass** | Launch + quit observed; relaunch path is same binary |
| Reset / import / export settings | **Pass (code + unit)** | UI in `GeneralTab`; domain replacement preserves import completion marker (unit tests) |
| One-time AltTab preference import | **Pass** | 24 importer tests; source domain read-only; banned prefixes include license/trial/sparkle/appcenter |
| Side-by-side with official AltTab | **Pass** | Distinct bundle IDs; official defaults domains remain after AlTab launch |
| Official AltTab defaults / license suite / Keychain untouched | **Pass** | Importer never writes source domains; Keychain license items not deleted (policy + code); live domains still present |
| Accessibility grant / deny / revoke / re-grant | **Pass (code + partial interactive)** | Permissions window + `SystemPermissions`; full TCC revoke matrix not exhaustively re-run this session — platform behavior documented; not a source-first blocker |
| Screen Recording grant / deny / revoke / re-grant | **Pass (code + partial interactive)** | Optional capture path; same accepted interactive limit |
| Login item enable/disable | **Pass (code)** | `LoginItem` writes `~/Library/LaunchAgents/<bundle-id>.plist` only for fork identity |
| Uninstall + residual data | **Pass (documented)** | Residual locations listed below and in README |
| Keyboard configs, gestures, search, Search on Release, Auto size, titles/icons, overrides | **Pass (automated)** | Included-features catalog + unit tests for search/appearance/resolvers/overrides |

### Residual data after removing the app

Deleting `AlTab.app` does not erase:

| Location | Contents |
| --- | --- |
| `~/Library/Preferences/dev.salasebas.AlTab.plist` (and related CFPreferences) | User settings |
| `~/Library/Preferences/dev.salasebas.AlTab.usage.plist` (or suite) | Local usage counters for About UI only |
| `~/Library/LaunchAgents/dev.salasebas.AlTab.plist` | Login-item agent if Start at login was enabled |
| TCC databases | Accessibility / Screen Recording grants for the code signature |
| Optional Keychain identity | “Local Self-Signed” only if the user ran `scripts/codesign/setup_local.sh` |

Debug identity uses `dev.salasebas.AlTabDev` with the same pattern. Official AltTab residuals under `com.lwouis.alt-tab-macos*` are **not** AlTab’s responsibility and must not be removed by AlTab.

## Security and privacy audit

| Check | Status | Notes |
| --- | --- | --- |
| No Sparkle / AppCenter / appcast / crash reporter in project or production paths | **Pass** | `check_service_isolation.sh` on source and bundles |
| No upstream licensing / checkout / account endpoints | **Pass** | `forbidden_service_contracts.sh` + source compliance |
| No paid-access / trial / upsell UI | **Pass** | `check_unrestricted_features.sh` |
| No private keys, cert passwords, tokens, notarization creds in source | **Pass** | Scanned operational paths; codesign scripts take passwords only as **runtime CLI args**, never committed secrets |
| CI permissions and secret boundary | **Pass** | `.github/workflows/ci.yml`: `permissions: contents: read`; no `secrets.`; pinned actions by full SHA; no packaging/publish steps |
| CI tool downloads integrity | **Pass** | ripgrep and SwiftFormat downloaded with pinned versions and SHA-256 checks |
| Optional packaging isolated | **Pass** | Not invoked by normal CI; `docs/releasing.md` + `check_release_packaging.sh` |
| Runtime network on startup | **Pass** | No TCP/UDP for `AlTab` during probe |
| Outbound URLs in production code | **Pass** | Only user-initiated opens: GitHub repo/issues/sponsors (`Endpoints.swift`), System Settings deep links, open-with-app for windows |
| Local “usage stats” | **Pass** | `UsageStats` stores timestamps in a local UserDefaults suite only; not transmitted |
| Binary residual strings | **Info** | `appcast`/`appcenter`/`sparkle` appear as **banned import prefixes** and SF Symbol name `sparkles` — not live service clients. Bundle guards still pass |
| Third-party dependency advisories | **Pass** | `pnpm audit --prod` clean; ShortcutRecorder vendored at pinned commit `52c6273d…` |
| Entitlements review | **Pass with note** | No App Sandbox (required class of app); library validation disabled — accepted for this architecture; hardened runtime enabled on Release |

## Compliance and documentation audit

| Check | Status | Notes |
| --- | --- | --- |
| Root metadata declares GPL-3.0 | **Pass** | `package.json` `GPL-3.0-only`; `Info.plist` copyright string; `LICENCE.md` GPLv3 text |
| Notices / provenance / third-party licenses | **Pass** | `NOTICE.md`, `docs/acknowledgments.md`, `docs/contributors.md`, vendored licenses, brand license |
| No non-redistributable Apple font subset | **Pass** | Symbol assets are Tabler PDFs + system symbols; `check_symbol_assets.sh` |
| README / FORK / contributing accuracy | **Pass** | Independent fork, all features included, source-first build/update, no official binaries, no Sparkle/updater, privacy status, optional signing limits |
| Upstream review currency | **Pass** | `UPSTREAM.md` matches `upstream/master` at audit time; issue #19 skip decision recorded for font work |

## Pass / fail checklist (acceptance criteria)

| Criterion | Result |
| --- | --- |
| Every matrix item has evidence or a documented accepted limitation | **Pass** |
| No source-first-blocking security, privacy, compatibility, or licensing finding remains open | **Pass** |
| Automated checks, unit tests, Debug build, optimized local Release, bundle guards pass on audited revision | **Pass** |
| Documentation matches observed behavior | **Pass** |
| Audited commit is the exact commit proposed for the first source-only milestone | **Pass** — propose the docs commit that lands this report (parent product tree `7f109d01…`) for #11 |

## Findings

### Blocking

None.

### Non-blocking / accepted limitations

1. **Intel native runtime** — not exercised on Intel silicon; universal `x86_64` slice verified via `lipo`.
2. **Live self-signed identity install** — script structure and negative tests pass; installing into the auditor’s Keychain was skipped by design.
3. **Exhaustive TCC revoke matrix** — Accessibility/Screen Recording grant and deny paths are implemented and documented; full revoke/re-grant on a clean user was not re-scripted this session.
4. **Interactive keyboard/gesture QA** — covered by unit tests and feature specs, not a full manual smoke of every shortcut on every macOS minor release.
5. **Test suite UserDefaults pollution** — many temporary `*.IncludedFeaturesTests.*` suites remain on long-lived developer machines; hygiene only, not a product leak.

### Follow-up issues (suggested)

| Priority | Suggested title | Notes |
| --- | --- | --- |
| Low | docs: optional end-user uninstall checklist expansion | Residual paths are documented; could add a one-liner shell recipe for power users |
| Low | test: clean temporary UserDefaults suites after IncludedFeaturesTests | Dev machine hygiene |
| Medium (post-milestone) | qa: manual TCC grant/revoke matrix on a clean user account | Non-blocking for source-only; valuable before any future binary distribution |
| Out of scope for source-only | release: Developer ID + notarization (#8 historical) | Explicit non-goal of this audit |
| Out of scope for source-only | updates: fork-owned Sparkle (#9 historical) | Explicit non-goal |

## Final recommendation

**Ready** for the first **source-only** milestone.

The repository can be cloned, built without an Apple account, and run without upstream licensing, analytics, or update services. Guards, unit tests, Debug and Release builds, and documentation align with the source-first product model. Tag the commit that contains this audit report per issue #11; do not attach compiled application artifacts to the release.

Re-run after any non-doc change that lands before the tag:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
scripts/check_source_compliance.sh
scripts/check_local_build.sh
scripts/build_local.sh
scripts/run_tests.sh DerivedData/MilestoneGate
```
