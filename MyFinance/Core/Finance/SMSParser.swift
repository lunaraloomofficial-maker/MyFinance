import Foundation
import CryptoKit

public enum ParseConfidence: String, Codable { case high, medium, low, invalid }
public struct ParsedSMS: Codable, Equatable {
    public var amount: Int64?
    public var kind: EntryKind?
    public var currency: String = "LKR"
    public var bank: String?
    public var maskedIdentifier: String?
    public var merchant: String?
    public var date: Date
    public var explicitDate: Bool = false
    public var reference: String?
    public var reportedBalance: Int64?
    public var confidence: ParseConfidence = .invalid
    public var reason: String = "Unsupported message"
    public var fingerprint: String
}
public protocol SMSParsing { func parse(_ text: String, sender: String, receivedAt: Date) -> ParsedSMS }
/// Generic heuristics only. No bank-specific SMS format is claimed to be verified.
public struct SMSParser: SMSParsing {
    public init() {}
    public static let banks = ["Commercial Bank", "HNB", "Sampath Bank", "Bank of Ceylon", "People's Bank", "Seylan Bank", "NDB", "DFCC", "Nations Trust Bank"]
    public static func fingerprint(_ text: String) -> String {
        SHA256.hash(data: Data(text.lowercased().split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").utf8)).map { String(format: "%02x", $0) }.joined()
    }
    public func parse(_ text: String, sender: String = "", receivedAt: Date = Date()) -> ParsedSMS {
        var result = ParsedSMS(date: receivedAt, fingerprint: Self.fingerprint(text))
        guard !text.isEmpty, text.utf8.count <= 16_384 else { return result }
        let lower = text.lowercased()
        if match(#"\b(otp|one[ -]time|verification|verify|passcode|security code|promo|offer|discount|win a|apply now)\b"#, lower) != nil { result.reason = "Security or promotional message rejected"; return result }
        if match(#"\b(USD|EUR|GBP|INR|AUD|SGD)\b"#, text) != nil { result.reason = "Only LKR imports are supported"; return result }
        let credit = match(#"\b(credited|deposited|payment received|salary credit|refund(?:ed)?|reversed)\b"#, lower) != nil
        let debit = match(#"\b(debited|withdrawn|withdrawal|purchase|pos|spent|online payment|card transaction|paid)\b"#, lower) != nil
        let uncertainEvent = match(#"\b(transfer|fee|service charge|payment)\b"#, lower) != nil
        guard credit || debit || uncertainEvent else { result.reason = "No credit or debit event found"; return result }
        result.bank = Self.banks.first { (sender + " " + text).localizedCaseInsensitiveContains($0) }
        if result.bank == nil {
            let aliases = [("COMBANK", "Commercial Bank"), ("SAMPATH", "Sampath Bank"), ("BOC", "Bank of Ceylon"), ("SEYLAN", "Seylan Bank"), ("NTB", "Nations Trust Bank")]
            result.bank = aliases.first { sender.localizedCaseInsensitiveContains($0.0) }?.1
        }
        result.maskedIdentifier = capture(#"((?:X{2,}|\*{2,})\s*\d{4})"#, text)?.replacingOccurrences(of: " ", with: "").uppercased()
        result.reference = capture(#"\b(?:ref(?:erence)?|txn(?:\s*id)?)\s*[:#.-]?\s*([A-Z0-9][A-Z0-9-]{2,})"#, text)
        let balancePattern = #"(?:available\s*(?:balance|bal)|avail\.?\s*(?:balance|bal)|balance|bal)\s*[:=]?\s*(?:LKR\s*|Rs\.?\s*)?([\d,]+(?:\.\d{1,2})?)"#
        if let balance = capture(balancePattern, text) { result.reportedBalance = try? Money.parse(balance) }
        let withoutBalance = replacing(balancePattern + #"(?:\s*LKR)?"#, in: text, with: " ")
        let pattern = #"(?:\bLKR\s*|\bRs\.?\s*)([\d,]+(?:\.\d{1,2})?)(?![\d.])|(?<![\d.,])([\d,]+(?:\.\d{1,2})?)\s*LKR\b"#
        let amounts = captures(pattern, withoutBalance).compactMap { groups -> Int64? in groups.compactMap { try? Money.parse($0) }.first }
        guard let amount = amounts.first, amount > 0 else { result.reason = "No valid transaction amount found"; return result }
        result.amount = amount
        result.kind = credit ? (match(#"refund|reversed"#, lower) != nil ? .refund : .income) : (match(#"\bfee\b|service charge"#, lower) != nil ? .fee : .expense)
        result.merchant = capture(#"\b(?:at|to|from)\s+(.+?)(?=\s+(?:on|using|via|ref|available|balance|bal|a/c|account|card)\b|[.;]|$)"#, text)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let datePatterns = [(#"\b(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}(?::\d{2})?)\b"#, ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm"]), (#"\b(\d{2}[/-]\d{2}[/-]\d{4}(?:\s+\d{2}:\d{2})?)\b"#, ["dd/MM/yyyy HH:mm", "dd-MM-yyyy HH:mm", "dd/MM/yyyy", "dd-MM-yyyy"]), (#"\b(\d{4}-\d{2}-\d{2})\b"#, ["yyyy-MM-dd"])]
        for (pattern, formats) in datePatterns {
            if let raw = capture(pattern, text) {
                for format in formats {
                    let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "Asia/Colombo"); formatter.dateFormat = format; formatter.isLenient = false
                    if let date = formatter.date(from: raw) { result.date = date; result.explicitDate = true; break }
                }
                break
            }
        }
        if (!credit && !debit) || credit && debit || amounts.count != 1 || lower.contains("transfer") || (lower.contains("payment") && lower.contains("credit card")) {
            result.confidence = .low; result.reason = "Direction, amount or transfer classification needs review"
        } else if result.bank != nil && result.maskedIdentifier != nil && result.explicitDate && result.reference != nil {
            result.confidence = .high; result.reason = "Amount, direction, bank, account, date and reference identified"
        } else { result.confidence = .medium; result.reason = "Please verify the account, date and category" }
        return result
    }
    private func match(_ pattern: String, _ text: String) -> String? { text.range(of: pattern, options: [.regularExpression, .caseInsensitive]).map { String(text[$0]) } }
    private func capture(_ pattern: String, _ text: String) -> String? { captures(pattern, text).first?.first }
    private func captures(_ pattern: String, _ text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { match in (1..<match.numberOfRanges).compactMap { Range(match.range(at: $0), in: text).map { String(text[$0]) } } }
    }
    private func replacing(_ pattern: String, in text: String, with replacement: String) -> String { text.replacingOccurrences(of: pattern, with: replacement, options: [.regularExpression, .caseInsensitive]) }
}
public enum Duplicates {
    public static func matches(_ parsed: ParsedSMS, accountID: UUID, entries: [Entry]) -> [Entry] {
        entries.filter { entry in
            guard entry.accountID == accountID else { return false }
            if !entry.fingerprint.isEmpty && entry.fingerprint == parsed.fingerprint { return true }
            if let reference = parsed.reference, !reference.isEmpty, entry.reference?.lowercased() == reference.lowercased() { return true }
            guard parsed.explicitDate, let amount = parsed.amount, let kind = parsed.kind else { return false }
            return abs(entry.amount) == amount && (entry.amount > 0) == ([.income, .refund].contains(kind)) && abs(entry.date.timeIntervalSince(parsed.date)) < 60 && entry.merchant.caseInsensitiveCompare(parsed.merchant ?? "") == .orderedSame
        }
    }
}
