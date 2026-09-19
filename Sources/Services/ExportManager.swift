import Foundation
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable, Identifiable {
    case json, csv, markdown, html

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .markdown: return "md"
        case .html: return "html"
        }
    }

    var contentType: UTType {
        switch self {
        case .json: return .json
        case .csv: return .commaSeparatedText
        case .markdown: return UTType(filenameExtension: "md") ?? .plainText
        case .html: return .html
        }
    }
}

enum ExportManager {
    /// Exports history in the requested format.
    ///
    /// Clips marked sensitive are deliberately left out: an export is a plain
    /// file the user may email or sync, and decrypting secrets into it would
    /// defeat the point of encrypting them.
    static func export(items: [ClipboardItem], format: ExportFormat) -> Data? {
        let exportable = items.filter { !$0.isSensitive }
        switch format {
        case .json: return json(exportable)
        case .csv: return csv(exportable).data(using: .utf8)
        case .markdown: return markdown(exportable).data(using: .utf8)
        case .html: return html(exportable).data(using: .utf8)
        }
    }

    /// `ISO8601DateFormatter` is thread-safe for formatting; we only ever read from it.
    nonisolated(unsafe) private static let dateFormatter = ISO8601DateFormatter()

    private static func json(_ items: [ClipboardItem]) -> Data? {
        let payload: [[String: Any]] = items.map { item in
            [
                "id": item.id.uuidString,
                "type": item.contentType,
                "title": item.displayTitle,
                "text": item.body ?? "",
                "url": item.url ?? "",
                "extractedText": item.extractedText ?? "",
                "source": item.sourceApp ?? "",
                "category": item.category,
                "tags": item.tags,
                "favorite": item.isFavorite,
                "createdAt": dateFormatter.string(from: item.createdAt)
            ]
        }
        return try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    private static func csv(_ items: [ClipboardItem]) -> String {
        var rows = ["ID,Type,Text,URL,Source,Category,Tags,Favourite,Date"]
        for item in items {
            let fields = [
                item.id.uuidString,
                item.contentType,
                item.body ?? "",
                item.url ?? "",
                item.sourceApp ?? "",
                item.category,
                item.tags.joined(separator: " "),
                item.isFavorite ? "yes" : "no",
                dateFormatter.string(from: item.createdAt)
            ]
            rows.append(fields.map(escapeCSV).joined(separator: ","))
        }
        return rows.joined(separator: "\n") + "\n"
    }

    /// Quotes a CSV field and doubles embedded quotes, so text containing commas,
    /// quotes or newlines survives a round trip through a spreadsheet.
    private static func escapeCSV(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func markdown(_ items: [ClipboardItem]) -> String {
        var output = "# CopyWell Export\n\nExported \(Date().formatted(date: .long, time: .shortened))\n\n"
        for item in items {
            output += "## \(item.displayTitle)\n\n"
            output += "- Type: \(item.type.displayName)\n"
            output += "- Source: \(item.sourceApp ?? L("Unknown"))\n"
            output += "- Date: \(item.createdAt.formatted(date: .abbreviated, time: .shortened))\n"
            if !item.tags.isEmpty { output += "- Tags: \(item.tags.joined(separator: ", "))\n" }
            output += "\n"
            if let body = item.body, !body.isEmpty {
                output += "```\n\(body)\n```\n\n"
            } else if let url = item.url {
                output += "<\(url)>\n\n"
            }
            output += "---\n\n"
        }
        return output
    }

    private static func html(_ items: [ClipboardItem]) -> String {
        var output = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <title>CopyWell Export</title>
        <style>
          :root { color-scheme: light dark; }
          body { font: 15px/1.5 -apple-system, system-ui, sans-serif; max-width: 760px; margin: 2rem auto; padding: 0 1rem; }
          .clip { border: 1px solid color-mix(in srgb, currentColor 18%, transparent); border-radius: 8px; padding: 1rem; margin: 0.75rem 0; }
          .meta { color: color-mix(in srgb, currentColor 55%, transparent); font-size: 0.85em; }
          pre { white-space: pre-wrap; word-break: break-word; margin: 0.5rem 0 0; }
        </style>
        </head>
        <body>
        <h1>CopyWell Export</h1>
        """
        for item in items {
            output += "<div class=\"clip\"><strong>\(escapeHTML(item.displayTitle))</strong>"
            output += "<div class=\"meta\">\(escapeHTML(item.type.displayName)) · \(escapeHTML(item.sourceApp ?? L("Unknown"))) · \(escapeHTML(item.createdAt.formatted()))</div>"
            if let body = item.body, !body.isEmpty {
                output += "<pre>\(escapeHTML(body))</pre>"
            } else if let url = item.url {
                output += "<p><a href=\"\(escapeHTML(url))\">\(escapeHTML(url))</a></p>"
            }
            output += "</div>"
        }
        return output + "\n</body>\n</html>\n"
    }

    /// Clip text is arbitrary user content and goes straight into markup —
    /// escaping it is not optional.
    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
