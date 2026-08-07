enum ContinuousNavigationResolver {
    static func allowsBoundaryWrap(interactionAllowsWrap: Bool, nativeRepeat: Bool, timerIsSuspended: Bool, preferenceEnabled: Bool) -> Bool {
        interactionAllowsWrap && (!(nativeRepeat || !timerIsSuspended) || preferenceEnabled)
    }
}
