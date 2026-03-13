import Foundation

nonisolated func parsedLeadingInteger(in value: String) -> Int? {
    let digits = value.split(whereSeparator: { !$0.isNumber }).first
    return digits.flatMap { Int($0) }
}

nonisolated func optionalParsedLeadingInteger(in value: String, isEnabled: Bool) -> Int? {
    guard isEnabled else { return nil }
    return parsedLeadingInteger(in: value)
}

nonisolated func parsedDimensions(in value: String, separator: Character = "x") -> (width: Int, height: Int)? {
    let parts = value.split(separator: separator)
    guard parts.count == 2,
          let width = Int(parts[0]),
          let height = Int(parts[1]) else {
        return nil
    }
    return (width, height)
}

nonisolated func optionalParsedDimensions(in value: String, isEnabled: Bool) -> (width: Int, height: Int)? {
    guard isEnabled else { return nil }
    return parsedDimensions(in: value)
}

nonisolated func parsedParenthesizedInteger(in value: String) -> Int? {
    guard let start = value.firstIndex(of: "("),
          let end = value.firstIndex(of: ")"),
          start < end else {
        return nil
    }
    let substring = value[value.index(after: start)..<end]
    let digits = substring.filter(\.isNumber)
    return Int(digits)
}

nonisolated func parsedTrailingDouble(in value: String, trimming suffix: Character) -> Double? {
    guard value.last == suffix else { return nil }
    return Double(value.dropLast())
}
