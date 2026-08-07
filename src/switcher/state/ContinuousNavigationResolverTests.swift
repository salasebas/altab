import XCTest

final class ContinuousNavigationResolverTests: XCTestCase {
    func testDiscreteKeyboardNavigationWrapsWithEitherPreferenceValue() {
        XCTAssertTrue(allowsWrap(isRepeating: false, preferenceEnabled: false))
        XCTAssertTrue(allowsWrap(isRepeating: false, preferenceEnabled: true))
    }

    func testRepeatedKeyboardNavigationStopsByDefault() {
        XCTAssertFalse(allowsWrap(isRepeating: true, preferenceEnabled: false))
        XCTAssertEqual(Preferences.defaultValues["wrapContinuousKeyboardNavigation"] as? String, "false")
    }

    func testRepeatedKeyboardNavigationWrapsWhenEnabled() {
        XCTAssertTrue(allowsWrap(isRepeating: true, preferenceEnabled: true))
    }

    func testNativeAndSyntheticRepeatSignalsAreRecognized() {
        XCTAssertFalse(allowsWrap(nativeRepeat: true, timerIsSuspended: true, preferenceEnabled: false))
        XCTAssertFalse(allowsWrap(nativeRepeat: false, timerIsSuspended: false, preferenceEnabled: false))
        XCTAssertTrue(allowsWrap(nativeRepeat: false, timerIsSuspended: true, preferenceEnabled: false))
    }

    func testInteractionVetoPreventsTrackpadWrapping() {
        XCTAssertFalse(allowsWrap(interactionAllowsWrap: false, isRepeating: false, preferenceEnabled: true))
        XCTAssertFalse(allowsWrap(interactionAllowsWrap: false, isRepeating: true, preferenceEnabled: true))
    }

    private func allowsWrap(interactionAllowsWrap: Bool = true, isRepeating: Bool, preferenceEnabled: Bool) -> Bool {
        allowsWrap(
            interactionAllowsWrap: interactionAllowsWrap,
            nativeRepeat: isRepeating,
            timerIsSuspended: true,
            preferenceEnabled: preferenceEnabled)
    }

    private func allowsWrap(interactionAllowsWrap: Bool = true, nativeRepeat: Bool, timerIsSuspended: Bool, preferenceEnabled: Bool) -> Bool {
        ContinuousNavigationResolver.allowsBoundaryWrap(
            interactionAllowsWrap: interactionAllowsWrap,
            nativeRepeat: nativeRepeat,
            timerIsSuspended: timerIsSuspended,
            preferenceEnabled: preferenceEnabled)
    }
}
