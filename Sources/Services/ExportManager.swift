import Foundation

struct ExportManager {
    static func exportToJSON(items: [ClipboardItem]) -> Data? {
        let exportData = items.map { item in
            ["id": item.id.uuidString, "text": item.text ?? "", "url": item.url ?? "",
             "type": item.contentType, "source": item.sourceApp ?? "",
             "date": ISO8601DateFormatter().string(from: item.createdAt)]
        }
        return try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }

    static func exportToCSV(items: [ClipboardItem]) -> String {
        var csv = "ID,Text,URL,Type,Source,Date\n"
        for item in items {
            let text = (item.text ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\"\(item.id.uuidString)\",\"\(text)\",\"\(item.url ?? "")\",\"\(item.contentType)\",\"\(item.sourceApp ?? "")\",\"\(ISO8601DateFormatter().string(from: item.createdAt))\"\n"
        }
        return csv
    }

    static func exportToMarkdown(items: [ClipboardItem]) -> String {
        var md = "# ClipStack Export\n\nExported: \(Date().formatted())\n\n---\n\n"
        for item in items {
            md += "## \(item.displayTitle)\n\n- **Type:** \(item.contentType)\n- **Source:** \(item.sourceApp ?? "Unknown")\n- **Date:** \(item.createdAt.formatted())\n\n"
            if let text = item.text { md += "```\n\(text)\n```\n\n" }
            else if let url = item.url { md += "Link: \(url)\n\n" }
            md += "---\n\n"
        }
        return md
    }

    static func exportToHTML(items: [ClipboardItem]) -> String {
        var html = "<!DOCTYPE html><html><head><title>ClipStack Export</title><style>body{font-family:-apple-system,sans-serif;max-width:800px;margin:0 auto;padding:20px}.item{border:1px solid #ddd;border-radius:8px;padding:16px;margin:12px 0}</style></head><body><h1>📋 ClipStack Export</h1>"
        for item in items {
            html += "<div class=\"item\"><h3>\(item.displayTitle)</h3><p>\(item.contentType) • \(item.sourceApp ?? "Unknown")</p>"
            if let text = item.text { html += "<pre>\(text)</pre>" }
            html += "</div>"
        }
        return html + "</body></html>"
    }
}
