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
        // If text is already within limit, return as-is
        if text.count <= maxCharacters {
            return text[...]
        }
        
        // Get the prefix up to the limit
        let truncated = text.prefix(maxCharacters)
        
        // Try to find the last word boundary (space, newline, or punctuation)
        let boundaryCharacters = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        
        // Search backwards from the end to find a good breaking point
        if let lastIndex = truncated.lastIndex(where: { char in
            char.unicodeScalars.allSatisfy { boundaryCharacters.contains($0) }
        }) {
            // Break at the word boundary
            return text[..<lastIndex]
        }
        
        // If no boundary found, just return the hard limit
        return truncated
    }
}