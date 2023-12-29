import Foundation

extension System {
    public static func time(
        _ errorMessage: String = "",
        _ function: @escaping () async throws -> Void
    ) async {
        do {
            var t = Timer()
            t.startTimer()
            try await function()
            print(t.stopTimer())
        } catch {
            print("\(errorMessage): \(error.localizedDescription)")
        }
    }

    public static func time(_ function: @escaping () async -> Void) async {
        var t = Timer()
        t.startTimer()
        await function()
        print(t.stopTimer())
    }
}

private struct Timer {
    var start: TimeInterval = 0

    mutating func startTimer() {
        start = getCurrentAbsoluteTime()
    }

    func stopTimer() -> String {
        let diff = getCurrentAbsoluteTime() - start
        return "\(diff.formatted)"
    }
}

// TODO delete for FoundationEssentials Date() after swift 5.9 is released
// https://github.com/apple/swift-foundation/blob/main/Sources/FoundationEssentials/Date.swift#L36
private func getCurrentAbsoluteTime() -> TimeInterval {
    #if canImport(WinSDK)
        var ft: FILETIME = FILETIME()
        var li: ULARGE_INTEGER = ULARGE_INTEGER()
        GetSystemTimePreciseAsFileTime(&ft)
        li.LowPart = ft.dwLowDateTime
        li.HighPart = ft.dwHighDateTime
        // FILETIME represents 100-ns intervals since January 1, 1601 (UTC)
        return TimeInterval((li.QuadPart - 1164447360_000_000) / 1_000_000_000)
    #else
        var ts: timespec = timespec()
        clock_gettime(CLOCK_REALTIME, &ts)
        var ret = TimeInterval(ts.tv_sec) - 978307200.0
        ret += (1.0E-9 * TimeInterval(ts.tv_nsec))
        return ret
    #endif  // canImport(WinSDK)
}

extension TimeInterval {
    fileprivate var formatted: String {
        let endingDate = Date()
        let startingDate = endingDate.addingTimeInterval(-self)
        let calendar = Calendar.current

        let componentsNow = calendar.dateComponents(
            [.hour, .minute, .second, .nanosecond], from: startingDate,
            to: endingDate)
        if let hour = componentsNow.hour,
            let minute = componentsNow.minute,
            let seconds = componentsNow.second,
            let nano = componentsNow.nanosecond
        {
            let ms = nano / 1_000_000
            let n = nano % 1_000_000
            return
                "\(String(format: "H{%02d}", hour)):\(String(format: "M{%02d}", minute)):\(String(format: "S{%02d}", seconds)):\(String(format: "ms{%02d}",ms)):\(String(format: "ns{%02d}",n))"
        } else {
            return "H{00}:M{00}:S{00}:ms{00}:ns{00}"
        }
    }
}
