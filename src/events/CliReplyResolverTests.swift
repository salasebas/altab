import XCTest

/// Pins the pure CLI wire contract: argv detection, reply classification, and safe float encoding.
final class CliReplyResolverTests: XCTestCase {

    // MARK: - Command detection

    func testDetectsListAndDetailedList() {
        XCTAssertEqual(CliReplyResolver.detectCommand(from: ["AlTab", "--list"]), "--list")
        XCTAssertEqual(CliReplyResolver.detectCommand(from: ["AlTab", "--detailed-list"]), "--detailed-list")
    }

    func testDetectsQaAndHideCommands() {
        XCTAssertEqual(CliReplyResolver.detectCommand(from: ["AlTab", "--qa-state"]), "--qa-state")
        XCTAssertEqual(CliReplyResolver.detectCommand(from: ["AlTab", "--hide"]), "--hide")
        XCTAssertEqual(CliReplyResolver.detectCommand(from: ["AlTab", "--qa-mark=step-3"]), "--qa-mark=step-3")
    }

    func testDetectsFocusAndShowPrefixes() {
        XCTAssertEqual(CliReplyResolver.detectCommand(from: ["AlTab", "--focus=42"]), "--focus=42")
        XCTAssertEqual(CliReplyResolver.detectCommand(from: ["AlTab", "--focusUsingLastFocusOrder=1"]), "--focusUsingLastFocusOrder=1")
        XCTAssertEqual(CliReplyResolver.detectCommand(from: ["AlTab", "--show=0"]), "--show=0")
    }

    func testRejectsLogsOnlyAndUnknownArgs() {
        XCTAssertNil(CliReplyResolver.detectCommand(from: ["AlTab", "--logs=debug"]))
        XCTAssertNil(CliReplyResolver.detectCommand(from: ["AlTab", "--unknown"]))
        XCTAssertNil(CliReplyResolver.detectCommand(from: ["AlTab"]))
        XCTAssertNil(CliReplyResolver.detectCommand(from: ["AlTab", "--list", "extra"]))
    }

    // MARK: - Reply classification

    func testMissingReplyIsFailure() {
        let result = CliReplyResolver.classify(command: "--list", responseData: nil, portStatus: -1, appName: "AlTab")
        guard case .failure(let message) = result else { return XCTFail("expected failure, got \(result)") }
        XCTAssertTrue(message.contains("no reply"))
        XCTAssertTrue(message.contains("--list"))
    }

    func testEmptyReplyIsFailure() {
        let result = CliReplyResolver.classify(command: "--list", responseData: Data(), portStatus: 0, appName: "AlTab")
        guard case .failure(let message) = result else { return XCTFail("expected failure, got \(result)") }
        XCTAssertTrue(message.contains("empty reply"))
    }

    func testNonTextReplyIsFailure() {
        let result = CliReplyResolver.classify(command: "--list", responseData: Data([0xFF, 0xFE]), portStatus: 0, appName: "AlTab")
        guard case .failure(let message) = result else { return XCTFail("expected failure, got \(result)") }
        XCTAssertTrue(message.contains("not text"))
    }

    func testRejectedCommandIsFailure() {
        let data = Data("\"error\"".utf8)
        let result = CliReplyResolver.classify(command: "--bogus", responseData: data, portStatus: 0, appName: "AlTab")
        guard case .failure(let message) = result else { return XCTFail("expected failure, got \(result)") }
        XCTAssertEqual(message, "Couldn't execute command. Is it correct?")
    }

    func testNoOutputIsSilentSuccess() {
        let data = Data("\"noOutput\"".utf8)
        XCTAssertEqual(
            CliReplyResolver.classify(command: "--hide", responseData: data, portStatus: 0, appName: "AlTab"),
            .silentSuccess)
    }

    func testPayloadIsSuccessOutput() {
        let payload = #"{"windows":[]}"#
        let result = CliReplyResolver.classify(command: "--list", responseData: Data(payload.utf8), portStatus: 0, appName: "AlTab")
        XCTAssertEqual(result, .output(payload))
    }

    func testFailureMessagesUseInjectedAppName() {
        let result = CliReplyResolver.classify(command: "--list", responseData: nil, portStatus: 42, appName: "AlTab")
        guard case .failure(let message) = result else { return XCTFail("expected failure, got \(result)") }
        XCTAssertTrue(message.hasPrefix("AlTab "))
        XCTAssertFalse(message.contains("AltTab"))
    }

    // MARK: - Non-conforming float encoding

    func testEncoderConvertsNanAndInfinity() throws {
        struct Sample: Codable { var x: Double; var y: Double; var z: Double }
        let data = try CliReplyResolver.makeJsonEncoder().encode(Sample(x: .nan, y: .infinity, z: -.infinity))
        let text = String(data: data, encoding: .utf8)!
        XCTAssertTrue(text.contains("nan"))
        XCTAssertTrue(text.contains("inf"))
        XCTAssertTrue(text.contains("-inf"))
    }
}
