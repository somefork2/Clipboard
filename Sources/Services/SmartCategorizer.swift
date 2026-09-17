import NaturalLanguage
import Foundation

// MARK: - Результат категоризации

struct CategorizationResult {
    let category: ContentCategory
    let language: String?
    let confidence: Double
    let entities: [ExtractedEntity]
    let sentiment: Double  // -1.0 (негатив) ... 0.0 (нейтрально) ... +1.0 (позитив)
    let tags: [String]
    let suggestedTitle: String
    let isSensitive: Bool
}

struct ExtractedEntity: Identifiable, Codable {
    var id = UUID()
    let type: EntityType
    let value: String
    let range: NSRange?
}

enum EntityType: String, Codable, CaseIterable {
    case email
    case phoneNumber
    case url
    case personalName
    case organizationName
    case placeName
    case date
    case monetaryAmount
    case codeSnippet

    var displayName: String {
        switch self {
        case .email: return "Email"
        case .phoneNumber: return "Phone"
        case .url: return "URL"
        case .personalName: return "Name"
        case .organizationName: return "Organization"
        case .placeName: return "Place"
        case .date: return "Date"
        case .monetaryAmount: return "Money"
        case .codeSnippet: return "Code"
        }
    }

    var icon: String {
        switch self {
        case .email: return "envelope.fill"
        case .phoneNumber: return "phone.fill"
        case .url: return "link"
        case .personalName: return "person.fill"
        case .organizationName: return "building.2.fill"
        case .placeName: return "mappin.circle.fill"
        case .date: return "calendar"
        case .monetaryAmount: return "dollarsign.circle.fill"
        case .codeSnippet: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

// MARK: - Smart Categorizer (NaturalLanguage + Apple Intelligence)

actor SmartCategorizer {

    static let shared = SmartCategorizer()

    // Kэш для определения языка
    private let languageRecognizer = NLLanguageRecognizer()
    private var cachedModels: [String: NLModel] = [:]

    // MARK: - Основная функция категоризации

    func categorize(_ text: String) async -> CategorizationResult {
        // 1. Определяем язык
        let language = detectLanguage(text)

        // 2. Извлекаем сущности (NER)
        let entities = extractEntities(from: text)

        // 3. Определяем категорию контента
        let category = classifyContent(text, entities: entities)

        // 4. Анализируем sentiment
        let sentiment = analyzeSentiment(text)

        // 5. Извлекаем теги
        let tags = extractTags(from: text, entities: entities)

        // 6. Проверяем чувствительность
        let isSensitive = checkSensitivity(text, entities: entities)

        // 7. Предлагаем заголовок
        let title = suggestTitle(text, category: category, entities: entities)

        // 8. Confidence score
        let confidence = calculateConfidence(entities: entities, category: category)

        // 9. Если доступен Apple Intelligence — обогащаем результат
        if #available(macOS 26.0, *) {
            let enriched = await appleIntelligenceEnrich(text, baseResult: CategorizationResult(
                category: category, language: language, confidence: confidence,
                entities: entities, sentiment: sentiment, tags: tags,
                suggestedTitle: title, isSensitive: isSensitive
            ))
            return enriched
        }

        return CategorizationResult(
            category: category, language: language, confidence: confidence,
            entities: entities, sentiment: sentiment, tags: tags,
            suggestedTitle: title, isSensitive: isSensitive
        )
    }

    // MARK: - Определение языка

    private func detectLanguage(_ text: String) -> String? {
        languageRecognizer.reset()
        languageRecognizer.processString(text)
        guard let lang = languageRecognizer.dominantLanguage else { return nil }
        return lang.rawValue
    }

    // MARK: - Извлечение сущностей (NER)

    private func extractEntities(from text: String) -> [ExtractedEntity] {
        var entities: [ExtractedEntity] = []
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = text

        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            guard let tag else { return true }

            let entityValue = String(text[range])
            let nsRange = NSRange(range, in: text)

            switch tag {
            case .personalName:
                entities.append(ExtractedEntity(type: .personalName, value: entityValue, range: nsRange))
            case .organizationName:
                entities.append(ExtractedEntity(type: .organizationName, value: entityValue, range: nsRange))
            case .placeName:
                entities.append(ExtractedEntity(type: .placeName, value: entityValue, range: nsRange))
            default:
                break
            }
            return true
        }

        // Дополнительно: regex для email, phone, URL, дат
        entities.append(contentsOf: extractRegexEntities(from: text))

        return entities
    }

    private func extractRegexEntities(from text: String) -> [ExtractedEntity] {
        var entities: [ExtractedEntity] = []

        // Email
        let emailPattern = #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
        if let regex = try? NSRegularExpression(pattern: emailPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range, in: text) {
                    entities.append(ExtractedEntity(type: .email, value: String(text[range]), range: match.range))
                }
            }
        }

        // Phone
        let phonePattern = #"[\+]?[(]?[0-9]{1,4}[)]?[-\s\.]?[0-9]{1,4}[-\s\.]?[0-9]{1,9}"#
        if let regex = try? NSRegularExpression(pattern: phonePattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let phone = String(text[range]).trimmingCharacters(in: .whitespaces)
                    if phone.count >= 7 {
                        entities.append(ExtractedEntity(type: .phoneNumber, value: phone, range: match.range))
                    }
                }
            }
        }

        // URL
        let urlPattern = #"https?://[^\s]+"#
        if let regex = try? NSRegularExpression(pattern: urlPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range, in: text) {
                    entities.append(ExtractedEntity(type: .url, value: String(text[range]), range: match.range))
                }
            }
        }

        // Monetary amounts
        let moneyPattern = #"[\$€£¥][\d,]+\.?\d*"# 
        if let regex = try? NSRegularExpression(pattern: moneyPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range, in: text) {
                    entities.append(ExtractedEntity(type: .monetaryAmount, value: String(text[range]), range: match.range))
                }
            }
        }

        return entities
    }

    // MARK: - Классификация контента

    private func classifyContent(_ text: String, entities: [ExtractedEntity]) -> ContentCategory {
        // Код
        if looksLikeCode(text) { return .code }

        // Ссылки
        if entities.contains(where: { $0.type == .url }) { return .links }

        // Контакты
        let hasEmail = entities.contains(where: { $0.type == .email })
        let hasPhone = entities.contains(where: { $0.type == .phoneNumber })
        let hasName = entities.contains(where: { $0.type == .personalName })
        if hasEmail || hasPhone || hasName { return .contacts }

        // Адреса
        if entities.contains(where: { $0.type == .placeName }) { return .addresses }

        // Длинный текст = заметки
        if text.count > 300 { return .notes }

        return .text
    }

    private func looksLikeCode(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let codeIndicators = [
            "func ", "var ", "let ", "if ", "else ", "for ", "while ",
            "class ", "struct ", "enum ", "protocol ", "import ",
            "return ", "print(", "console.log", "def ", "self.",
            "<div", "<span", "<html", "<?php", "#include",
            "=>", "->", "&&", "||", "!=", "===", "!=="
        ]
        for indicator in codeIndicators {
            if trimmed.lowercased().contains(indicator.lowercased()) { return true }
        }

        // Проверка на баланс скобок
        let openBraces = text.filter { $0 == "{" }.count
        let closeBraces = text.filter { $0 == "}" }.count
        if openBraces > 0 && openBraces == closeBraces { return true }

        let openParens = text.filter { $0 == "(" }.count
        let closeParens = text.filter { $0 == ")" }.count
        if openParens > 2 && openParens == closeParens { return true }

        return false
    }

    // MARK: - Sentiment Analysis

    private func analyzeSentiment(_ text: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text

        guard let tag = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore).0 else {
            return 0.0
        }
        return Double(tag.rawValue) ?? 0.0
    }

    // MARK: - Tag Extraction

    private func extractTags(from text: String, entities: [ExtractedEntity]) -> [String] {
        var tags: [String] = []
        let lowercased = text.lowercased()

        // Теги по содержимому
        if lowercased.contains("todo") || lowercased.contains("задача") || lowercased.contains("task") { tags.append("todo") }
        if lowercased.contains("meeting") || lowercased.contains("встреча") || lowercased.contains("sync") { tags.append("meeting") }
        if lowercased.contains("deadline") || lowercased.contains("дедлайн") || lowercased.contains("крайний срок") { tags.append("deadline") }
        if lowercased.contains("password") || lowercased.contains("пароль") || lowercased.contains("token") { tags.append("sensitive") }
        if lowercased.contains("bug") || lowercased.contains("fix") || lowercased.contains("error") || lowercased.contains("ошибка") { tags.append("bug") }
        if lowercased.contains("idea") || lowercased.contains("идея") || lowercased.contains(" thoughts") { tags.append("idea") }
        if lowercased.contains("link") || lowercased.contains("ссылка") || lowercased.contains("check") { tags.append("link") }
        if lowercased.contains("address") || lowercased.contains("адрес") || lowercased.contains("улица") { tags.append("address") }

        // Теги по сущностям
        if entities.contains(where: { $0.type == .email }) { tags.append("email") }
        if entities.contains(where: { $0.type == .phoneNumber }) { tags.append("phone") }
        if entities.contains(where: { $0.type == .organizationName }) { tags.append("company") }

        // Убираем дубликаты
        return Array(Set(tags)).sorted()
    }

    // MARK: - Sensitivity Check

    private func checkSensitivity(_ text: String, entities: [ExtractedEntity]) -> Bool {
        let lowercased = text.lowercased()
        let sensitivePatterns = [
            "password", "passwd", "pwd", "secret", "token",
            "api_key", "apikey", "api-key", "auth", "credential",
            "credit card", "信用卡", "номер карты", "cvv", "ssn",
            "social security", "passport", "паспорт"
        ]
        for pattern in sensitivePatterns {
            if lowercased.contains(pattern) { return true }
        }

        // Если найдены персональные данные — тоже чувствительно
        if entities.contains(where: { $0.type == .email }) && text.count < 100 { return true }

        return false
    }

    // MARK: - Title Suggestion

    private func suggestTitle(_ text: String, category: ContentCategory, entities: [ExtractedEntity]) -> String {
        switch category {
        case .code:
            // Попробовать найти имя функции/класса
            if let funcMatch = text.range(of: #"func\s+(\w+)"#, options: .regularExpression) {
                return "Function: \(String(text[funcMatch]).replacingOccurrences(of: "func ", with: ""))"
            }
            if let classMatch = text.range(of: #"class\s+(\w+)"#, options: .regularExpression) {
                return "Class: \(String(text[classMatch]).replacingOccurrences(of: "class ", with: ""))"
            }
            return "Code Snippet"

        case .links:
            if let urlEntity = entities.first(where: { $0.type == .url }),
               let url = URL(string: urlEntity.value) {
                return url.host() ?? "Link"
            }
            return "Link"

        case .contacts:
            if let name = entities.first(where: { $0.type == .personalName }) {
                return "Contact: \(name.value)"
            }
            if let email = entities.first(where: { $0.type == .email }) {
                return "Email: \(email.value)"
            }
            return "Contact"

        case .addresses:
            if let place = entities.first(where: { $0.type == .placeName }) {
                return "📍 \(place.value)"
            }
            return "Address"

        case .notes:
            let firstLine = String(text.prefix(60)).replacingOccurrences(of: "\n", with: " ")
            return "\(firstLine)..."

        default:
            let preview = String(text.prefix(40))
            return preview.isEmpty ? "Text" : preview
        }
    }

    // MARK: - Confidence Score

    private func calculateConfidence(entities: [ExtractedEntity], category: ContentCategory) -> Double {
        var confidence: Double = 0.5  // базовый

        // Если нашли сущности — уверенность выше
        if !entities.isEmpty { confidence += 0.15 * Double(min(entities.count, 3)) }

        // Если категория не "text" — выше
        if category != .text { confidence += 0.1 }

        return min(confidence, 1.0)
    }

    // MARK: - Apple Intelligence (macOS 26+)

    @available(macOS 26.0, *)
    private func appleIntelligenceEnrich(_ text: String, baseResult: CategorizationResult) async -> CategorizationResult {
        // Apple Intelligence API доступен через FoundationModels
        // Пока используем fallback — в будущем здесь будет вызов LLM

        // TODO: Интеграция с Apple Intelligence
        // let session = LanguageModelSession()
        // let response = await session.respond(to: "Категоризируй: \(text)")

        return baseResult
    }
}

// MARK: - ContentCategory (обновлённый)

enum ContentCategory: String, Codable, CaseIterable {
    case text
    case code
    case links
    case contacts
    case addresses
    case notes
    case images
    case files

    var displayName: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .text: return "doc.text"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .links: return "link"
        case .contacts: return "person.2"
        case .addresses: return "mappin.and.ellipse"
        case .notes: return "note.text"
        case .images: return "photo"
        case .files: return "doc"
        }
    }

    var color: String {
        switch self {
        case .text: return "blue"
        case .code: return "green"
        case .links: return "purple"
        case .contacts: return "pink"
        case .addresses: return "orange"
        case .notes: return "cyan"
        case .images: return "yellow"
        case .files: return "gray"
        }
    }
}
