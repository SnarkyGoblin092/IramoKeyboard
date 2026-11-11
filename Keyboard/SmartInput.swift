import Foundation

/// What the suggestion bar offers for a calculation or a measurement at the end of the text: the words it shows, and
/// how to write them (how many characters before the cursor they take the place of, and what goes there).
struct SmartResult: Equatable {
    let shown: String
    let replaceCount: Int
    let insert: String
}

/// Numbers as the typing language writes them.
enum SmartNumbers {
    /// The language's decimal separator ("," in Hungarian, "." in English).
    static func decimalSeparator(for language: Language) -> String {
        return Locale(identifier: language.localeIdentifier).decimalSeparator ?? "."
    }

    /// `value` with at most `decimals` decimals (no trailing zeros), in the language's style without grouping. Very
    /// small and very large numbers keep three significant digits.
    static func format(_ value: Double, decimals: Int, language: Language) -> String? {
        guard value.isFinite else { return nil }
        let formatter = NumberFormatter()
        // Western digits: the result goes into text typed with them (Arabic-Indic ones are read in too).
        formatter.locale = Locale(identifier: language.localeIdentifier + "@numbers=latn")
        let magnitude = abs(value)
        // (The style first: setting it puts the digit counts back to its own.)
        if magnitude >= 1e15 {
            formatter.numberStyle = .scientific
            formatter.usesSignificantDigits = true
            formatter.maximumSignificantDigits = 6
        } else if magnitude > 0 && magnitude < pow(10, -Double(decimals)) {
            formatter.numberStyle = .decimal
            formatter.usesSignificantDigits = true
            formatter.maximumSignificantDigits = 3
        } else {
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = decimals
        }
        formatter.usesGroupingSeparator = false
        guard var text = formatter.string(from: NSNumber(value: value)) else { return nil }
        if text == "-0" { text = "0" }
        return text
    }

    /// Arabic-Indic and Persian digits as 0-9.
    static func westernDigits(_ text: String) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x0660...0x0669: result.unicodeScalars.append(Unicode.Scalar(scalar.value - 0x0660 + 48)!)
            case 0x06F0...0x06F9: result.unicodeScalars.append(Unicode.Scalar(scalar.value - 0x06F0 + 48)!)
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result
    }
}

// MARK: - Calculator

/// "12*3" -> 36, "(2+3)^2/5" -> 5, "√2·π" -> 4.443, "sin(30)" -> 0.5, "200+15%" -> 230. A calculation is offered
/// as it stands, or once "=" ends it (dates and phone numbers are left alone). It knows + - * / × ÷ ^ ! %, brackets
/// (also implied: "2(3+4)", "2π"), the constants π and e, and sqrt, cbrt, sin, cos, tan, asin, acos, atan, log, ln,
/// log2, exp, abs, floor, ceil and round. Angles are in degrees.
enum InlineCalculator {
    static func result(before: String, language: Language, decimals: Int) -> SmartResult? {
        var text = SmartNumbers.westernDigits(before)
        var spaceAfter = false
        if text.hasSuffix(" ") {
            text.removeLast()
            spaceAfter = true
        }
        // Without "=" the sum is offered as it stands, and writing it down replaces it with the answer.
        let endsWithEquals = text.hasSuffix("=")
        if endsWithEquals {
            text.removeLast()
            if text.hasSuffix("=") { return nil }   // "==" is code, not a sum
        }
        let spaceBefore = text.hasSuffix(" ")
        while text.hasSuffix(" ") { text.removeLast() }
        guard !text.isEmpty else { return nil }

        // The longest run at the end made only of what a calculation can hold.
        let tail = Array(text.suffix(160))
        var start = tail.count
        while start > 0, isAllowed(tail[start - 1]) { start -= 1 }
        let candidate = Array(tail[start...])
        guard !candidate.isEmpty else { return nil }

        let decimal = SmartNumbers.decimalSeparator(for: language)
        // The longest calculation that reads cleanly, starting at a word boundary ("I have 3+4=" -> "3+4").
        for index in candidate.indices {
            let character = candidate[index]
            if character.isWhitespace { continue }
            if index > 0 {
                let previous = candidate[index - 1]
                if previous.isLetter || previous.isNumber || previous == "." || previous == "," { continue }
            }
            let expression = String(candidate[index...])
            if !endsWithEquals && !looksLikeSum(expression) { continue }
            guard var parser = ExpressionParser(expression, decimalComma: decimal == ",") else { continue }
            guard let value = parser.parse(), parser.operations > 0 else { continue }
            guard let formatted = SmartNumbers.format(value, decimals: decimals, language: language) else { return nil }
            if !endsWithEquals {
                // The sum is replaced by its answer alone ("3+4" -> "7"), a space after it kept.
                return SmartResult(shown: formatted, replaceCount: expression.count + (spaceAfter ? 1 : 0),
                                   insert: formatted + (spaceAfter ? " " : ""))
            }
            // "3 + 4 =" gets " 7"; "3+4=" gets "7"; after "= " the result comes straight on.
            let insert = (spaceBefore && !spaceAfter ? " " : "") + formatted
            return SmartResult(shown: formatted, replaceCount: 0, insert: insert)
        }
        return nil
    }

    /// Whether text with no "=" after it is plainly a sum and not a date, a phone number or a range: it holds an
    /// operator (or a bracket), is made of numbers and known functions, and a run of digits and dashes ("2024-05-01",
    /// "555-1234") is left alone.
    private static func looksLikeSum(_ expression: String) -> Bool {
        let characters = Array(expression)
        guard let last = characters.last(where: { !$0.isWhitespace }) else { return false }
        guard last.isNumber || ")!%π²³°".contains(last) else { return false }
        guard characters.contains(where: { "+-−*/×÷·^%!√(".contains($0) }) else { return false }
        let compact = expression.filter { !$0.isWhitespace }
        if compact.allSatisfy({ $0.isNumber || "-/.:".contains($0) }) {
            let groups = compact.split(whereSeparator: { "-/.:".contains($0) })
            if groups.count > 2 { return false }
            if groups.count == 2, !expression.contains(" "), groups.allSatisfy({ $0.count >= 3 }) { return false }
        }
        return true
    }

    private static func isAllowed(_ character: Character) -> Bool {
        if character.isNumber || character.isLetter || character == " " { return true }
        return "+-−*/×÷·^%!().,√π°²³".contains(character)
    }
}

/// A recursive-descent reader of one calculation; nil when the text is not one.
private struct ExpressionParser {
    private enum Token: Equatable {
        case number(Double)
        case name(String)
        case symbol(Character)
    }

    private var tokens: [Token] = []
    private var position = 0
    /// Operators, functions, postfix signs: a lone number is no calculation.
    private(set) var operations = 0

    init?(_ text: String, decimalComma: Bool) {
        let characters = Array(text)
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if character.isWhitespace {
                index += 1
            } else if ExpressionParser.isDigit(character)
                        || (character == "." || character == ",") && index + 1 < characters.count && ExpressionParser.isDigit(characters[index + 1]) {
                // A number: digits with one decimal point ("." always; "," where the language writes decimals so);
                // in English "1,000" is a thousand.
                var digits = ""
                var seenPoint = false
                while index < characters.count {
                    let c = characters[index]
                    if ExpressionParser.isDigit(c) {
                        digits.append(c)
                        index += 1
                    } else if c == "." || c == "," {
                        let isPoint = c == "." || decimalComma
                        if isPoint {
                            if seenPoint { return nil }
                            seenPoint = true
                            digits.append(".")
                            index += 1
                        } else {
                            // A thousands comma: exactly three digits must follow.
                            var count = 0
                            while index + 1 + count < characters.count, ExpressionParser.isDigit(characters[index + 1 + count]) { count += 1 }
                            guard count == 3 else { return nil }
                            index += 1
                        }
                    } else {
                        break
                    }
                }
                guard let value = Double(digits) else { return nil }
                tokens.append(.number(value))
            } else if character.isLetter && character != "π" {
                var name = ""
                while index < characters.count, characters[index].isLetter, characters[index] != "π" {
                    name.append(characters[index])
                    index += 1
                }
                tokens.append(.name(name.lowercased()))
            } else if "+-−*/×÷·^%!()√π°²³".contains(character) {
                tokens.append(character == "π" ? .name("π") : .symbol(character == "−" ? "-" : character))
                index += 1
            } else {
                return nil
            }
        }
        if tokens.isEmpty { return nil }
    }

    static func isDigit(_ character: Character) -> Bool {
        return character.isASCII && character.isNumber
    }

    /// The value, when every token was used.
    mutating func parse() -> Double? {
        guard let value = expression(), position == tokens.count, value.isFinite else { return nil }
        return value
    }

    private var current: Token? { return position < tokens.count ? tokens[position] : nil }

    private mutating func take(_ symbol: Character) -> Bool {
        if current == .symbol(symbol) {
            position += 1
            return true
        }
        return false
    }

    /// Sums: "200+15%" is 200 and fifteen percent of it.
    private mutating func expression() -> Double? {
        guard var value = term()?.value else { return nil }
        while true {
            let adding: Bool
            if take("+") { adding = true } else if take("-") { adding = false } else { break }
            operations += 1
            guard let right = term() else { return nil }
            let amount = right.percent ? value * right.value : right.value
            value = adding ? value + amount : value - amount
        }
        return value
    }

    /// Products, with the multiplication implied before a bracket, a constant or a function ("2(3+4)", "2π").
    private mutating func term() -> (value: Double, percent: Bool)? {
        guard var left = unary() else { return nil }
        while true {
            if take("*") || take("×") || take("·") {
                operations += 1
                guard let right = unary() else { return nil }
                left = (left.value * right.value, false)
            } else if take("/") || take("÷") {
                operations += 1
                guard let right = unary(), right.value != 0 else { return nil }
                left = (left.value / right.value, false)
            } else if case .name(let name)? = current, name == "x" {
                // "3x4": x between two numbers multiplies.
                position += 1
                operations += 1
                guard case .number? = current, let right = unary() else { return nil }
                left = (left.value * right.value, false)
            } else if current == .symbol("(") || current == .symbol("√") || isConstantOrFunction(current) {
                operations += 1
                guard let right = unary() else { return nil }
                left = (left.value * right.value, false)
            } else {
                break
            }
        }
        return left
    }

    private func isConstantOrFunction(_ token: Token?) -> Bool {
        guard case .name(let name)? = token else { return false }
        return ExpressionParser.constants[name] != nil || ExpressionParser.functions.contains(name)
    }

    private mutating func unary() -> (value: Double, percent: Bool)? {
        if take("-") {
            guard let inner = unary() else { return nil }
            return (-inner.value, inner.percent)
        }
        if take("+") { return unary() }
        return power()
    }

    /// Powers bind to the right: 2^3^2 = 2^9.
    private mutating func power() -> (value: Double, percent: Bool)? {
        guard let base = postfix() else { return nil }
        if take("^") {
            operations += 1
            guard let exponent = unary() else { return nil }
            return (pow(base.value, exponent.value), false)
        }
        return base
    }

    /// "5!" and "15%" (a percent of the number before, in a sum).
    private mutating func postfix() -> (value: Double, percent: Bool)? {
        guard var value = primary() else { return nil }
        var percent = false
        while true {
            if take("!") {
                operations += 1
                guard value >= 0, value <= 170, value == value.rounded() else { return nil }
                value = (1..<max(2, Int(value) + 1)).reduce(1.0) { $0 * Double($1) }
            } else if take("%") {
                operations += 1
                value /= 100
                percent = true
            } else if take("²") {
                operations += 1
                value *= value
            } else if take("³") {
                operations += 1
                value = value * value * value
            } else if take("°") {
                // Degrees, as the trigonometry takes them anyway.
            } else {
                break
            }
        }
        return (value, percent)
    }

    private static let constants: [String: Double] = ["π": .pi, "pi": .pi, "e": M_E, "tau": 2 * .pi]
    private static let functions: Set<String> = ["sqrt", "cbrt", "sin", "cos", "tan", "asin", "acos", "atan",
                                                 "log", "lg", "ln", "log2", "exp", "abs", "floor", "ceil", "round"]

    private mutating func primary() -> Double? {
        guard let token = current else { return nil }
        switch token {
        case .number(let value):
            position += 1
            return value
        case .symbol("("):
            position += 1
            guard let value = expression(), take(")") else { return nil }
            return value
        case .symbol("√"):
            position += 1
            operations += 1
            guard let value = argument(), value >= 0 else { return nil }
            return sqrt(value)
        case .name(let name):
            position += 1
            if let constant = ExpressionParser.constants[name] { return constant }
            guard ExpressionParser.functions.contains(name) else { return nil }
            operations += 1
            guard let x = argument() else { return nil }
            let degrees = Double.pi / 180
            switch name {
            case "sqrt": return x >= 0 ? sqrt(x) : nil
            case "cbrt": return cbrt(x)
            case "sin": return clean(sin(x * degrees))
            case "cos": return clean(cos(x * degrees))
            case "tan": return clean(tan(x * degrees))
            case "asin": return abs(x) <= 1 ? asin(x) / degrees : nil
            case "acos": return abs(x) <= 1 ? acos(x) / degrees : nil
            case "atan": return atan(x) / degrees
            case "log", "lg": return x > 0 ? log10(x) : nil
            case "ln": return x > 0 ? log(x) : nil
            case "log2": return x > 0 ? log2(x) : nil
            case "exp": return exp(x)
            case "abs": return abs(x)
            case "floor": return floor(x)
            case "ceil": return ceil(x)
            case "round": return x.rounded()
            default: return nil
            }
        default:
            return nil
        }
    }

    /// A function's argument: a bracket, or the number or name right after it ("√2", "sin 30").
    private mutating func argument() -> Double? {
        if current == .symbol("(") { return primaryWithPostfix() }
        return power()?.value
    }

    private mutating func primaryWithPostfix() -> Double? {
        return postfix()?.value
    }

    /// sin(180°) is 0, not 1.2e-16.
    private func clean(_ value: Double) -> Double {
        return abs(value) < 1e-12 ? 0 : value
    }
}

// MARK: - Units

/// "5 km" -> "3.107 mi", "70 kg" -> "154.324 lb", "20 °C" -> "68 °F", "60 mph" -> "96.561 km/h". Offered while a
/// number and a unit end the text; picking it writes the converted measurement in their place.
enum UnitConverter {
    private enum Kind { case length, mass, volume, temperature, speed, area, data }
    private enum System { case metric, imperial }

    private struct Unit {
        let symbol: String
        let names: [String]
        let kind: Kind
        let system: System
        /// How many of the kind's base unit one is (metre, kilogram, litre, m/s, m²); temperatures convert on their own.
        let factor: Double
    }

    private static let units: [Unit] = [
        Unit(symbol: "mm", names: ["mm", "millimeter", "millimeters", "millimetre", "millimetres"], kind: .length, system: .metric, factor: 0.001),
        Unit(symbol: "cm", names: ["cm", "centimeter", "centimeters", "centimetre", "centimetres"], kind: .length, system: .metric, factor: 0.01),
        Unit(symbol: "m", names: ["m", "meter", "meters", "metre", "metres"], kind: .length, system: .metric, factor: 1),
        Unit(symbol: "km", names: ["km", "kilometer", "kilometers", "kilometre", "kilometres"], kind: .length, system: .metric, factor: 1000),
        Unit(symbol: "in", names: ["inch", "inches", "\u{2033}", "\""], kind: .length, system: .imperial, factor: 0.0254),
        Unit(symbol: "ft", names: ["ft", "foot", "feet", "\u{2032}"], kind: .length, system: .imperial, factor: 0.3048),
        Unit(symbol: "yd", names: ["yd", "yard", "yards"], kind: .length, system: .imperial, factor: 0.9144),
        Unit(symbol: "mi", names: ["mi", "mile", "miles"], kind: .length, system: .imperial, factor: 1609.344),
        Unit(symbol: "mg", names: ["mg", "milligram", "milligrams"], kind: .mass, system: .metric, factor: 0.000001),
        Unit(symbol: "g", names: ["g", "gram", "grams", "gramme", "grammes"], kind: .mass, system: .metric, factor: 0.001),
        Unit(symbol: "kg", names: ["kg", "kilogram", "kilograms", "kilo", "kilos"], kind: .mass, system: .metric, factor: 1),
        Unit(symbol: "t", names: ["t", "tonne", "tonnes", "metric ton", "metric tons"], kind: .mass, system: .metric, factor: 1000),
        Unit(symbol: "st", names: ["stone", "stones"], kind: .mass, system: .imperial, factor: 6.35029318),
        Unit(symbol: "oz", names: ["oz", "ounce", "ounces"], kind: .mass, system: .imperial, factor: 0.028349523125),
        Unit(symbol: "lb", names: ["lb", "lbs", "pound", "pounds"], kind: .mass, system: .imperial, factor: 0.45359237),
        Unit(symbol: "ml", names: ["ml", "milliliter", "milliliters", "millilitre", "millilitres"], kind: .volume, system: .metric, factor: 0.001),
        Unit(symbol: "cl", names: ["cl", "centiliter", "centiliters", "centilitre", "centilitres"], kind: .volume, system: .metric, factor: 0.01),
        Unit(symbol: "dl", names: ["dl", "deciliter", "deciliters", "decilitre", "decilitres"], kind: .volume, system: .metric, factor: 0.1),
        Unit(symbol: "l", names: ["l", "liter", "liters", "litre", "litres"], kind: .volume, system: .metric, factor: 1),
        Unit(symbol: "fl oz", names: ["fl oz", "floz", "fluid ounce", "fluid ounces"], kind: .volume, system: .imperial, factor: 0.0295735295625),
        Unit(symbol: "cups", names: ["cup", "cups"], kind: .volume, system: .imperial, factor: 0.2365882365),
        Unit(symbol: "tbsp", names: ["tbsp", "tablespoon", "tablespoons"], kind: .volume, system: .imperial, factor: 0.01478676478125),
        Unit(symbol: "tsp", names: ["tsp", "teaspoon", "teaspoons"], kind: .volume, system: .imperial, factor: 0.00492892159375),
        Unit(symbol: "pt", names: ["pt", "pint", "pints"], kind: .volume, system: .imperial, factor: 0.473176473),
        Unit(symbol: "qt", names: ["qt", "quart", "quarts"], kind: .volume, system: .imperial, factor: 0.946352946),
        Unit(symbol: "gal", names: ["gal", "gallon", "gallons"], kind: .volume, system: .imperial, factor: 3.785411784),
        Unit(symbol: "°C", names: ["°c", "ºc", "\u{2103}", "celsius", "degrees celsius"], kind: .temperature, system: .metric, factor: 1),
        Unit(symbol: "°F", names: ["°f", "ºf", "\u{2109}", "fahrenheit", "degrees fahrenheit"], kind: .temperature, system: .imperial, factor: 1),
        Unit(symbol: "K", names: ["kelvin", "\u{00B0}k", "\u{212A}"], kind: .temperature, system: .metric, factor: 1),
        Unit(symbol: "kn", names: ["kn", "knot", "knots"], kind: .speed, system: .imperial, factor: 0.514444),
        Unit(symbol: "B", names: ["byte", "bytes"], kind: .data, system: .metric, factor: 1),
        Unit(symbol: "kB", names: ["kb", "kilobyte", "kilobytes"], kind: .data, system: .metric, factor: 1e3),
        Unit(symbol: "MB", names: ["mb", "megabyte", "megabytes"], kind: .data, system: .metric, factor: 1e6),
        Unit(symbol: "GB", names: ["gb", "gigabyte", "gigabytes"], kind: .data, system: .metric, factor: 1e9),
        Unit(symbol: "TB", names: ["tb", "terabyte", "terabytes"], kind: .data, system: .metric, factor: 1e12),
        Unit(symbol: "km/h", names: ["km/h", "kmh", "kph", "km/hr"], kind: .speed, system: .metric, factor: 1 / 3.6),
        Unit(symbol: "m/s", names: ["m/s"], kind: .speed, system: .metric, factor: 1),
        Unit(symbol: "mph", names: ["mph", "mi/h"], kind: .speed, system: .imperial, factor: 0.44704),
        Unit(symbol: "m²", names: ["m²", "m2", "sqm", "square meters", "square metres"], kind: .area, system: .metric, factor: 1),
        Unit(symbol: "cm\u{00B2}", names: ["cm\u{00B2}", "cm2", "square centimeters", "square centimetres"], kind: .area, system: .metric, factor: 0.0001),
        Unit(symbol: "in\u{00B2}", names: ["in\u{00B2}", "in2", "sq in", "square inches"], kind: .area, system: .imperial, factor: 0.00064516),
        Unit(symbol: "yd\u{00B2}", names: ["yd\u{00B2}", "yd2", "sq yd", "square yards"], kind: .area, system: .imperial, factor: 0.83612736),
        Unit(symbol: "ha", names: ["ha", "hectare", "hectares"], kind: .area, system: .metric, factor: 10_000),
        Unit(symbol: "km²", names: ["km²", "km2", "square kilometers", "square kilometres"], kind: .area, system: .metric, factor: 1_000_000),
        Unit(symbol: "ft²", names: ["ft²", "ft2", "sq ft", "sqft", "square feet"], kind: .area, system: .imperial, factor: 0.09290304),
        Unit(symbol: "acres", names: ["acre", "acres"], kind: .area, system: .imperial, factor: 4046.8564224),
        Unit(symbol: "mi²", names: ["mi²", "mi2", "sq mi", "square miles"], kind: .area, system: .imperial, factor: 2_589_988.110336)
    ]

    /// Every way a unit can be written (lower case) -> the unit, longest first for the matcher.
    private static let byName: [(name: String, unit: Unit)] = {
        var list: [(name: String, unit: Unit)] = []
        for unit in units { for name in unit.names { list.append((name, unit)) } }
        return list.sorted { $0.name.count > $1.name.count }
    }()

    /// The first conversion (the one `result` offers where only one fits).
    static func result(before: String, language: Language, decimals: Int, target: String) -> SmartResult? {
        return results(before: before, language: language, decimals: decimals, target: target).first
    }

    /// Every unit of the same kind the measurement can be written in, the likeliest first. `target`: "auto" (all of
    /// them), "metric" or "imperial" (only that system's).
    static func results(before: String, language: Language, decimals: Int, target: String) -> [SmartResult] {
        var text = SmartNumbers.westernDigits(String(before.suffix(48)))
        var trailing = ""
        if text.hasSuffix(" ") {
            text.removeLast()
            trailing = " "
        }
        let lower = text.lowercased()
        guard lower.count == text.count else { return [] }
        for (name, unit) in byName where lower.hasSuffix(name) {
            var rest = String(text.dropLast(name.count))
            // A unit spelled out needs a space before it ("5 miles"); a symbol may touch the number ("5km").
            let spaced = rest.hasSuffix(" ")
            if spaced { rest.removeLast() }
            if !spaced, name.count > 2, name.first?.isLetter == true { continue }
            // The unit is a whole word: "5 cm" but not "5 acm".
            guard let number = trailingNumber(in: rest, language: language) else { continue }
            let replaced = number.length + (spaced ? 1 : 0) + name.count + trailing.count
            var converted: [(unit: Unit, value: Double)] = []
            for other in units where other.kind == unit.kind && other.symbol != unit.symbol {
                if unit.kind != .data {
                    if target == "metric" && other.system != .metric { continue }
                    if target == "imperial" && other.system != .imperial { continue }
                }
                converted.append((other, convert(number.value, from: unit, to: other)))
            }
            // The values nearest a few tens first: 30 m is 32.8 yd and 98.4 ft before 0.03 km and 30 000 mm.
            func distance(_ value: Double) -> Double {
                return value == 0 ? 0 : abs(log10(abs(value) / 30))
            }
            let ordered = converted.enumerated().sorted { first, second in
                let (a, b) = (distance(first.element.value), distance(second.element.value))
                return a == b ? first.offset < second.offset : a < b
            }.map { $0.element }
            var list: [SmartResult] = []
            for item in ordered {
                guard let formatted = SmartNumbers.format(item.value, decimals: decimals, language: language) else { continue }
                let shown = formatted + " " + item.unit.symbol
                list.append(SmartResult(shown: shown, replaceCount: replaced, insert: shown + trailing))
            }
            return list
        }
        return []
    }

    private static func convert(_ value: Double, from: Unit, to: Unit) -> Double {
        if from.kind == .temperature {
            let celsius: Double
            switch from.symbol {
            case "°F": celsius = (value - 32) * 5 / 9
            case "K": celsius = value - 273.15
            default: celsius = value
            }
            switch to.symbol {
            case "°F": return celsius * 9 / 5 + 32
            case "K": return celsius + 273.15
            default: return celsius
            }
        }
        return value * from.factor / to.factor
    }

    /// The number that ends `text` ("-3", "2.5", "1,000"), standing on its own, and how many characters it takes.
    private static func trailingNumber(in text: String, language: Language) -> (value: Double, length: Int)? {
        let characters = Array(text)
        var start = characters.count
        while start > 0, characters[start - 1].isNumber || characters[start - 1] == "." || characters[start - 1] == "," {
            start -= 1
        }
        if start > 0, characters[start - 1] == "-" || characters[start - 1] == "\u{2212}" { start -= 1 }
        guard start < characters.count else { return nil }
        if start > 0 {
            let previous = characters[start - 1]
            guard previous.isWhitespace || "([{".contains(previous) else { return nil }
        }
        var raw = String(characters[start...])
        guard raw.last?.isNumber == true, raw.contains(where: { $0.isNumber }) else { return nil }
        let length = raw.count
        raw = raw.replacingOccurrences(of: "\u{2212}", with: "-")
        if SmartNumbers.decimalSeparator(for: language) == "," {
            // "1.000,5" in Hungarian: dots group, the comma is the decimal point; "2.5" still reads as a decimal.
            if raw.contains(",") { raw = raw.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".") }
        } else {
            raw = raw.replacingOccurrences(of: ",", with: "")
        }
        guard let value = Double(raw) else { return nil }
        return (value, length)
    }
}
