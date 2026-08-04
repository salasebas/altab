struct UsageStats {
    private static let defaults = UserDefaults(suiteName: "\(App.bundleIdentifier).usage")!
    private static let writeQueue = DispatchQueue(label: "UsageStats.writeQueue", qos: .utility)
    private static let maxAge: TimeInterval = 365 * 24 * 3600
    private static let triggersKey = "triggers"

    static func recordTrigger() {
        let now = Int(Date().timeIntervalSince1970)
        writeQueue.async {
            var timestamps = getTimestamps()
            timestamps.append(now)
            defaults.set(timestamps, forKey: triggersKey)
        }
    }

    static func count(since date: Date) -> Int {
        let threshold = Int(date.timeIntervalSince1970)
        return getTimestamps().count { $0 >= threshold }
    }

    static func prune() {
        let cutoff = Int(Date().timeIntervalSince1970 - maxAge)
        writeQueue.async {
            let timestamps = getTimestamps()
            guard !timestamps.isEmpty else { return }
            defaults.set(timestamps.filter { $0 >= cutoff }, forKey: triggersKey)
        }
    }

    private static func getTimestamps() -> [Int] {
        defaults.array(forKey: triggersKey) as? [Int] ?? []
    }
}
