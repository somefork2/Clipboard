import Foundation

struct TypeDetector {
    func detectType(for text: String) -> ContentType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isURL(trimmed) { return .url }
        if isEmail(trimmed) { return .email }
        if isPhoneNumber(trimmed) { return .phoneNumber }
        if isColor(trimmed) { return .color }
        if isCode(trimmed) { return .code }
        if isPassword(trimmed) { return .password }
        return .text
    }

    /// Whether a clip looks like a credential.
    ///
    /// The old rule flagged any 8–128 character string containing an upper, a
    /// lower, a digit and a symbol. With "never record passwords" on by default
    /// that silently threw away tokens, hashes, IDs and one-line code — the user
    /// copied something and it simply did not appear. The strongest signal is
    /// the pasteboard's own concealed marker, which is honoured separately; this
    /// is only the fallback, and it is deliberately narrow.
    func isPassword(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // A labelled secret: "password: hunter2", "api_key=…", "Bearer …".
        if let range = trimmed.range(of: #"(?i)\b(pass(word|wd)?|passphrase|secret|api[_-]?key|access[_-]?token|client[_-]?secret|private[_-]?key)\b\s*[:=]"#,
                                     options: .regularExpression),
           range.lowerBound == trimmed.startIndex || trimmed.distance(from: trimmed.startIndex, to: range.lowerBound) < 40 {
            return true
        }

        // Recognisable credential formats.
        if trimmed.range(of: #"^(sk|pk|rk)_(live|test)_[A-Za-z0-9]{16,}$"#, options: .regularExpression) != nil { return true }
        if trimmed.range(of: #"^gh[pousr]_[A-Za-z0-9]{20,}$"#, options: .regularExpression) != nil { return true }
        if trimmed.range(of: #"^-----BEGIN [A-Z ]*PRIVATE KEY-----"#, options: .regularExpression) != nil { return true }

        // A bare high-entropy token: one word, mixed classes, no punctuation that
        // would make it a path, a URL or a sentence.
        guard !trimmed.contains(where: { $0.isWhitespace }),
              (12...64).contains(trimmed.count),
              !trimmed.contains("/"),
              !trimmed.contains("\\"),
              !trimmed.contains("@"),
              !trimmed.hasPrefix("#"),
              isURL(trimmed) == false else {
            return false
        }

        let hasUpper = trimmed.contains { $0.isUppercase }
        let hasLower = trimmed.contains { $0.isLowercase }
        let hasDigit = trimmed.contains { $0.isNumber }
        let hasSymbol = trimmed.contains { !$0.isLetter && !$0.isNumber }
        return hasUpper && hasLower && hasDigit && hasSymbol
    }

    private func isURL(_ text: String) -> Bool { text.range(of: #"https?://[^\s]+"#, options: .regularExpression) != nil }
    private func isEmail(_ text: String) -> Bool { text.range(of: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, options: .regularExpression) != nil }
    private func isPhoneNumber(_ text: String) -> Bool { text.range(of: #"^[\+]?[(]?[0-9]{1,4}[)]?[-\s\.]?[0-9]{1,4}[-\s\.]?[0-9]{1,9}$"#, options: .regularExpression) != nil }
    private func isColor(_ text: String) -> Bool {
        text.range(of: #"^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$"#, options: .regularExpression) != nil ||
        text.range(of: #"^rgb\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*\)$"#, options: .regularExpression) != nil
    }
    private func isCode(_ text: String) -> Bool {
        let codeIndicators = ["func ", "var ", "let ", "if ", "class ", "struct ", "import ", "return ", "print(", "console.log", "def ", "self.", "<div", "<?php"]
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for indicator in codeIndicators { if trimmed.lowercased().hasPrefix(indicator.lowercased()) { return true } }
        return false
    }
}
