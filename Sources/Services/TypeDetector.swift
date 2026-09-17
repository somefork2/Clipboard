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

    func isPassword(_ text: String) -> Bool {
        let indicators = ["password", "passwd", "pwd", "secret", "token", "api_key", "apikey"]
        let lowercased = text.lowercased()
        for indicator in indicators { if lowercased.contains(indicator) { return true } }
        if text.count >= 8 && text.count <= 128 {
            let hasUpper = text.contains { $0.isUppercase }
            let hasLower = text.contains { $0.isLowercase }
            let hasDigit = text.contains { $0.isNumber }
            let hasSpecial = text.contains { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }
            if hasUpper && hasLower && hasDigit && hasSpecial { return true }
        }
        return false
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
