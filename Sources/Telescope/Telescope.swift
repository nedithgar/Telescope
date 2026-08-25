import Foundation
import MCP
import ScrubberKit

/// Website content representations exposed by Telescope.
public enum DocumentContentFormat: String, CaseIterable, Codable, Sendable {
    /// Rendered page content converted to Markdown. Falls back to plain text when empty.
    case markdown
    /// Rendered page content flattened to plain text.
    case text
    /// Rendered DOM serialized as HTML.
    case html
}

/// Lightweight document representation to avoid exposing ScrubberKit internals directly.
public struct SearchDocument: Codable, Sendable {
    public let title: String
    public let url: String
    public let content: String
    public let format: DocumentContentFormat
    
    public init(
        title: String,
        url: String,
        content: Substring,
        format: DocumentContentFormat
    ) {
        self.title = title
        self.url = url
        self.content = String(content)
        self.format = format
    }

    @available(*, deprecated, message: "Use content instead")
    public var plainText: String {
        content
    }

    @available(*, deprecated, message: "Use init(title:url:content:format:) instead")
    public init(title: String, url: String, plainText: Substring) {
        self.init(title: title, url: url, content: plainText, format: .text)
    }
}

struct SelectedDocumentContent: Equatable, Sendable {
    let content: String
    let format: DocumentContentFormat
}

/// Service for performing web searches using ScrubberKit
public struct TelescopeSearchService: Sendable {
    /// Whether to apply URL re-ranking when performing searches.
    /// Enabled by default. Can be disabled via server CLI flag `--disable-rerank`.
    private let useRerank: Bool
    /// Maximum number of results to keep per hostname when reranking (diversity cap).
    /// Defaults to 2 under balanced profile. Set to nil to disable capping.
    private let rerankKeepPerHostname: Int?
    
    public init(useRerank: Bool = true, rerankKeepPerHostname: Int? = 2) {
        self.useRerank = useRerank
        self.rerankKeepPerHostname = rerankKeepPerHostname
    }
    
    /// Perform a web search and return cleaned document excerpts
    /// - Parameters:
    ///   - query: The search query keywords
    ///   - limit: Maximum number of documents to return (clamped between 10-20)
    ///   - format: Content representation to return. Defaults to Markdown.
    /// - Returns: Array of search documents
    public func search(
        query: String,
        limit: Int = 10,
        format: DocumentContentFormat = .markdown
    ) async -> [SearchDocument] {
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
                let scrubber: Scrubber
                if useRerank {
                    // Balanced profile tuning:
                    // - Reweights semantic relevance vs structural signals
                    // - Adds per-host diversity cap (default 2)
                    // - Slightly compresses score range and raises semantic weight
                    let reranker = URLsReranker(
                        freqFactor: 0.35,
                        hostnameBoostFactor: 0.40,
                        pathBoostFactor: 0.25,
                        decayFactor: 0.65,
                        bm25RerankFactor: 1.20,
                        minBoost: 0.10,
                        maxBoost: 4.0,
                        question: query,
                        keepKPerHostname: rerankKeepPerHostname
                    )
                    let options = Scrubber.ScrubberOptions(urlsReranker: reranker)
                    scrubber = Scrubber(query: query, options: options)
                } else {
                    scrubber = Scrubber(query: query)
                }
                scrubber.run(limitation: adjustedLimit) { documents in
                    // Map to a lightweight serializable structure using the requested representation.
                    let mappedDocuments = documents.map { document in
                        // ScrubberKit materializes and stores all representations before invoking
                        // this completion handler, so these property reads trigger no conversions.
                        let selectedContent = Self.selectContent(
                            format: format,
                            html: document.document,
                            text: document.textDocument,
                            markdown: document.markdownDocument
                        )
                        // Every representation is returned as a size-bounded excerpt. In particular,
                        // truncated HTML is not guaranteed to remain a balanced, standalone document.
                        return SearchDocument(
                            title: document.title,
                            url: document.url.absoluteString,
                            content: Self.truncateText(selectedContent.content, maxCharacters: 20_000),
                            format: selectedContent.format
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
            output += document.content + "\n\n"
        }
        return output
    }

    /// Select the requested ScrubberKit representation.
    /// Markdown falls back to plain text when conversion produces no usable content.
    static func selectContent(
        format: DocumentContentFormat,
        html: String,
        text: String,
        markdown: String
    ) -> SelectedDocumentContent {
        switch format {
        case .markdown:
            guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .init(content: text, format: .text)
            }
            return .init(content: markdown, format: .markdown)
        case .text:
            return .init(content: text, format: .text)
        case .html:
            return .init(content: html, format: .html)
        }
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
