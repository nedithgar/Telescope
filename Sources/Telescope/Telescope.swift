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
        guard let endLimitIndex = text.index(text.startIndex, offsetBy: maxCharacters, limitedBy: text.endIndex) else {
            // String shorter than limit – return whole thing.
            return text[...]
        }

        let limitedSlice = text[..<endLimitIndex] // Substring limited to maxCharacters

        // Prioritized backward scan for a natural cut point:
        //  1. Newline (paragraph break) -> strongest semantic boundary
        //  2. Sentence punctuation (. ! ? ; :) -> next best
        //  3. Any remaining whitespace or punctuation -> fallback soft boundary
        // Limit the scan window to avoid pathological cost on huge inputs.
        let backwardScanLimit = 512
        let whitespaceAndPunctuation = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        let newlineCharacterSet = CharacterSet.newlines
        let sentenceTerminators: Set<Character> = [".", "!", "?", ";", ":"] // extendable

        var sentenceBoundaryIndex: String.Index? = nil
        var softBoundaryIndex: String.Index? = nil

        var scanIndex = limitedSlice.endIndex
        var scannedCharacters = 0
        while scanIndex > limitedSlice.startIndex && scannedCharacters < backwardScanLimit {
            scannedCharacters += 1
            scanIndex = text.index(before: scanIndex)
            let character = text[scanIndex]

            // Priority 1: newline
            if character.unicodeScalars.allSatisfy({ newlineCharacterSet.contains($0) }) {
                return text[..<scanIndex]
            }
            // Priority 2: sentence terminator
            if sentenceBoundaryIndex == nil && sentenceTerminators.contains(character) {
                sentenceBoundaryIndex = scanIndex
                continue
            }
            // Priority 3: any whitespace or punctuation cluster
            if softBoundaryIndex == nil && character.unicodeScalars.allSatisfy({ whitespaceAndPunctuation.contains($0) }) {
                softBoundaryIndex = scanIndex
            }
        }

        if let sentenceBoundaryIndex { return text[..<sentenceBoundaryIndex] }
        if let softBoundaryIndex { return text[..<softBoundaryIndex] }
        // No boundary found in scan window – return hard slice.
        return limitedSlice
    }
}