import Foundation
import MCP
import ScrubberKit

/// Lightweight document representation to avoid exposing ScrubberKit internals directly
public struct SearchDocument: Codable, Sendable {
    public let title: String
    public let url: String
    public let plainText: String
    
    public init(title: String, url: String, plainText: Substring) {
        self.title = title
        self.url = url
        self.plainText = String(plainText)
    }
}

/// Service for performing web searches using ScrubberKit
public struct TelescopeSearchService: Sendable {
    
    public init() {}
    
    /// Perform a web search and return cleaned document excerpts
    /// - Parameters:
    ///   - query: The search query keywords
    ///   - limit: Maximum number of documents to return (clamped between 10-20)
    /// - Returns: Array of search documents
    public func search(query: String, limit: Int = 10) async -> [SearchDocument] {
        let adjustedLimit: Int
        if limit < 10 {
            adjustedLimit = 10
        } else if limit > 20 {
            adjustedLimit = 20
        } else {
            adjustedLimit = limit
        }
        
        // ScrubberKit must be executed on main thread per its design (asserts)
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let scrubber = Scrubber(query: query)
                scrubber.run(limitation: adjustedLimit) { documents in
                    // Map to lightweight serializable structure using direct property access
                    let mappedDocuments = documents.map { document in
                        SearchDocument(
                            title: document.title,
                            url: document.url.absoluteString,
                            plainText: Self.truncateText(document.textDocument, maxCharacters: 20_000)
                        )
                    }
                    continuation.resume(returning: mappedDocuments)
                } onProgress: { _ in }
            }
        }
    }
    
    /// Format search results as text output
    /// - Parameters:
    ///   - query: The original search query
    ///   - documents: The search results to format
    /// - Returns: Formatted text output
    public func formatResults(query: String, documents: [SearchDocument]) -> String {
        var output = "Search results for: \(query)\n\n"
        for (index, document) in documents.enumerated() {
            output += "# Result \(index + 1): \(document.title)\nURL: \(document.url)\n\n"
            output += document.plainText + "\n\n"
        }
        return output
    }
    
    /// Intelligently truncate text to a maximum character count
    /// - Parameters:
    ///   - text: The text to truncate
    ///   - maxCharacters: Maximum number of characters (default: 20000)
    /// - Returns: Truncated text, preferably at a word boundary
    static func truncateText(_ text: String, maxCharacters: Int = 20_000) -> Substring {
        // Fast path: attempt to derive the end index without traversing the entire string.
        // Using index(_:offsetBy:limitedBy:) avoids an O(n) full count when the string is much longer.
        guard let hardEnd = text.index(text.startIndex, offsetBy: maxCharacters, limitedBy: text.endIndex) else {
            // String shorter than limit – return whole thing.
            return text[...]
        }

        let slice = text[..<hardEnd] // Substring limited to maxCharacters

        // Backward scan to find a word/punctuation boundary close to the end.
        // Limit how far we scan backwards to avoid pathological O(k) cost on very large inputs.
        // 512 is an empirical balance: usually finds a boundary quickly due to frequent whitespace.
        let maxBackwardScan = 512
        let boundarySet: CharacterSet = {
            // Static-like cached set (captures once). Allocation cost negligible vs large text handling.
            CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        }()

        var current = slice.endIndex
        var scanned = 0
        while current > slice.startIndex && scanned < maxBackwardScan {
            scanned += 1
            current = text.index(before: current)
            let currentCharacter = text[current]
            // If every scalar is boundary, we cut there (excluding that boundary char itself)
            if currentCharacter.unicodeScalars.allSatisfy({ boundarySet.contains($0) }) {
                return text[..<current]
            }
        }

        // Fallback: no boundary found in the scan window; return the hard slice.
        return slice
    }
}