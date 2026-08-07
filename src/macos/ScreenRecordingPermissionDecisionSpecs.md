# ScreenRecordingPermissionDecision

> Coverage: see root `src/coverage.md` after the next coverage run.

## Purpose

Decide when AlTab may call a **prompt-capable** Screen Recording API versus a **silent** preflight, so the system permission dialog cannot loop while the permissions window is open.

## Background

- Silent path: `CGPreflightScreenCaptureAccess` (no system UI; frozen per-process for mid-session grants).
- Prompt-capable path: `SCShareableContent` / `CGDisplayStream` (can show the macOS dialog; can detect mid-session grants).
- A 0.5s timer used to call the prompt-capable path while the permissions window was visible. Choosing **Deny** did not set `screenRecordingPermissionSkipped`, so the dialog could return on every tick.

## Rules

1. If silent preflight reports granted → `.granted` (even when skip is set).
2. If skip is set and silent is not granted → `.skipped`; never prompt.
3. Prompt-capable probes only when `allowPrompt` is true **and** no prompt-capable probe has already been issued for this interaction.
4. After a prompt-capable probe is issued, further calls stay quiet until the process restarts or state is reset for a new explicit retry.
5. Timer ticks must never request a prompt-capable probe (`timerMayUsePromptCapableProbe() == false`).
6. Explicit user actions (permissions button) may set `allowPrompt` once.

## Scenarios

- Silent grant → granted without prompt
- Skip without grant → skipped without prompt
- Timer tick (allowPrompt false) while not granted → notGranted, no prompt
- First explicit request while not granted → should run prompt-capable once
- Second request after prompt already issued → notGranted, no second prompt
- Prompt-capable returns granted → granted
- Prompt-capable returns denied, skip false → notGranted
- Prompt-capable returns denied, skip true → skipped
- timerMayUsePromptCapableProbe is always false
