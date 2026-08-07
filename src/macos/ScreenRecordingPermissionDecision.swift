import Foundation

/// Shared permission UI / probe status used by Accessibility and Screen Recording flows.
enum PermissionStatus {
    case granted
    case notGranted
    case skipped
}

/// Pure decision kernel for Screen Recording permission probes.
/// Keeps prompt-capable APIs (ScreenCaptureKit / CGDisplayStream) off recurring timers so Deny
/// cannot loop system dialogs. Timer ticks always use the silent preflight path.
enum ScreenRecordingPermissionDecision {
    enum ProbeKind: Equatable {
        /// CGPreflightScreenCaptureAccess-style check: never shows system UI.
        case silent
        /// SCShareableContent / CGDisplayStream path: may show the system permission dialog.
        case promptCapable
    }

    struct Input: Equatable {
        /// Result of a silent preflight (true = granted at process start / frozen mid-session).
        var preflightGranted: Bool
        /// User opted out via "Use the app without this permission. Thumbnails won’t show."
        var skipped: Bool
        /// Whether a prompt-capable probe may run (explicit user action or one-shot interaction).
        var allowPrompt: Bool
        /// Whether a prompt-capable probe already ran for this interaction (deny stays quiet).
        var hasIssuedPromptCapableProbe: Bool
    }

    struct Outcome: Equatable {
        var status: PermissionStatus
        /// When true, the caller must run the prompt-capable OS API once and fold its result back in.
        var shouldRunPromptCapableProbe: Bool
        var hasIssuedPromptCapableProbe: Bool
    }

    /// Decide status and whether a prompt-capable probe is allowed this call.
    /// Callers that receive `shouldRunPromptCapableProbe == true` must invoke the OS API once, then
    /// call `resolveAfterPromptCapableProbe` with that result.
    static func resolve(_ input: Input) -> Outcome {
        if input.preflightGranted {
            return Outcome(status: .granted, shouldRunPromptCapableProbe: false, hasIssuedPromptCapableProbe: input.hasIssuedPromptCapableProbe)
        }
        if input.skipped {
            return Outcome(status: .skipped, shouldRunPromptCapableProbe: false, hasIssuedPromptCapableProbe: input.hasIssuedPromptCapableProbe)
        }
        if input.allowPrompt && !input.hasIssuedPromptCapableProbe {
            return Outcome(status: .notGranted, shouldRunPromptCapableProbe: true, hasIssuedPromptCapableProbe: true)
        }
        return Outcome(status: .notGranted, shouldRunPromptCapableProbe: false, hasIssuedPromptCapableProbe: input.hasIssuedPromptCapableProbe)
    }

    /// Fold a prompt-capable probe result after `resolve` requested one.
    static func resolveAfterPromptCapableProbe(granted: Bool, skipped: Bool) -> PermissionStatus {
        if granted { return .granted }
        if skipped { return .skipped }
        return .notGranted
    }

    /// Whether a recurring timer tick may invoke a prompt-capable probe. Always false.
    static func timerMayUsePromptCapableProbe() -> Bool {
        false
    }
}
