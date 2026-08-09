import Foundation

/// Pure CLI wire decisions: which argv is a command, and how a server reply maps to exit behaviour.
/// Kept free of AppKit / message ports so the unit-tests target can pin the contract without a running app.
enum CliReplyResolver {
    static let errorToken = "error"
    static let noOutputToken = "noOutput"

    enum Reply: Equatable {
        case output(String)
        case silentSuccess
        case failure(String)
    }

    static func detectCommand(from args: [String]) -> String? {
        guard args.count == 2, !args[1].starts(with: "--logs=") else { return nil }
        let arg = args[1]
        if arg == "--list" || arg == "--detailed-list" || arg == "--qa-state" || arg == "--hide"
            || arg.hasPrefix("--qa-mark=") || arg.hasPrefix("--focus=")
            || arg.hasPrefix("--focusUsingLastFocusOrder=") || arg.hasPrefix("--show=") {
            return arg
        }
        return nil
    }

    /// Every failure is a non-zero exit with a message on stderr. Silence on stdout with exit 0 means the
    /// command ran and has no payload. A zero-byte reply is a failure — that is what a NULL callback looks
    /// like from the client, and reading it as success is what let a broken port pass for a healthy one.
    static func classify(command: String, responseData: Data?, portStatus: Int32, appName: String) -> Reply {
        guard let responseData else {
            return .failure("\(appName) did not answer \(command) (CFMessagePortSendRequest status \(portStatus), no reply)")
        }
        guard !responseData.isEmpty else {
            return .failure("\(appName) did not answer \(command) (CFMessagePortSendRequest status \(portStatus), empty reply)")
        }
        guard let response = String(data: responseData, encoding: .utf8) else {
            return .failure("\(appName)'s answer to \(command) is \(responseData.count) bytes that are not text")
        }
        if response == "\"\(errorToken)\"" {
            return .failure("Couldn't execute command. Is it correct?")
        }
        if response == "\"\(noOutputToken)\"" {
            return .silentSuccess
        }
        return .output(response)
    }

    /// `JSONEncoder` refuses NaN / infinite `Double` by default. Window geometry comes from AX and can be
    /// either; converting keeps replies encodable instead of returning nil (which the client cannot
    /// distinguish from a healthy empty answer without the hardening above).
    static func makeJsonEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
        return encoder
    }
}
