# CliReplyResolver — Specs

## Summary

`CliReplyResolver` is the pure CLI wire contract: which argv tokens are treated as client commands, and
how a message-port reply maps onto stdout/stderr + exit status. Live transport (`CFMessagePort`,
`App.name`, process exit) stays in `CliEvents` / `CliClient`.

Ported from the CLI transport subset of upstream `c14960bb` (issue #59), with AlTab naming via
`appName` injection rather than hard-coded upstream product strings.

## Behavior

### Command detection
- Exactly two argv tokens; the second must not be a `--logs=` flag.
- Accepted: `--list`, `--detailed-list`, `--qa-state`, `--hide`, `--qa-mark=…`, `--focus=…`,
  `--focusUsingLastFocusOrder=…`, `--show=…`.
- Anything else → not a CLI command (app launches normally).

### Reply classification
- Missing reply → failure (mentions "no reply" + port status).
- Empty reply bytes → failure (mentions "empty reply" + port status). Non-text UTF-8 → failure.
- JSON-encoded `"error"` sentinel → failure ("Couldn't execute command…").
- JSON-encoded `"noOutput"` sentinel → silent success (empty stdout, exit 0).
- Any other text → success with that payload on stdout.

### Non-conforming float encoding
- `makeJsonEncoder()` converts `+inf` / `-inf` / `NaN` to string tokens instead of throwing, so one bad
  window geometry cannot suppress every CLI reply.

## Test scenarios

Mirrors `CliReplyResolverTests.swift` 1:1.

### Command detection
- **testDetectsListAndDetailedList** — known list commands are accepted.
- **testDetectsQaAndHideCommands** — `--qa-state`, `--hide`, `--qa-mark=` are accepted.
- **testDetectsFocusAndShowPrefixes** — focus/show prefixes are accepted.
- **testRejectsLogsOnlyAndUnknownArgs** — `--logs=…`, unknown flags, wrong arity → nil.

### Reply classification
- **testMissingReplyIsFailure** — nil data → failure mentioning "no reply".
- **testEmptyReplyIsFailure** — empty data → failure mentioning "empty reply".
- **testNonTextReplyIsFailure** — invalid UTF-8 → failure mentioning "not text".
- **testRejectedCommandIsFailure** — encoded error sentinel → rejected-command failure.
- **testNoOutputIsSilentSuccess** — encoded noOutput sentinel → silent success.
- **testPayloadIsSuccessOutput** — ordinary JSON text → `.output`.
- **testFailureMessagesUseInjectedAppName** — app name appears in transport failures, not a hard-coded
  upstream product name.

### Non-conforming float encoding
- **testEncoderConvertsNanAndInfinity** — encoding NaN/±inf does not throw and emits string tokens.
