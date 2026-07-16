import Foundation

/// Compact formatting for large values, used when the "Compact large values"
/// setting is on.
enum ValueFormatting {
    /// 69,319 → "69.3K"; 1,234,567 → "1.2M". Callers gate on magnitude.
    static func compactNumber(_ value: Double) -> String {
        if value >= 1_000_000 { return trimmed(value / 1_000_000) + "M" }
        if value >= 10_000 { return trimmed(value / 1_000) + "K" }
        return Int(value.rounded()).formatted()
    }

    private static func trimmed(_ value: Double) -> String {
        let text = String(format: "%.1f", value)
        return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
    }

    /// Plain style is hours/minutes ("128h 23m"). Compact style climbs the
    /// ladder for anything from two days up: "5d 8h", "7w 4d", "3mo 2w", "1y 2mo".
    static func duration(_ seconds: TimeInterval, compact: Bool) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        guard compact, hours >= 48 else {
            if hours > 0 { return "\(hours)h \(minutes)m" }
            return "\(minutes)m"
        }
        let day = 24.0 * 3600
        let week = 7 * day
        let month = 30.44 * day
        let year = 365.25 * day
        switch seconds {
        case ..<(14 * day):
            let days = Int(seconds / day)
            let remHours = Int((seconds - Double(days) * day) / 3600)
            return remHours > 0 ? "\(days)d \(remHours)h" : "\(days)d"
        case ..<(8 * week):
            let weeks = Int(seconds / week)
            let remDays = Int((seconds - Double(weeks) * week) / day)
            return remDays > 0 ? "\(weeks)w \(remDays)d" : "\(weeks)w"
        case ..<year:
            let months = Int(seconds / month)
            let remWeeks = Int((seconds - Double(months) * month) / week)
            return remWeeks > 0 ? "\(months)mo \(remWeeks)w" : "\(months)mo"
        default:
            let years = Int(seconds / year)
            let remMonths = Int((seconds - Double(years) * year) / month)
            return remMonths > 0 ? "\(years)y \(remMonths)mo" : "\(years)y"
        }
    }
}
