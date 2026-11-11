import Foundation

/// Placeholders in a text shortcut's phrase, filled in when it is typed: "Sent {date} at {time}" -> "Sent 11 Nov 2026
/// at 14:05". {cursor} marks where the cursor goes once the phrase is written.
enum ShortcutTemplate {
    /// The placeholders, in the order the Text shortcuts screen lists them, with what each writes (English keys).
    static let placeholders: [(token: String, note: String)] = [
        ("{date}", "Today's date"),
        ("{time}", "The time now"),
        ("{datetime}", "Date and time"),
        ("{day}", "The day of the week"),
        ("{month}", "The month's name"),
        ("{year}", "The year"),
        ("{today+3}", "The weekday 3 days from now (-3: back; 2w: weeks)"),
        ("{date+7}", "The date 7 days from now"),
        ("{month+2}", "The month's name 2 months from now"),
        ("{time+2h}", "The time 2 hours from now (30m: minutes)"),
        ("{clipboard}", "What you last copied"),
        ("{cursor}", "Where the cursor goes")
    ]

    /// Examples of placeholders moved ahead or back, shown with what they write today.
    static let offsetExamples = ["{today+1}", "{today-1}", "{today+3}", "{today+2w}", "{date+7}", "{month+1}", "{month-2}",
                                 "{year+1}", "{time+30m}", "{time+2h}", "{datetime+1h}"]

    /// Stands in for {cursor} in a filled-in phrase until it is written (a private-use character no text has).
    static let cursorMark: Character = "\u{E000}"

    /// Whether a phrase has any placeholder.
    static func hasPlaceholders(_ phrase: String) -> Bool {
        let lower = phrase.lowercased()
        if placeholders.contains(where: { lower.contains($0.token) }) { return true }
        return lower.range(of: #"\{\s*[a-z]+\s*[+-]\s*\d+\s*[a-z]*\s*\}"#, options: .regularExpression) != nil
    }

    /// The phrase with its placeholders filled in (the cursor's place as `cursorMark`). Dates are written in
    /// `locale`'s words; `clipboard` is asked only when the phrase has {clipboard}.
    static func expand(_ phrase: String, locale: Locale, now: Date = Date(), clipboard: () -> String?) -> String {
        guard phrase.contains("{") else { return phrase }
        var result = ""
        var rest = Substring(phrase)
        while let open = rest.firstIndex(of: "{") {
            result += rest[..<open]
            guard let close = rest[open...].firstIndex(of: "}") else {
                result += rest[open...]
                return result
            }
            let name = rest[rest.index(after: open)..<close].lowercased()
            if let value = fill(name, locale: locale, now: now, clipboard: clipboard) {
                result += value
            } else {
                result += rest[open...close]   // not a placeholder: kept as written
            }
            rest = rest[rest.index(after: close)...]
        }
        result += rest
        // Only the first {cursor} counts.
        if let first = result.firstIndex(of: cursorMark) {
            let after = result.index(after: first)
            result = String(result[...first]) + result[after...].filter { $0 != cursorMark }
        }
        return result
    }

    /// A filled-in phrase as it is written, and how many characters the cursor then goes back ({cursor}).
    static func split(_ expanded: String) -> (text: String, cursorBack: Int) {
        guard let mark = expanded.firstIndex(of: cursorMark) else { return (expanded, 0) }
        let after = expanded[expanded.index(after: mark)...]
        return (String(expanded[..<mark]) + after, after.count)
    }

    /// "today+3", "month-2", "time+90m", "date+2w": a base, a sign, a number and an optional unit.
    private static func offset(_ name: String, locale: Locale, now: Date) -> String? {
        guard name.range(of: #"^\s*[a-z]+\s*[+-]\s*\d{1,5}\s*[a-z]*\s*$"#, options: .regularExpression) != nil,
              let signIndex = name.firstIndex(where: { $0 == "+" || $0 == "-" }) else { return nil }
        let base = name[..<signIndex].trimmingCharacters(in: .whitespaces)
        let sign = name[signIndex] == "-" ? -1 : 1
        let rest = name[name.index(after: signIndex)...].trimmingCharacters(in: .whitespaces)
        let digits = rest.prefix(while: { $0.isNumber })
        guard let amount = Int(digits) else { return nil }
        let unit = rest.dropFirst(digits.count).trimmingCharacters(in: .whitespaces)
        let value = sign * amount
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        func shifted(_ component: Calendar.Component, _ count: Int) -> Date? {
            return calendar.date(byAdding: component, value: count, to: now)
        }
        switch base {
        case "today", "day", "date":
            let days: Int
            switch unit {
            case "", "d": days = value
            case "w": days = value * 7
            default: return nil
            }
            guard let date = shifted(.day, days) else { return nil }
            return base == "date" ? dateText(date, locale: locale) : formatted(date, pattern: "EEEE", locale: locale)
        case "month":
            guard unit.isEmpty || unit == "m", let date = shifted(.month, value) else { return nil }
            return formatted(date, pattern: "LLLL", locale: locale)
        case "year":
            guard unit.isEmpty || unit == "y", let date = shifted(.year, value) else { return nil }
            return formatted(date, pattern: "yyyy", locale: locale)
        case "time", "datetime":
            let minutes: Int
            switch unit {
            case "", "m", "min": minutes = value
            case "h": minutes = value * 60
            default: return nil
            }
            guard let date = shifted(.minute, minutes) else { return nil }
            return base == "time" ? timeText(date, locale: locale) : dateText(date, locale: locale) + " " + timeText(date, locale: locale)
        default:
            return nil
        }
    }

    private static func fill(_ name: String, locale: Locale, now: Date, clipboard: () -> String?) -> String? {
        if let moved = offset(name, locale: locale, now: now) { return moved }
        switch name {
        case "today": return formatted(now, pattern: "EEEE", locale: locale)
        case "date": return dateText(now, locale: locale)
        case "time": return timeText(now, locale: locale)
        case "datetime": return dateText(now, locale: locale) + " " + timeText(now, locale: locale)
        case "day": return formatted(now, pattern: "EEEE", locale: locale)
        case "month": return formatted(now, pattern: "LLLL", locale: locale)
        case "year": return formatted(now, pattern: "yyyy", locale: locale)
        case "clipboard": return clipboard() ?? ""
        case "cursor": return String(cursorMark)
        default: return nil
        }
    }

    /// The date as the Date format setting writes it.
    static func dateText(_ date: Date, locale: Locale, style: String? = nil, custom: String? = nil) -> String {
        let settings = Settings.shared
        let formatter = DateFormatter()
        formatter.locale = locale
        switch style ?? settings.dateFormat {
        case "short": formatter.dateStyle = .short
        case "long": formatter.dateStyle = .long
        case "full": formatter.dateStyle = .full
        case "iso": formatter.dateFormat = "yyyy-MM-dd"
        case "custom":
            let pattern = (custom ?? settings.customDateFormat).trimmingCharacters(in: .whitespaces)
            if pattern.isEmpty { formatter.dateStyle = .medium } else { formatter.dateFormat = pattern }
        default: formatter.dateStyle = .medium
        }
        return formatter.string(from: date)
    }

    /// The time as the Time format setting writes it.
    static func timeText(_ date: Date, locale: Locale, style: String? = nil, seconds: Bool? = nil) -> String {
        let settings = Settings.shared
        let withSeconds = seconds ?? settings.timeSeconds
        switch style ?? settings.timeFormat {
        case "24h": return formatted(date, pattern: withSeconds ? "HH:mm:ss" : "HH:mm", locale: locale)
        case "12h": return formatted(date, pattern: withSeconds ? "h:mm:ss a" : "h:mm a", locale: locale)
        default:
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeStyle = withSeconds ? .medium : .short
            return formatter.string(from: date)
        }
    }

    private static func formatted(_ date: Date, pattern: String, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
