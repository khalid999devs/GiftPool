import Foundation

enum InviteService {
    static let tokenLength = 16
    static let validity: TimeInterval = 14 * 24 * 60 * 60
    // No 0/O or 1/I, so codes are easy to read aloud and retype.
    private static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func makeToken() -> String {
        var generator = SystemRandomNumberGenerator()
        return String((0..<tokenLength).map { _ in alphabet[Int.random(in: 0..<alphabet.count, using: &generator)] })
    }

    static func normalize(_ input: String) -> String? {
        let cleaned = input.uppercased().filter { $0.isLetter || $0.isNumber }
        guard cleaned.count == tokenLength, cleaned.allSatisfy({ alphabet.contains($0) }) else { return nil }
        return cleaned
    }

    static func displayCode(_ token: String) -> String {
        stride(from: 0, to: token.count, by: 4).map { start in
            let begin = token.index(token.startIndex, offsetBy: start)
            let end = token.index(begin, offsetBy: 4, limitedBy: token.endIndex) ?? token.endIndex
            return String(token[begin..<end])
        }
        .joined(separator: "-")
    }

    static func expiryDate(from now: Date = .now) -> Date {
        now.addingTimeInterval(validity)
    }
}
